import Libc
import OS
import Foundation

// MARK: - Socket

/// Socket is an endpoint for network communication. See socket(2).
public struct Socket: FileDescriptor {

  // MARK: - Properties

  /// The file descriptor for this socket.
  public let fileDescriptor: Int32
  /// The network family of this socket. Can be nil if the socket
  /// was created from an existing file descriptor and the current
  /// platform does not support looking up the family.
  public let family: Family?
  /// The socket protocol.
  public let proto: SocketProtocol
  /// The socket type.
  public let type: SocketType

  /// The address of the peer if this is the server side of an
  /// accepted socket connection.
  public private(set) var peerAddress: Address? = nil
  /// The local address this socket is bound to.
  public private(set) var boundAddress: Address? = nil

  // MARK: - Constructors

  /// Creates an unconnected socket with the specified family and type,
  /// automatically deducing the protocol (unix if family is unix, otherwise
  /// TCP if the type is stream, UDP if the type is datagram).
  public init(family: Family = .inet, type: SocketType = .stream) throws {
    self.family = family
    self.type = type
    self.proto = family == .unix ? .unix : (type == .stream ? .tcp : .udp)

    let fd = socket(family.value, type.value, proto.value)
    try CError.makeAndThrow(fromReturnCode: fd)
    self.fileDescriptor = fd
  }

  /// Creates a socket using an already existing socket's file descriptor.
  /// The family can be specified if known, otherwise it will attempt
  /// to detect it.
  public init(fd: Int32, family: Family? = nil) throws {
    self.fileDescriptor = fd

    let sockType = try Socket.getOption(fd: fileDescriptor, option: SO_TYPE)
    guard let type = SocketType.make(sockType) else {
      throw MessageError("unsupported socket type \(sockType)")
    }
    self.type = type

    #if os(Linux)
      self.family = try family ?? Family.make(try Socket.getOption(fd: fd, option: SO_DOMAIN))
      guard let proto = SocketProtocol.make(try Socket.getOption(fd: fd, option: SO_PROTOCOL)) else {
        throw MessageError("unsupported socket protocol")
      }
      self.proto = proto
    #else
      self.family = family
      self.proto = family == .unix ? .unix : (type == .stream ? .tcp : .udp)
    #endif
  }

  // MARK: - Methods

  /// Sets an Int32-based option on the socket. Boolean options are set by passing
  /// 1 for true, 0 for false.
  public func setOption(_ option: Int32, to value: Int) throws {
    try Socket.setOption(fd: fileDescriptor, option: option, value: Int32(value))
  }

  /// Gets the current setting for an Int32-based option.
  public func getOption(_ option: Int32) throws -> Int {
    return Int(try Socket.getOption(fd: fileDescriptor, option: option))
  }

