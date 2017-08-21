// Not needed on Darwin as kqueue natively supports timers.

#if os(Linux)

import Libc
import Foundation

// to avoid ambiguity between the Timer methods and the system calls.
private let cclose = close

// MARK: - Timer

class Timer: FileDescriptorRepresentable {

  // MARK: - Properties

  let fileDescriptor: Int32

  // MARK: - Constructors

  init(using clock: Clock = .realTime, flags: Flags = []) throws {
    let ret = timerfd_create(clock.value, flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  @discardableResult
  func set(initial: TimeInterval, thenEach interval: TimeInterval = 0, flags: SetFlags = []) throws -> (initial: TimeInterval, interval: TimeInterval) {
    var oldValue = itimerspec()
    var newValue = itimerspec()
    newValue.it_value = initial.toTimeSpec()
    newValue.it_interval = interval.toTimeSpec()

    let ret = timerfd_settime(fileDescriptor, flags.rawValue, &newValue, &oldValue)
    try CError.makeAndThrow(fromReturnCode: ret)

    let (t1, t2) = (TimeInterval(from: oldValue.it_value), TimeInterval(from: oldValue.it_interval))
    return (t1, t2)
  }

  @discardableResult
  func unset() throws -> (initial: TimeInterval, interval: TimeInterval) {
    return try set(initial: 0)
  }

  func get() throws -> (initial: TimeInterval, interval: TimeInterval) {
    var currValue = itimerspec()
    let ret = timerfd_gettime(fileDescriptor, &currValue)
    try CError.makeAndThrow(fromReturnCode: ret)

    let (t1, t2) = (TimeInterval(from: currValue.it_value), TimeInterval(from: currValue.it_interval))
    return (t1, t2)
  }

  func expirations() throws -> UInt64 {
    var n: UInt64 = 0
    let sz = MemoryLayout.size(ofValue: n)

    let ret = read(fileDescriptor, &n, sz)
    try CError.makeAndThrow(fromReturnCode: Int32(ret))

    return n
  }

  func close() throws {
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

// MARK: - Timer+Clock

extension Timer {
  enum Clock {
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
  struct Flags: OptionSet {
    let rawValue: Int32

    init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    static let nonBlock = Flags(rawValue: Int32(TFD_NONBLOCK))
    static let cloExec = Flags(rawValue: Int32(TFD_CLOEXEC))
  }
}

// MARK: - Timer+SetFlags

extension Timer {
  struct SetFlags: OptionSet {
    let rawValue: Int32

    init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    static let absTime = SetFlags(rawValue: Int32(TFD_TIMER_ABSTIME))
    // TODO: mentioned in man page but somehow not in header file (not in any system header)
    //static let cancelOnSet = SetFlags(rawValue: Int32(TFD_TIMER_CANCEL_ON_SET))
  }
}

#endif
