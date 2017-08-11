import Libc

// MARK: - Address

/// Address is a resolved network address.
public enum Address {
  /// Combines host and port into a network address of the form
  /// "host:port" or "[host]:port" if the host contains a colon
  /// or a percent sign.
  public static func join(host: String, port: String) -> String {
    if host.contains(":") || host.contains("%") {
      return "[\(host)]:\(port)"
    }
    return "\(host):\(port)"
  }

  /// Splits a network address of the form "host:port", "[host]:port"
  /// or "[ipv6-host%zone]:port" into host or ipv6-host%zone and port.
  public static func split(hostPort: String) throws -> (String, String) {
    let chars = [Character](hostPort.characters)
    // get the index of the last colon
    guard let lastColon = chars.reversed().index(of: ":") else {
      throw MessageError("missing port", context: ["hostPort": hostPort])
    }

    // translate backward index to forward one
    let portColon = lastColon.base - 1
    var (open, close) = (0, 0)

    let host: String
    if chars[0] == "[" {
      // find the closing ']'
      guard let closeBracket = chars.index(of: "]") else {
        throw MessageError("missing ']' in address", context: ["hostPort": hostPort])
      }

      switch closeBracket + 1 {
      case chars.count:
        // there can't be a ":" after the "]"
        throw MessageError("missing port", context: ["hostPort": hostPort])
      case portColon:
        // expected
        break
      default:
        // "]" is not followed by the last colon
        if chars[closeBracket + 1] == ":" {
          throw MessageError("too many colons", context: ["hostPort": hostPort])
        }
        throw MessageError("missing port", context: ["hostPort": hostPort])
      }

      host = String(chars[1..<closeBracket])
      (open, close) = (1, closeBracket + 1) // can't be a '[' / ']' before those indices

    } else {

      let hostSlice = chars[0..<portColon]
      if hostSlice.index(of: ":") != nil {
        throw MessageError("too many colons", context: ["hostPort": hostPort])
      }
      if hostSlice.index(of: "%") != nil {
        throw MessageError("missing brackets", context: ["hostPort": hostPort])
      }

      host = String(hostSlice)
    }

    if chars[open..<chars.count].index(of: "[") != nil {
      throw MessageError("unexpected '['", context: ["hostPort": hostPort])
    }
    if chars[close..<chars.count].index(of: "]") != nil {
      throw MessageError("unexpected ']'", context: ["hostPort": hostPort])
    }

    let port = String(chars[(portColon+1)..<chars.count])
    return (host, port)
  }

  private static var maxUnixPathLen: Int = {
    let sa = sockaddr_un()
    return MemoryLayout.size(ofValue: sa.sun_path)
  }()

  // MARK: - Enum Cases

  case ip4(ip: IPAddress, port: Int)
  case ip6(ip: IPAddress, port: Int, scopeID: Int)
  case unix(path: String)

  // MARK: - Constructors

  init?(ip: IPAddress, port: Int, scopeID: Int = 0) {
    switch ip.family {
    case .inet:
      self = .ip4(ip: ip, port: port)
    case .inet6:
      self = .ip6(ip: ip, port: port, scopeID: scopeID)
    default:
      return nil
    }
  }

  init?(path: String) {
    if path.utf8.count >= Address.maxUnixPathLen {
      return nil
    }
    self = .unix(path: path)
  }

  init?(sockaddr sa: sockaddr_in) {
    let port = Int(Endianness.ntoh(sa.sin_port))
    var sa = sa

    let count = MemoryLayout.stride(ofValue: sa.sin_addr)
    let bytes = withUnsafePointer(to: &sa.sin_addr) { sad in
      return sad.withMemoryRebound(to: UInt8.self, capacity: count) {
        return Array(UnsafeBufferPointer(start: $0, count: count))
      }
    }

    guard let ip = IPAddress(bytes: bytes) else {
      return nil
    }
    self = .ip4(ip: ip, port: port)
  }

