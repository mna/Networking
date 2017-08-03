import Libc

// to avoid ambiguity in Socket.close (where close refers to the Socket method
// instead of the libc/darwin system call).
private var cclose = close

// MARK: - Socket

class Socket {
  private static func getOption(fd: Int32, option: Int32) throws -> Int32 {
    var v: Int32 = 0
    var len = socklen_t(MemoryLayout<Int32>.size)

    let ret = getsockopt(fd, SOL_SOCKET, option, &v, &len)
    try Error.makeAndThrow(fromReturnCode: ret)
    return v
  }

  private static func setFcntl(fd: Int32, flag: Int32) throws {
    let flags = fcntl(fd, F_GETFL)
    try Error.makeAndThrow(fromReturnCode: flags)

    // if flag is negative, unset the flag
    let new = flag >= 0 ? (flags | flag) : (flags & ~(-flag))

    let ret = fcntl(fd, F_SETFL, new)
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  // MARK: - Properties

  let fd: Int32
  let family: Family
  let type: SocketType
  let proto: SocketProtocol
  private(set) var isBlocking: Bool = true // blocking by default

  // MARK: - Constructors

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
    self.family = Family.make(try Socket.getOption(fd: fd, option: SO_DOMAIN))
    self.proto = SocketProtocol.make(try Socket.getOption(fd: fd, option: SO_PROTOCOL))
    #else
    self.family = .unknown
    self.proto = .unknown
    #endif

    self.type = SocketType.make(try Socket.getOption(fd: fd, option: SO_TYPE))
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  func setBlocking() throws {
    try Socket.setFcntl(fd: fd, flag: -O_NONBLOCK)
  }

  func setNonBlocking() throws {
    try Socket.setFcntl(fd: fd, flag: O_NONBLOCK)
  }

  func close() throws {
    let ret = cclose(fd)
    try Error.makeAndThrow(fromReturnCode: ret)
  }
}

