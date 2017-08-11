import Libc
import Foundation

// to avoid ambiguity between the Socket methods and the system calls.
private let caccept = accept
private let cbind = bind
private let cclose = close
private let cconnect = connect
private let clisten = listen
private let cshutdown = shutdown

// MARK: - Socket

class Socket: FileDescriptorRepresentable {

  // MARK: - Static Methods

  private static func getOption(fd: Int32, option: Int32) throws -> Int32 {
    var v: Int32 = 0
    var len = socklen_t(MemoryLayout<Int32>.size)

    let ret = getsockopt(fd, SOL_SOCKET, option, &v, &len)
    try CError.makeAndThrow(fromReturnCode: ret)
    return v
  }

  private static func getTimevalOption(fd: Int32, option: Int32) throws -> TimeInterval {
    var val = timeval()
    var len = socklen_t(MemoryLayout<timeval>.stride)

    let ret = getsockopt(fd, SOL_SOCKET, option, &val, &len)
    try CError.makeAndThrow(fromReturnCode: ret)

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
    try CError.makeAndThrow(fromReturnCode: ret)

    if val.l_onoff == 0 {
      return nil
    }
    return TimeInterval(val.l_linger)
  }

  private static func setOption(fd: Int32, option: Int32, value: Int32) throws {
    var v = value
    let ret = setsockopt(fd, SOL_SOCKET, option, &v, socklen_t(MemoryLayout<Int32>.size))
    try CError.makeAndThrow(fromReturnCode: ret)
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
    try CError.makeAndThrow(fromReturnCode: ret)
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
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  private static func getFcntl(fd: Int32) throws -> Int32 {
    let flags = fcntl(fd, F_GETFL)
    try CError.makeAndThrow(fromReturnCode: flags)
    return flags
  }

  private static func setFcntl(fd: Int32, flag: Int32) throws {
    let flags = try getFcntl(fd: fd)

    // if flag is negative, unset the flag
    let new = flag >= 0 ? (flags | flag) : (flags & ~(-flag))

    let ret = fcntl(fd, F_SETFL, new)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  // MARK: - ShutdownMode

  enum ShutdownMode {
    case read
    case write
    case readWrite

    var value: Int32 {
      guard let v = ShutdownMode.toValues[self] else {
        fatalError("unknown ShutdownMode enum: \(self)")
      }
      return v
    }

    static func make(_ value: Int32) -> ShutdownMode? {
      return fromValues[value]
    }

    private static let toValues: [ShutdownMode: Int32] = [
      .read: SHUT_RD,
      .write: SHUT_WR,
      .readWrite: SHUT_RDWR,
    ]

    private static let fromValues: [Int32: ShutdownMode] = [
      SHUT_RD: .read,
      SHUT_WR: .write,
      SHUT_RDWR: .readWrite,
    ]
  }

  // MARK: - Properties

  let fileDescriptor: Int32
  let family: Family?        // can be nil if created from existing FD and can't lookup family
  let proto: SocketProtocol? // idem
  let type: SocketType

  // MARK: - Constructors

  /// Creates an unconnected socket with the specified family, type and
  /// protocol properties.
  init(family: Family = .inet, type: SocketType = .stream, proto: SocketProtocol = .tcp) throws {
    let fd = socket(family.value, type.value, proto.value)
    try CError.makeAndThrow(fromReturnCode: fd)

    self.fileDescriptor = fd
    self.family = family
    self.type = type
    self.proto = proto
  }

  /// Creates a socket using an already existing socket's file descriptor.
  init(fd: Int32, family: Family? = nil) throws {
    self.fileDescriptor = fd

    // TODO: get protocol from family and socket type?
    #if os(Linux)
      self.family = family ?? Family.make(try Socket.getOption(fd: fileDescriptor, option: SO_DOMAIN))
      self.proto = SocketProtocol.make(try Socket.getOption(fd: fileDescriptor, option: SO_PROTOCOL))
    #else
      self.family = family
      self.proto = nil
    #endif

    let sockType = try Socket.getOption(fd: fileDescriptor, option: SO_TYPE)
    guard let type = SocketType.make(sockType) else {
      throw MessageError("unsupported socket type \(sockType)")
    }
    self.type = type
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  func setOption(_ option: Int32, to value: Int) throws {
    try Socket.setOption(fd: fileDescriptor, option: option, value: Int32(value))
  }

  func getOption(_ option: Int32) throws -> Int {
    return Int(try Socket.getOption(fd: fileDescriptor, option: option))
  }

  func setReadTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fileDescriptor, option: SO_RCVTIMEO, t: t)
  }

  func getReadTimeout() throws -> TimeInterval {
    return try Socket.getTimevalOption(fd: fileDescriptor, option: SO_RCVTIMEO)
  }

  func setWriteTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fileDescriptor, option: SO_SNDTIMEO, t: t)
  }

  func getWriteTimeout() throws -> TimeInterval {
    return try Socket.getTimevalOption(fd: fileDescriptor, option: SO_SNDTIMEO)
  }

  func setLinger(timeout: TimeInterval?) throws {
    try Socket.setLingerOption(fd: fileDescriptor, t: timeout)
  }

  func getLinger() throws -> TimeInterval? {
    return try Socket.getLingerOption(fd: fileDescriptor)
  }

  func setBlocking() throws {
    try Socket.setFcntl(fd: fileDescriptor, flag: -O_NONBLOCK)
  }

  func setNonBlocking() throws {
    try Socket.setFcntl(fd: fileDescriptor, flag: O_NONBLOCK)
  }

  func isBlocking() throws -> Bool {
    let flags = try Socket.getFcntl(fd: fileDescriptor)
    return (flags & O_NONBLOCK) == 0
  }

  func bind(to addr: Address) throws {
    // no need to call getaddrinfo, address already resolved
    fatalError("not implemented")
  }

  func bind(to addr: String) throws {
    if addr.contains("/") {
      try bind(toPath: addr)
    } else {
      try bind(toHostPort: addr)
    }
  }

  func bind(toPath path: String) throws {
    fatalError("not implemented")
  }

  func bind(toHostPort hostPort: String) throws {
    let (host, service) = try Address.split(hostPort: hostPort)
    try bind(toHost: host, service: service)
  }

  func bind(toHost host: String, service: String) throws {
    // needs to resolve address, calling getaddrinfo
    fatalError("not implemented")
  }

  func bind(toHost host: String, port: Int) throws {
    try bind(toHost: host, service: String(port))
  }

  func connect(to addr: Address) throws {
    // no need to call getaddrinfo, address already resolved
    fatalError("not implemented")
  }

  func connect(to addr: String) throws {
    if addr.contains("/") {
      try connect(toPath: addr)
    } else {
      try connect(toHostPort: addr)
    }
  }

  func connect(toPath path: String) throws {
    // connect to a unix path, do some early checks that this has a
    // remote chance to work.
    if let family = family, family != .unix {
      throw MessageError("invalid socket family to connect to unix path", context: ["path": path])
    }
    if let proto = proto, proto != .unix {
      throw MessageError("invalid socket protocol to connect to unix path", context: ["path": path])
    }

    var addr = sockaddr_un()
    let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
    let addrLen = MemoryLayout.stride(ofValue: addr)
    if path.utf8.count > maxLen {
      throw MessageError("path too long", context: ["path": path])
    }

    #if !os(Linux)
      addr.sun_len = UInt8(addrLen)
    #endif

    // if the socket has no family, leave it to 0 and let connect fail
    if let family = family {
      #if os(Linux)
        addr.sun_family = UInt16(family.value)
      #else
        addr.sun_family = UInt8(family.value)
      #endif
    }

    // set the path
    var chars = path.utf8.map({ CChar($0) })
    withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
      pathPtr.withMemoryRebound(to: CChar.self, capacity: maxLen) { arPtr in
        let buf = UnsafeMutableBufferPointer<CChar>(start: arPtr, count: maxLen)
        for i in 0..<maxLen {
          if i < chars.count {
            buf[i] = chars[i]
          } else {
            buf[i] = CChar(0)
          }
        }
      }
    }

    // call connect
    let ret: Int32 = withUnsafePointer(to: &addr) { addrPtr in
      return addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { (saPtr: UnsafePointer<sockaddr>) in
        return cconnect(fileDescriptor, saPtr, socklen_t(addrLen))
      }
    }
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  func connect(toHostPort hostPort: String) throws {
    let (host, service) = try Address.split(hostPort: hostPort)
    try connect(toHost: host, service: service)
  }

  func connect(toHost host: String, service: String) throws {
    // needs to call getaddrinfo to resolve address
    fatalError("not implemented")
  }

  func connect(toHost host: String, port: Int) throws {
    try connect(toHost: host, service: String(port))
  }

  func listen(backlog: Int) throws {
    let ret = clisten(fileDescriptor, Int32(backlog))
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  func accept() throws -> Socket {
    var addr = sockaddr()
    var addrLen = socklen_t()

    let ret = caccept(fileDescriptor, &addr, &addrLen)
    try CError.makeAndThrow(fromReturnCode: ret)

    guard let family = Family.make(Int32(addr.sa_family)) else {
      throw MessageError("unsupported address family \(addr.sa_family)")
    }

    let remoteAddr: Address?
    switch family {
    case .inet:
      remoteAddr = withUnsafePointer(to: &addr) { ptrAddr in
        ptrAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sa in
          Address(sockaddr: sa.pointee)
        }
      }

    case .inet6:
      remoteAddr = withUnsafePointer(to: &addr) { ptrAddr in
        ptrAddr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sa in
          Address(sockaddr: sa.pointee)
        }
      }

    case .unix:
      // TODO: an Address for unix path?
      fatalError("unexpected family type: \(family)")

    case .unspec:
      fatalError("unexpected family type: \(family)")
    }

    // TODO: store connected address on socket
    return try Socket(fd: ret, family: family)
  }

  func shutdown(mode: ShutdownMode = .readWrite) throws {
    let ret = cshutdown(fileDescriptor, mode.value)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  func close() throws {
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}
