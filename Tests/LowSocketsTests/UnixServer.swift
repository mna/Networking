import Libc
import OS
import LowSockets

// MARK: - UnixServer

class UnixServer {
  let path: String
  var sock: Socket? = nil

  init(_ path: String) {
    self.path = path
  }

  deinit {
    try? sock?.close()
    unlink(path)
  }

  func listen() throws {
    var sock = try Socket(family: .unix)
    try sock.setOption(SO_REUSEADDR, to: 1)

    try sock.bind(to: path)
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
