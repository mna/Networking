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

public class Socket: FileDescriptorRepresentable {

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

  public enum ShutdownMode {
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

  public let fileDescriptor: Int32
  public let family: Family?        // can be nil if created from existing FD and can't lookup family
  public let proto: SocketProtocol
  public let type: SocketType

  // TODO: should have a local and a remote address
  public private(set) var address: Address? = nil

  // MARK: - Constructors

  /// Creates an unconnected socket with the specified family and type,
  /// automatically deducing the protocol.
  public init(family: Family = .inet, type: SocketType = .stream) throws {
    self.family = family
    self.type = type
    self.proto = family == .unix ? .unix : (type == .stream ? .tcp : .udp)

    let fd = socket(family.value, type.value, proto.value)
    try CError.makeAndThrow(fromReturnCode: fd)
    self.fileDescriptor = fd
  }

  /// Creates a socket using an already existing socket's file descriptor.
  public init(fd: Int32, connectedTo address: Address? = nil, family: Family? = nil) throws {
    self.fileDescriptor = fd
    self.address = address

    let sockType = try Socket.getOption(fd: fileDescriptor, option: SO_TYPE)
    guard let type = SocketType.make(sockType) else {
      throw MessageError("unsupported socket type \(sockType)")
    }
    self.type = type

    #if os(Linux)
      self.family = family ?? Family.make(try Socket.getOption(fd: fileDescriptor, option: SO_DOMAIN))
      self.proto = SocketProtocol.make(try Socket.getOption(fd: fileDescriptor, option: SO_PROTOCOL))
    #else
      self.family = family
      self.proto = family == .unix ? .unix : (type == .stream ? .tcp : .udp)
    #endif
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  public func setOption(_ option: Int32, to value: Int) throws {
    try Socket.setOption(fd: fileDescriptor, option: option, value: Int32(value))
  }

  public func getOption(_ option: Int32) throws -> Int {
    return Int(try Socket.getOption(fd: fileDescriptor, option: option))
  }

  public func setReadTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fileDescriptor, option: SO_RCVTIMEO, t: t)
  }

  public func getReadTimeout() throws -> TimeInterval {
    return try Socket.getTimevalOption(fd: fileDescriptor, option: SO_RCVTIMEO)
  }

