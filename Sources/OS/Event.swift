#if os(Linux)

import Libc

// MARK: - Event

/// Event represents an event file descriptor as described in
/// eventfd(2).
public struct Event: FileDescriptor {

  // MARK: - Properties

  /// The file descriptor for this event.
  public let fileDescriptor: Int32

  // MARK: - Constructors

  /// Creates an event file descriptor with the provided initial value and
  /// flags.
  public init(initialValue: UInt32 = 0, flags: Flags =  []) throws {
    let ret = eventfd(initialValue, flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  // MARK: - Methods

  /// Reads the current value from the file descriptor. See eventfd(2)
  /// for details on the behaviour of this call. Returns the value
  /// read from the event.
  public func read() throws -> UInt64 {
    var n: UInt64 = 0
    let ret = Libc.read(fileDescriptor, &n, MemoryLayout<UInt64>.size)
    try CError.makeAndThrow(fromReturnCode: Int32(ret))

    return n
  }

  /// Adds the specified value to the event file descriptor. See
  /// eventfd(2) for details on the behaviour of this call.
  public func write(_ n: UInt64) throws {
    var n: UInt64 = n
    let ret = Libc.write(fileDescriptor, &n, MemoryLayout<UInt64>.size)
    try CError.makeAndThrow(fromReturnCode: Int32(ret))
  }

  /// Releases the resource associated with this file descriptor.
  public func close() throws {
    let ret = Libc.close(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

// MARK: - Event+Flags

extension Event {
  /// Flags for the event file descriptor.
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