  /// Sets the read timeout option.
  public func setReadTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fileDescriptor, option: SO_RCVTIMEO, t: t)
  }

  /// Gets the current read timeout setting.
  public func getReadTimeout() throws -> TimeInterval {
    return try Socket.getTimevalOption(fd: fileDescriptor, option: SO_RCVTIMEO)
  }

  /// Sets the write timeout option.
  public func setWriteTimeout(_ t: TimeInterval) throws {
    try Socket.setTimevalOption(fd: fileDescriptor, option: SO_SNDTIMEO, t: t)
  }

  /// Gets the current write timeout setting.
  public func getWriteTimeout() throws -> TimeInterval {
    return try Socket.getTimevalOption(fd: fileDescriptor, option: SO_SNDTIMEO)
  }

  /// Sets the linger option.
  public func setLinger(timeout: TimeInterval?) throws {
    try Socket.setLingerOption(fd: fileDescriptor, t: timeout)
  }

  /// Gets the current linger setting.
  public func getLinger() throws -> TimeInterval? {
    return try Socket.getLingerOption(fd: fileDescriptor)
  }

  /// Sets the socket as blocking.
  public func setBlocking() throws {
    try Socket.setFcntl(fd: fileDescriptor, flag: -O_NONBLOCK)
  }

  /// Sets the socket as non-blocking.
  public func setNonBlocking() throws {
    try Socket.setFcntl(fd: fileDescriptor, flag: O_NONBLOCK)
  }

  /// Indicates if the socket is currently set as blocking.
  public func isBlocking() throws -> Bool {
    let flags = try Socket.getFcntl(fd: fileDescriptor)
    return (flags & O_NONBLOCK) == 0
  }

  /// Loads the bound address of the socket. This also overwrites the
  /// boundAddress property.
  public mutating func loadBoundAddress() throws -> Address {
    guard let family = family else {
      throw MessageError("socket has no family specified")
    }

    let (_, boundAddr) = try Socket.getReturnCodeAndAddress(fd: fileDescriptor, family: family, getsockname)
    guard let mustBoundAddr = boundAddr else {
      throw MessageError("no bound address")
    }
    self.boundAddress = mustBoundAddr
    return mustBoundAddr
  }

  /// Loads the peer address of the socket. This also overwrites the
  /// peerAddress property.
  public mutating func loadPeerAddress() throws -> Address {
    guard let family = family else {
      throw MessageError("socket has no family specified")
    }

    let (_, peerAddr) = try Socket.getReturnCodeAndAddress(fd: fileDescriptor, family: family, getpeername)
    guard let mustPeerAddr = peerAddr else {
      throw MessageError("no peer address")
    }
    self.peerAddress = mustPeerAddr
    return mustPeerAddr
  }

  /// Binds the socket to the specified address.
  public mutating func bind(to addr: Address) throws {
    let ret = addr.withUnsafeSockaddrPointer { (ptr, size) in
      Libc.bind(fileDescriptor, ptr, size)
    }
    try CError.makeAndThrow(fromReturnCode: ret)
    self.boundAddress = addr
  }

  /// Connects the socket to the specified address.
  public func connect(to addr: Address) throws {
    let ret = addr.withUnsafeSockaddrPointer { (ptr, size) in
      Libc.connect(fileDescriptor, ptr, size)
    }
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  // TODO: when conditional protocol conformance lands, refactor this
  // by conforming Array<UInt8> and ArraySlice<UInt8> to an UnsafeBytesBuffer
  // protocol.

  /// Sends data over the socket.
  public func send(_ data: Array<UInt8>, flags: SendFlags = []) throws -> Int {
    let ret = data.withUnsafeBufferPointer { buf in
      Libc.send(fileDescriptor, buf.baseAddress, buf.count, flags.rawValue)
    }
    try CError.makeAndThrow(fromReturnCode: Int32(ret))
    return ret
  }

  /// Sends data over the socket.
  public func send(_ data: ArraySlice<UInt8>, flags: SendFlags = []) throws -> Int {
    let ret = data.withUnsafeBufferPointer { buf in
      Libc.send(fileDescriptor, buf.baseAddress, buf.count, flags.rawValue)
    }
    try CError.makeAndThrow(fromReturnCode: Int32(ret))
    return ret
  }

  /// Sends data to the specified address.
  public func send(_ data: Array<UInt8>, to addr: Address, flags: SendFlags = []) throws -> Int {
    let ret = data.withUnsafeBufferPointer { buf in
      addr.withUnsafeSockaddrPointer { sa, len in
        Libc.sendto(fileDescriptor, buf.baseAddress, buf.count, flags.rawValue, sa, len)
      }
    }
    try CError.makeAndThrow(fromReturnCode: Int32(ret))
    return ret
  }

  /// Sends data to the specified address.
  public func send(_ data: ArraySlice<UInt8>, to addr: Address, flags: SendFlags = []) throws -> Int {
    let ret = data.withUnsafeBufferPointer { buf in
      addr.withUnsafeSockaddrPointer { sa, len in
        Libc.sendto(fileDescriptor, buf.baseAddress, buf.count, flags.rawValue, sa, len)
      }
    }
    try CError.makeAndThrow(fromReturnCode: Int32(ret))
    return ret
  }

  /// Read data from the socket into the provided array. At most `data.count` bytes
  /// are read.
  public func receive(_ data: inout Array<UInt8>, flags: ReceiveFlags = []) throws -> Int {
    let ret = data.withUnsafeMutableBufferPointer { buf in
      Libc.recv(fileDescriptor, buf.baseAddress, buf.count, flags.rawValue)
    }
    try CError.makeAndThrow(fromReturnCode: Int32(ret))
    return Int(ret)
  }

  /// Read data from the socket into the provided array. At most `data.count` bytes
  /// are read.
  public func receive(_ data: inout ArraySlice<UInt8>, flags: ReceiveFlags = []) throws -> Int {
    let ret = data.withUnsafeMutableBufferPointer { buf in
      Libc.recv(fileDescriptor, buf.baseAddress, buf.count, flags.rawValue)
    }
    try CError.makeAndThrow(fromReturnCode: Int32(ret))
    return Int(ret)
  }

  private func receive(_ data: UnsafeMutableBufferPointer<UInt8>, from addr: inout Address, flags: ReceiveFlags) throws -> Int {
    var storage = sockaddr_storage()
    var length = socklen_t(MemoryLayout<sockaddr_storage>.stride)

    let ret = withUnsafeMutablePointer(to: &storage) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { (saptr: UnsafeMutablePointer<sockaddr>) in
        Libc.recvfrom(fileDescriptor, data.baseAddress, data.count, flags.rawValue, saptr, &length)
      }
    }
    try CError.makeAndThrow(fromReturnCode: Int32(ret))

    guard let family = Family.make(Int32(storage.ss_family)) else {
      throw MessageError("unsupported address family", context: ["family": String(storage.ss_family)])
    }

    let fromAddr: Address?
    switch family {
    case .inet:
      fromAddr = withUnsafePointer(to: &storage) { ptr in
        ptr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { (saptr: UnsafePointer<sockaddr_in>) in
          Address(sockaddr: saptr.pointee)
        }
      }
    case .inet6:
      fromAddr = withUnsafePointer(to: &storage) { ptr in
        ptr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { (saptr: UnsafePointer<sockaddr_in6>) in
          Address(sockaddr: saptr.pointee)
        }
      }
    case .unix:
      fromAddr = withUnsafePointer(to: &storage) { ptr in
        ptr.withMemoryRebound(to: sockaddr_un.self, capacity: 1) { (saptr: UnsafePointer<sockaddr_un>) in
          Address(sockaddr: saptr.pointee)
        }
      }
    case .unspec:
      fromAddr = nil
    }

    guard let mustFromAddr = fromAddr else {
      throw MessageError("invalid from address")
    }
    addr = mustFromAddr

    return ret
  }

  /// Read data from the socket into the provided array and stores the sender
  /// address in `addr`. At most `data.count` bytes are read.
  public func receive(_ data: inout Array<UInt8>, from addr: inout Address, flags: ReceiveFlags = []) throws -> Int {
    let ret = try data.withUnsafeMutableBufferPointer { buf in
      try receive(buf, from: &addr, flags: flags)
    }
    return ret
  }

  /// Read data from the socket into the provided array and stores the sender
  /// address in `addr`. At most `data.count` bytes are read.
  public func receive(_ data: inout ArraySlice<UInt8>, from addr: inout Address, flags: ReceiveFlags = []) throws -> Int {
    let ret = try data.withUnsafeMutableBufferPointer { buf in
      try receive(buf, from: &addr, flags: flags)
    }
    return ret
  }

  /// Listen for incoming connections on the bound address.
  public func listen(backlog: Int = 128) throws {
    let ret = Libc.listen(fileDescriptor, Int32(backlog))
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  /// Accept an incoming connection, returning the accepted socket.
  public func accept() throws -> Socket {
    guard let family = family else {
      throw MessageError("listening socket has no family specified")
    }

    let (remoteFD, remoteAddr) = try Socket.getReturnCodeAndAddress(fd: fileDescriptor, family: family, Libc.accept)

    var remote = try Socket(fd: remoteFD, family: family)
    remote.peerAddress = remoteAddr
    return remote
  }

  /// Shutdown the read, write or both ends of the socket. The socket
  /// must still be closed to properly release all resources.
  public func shutdown(mode: ShutdownMode = .readWrite) throws {
    let ret = Libc.shutdown(fileDescriptor, mode.value)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  /// Releases the resources for this file descriptor.
  public mutating func close() throws {
    self.boundAddress = nil
    self.peerAddress = nil
    let ret = Libc.close(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

// MARK: - Socket+SendFlags+ReceiveFlags

extension Socket {
  /// Available flags used to send data.
  public struct SendFlags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let oob = SendFlags(rawValue: Int32(MSG_OOB))
    public static let dontRoute = SendFlags(rawValue: Int32(MSG_DONTROUTE))
    #if os(Linux)
      public static let noSignal = SendFlags(rawValue: Int32(MSG_NOSIGNAL))
    #endif
  }

  /// Available flags used to receive data.
  public struct ReceiveFlags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let oob = ReceiveFlags(rawValue: Int32(MSG_OOB))
    public static let peek = ReceiveFlags(rawValue: Int32(MSG_PEEK))
    public static let waitAll = ReceiveFlags(rawValue: Int32(MSG_WAITALL))
  }
}

// MARK: - Socket+ShutdownMode

extension Socket {
  /// Available socket shutdown modes.
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
      .read: Int32(SHUT_RD),
      .write: Int32(SHUT_WR),
      .readWrite: Int32(SHUT_RDWR),
    ]

    private static let fromValues: [Int32: ShutdownMode] = [
      Int32(SHUT_RD): .read,
      Int32(SHUT_WR): .write,
      Int32(SHUT_RDWR): .readWrite,
    ]
  }
}