  public func setWriteTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fileDescriptor, option: SO_SNDTIMEO, t: t)
  }

  public func getWriteTimeout() throws -> TimeInterval {
    return try Socket.getTimevalOption(fd: fileDescriptor, option: SO_SNDTIMEO)
  }

  public func setLinger(timeout: TimeInterval?) throws {
    try Socket.setLingerOption(fd: fileDescriptor, t: timeout)
  }

  public func getLinger() throws -> TimeInterval? {
    return try Socket.getLingerOption(fd: fileDescriptor)
  }

  public func setBlocking() throws {
    try Socket.setFcntl(fd: fileDescriptor, flag: -O_NONBLOCK)
  }

  public func setNonBlocking() throws {
    try Socket.setFcntl(fd: fileDescriptor, flag: O_NONBLOCK)
  }

  public func isBlocking() throws -> Bool {
    let flags = try Socket.getFcntl(fd: fileDescriptor)
    return (flags & O_NONBLOCK) == 0
  }

  public func bind(to addr: Address) throws {
    let ret = addr.withUnsafeSockaddrPointer { (ptr, size) in
      cbind(fileDescriptor, ptr, size)
    }
    try CError.makeAndThrow(fromReturnCode: ret)
    self.address = addr
  }

  public func bind(to addr: String) throws {
    if addr.contains("/") {
      try bind(toPath: addr)
    } else {
      try bind(toHostPort: addr)
    }
  }

  public func bind(toPath path: String) throws {
    guard let addr = Address(path: path) else {
      throw MessageError("path too long", context: ["path": path])
    }
    try bind(to: addr)
  }

  public func bind(toHostPort hostPort: String) throws {
    let (host, service) = try Address.split(hostPort: hostPort)
    try bind(toHost: host, service: service)
  }

  public func bind(toHost host: String, service: String) throws {
    let host = host.isEmpty ? nil : host
    let flags: AddrInfo.Flags = host == nil ? [.default, .passive] : .default
    let (_, addrs) = try AddrInfo.get(host: host, service: service, flags: flags, family: family, type: type, proto: proto)

    guard let first = addrs.first else {
      throw MessageError("no address found", context: ["host": host ?? "", "service": service])
    }
    try bind(to: first)
  }

  public func bind(toHost host: String, port: Int) throws {
    try bind(toHost: host, service: String(port))
  }

  public func connect(to addr: Address) throws {
    let ret = addr.withUnsafeSockaddrPointer { (ptr, size) in
      cconnect(fileDescriptor, ptr, size)
    }
    try CError.makeAndThrow(fromReturnCode: ret)
    self.address = addr
  }

  public func connect(to addr: String) throws {
    if addr.contains("/") {
      try connect(toPath: addr)
    } else {
      try connect(toHostPort: addr)
    }
  }

  public func connect(toPath path: String) throws {
    guard let addr = Address(path: path) else {
      throw MessageError("path too long", context: ["path": path])
    }
    try connect(to: addr)
  }

  public func connect(toHostPort hostPort: String) throws {
    let (host, service) = try Address.split(hostPort: hostPort)
    try connect(toHost: host, service: service)
  }

  public func connect(toHost host: String, service: String) throws {
    // needs to call getaddrinfo to resolve address
    let (_, addrs) = try AddrInfo.get(host: host, service: service, family: family, type: type, proto: proto)
    guard let first = addrs.first else {
      throw MessageError("no address found", context: ["host": host])
    }
    try connect(to: first)
  }

  public func connect(toHost host: String, port: Int) throws {
    try connect(toHost: host, service: String(port))
  }

  public func listen(backlog: Int = 128) throws {
    let ret = clisten(fileDescriptor, Int32(backlog))
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  public func accept() throws -> Socket {
    guard let family = family else {
      throw MessageError("listening socket has no family specified")
    }

    var addrLen = socklen_t()
    let remoteAddr: Address?
    let remoteFD: Int32

    switch family {
    case .inet:
      var addr = sockaddr_in()
      addrLen = UInt32(MemoryLayout<sockaddr_in>.stride)

      remoteFD = withUnsafeMutablePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
          caccept(fileDescriptor, sa, &addrLen)
        }
      }
      try CError.makeAndThrow(fromReturnCode: remoteFD)

      guard let remoteFamily = Family.make(Int32(addr.sin_family)), remoteFamily == family else {
        throw MessageError("unsupported remote address family")
      }
      remoteAddr = Address(sockaddr: addr)

    case .inet6:
      var addr = sockaddr_in6()
      addrLen = UInt32(MemoryLayout<sockaddr_in6>.stride)

      remoteFD = withUnsafeMutablePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
          caccept(fileDescriptor, sa, &addrLen)
        }
      }
      try CError.makeAndThrow(fromReturnCode: remoteFD)

      guard let remoteFamily = Family.make(Int32(addr.sin6_family)), remoteFamily == family else {
        throw MessageError("unsupported remote address family")
      }
      remoteAddr = Address(sockaddr: addr)

    case .unix:
      var addr = sockaddr_un()
      addrLen = UInt32(MemoryLayout<sockaddr_un>.stride)

      remoteFD = withUnsafeMutablePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
          caccept(fileDescriptor, sa, &addrLen)
        }
      }
      try CError.makeAndThrow(fromReturnCode: remoteFD)

      guard let remoteFamily = Family.make(Int32(addr.sun_family)), remoteFamily == family else {
        throw MessageError("unsupported remote address family")
      }
      remoteAddr = Address(sockaddr: addr)

    case .unspec:
      throw MessageError("unsupported listening socket family")
    }

    return try Socket(fd: remoteFD, connectedTo: remoteAddr, family: family)
  }

  public func shutdown(mode: ShutdownMode = .readWrite) throws {
    let ret = cshutdown(fileDescriptor, mode.value)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  public func close() throws {
    self.address = nil
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}
