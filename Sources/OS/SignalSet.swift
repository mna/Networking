import Libc

// MARK: - SignalSet

public struct SignalSet {

  // MARK: - Properties

  private var sigset = sigset_t()

  // MARK: - Constructors

  private init(mask sigset: sigset_t) {
    self.sigset = sigset
  }

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

  public func contains(signal: Signal) throws -> Bool {
    var mask = sigset // copy so "mutating" is not required
    let ret = sigismember(&mask, signal.value)
    try CError.makeAndThrow(fromReturnCode: ret)
    return ret == 1
  }

  @discardableResult
  public func block(mode: BlockMode = .setMask) throws -> SignalSet {
    var mask = sigset // copy so "mutating" is not required
    var old = sigset_t()
    let ret = pthread_sigmask(mode.value, &mask, &old)
    try CError.makeAndThrow(fromErrNo: ret)

    return SignalSet(mask: old)
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

// MARK: - SignalSet+BlockMode

extension SignalSet {
  public enum BlockMode {
    case block
    case unblock
    case setMask

    var value: Int32 {
      guard let v = BlockMode.toValues[self] else {
        fatalError("unknown BlockMode enum: \(self)")
      }
      return v
    }

    static func make(_ value: Int32) -> BlockMode? {
      return fromValues[value]
    }

    private static let toValues: [BlockMode: Int32] = [
      .block: SIG_BLOCK,
      .unblock: SIG_UNBLOCK,
      .setMask: SIG_SETMASK,
    ]

    private static let fromValues: [Int32: BlockMode] = [
      SIG_BLOCK: .block,
      SIG_UNBLOCK: .unblock,
      SIG_SETMASK: .setMask,
    ]
  }
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
