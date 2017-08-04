import Libc

// MARK: - Resolver

struct Resolver {
  private init() { }

  /// Combines host and port into a network address of the form
  /// "host:port" or "[host]:port" if the host contains a colon
  /// or a percent sign.
  static func join(host: String, port: String) -> String {
    if host.contains(":") || host.contains("%") {
      return "[\(host)]:\(port)"
    }
    return "\(host):\(port)"
  }

  /// Splits a network address of the form "host:port", "[host]:port"
  /// or "[ipv6-host%zone]:port" into host or ipv6-host%zone and port.
  static func split(hostPort: String) throws -> (String, String) {
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

  static func lookupIP(forHost host: String) throws -> [IPAddress] {
    var hints = addrinfo()

    hints.ai_socktype = SocketType.stream.value

    var addrs: [IPAddress] = []
    do {
      var info: UnsafeMutablePointer<addrinfo>?
      defer {
        if info != nil { freeaddrinfo(info) }
      }

      let ret = getaddrinfo(host, nil, &hints, &info)
      try CError.makeAndThrow(fromGAICode: ret)

      var list = info
      while true {
        guard let addr = list else {
          break
        }

        switch addr.pointee.ai_family {
        case Family.ip4.value:
          let bytes: [UInt8] = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sai in
            let count = MemoryLayout.stride(ofValue: sai.pointee.sin_addr)
            return withUnsafePointer(to: &sai.pointee.sin_addr) { sad in
              return sad.withMemoryRebound(to: UInt8.self, capacity: count) {
                Array(UnsafeBufferPointer(start: $0, count: count))
              }
            }
          }
          if let ip = IPAddress(bytes: bytes) {
            addrs.append(ip)
          }

        case Family.ip6.value:
          let bytes: [UInt8] = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sai in
            let count = MemoryLayout.stride(ofValue: sai.pointee.sin6_addr)
            return withUnsafePointer(to: &sai.pointee.sin6_addr) { sad in
              return sad.withMemoryRebound(to: UInt8.self, capacity: count) {
                Array(UnsafeBufferPointer(start: $0, count: count))
              }
            }
          }
          if let ip = IPAddress(bytes: bytes) {
            addrs.append(ip)
          }

        default:
          break
        }
        list = addr.pointee.ai_next
      }
    }

    return addrs
  }

  static func lookupPort(forService service: String, family: Family = .unknown, proto: SocketProtocol = .tcp) throws -> Int {
    let checkValidRange = { (port: Int) throws in
      if port < 0 || port > 65535 {
        throw MessageError("invalid port", context: ["service": service])
      }
    }

    if let port = Int(service) {
      try checkValidRange(port)
      return port
    }

    var hints = addrinfo()
    switch family {
    case Family.ip4, Family.ip6:
      hints.ai_family = family.value
    case Family.unknown:
      hints.ai_family = AF_UNSPEC
    default:
      throw MessageError("invalid network", context: ["service": service])
    }

    switch proto {
    case SocketProtocol.tcp:
      hints.ai_protocol = proto.value
      hints.ai_socktype = SocketType.stream.value
    case SocketProtocol.udp:
      hints.ai_protocol = proto.value
      hints.ai_socktype = SocketType.datagram.value
    case SocketProtocol.unknown:
      // no hints
      break
    default:
      throw MessageError("invalid protocol", context: ["service": service])
    }

    do {
      var info: UnsafeMutablePointer<addrinfo>?
      defer {
        if info != nil { freeaddrinfo(info) }
      }

      let ret = getaddrinfo(nil, service.lowercased(), &hints, &info)
      try CError.makeAndThrow(fromGAICode: ret)

      var list = info
      while true {
        guard let addr = list else {
          break
        }

        switch addr.pointee.ai_family {
        case Family.ip4.value:
          let port = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ptr in
            return Int(Endianness.ntoh(ptr.pointee.sin_port))
          }
          try checkValidRange(port) // can still be out of range, apparently
          return port

        case Family.ip6.value:
          let port = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { ptr in
            return Int(Endianness.ntoh(ptr.pointee.sin6_port))
          }
          try checkValidRange(port) // can still be out of range, apparently
          return port

        default:
          break
        }
        list = addr.pointee.ai_next
      }
    }

    throw MessageError("unkown service", context: ["service": service])
  }
}
