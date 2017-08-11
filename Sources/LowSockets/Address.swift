import Libc

// MARK: - Address

/// Address is a resolved network address, consisting of an IP address
/// and a port, and if it is an IPv6 address, possibly a scope ID (zone).
public struct Address: Equatable {
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

  // MARK: - Properties

  public let ip: IPAddress
  public let port: Int
  public let scopeID: Int

  public static func ==(lhs: Address, rhs: Address) -> Bool {
    return lhs.ip == rhs.ip &&
      lhs.port == rhs.port &&
      lhs.scopeID == rhs.scopeID
  }

  init(ip: IPAddress, port: Int, scopeID: Int = 0) {
    self.ip = ip
    self.port = port
    self.scopeID = scopeID
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
    self.init(ip: ip, port: port)
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
    self.init(ip: ip, port: port, scopeID: scopeID)
  }
}
