#if os(Linux)

import Libc

// to avoid ambiguity between the Event methods and the system calls.
private let cclose = close
private let cread = read
private let cwrite = write

// MARK: - Event

public class Event: FileDescriptorRepresentable {

  // MARK: - Properties

  public let fileDescriptor: Int32

  // MARK: - Constructors

  public init(initialValue: UInt32, flags: Flags =  []) throws {
    let ret = eventfd(initialValue, flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  public func read() throws -> UInt64 {
    var n: UInt64 = 0
    let ret = cread(fileDescriptor, &n, MemoryLayout<UInt64>.size)
    try CError.makeAndThrow(fromReturnCode: Int32(ret))

    return n
  }

  public func write(_ n: UInt64) throws {
    var n: UInt64 = n
    let ret = cwrite(fileDescriptor, &n, MemoryLayout<UInt64>.size)
    try CError.makeAndThrow(fromReturnCode: Int32(ret))
  }

  public func close() throws {
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

// MARK: - Event+Flags

extension Event {
  public struct Flags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let cloExec = Flags(rawValue: Int32(EFD_CLOEXEC))
    public static let nonBlock = Flags(rawValue: Int32(EFD_NONBLOCK))
    public static let semaphore = Flags(rawValue: Int32(EFD_SEMAPHORE))
  }
}

#endif
