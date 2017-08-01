import Libc

// to avoid ambiguity in _Socket.close (where close refers to the _Socket method
// instead of the libc/darwin system call).
private var cclose = close

class _Socket {
  private static func getOption(fd: Int32, option: Int32) throws -> Int32 {
    var v: Int32 = 0
    var len = socklen_t(MemoryLayout<Int32>.size)

    let ret = getsockopt(fd, SOL_SOCKET, option, &v, &len)
    try Error.makeAndThrow(fromReturnCode: ret)
    return v
  }

  private let fd: Int32
  private let family: Family
  private let type: SocketType
  private let proto: SocketProtocol

  init(family: Family = .ip4, type: SocketType = .stream, proto: SocketProtocol = .tcp) throws {
    let fd = socket(family.value, type.value, proto.value)
    try Error.makeAndThrow(fromReturnCode: fd)

    self.fd = fd
    self.family = family
    self.type = type
    self.proto = proto
  }

  init(fd: Int32) throws {
    self.fd = fd

    #if os(Linux)
    self.family = Family.make(try _Socket.getOption(fd: fd, option: SO_DOMAIN))
    self.proto = SocketProtocol.make(try _Socket.getOption(fd: fd, option: SO_PROTOCOL))
    #else
    self.family = .unknown
    self.proto = .unknown
    #endif

    self.type = SocketType.make(try _Socket.getOption(fd: fd, option: SO_TYPE))
  }

  func close() throws {
    let ret = cclose(fd)
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  deinit {
    try? close()
  }
}