// MARK: - Socket Static Methods

extension Socket {
  fileprivate static func getOption(fd: Int32, option: Int32) throws -> Int32 {
    var v: Int32 = 0
    var len = socklen_t(MemoryLayout<Int32>.size)

    let ret = getsockopt(fd, SOL_SOCKET, option, &v, &len)
    try CError.makeAndThrow(fromReturnCode: ret)
    return v
  }

  fileprivate static func getTimevalOption(fd: Int32, option: Int32) throws -> TimeInterval {
    var val = timeval()
    var len = socklen_t(MemoryLayout<timeval>.stride)

    let ret = getsockopt(fd, SOL_SOCKET, option, &val, &len)
    try CError.makeAndThrow(fromReturnCode: ret)

    return TimeInterval(from: val)
  }

  fileprivate static func getLingerOption(fd: Int32) throws -> TimeInterval? {
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

  fileprivate static func setOption(fd: Int32, option: Int32, value: Int32) throws {
    var v = value
    let ret = setsockopt(fd, SOL_SOCKET, option, &v, socklen_t(MemoryLayout<Int32>.size))
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  fileprivate static func setTimevalOption(fd: Int32, option: Int32, t: TimeInterval) throws {
    var val = t > 0 ? t.toTimeVal() : TimeInterval(0).toTimeVal()
		let ret = setsockopt(fd, SOL_SOCKET, option, &val, socklen_t(MemoryLayout<timeval>.stride))
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  fileprivate static func setLingerOption(fd: Int32, t: TimeInterval?) throws {
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

  fileprivate static func getFcntl(fd: Int32) throws -> Int32 {
    let flags = fcntl(fd, F_GETFL)
    try CError.makeAndThrow(fromReturnCode: flags)
    return flags
  }

  fileprivate static func setFcntl(fd: Int32, flag: Int32) throws {
    let flags = try getFcntl(fd: fd)

    // if flag is negative, unset the flag
    let new = flag >= 0 ? (flags | flag) : (flags & ~(-flag))

    let ret = fcntl(fd, F_SETFL, new)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  // common implementation for accept(), getsockname(), getpeername().
  fileprivate static func getReturnCodeAndAddress(fd: Int32, family: Family,
    _ body: (Int32, UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) throws -> Int32) throws -> (Int32, Address?) {

    var addrLen = socklen_t()
    let returnAddr: Address?
    let ret: Int32

    switch family {
    case .inet:
      var addr = sockaddr_in()
      addrLen = UInt32(MemoryLayout<sockaddr_in>.stride)

      ret = try withUnsafeMutablePointer(to: &addr) { ptr in
        try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
          try body(fd, sa, &addrLen)
        }
      }
      try CError.makeAndThrow(fromReturnCode: ret)

      guard let f = Family.make(Int32(addr.sin_family)), f == family else {
        throw MessageError("unexpected address family")
      }
      returnAddr = Address(sockaddr: addr)

    case .inet6:
      var addr = sockaddr_in6()
      addrLen = UInt32(MemoryLayout<sockaddr_in6>.stride)

      ret = try withUnsafeMutablePointer(to: &addr) { ptr in
        try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
          try body(fd, sa, &addrLen)
        }
      }
      try CError.makeAndThrow(fromReturnCode: ret)

      guard let f = Family.make(Int32(addr.sin6_family)), f == family else {
        throw MessageError("unexpected address family")
      }
      returnAddr = Address(sockaddr: addr)

    case .unix:
      var addr = sockaddr_un()
      addrLen = UInt32(MemoryLayout<sockaddr_un>.stride)

      ret = try withUnsafeMutablePointer(to: &addr) { ptr in
        try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
          try body(fd, sa, &addrLen)
        }
      }
      try CError.makeAndThrow(fromReturnCode: ret)

      guard let f = Family.make(Int32(addr.sun_family)), f == family else {
        throw MessageError("unexpected address family")
      }
      returnAddr = Address(sockaddr: addr)

    case .unspec:
      throw MessageError("unsupported family")
    }

    return (ret, returnAddr)
  }
}
