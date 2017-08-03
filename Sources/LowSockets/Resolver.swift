import Libc

struct Resolver {
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

      let ret = getaddrinfo(nil, service, &hints, &info)
      try CError.makeAndThrow(fromGAICode: ret)
    }

    return 0
  }
}
