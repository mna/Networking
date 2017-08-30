import OS
@testable import LowSockets

extension Socket {

  // MARK: Socket.bind overloads

  mutating func bind(to addr: String) throws {
    if addr.contains("/") {
      try bind(toPath: addr)
    } else {
      try bind(toHostPort: addr)
    }
  }

  mutating func bind(toPath path: String) throws {
    guard let addr = Address(path: path) else {
      throw MessageError("path too long", context: ["path": path])
    }
    try bind(to: addr)
  }

  mutating func bind(toHostPort hostPort: String) throws {
    let (host, service) = try Address.split(hostPort: hostPort)
    try bind(toHost: host, service: service)
  }

  mutating func bind(toHost host: String, service: String) throws {
    let host = host.isEmpty ? nil : host
    let flags: Address.Flags = host == nil ? [.default, .passive] : .default
    let (_, addrs) = try Address.resolve(host: host, service: service, flags: flags, family: family, type: type, proto: proto)

    guard let first = addrs.first else {
      throw MessageError("no address found", context: ["host": host ?? "", "service": service])
    }
    try bind(to: first)
  }

  mutating func bind(toHost host: String, port: Int) throws {
    try bind(toHost: host, service: String(port))
  }

  // MARK: - Socket.connect overloads

  func connect(to addr: String) throws {
    if addr.contains("/") {
      try connect(toPath: addr)
    } else {
      try connect(toHostPort: addr)
    }
  }

  func connect(toPath path: String) throws {
    guard let addr = Address(path: path) else {
      throw MessageError("path too long", context: ["path": path])
    }
    try connect(to: addr)
  }

  func connect(toHostPort hostPort: String) throws {
    let (host, service) = try Address.split(hostPort: hostPort)
    try connect(toHost: host, service: service)
  }

  func connect(toHost host: String, service: String) throws {
    // needs to call getaddrinfo to resolve address
    let (_, addrs) = try Address.resolve(host: host, service: service, family: family, type: type, proto: proto)
    guard let first = addrs.first else {
      throw MessageError("no address found", context: ["host": host])
    }
    try connect(to: first)
  }

  func connect(toHost host: String, port: Int) throws {
    try connect(toHost: host, service: String(port))
  }
}
