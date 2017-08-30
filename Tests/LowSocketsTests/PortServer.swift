import Libc
import OS
import LowSockets

// MARK: - PortServer

class PortServer {
  let port: Int
  let host: String
  let family: Family

  var sock: Socket? = nil

  init(_ host: String, _ port: Int, family: Family = .inet) {
    self.family = family
    self.host = host
    self.port = port
  }

  deinit {
    try? sock?.close()
  }

  func listen() throws {
    var sock = try Socket(family: family)
    try sock.setOption(SO_REUSEADDR, to: 1)
    try sock.setOption(SO_REUSEPORT, to: 1)

    try sock.bind(toHost: host, port: port)
    try sock.listen()
    self.sock = sock
  }

  func serveOne(_ handler: (Socket) throws -> Void) throws {
    guard let sock = sock else {
      throw MessageError("no listening socket")
    }
    var remote = try sock.accept()
    defer { try? remote.close() }
    try handler(remote)
  }
}
