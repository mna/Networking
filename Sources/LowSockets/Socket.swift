import Libc
import Foundation

// to avoid ambiguity between the Socket methods and the libc/darwin system calls.
private var cclose = close
private var clisten = listen
private var cshutdown = shutdown

// MARK: - Socket

class Socket {

  // MARK: - Static Methods

  private static func getOption(fd: Int32, option: Int32) throws -> Int32 {
    var v: Int32 = 0
    var len = socklen_t(MemoryLayout<Int32>.size)

    let ret = getsockopt(fd, SOL_SOCKET, option, &v, &len)
    try Error.makeAndThrow(fromReturnCode: ret)
    return v
  }

  private static func getTimevalOption(fd: Int32, option: Int32) throws -> TimeInterval {
    var val = timeval()
    var len = socklen_t(MemoryLayout<timeval>.stride)

    let ret = getsockopt(fd, SOL_SOCKET, option, &val, &len)
    try Error.makeAndThrow(fromReturnCode: ret)

    let secs = Int(val.tv_sec)
    let us = Int(val.tv_usec)
    let t = TimeInterval(Double(secs) + (Double(us) / 1_000_000))

    return t
  }

  private static func getLingerOption(fd: Int32) throws -> TimeInterval? {
    var val = linger()
    var len = socklen_t(MemoryLayout<linger>.stride)

    #if os(Linux)
      let option = SO_LINGER
    #else
      let option = SO_LINGER_SEC
    #endif

    let ret = getsockopt(fd, SOL_SOCKET, option, &val, &len)
    try Error.makeAndThrow(fromReturnCode: ret)

    if val.l_onoff == 0 {
      return nil
    }
    return TimeInterval(val.l_linger)
  }

  private static func setOption(fd: Int32, option: Int32, value: Int32) throws {
    var v = value
    let ret = setsockopt(fd, SOL_SOCKET, option, &v, socklen_t(MemoryLayout<Int32>.size))
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  private static func setTimevalOption(fd: Int32, option: Int32, t: TimeInterval) throws {
    var val = timeval()

    // see https://stackoverflow.com/a/28872601/1094941
    if t > 0 {
      val.tv_sec = Int(t)

      let us = Int(t.truncatingRemainder(dividingBy: 1) * 1_000_000)
      #if os(Linux)
				val.tv_usec = Int(us)
			#else
				val.tv_usec = Int32(us)
			#endif
    }

		let ret = setsockopt(fd, SOL_SOCKET, option, &val, socklen_t(MemoryLayout<timeval>.stride))
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  private static func setLingerOption(fd: Int32, t: TimeInterval?) throws {
    var val = linger()

    val.l_onoff = t == nil ? 0 : 1
    val.l_linger = 0
    if let t = t, t > 0 {
      let secs = Int32(t)
      val.l_linger = secs
    }

    #if os(Linux)
      let option = SO_LINGER
    #else
      let option = SO_LINGER_SEC
    #endif

		let ret = setsockopt(fd, SOL_SOCKET, option, &val, socklen_t(MemoryLayout<linger>.stride))
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  private static func getFcntl(fd: Int32) throws -> Int32 {
    let flags = fcntl(fd, F_GETFL)
    try Error.makeAndThrow(fromReturnCode: flags)
    return flags
  }

  private static func setFcntl(fd: Int32, flag: Int32) throws {
    let flags = try getFcntl(fd: fd)

    // if flag is negative, unset the flag
    let new = flag >= 0 ? (flags | flag) : (flags & ~(-flag))

    let ret = fcntl(fd, F_SETFL, new)
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  // MARK: - ShutdownMode

  struct ShutdownMode {
    let value: Int32

    private init(value: Int32) {
      self.value = value
    }

    static let read = ShutdownMode(value: SHUT_RD)
    static let write = ShutdownMode(value: SHUT_WR)
    static let readWrite = ShutdownMode(value: SHUT_RDWR)
  }

  // MARK: - Properties

  let fd: Int32
  let family: Family
  let type: SocketType
  let proto: SocketProtocol

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

  func setOption(_ option: Int32, to value: Int) throws {
    try Socket.setOption(fd: fd, option: option, value: Int32(value))
  }

  func getOption(_ option: Int32) throws -> Int {
    return Int(try Socket.getOption(fd: fd, option: option))
  }

  func setReadTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fd, option: SO_RCVTIMEO, t: t)
  }

  func getReadTimeout() throws -> TimeInterval {
    return try Socket.getTimevalOption(fd: fd, option: SO_RCVTIMEO)
  }

  func setWriteTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fd, option: SO_SNDTIMEO, t: t)
  }

  func getWriteTimeout() throws -> TimeInterval {
    return try Socket.getTimevalOption(fd: fd, option: SO_SNDTIMEO)
  }

  func setLinger(timeout: TimeInterval?) throws {
    try Socket.setLingerOption(fd: fd, t: timeout)
  }

  func getLinger() throws -> TimeInterval? {
    return try Socket.getLingerOption(fd: fd)
  }

  func setBlocking() throws {
    try Socket.setFcntl(fd: fd, flag: -O_NONBLOCK)
  }

  func setNonBlocking() throws {
    try Socket.setFcntl(fd: fd, flag: O_NONBLOCK)
  }

  func isBlocking() throws -> Bool {
    let flags = try Socket.getFcntl(fd: fd)
    return (flags & O_NONBLOCK) == 0
  }

  func listen(backlog: Int) throws {
    let ret = clisten(fd, Int32(backlog))
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  func shutdown(mode: ShutdownMode = .readWrite) throws {
    let ret = cshutdown(fd, mode.value)
    try Error.makeAndThrow(fromReturnCode: ret)
  }

  func close() throws {
    let ret = cclose(fd)
    try Error.makeAndThrow(fromReturnCode: ret)
  }
}
