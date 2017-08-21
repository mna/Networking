import Libc

// MARK: - SignalSet

public struct SignalSet {

  // MARK: - Properties

  private var sigset = sigset_t()

  // MARK: - Constructors

  public init(fill: Bool) throws {
    let ret: Int32
    if fill {
      ret = sigfillset(&sigset)
    } else {
      ret = sigemptyset(&sigset)
    }
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  public init(insert signals: [Signal]) throws {
    try self.init(fill: false)
    for sig in signals {
      let ret = sigaddset(&sigset, sig.value)
      try CError.makeAndThrow(fromReturnCode: ret)
    }
  }

  // MARK: - Methods

  public mutating func insert(signal: Signal) throws {
    let ret = sigaddset(&sigset, signal.value)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  public mutating func remove(signal: Signal) throws {
    let ret = sigdelset(&sigset, signal.value)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  public mutating func contains(signal: Signal) throws -> Bool {
    let ret = sigismember(&sigset, signal.value)
    try CError.makeAndThrow(fromReturnCode: ret)
    return ret == 1
  }

  public func toCStruct() -> sigset_t {
    return sigset
  }

  #if os(Linux)

  public mutating func fileDescriptor(replacing fdr: FileDescriptorRepresentable? = nil, flags: Flags = []) throws -> SignalFileDescriptor {
    let fd = fdr?.fileDescriptor ?? -1
    let ret = signalfd(fd, &sigset, flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)

    if let fdr = fdr, let sfd = fdr as? SignalFileDescriptor {
      return sfd
    }
    return SignalFileDescriptor(ret)
  }

  #endif
}

#if os(Linux)

// MARK: - SignalSet+Flags

extension SignalSet {
  public struct Flags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let nonBlock = Flags(rawValue: Int32(SFD_NONBLOCK))
    public static let cloExec = Flags(rawValue: Int32(SFD_CLOEXEC))
  }
}

#endif
