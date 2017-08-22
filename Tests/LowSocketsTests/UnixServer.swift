import Libc
import LowSockets

// MARK: - UnixServer

class UnixServer {
  let path: String
  private(set) var sock: Socket? = nil

  init(_ path: String) {
    self.path = path
  }

  deinit {
    try? sock?.close()
    unlink(path)
  }

  func listen() throws {
    let sock = try Socket(family: .unix)
    try sock.setOption(SO_REUSEADDR, to: 1)
    self.sock = sock

    try sock.bind(to: path)
    try sock.listen()
  }

  func serveOne(_ handler: (Socket) throws -> Void) throws {
    guard let sock = sock else {
      throw MessageError("no listening socket")
    }
    let remote = try sock.accept()
    defer { try? remote.close() }
    try handler(remote)
  }
}
