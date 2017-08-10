import LowSockets

// MARK: - Resolver

/// Resolver performs various host, address and port parsing and DNS resolutions.
struct Resolver {
  private init() { }

  /// Returns the canonical name for host.
  static func lookupCNAME(forHost host: String) throws -> String {
    let (cname, _) = try AddrInfo.get(host: host, flags: [.default, .canonName], type: .stream)
    return cname
  }

  /// Returns a list of IP addresses for the specified host name.
  static func lookupIP(forHost host: String) throws -> [IPAddress] {
    let (_, addrs) = try AddrInfo.get(host: host, type: .stream)
    return addrs.map({ $0.ip })
  }

  /// Returns the port number corresponding to the service name and network family and protocol.
  static func lookupPort(forService service: String, family: Family = .unspec, proto: SocketProtocol = .tcp) throws -> Int {
    let checkValidRange = { (port: Int) throws in
      if port < 0 || port > 65535 {
        throw MessageError("invalid port", context: ["service": service])
      }
    }

    if let port = Int(service) {
      try checkValidRange(port)
      return port
    }

    let (_, addrs) = try AddrInfo.get(service: service, family: family, proto: proto)
    for addr in addrs {
      if addr.port > 0 {
        try checkValidRange(addr.port)
        return addr.port
      }
    }
    throw MessageError("unkown service", context: ["service": service])
  }
}
