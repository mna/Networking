import Socket

class Server {
  let port: Int
  let path: String

  init(port: Int) {
    self.port = port
    self.path = ""
  }

  init(path: String) {
    self.path = path
    self.port = 0
  }

  func run(_ fn: (_ s: Socket) throws -> Void) throws {
    let sock = path.isEmpty ? try Socket.create() : try Socket.create(family: .unix, proto: .unix)

    if path.isEmpty {
      try sock.listen(on: port)
    } else {
      try sock.listen(on: path)
    }

    while true {
      let client = try sock.acceptClientConnection()
      do {
        defer { client.close() }
        try fn(client)
      } catch {
        // if fn throws, close the server
        sock.close()
        return
      }
    }
  }
}
