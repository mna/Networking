// Not needed on Darwin as kqueue natively supports timers.

#if os(Linux)

import Libc
import Foundation

// MARK: - Timer

/// Timer is a file descriptor associated with a timer. See
/// timerfd_create(2) for details.
public struct Timer: FileDescriptor {

  // MARK: - Properties

  /// The file descriptor for this timer.
  public let fileDescriptor: Int32

  // MARK: - Constructors

  /// Creates a timer using the specified clock and configured with
  /// the specified flags. See timerfd_create(2) for details.
  public init(using clock: Clock = .realTime, flags: Flags = []) throws {
    let ret = timerfd_create(clock.value, flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  // MARK: - Methods

  /// Sets the timer to trigger on the initial delay, and then at the specified
  /// interval. Returns the previously set timer delays.
  @discardableResult
  public func set(initial: TimeInterval, thenEach interval: TimeInterval = 0, flags: SetFlags = []) throws -> (initial: TimeInterval, interval: TimeInterval) {
    var oldValue = itimerspec()
    var newValue = itimerspec()
    newValue.it_value = initial.toTimeSpec()
    newValue.it_interval = interval.toTimeSpec()

    let ret = timerfd_settime(fileDescriptor, flags.rawValue, &newValue, &oldValue)
    try CError.makeAndThrow(fromReturnCode: ret)

    let (t1, t2) = (TimeInterval(from: oldValue.it_value), TimeInterval(from: oldValue.it_interval))
    return (t1, t2)
  }

  /// Unsets the timer, so that it doesn't trigger anymore. Returns the previously
  /// set timer delays.
  @discardableResult
  public func unset() throws -> (initial: TimeInterval, interval: TimeInterval) {
    return try set(initial: 0)
  }

  /// Returns the currently set timer delays.
  public func get() throws -> (initial: TimeInterval, interval: TimeInterval) {
    var currValue = itimerspec()
    let ret = timerfd_gettime(fileDescriptor, &currValue)
    try CError.makeAndThrow(fromReturnCode: ret)

    let (t1, t2) = (TimeInterval(from: currValue.it_value), TimeInterval(from: currValue.it_interval))
    return (t1, t2)
  }

  /// Returns the number of times the timer expired since the last call.
  public func expirations() throws -> UInt64 {
    var n: UInt64 = 0
    let sz = MemoryLayout.size(ofValue: n)

    let ret = read(fileDescriptor, &n, sz)
    try CError.makeAndThrow(fromReturnCode: Int32(ret))

    return n
  }

  /// Releases the resources for this file descriptor.
  public func close() throws {
    let ret = Libc.close(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

// MARK: - Timer+Clock

extension Timer {
  /// The type of clock to use for the timer.
  public enum Clock {
    case realTime
    case monotonic
    case bootTime
    case realTimeAlarm
    case bootTimeAlarm

    var value: Int32 {
      guard let v = Clock.toValues[self] else {
        fatalError("unknown Clock enum: \(self)")
      }
      return v
    }

    static func make(_ value: Int32) -> Clock? {
      return fromValues[value]
    }

    private static let toValues: [Clock: Int32] = [
      .realTime: CLOCK_REALTIME,
      .monotonic: CLOCK_MONOTONIC,
      .bootTime: CLOCK_BOOTTIME,
      .realTimeAlarm: CLOCK_REALTIME_ALARM,
      .bootTimeAlarm: CLOCK_BOOTTIME_ALARM,
    ]

    private static let fromValues: [Int32: Clock] = [
      CLOCK_REALTIME: .realTime,
      CLOCK_MONOTONIC: .monotonic,
      CLOCK_BOOTTIME: .bootTime,
      CLOCK_REALTIME_ALARM: .realTimeAlarm,
      CLOCK_BOOTTIME_ALARM: .bootTimeAlarm,
    ]
  }
}

// MARK: - Timer+Flags

extension Timer {
  /// The flags to configure the timer file descriptor.
  public struct Flags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let nonBlock = Flags(rawValue: Int32(TFD_NONBLOCK))
    public static let cloExec = Flags(rawValue: Int32(TFD_CLOEXEC))
  }
}

// MARK: - Timer+SetFlags

extension Timer {
  /// The flags to configure how the delays set for the timer should be
  /// interpreted.
  public struct SetFlags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let absTime = SetFlags(rawValue: Int32(TFD_TIMER_ABSTIME))
    // TODO: mentioned in man page but somehow not in header file (not in any system header)
    //static let cancelOnSet = SetFlags(rawValue: Int32(TFD_TIMER_CANCEL_ON_SET))
  }
}

#endif
