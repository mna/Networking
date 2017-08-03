import LowSockets

struct Resolver {
  static func lookupPort(forService service: String, network: Network) throws -> Int {
    if let port = Int(service) {
      if port < 0 || port > 65535 {
        throw Error("invalid port", context: ["service": service])
      }
      return port
    }

    return 0
  }
}
