struct Address: Equatable {
  let ip: IPAddress
  let port: Int
  let scopeID: Int

  static func ==(lhs: Address, rhs: Address) -> Bool {
    return lhs.ip == rhs.ip &&
      lhs.port == rhs.port &&
      lhs.scopeID == rhs.scopeID
  }

  init(ip: IPAddress, port: Int, scopeID: Int = 0) {
    self.ip = ip
    self.port = port
    self.scopeID = scopeID
  }
}