  init?(sockaddr sa: sockaddr_in6) {
    let port = Int(Endianness.ntoh(sa.sin6_port))
    let scopeID = Int(sa.sin6_scope_id)
    var sa = sa

    let count = MemoryLayout.stride(ofValue: sa.sin6_addr)
    let bytes = withUnsafePointer(to: &sa.sin6_addr) { sad in
      return sad.withMemoryRebound(to: UInt8.self, capacity: count) {
        return Array(UnsafeBufferPointer(start: $0, count: count))
      }
    }

    guard let ip = IPAddress(bytes: bytes) else {
      return nil
    }
    self = .ip6(ip: ip, port: port, scopeID: scopeID)
  }

  init?(sockaddr sa: sockaddr_un) {
    var sa = sa

    let maybePath = withUnsafeMutablePointer(to: &sa.sun_path) { pathPtr in
      pathPtr.withMemoryRebound(to: CChar.self, capacity: Address.maxUnixPathLen) { arPtr in
        String(validatingUTF8: arPtr)
      }
    }

    guard let path = maybePath else {
      return nil
    }
    self = .unix(path: path)
  }

  // MARK: - Properties

  var family: Family {
    switch self {
    case .ip4(let ip, _):
      return ip.family
    case .ip6(let ip, _, _):
      return ip.family
    case .unix:
      return .unix
    }
  }

  // MARK: - Methods

  func withUnsafeSockaddrPointer<Result>(_ body: (UnsafePointer<sockaddr>, socklen_t) throws -> Result) rethrows -> Result {
    switch self {
    case .unix(let path):
      var sa = sockaddr_un()
      let len = MemoryLayout.stride(ofValue: sa)

      #if !os(Linux)
        sa.sun_len = UInt8(len)
      #endif

      #if os(Linux)
        sa.sun_family = UInt16(family.value)
      #else
        sa.sun_family = UInt8(family.value)
      #endif

      // set the path
      var chars = path.utf8.map({ CChar($0) })
      withUnsafeMutablePointer(to: &sa.sun_path) { pathPtr in
        pathPtr.withMemoryRebound(to: CChar.self, capacity: Address.maxUnixPathLen) { arPtr in
          let buf = UnsafeMutableBufferPointer<CChar>(start: arPtr, count: Address.maxUnixPathLen)
          for i in 0..<buf.count {
            if i < chars.count {
              buf[i] = chars[i]
            } else {
              buf[i] = CChar(0)
            }
          }
        }
      }
      let ret = try withUnsafePointer(to: &sa) { ptr in
        try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { (saPtr: UnsafePointer<sockaddr>) in
          try body(saPtr, socklen_t(len))
        }
      }
      return ret

    case .ip4(let ip, let port):
      var sa = sockaddr_in()
      let len = MemoryLayout.stride(ofValue: sa)

      #if os(Linux)
        sa.sin_family = UInt16(ip.family.value)
      #else
        sa.sin_len = UInt8(len)
        sa.sin_family = UInt8(ip.family.value)
      #endif
      sa.sin_port = UInt16(port).bigEndian

      let count = MemoryLayout.stride(ofValue: sa.sin_addr)
      withUnsafeMutablePointer(to: &sa.sin_addr) { sad in
        sad.withMemoryRebound(to: UInt8.self, capacity: count) { ar in
          let buf = UnsafeMutableBufferPointer(start: ar, count: count)
          for i in 0..<buf.count {
            buf[i] = ip.bytes[i]
          }
        }
      }

      let ret = try withUnsafePointer(to: &sa) { ptr in
        try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { (saPtr: UnsafePointer<sockaddr>) in
          try body(saPtr, socklen_t(len))
        }
      }
      return ret

    default:
      fatalError("not implemented")
    }
  }
}

// MARK: - Address+Equatable

extension Address: Equatable {
  public static func ==(lhs: Address, rhs: Address) -> Bool {
    switch (lhs, rhs) {
    case let (.ip4(lip, lport), .ip4(rip, rport)):
      return lip == rip && lport == rport
    case let (.ip6(lip, lport, lscope), .ip6(rip, rport, rscope)):
      return lip == rip && lport == rport && lscope == rscope
    case let (.unix(lpath), .unix(rpath)):
      return lpath == rpath
    default:
      return false
    }
  }
}
