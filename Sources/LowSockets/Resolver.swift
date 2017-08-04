import Libc

// MARK: - Resolver

struct Resolver {
  private init() { }

  // Combines host and port into a network address of the form
  // "host:port" or "[host]:port" if the host contains a colon
  // or a percent sign.
  static func join(host: String, port: String) -> String {
    if host.contains(":") || host.contains("%") {
      return "[\(host)]:\(port)"
    }
    return "\(host):\(port)"
  }

  static func split(hostPort: String) throws -> (String, String) {
    return ("", "")
  }

  static func lookupPort(forService service: String, family: Family = .unknown, proto: SocketProtocol = .tcp) throws -> Int {
    if let port = Int(service) {
      if port < 0 || port > 65535 {
        throw MessageError("invalid port", context: ["service": service])
      }
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
            return Endianness.ntoh(ptr.pointee.sin_port)
          }
          return Int(port)

        case Family.ip6.value:
          let port = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { ptr in
            return Endianness.ntoh(ptr.pointee.sin6_port)
          }
          return Int(port)

        default:
          break
        }
        list = addr.pointee.ai_next
      }
    }

    throw MessageError("unkown service", context: ["service": service])
  }
}
