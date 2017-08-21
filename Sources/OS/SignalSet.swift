import Libc

// MARK: - SignalSet

struct SignalSet {

  // MARK: - Properties

  private var sigset = sigset_t()

  // MARK: - Constructors

  init(fill: Bool) throws {
    let ret: Int32
    if fill {
      ret = sigfillset(&sigset)
    } else {
      ret = sigemptyset(&sigset)
    }
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  init(insert signals: [Signal]) throws {
    try self.init(fill: false)
    for sig in signals {
      let ret = sigaddset(&sigset, sig.value)
      try CError.makeAndThrow(fromReturnCode: ret)
    }
  }

  // MARK: - Methods

  mutating func insert(signal: Signal) throws {
    let ret = sigaddset(&sigset, signal.value)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  mutating func remove(signal: Signal) throws {
    let ret = sigdelset(&sigset, signal.value)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  mutating func contains(signal: Signal) throws -> Bool {
    let ret = sigismember(&sigset, signal.value)
    try CError.makeAndThrow(fromReturnCode: ret)
    return ret == 1
  }

  func toCStruct() -> sigset_t {
    return sigset
  }

  #if os(Linux)

  mutating func fileDescriptor(replacing fd: FileDescriptorRepresentable? = nil, flags: Flags = []) throws -> Int32 {
    let fd = fd?.fileDescriptor ?? -1
    let ret = signalfd(fd, &sigset, flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)
    return ret
  }

  #endif
}

#if os(Linux)

// MARK: SignalSet+Flags

extension SignalSet {
  struct Flags: OptionSet {
    let rawValue: Int32

    init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    static let nonBlock = Flags(rawValue: Int32(SFD_NONBLOCK))
    static let cloExec = Flags(rawValue: Int32(SFD_CLOEXEC))
  }
}

#endif
