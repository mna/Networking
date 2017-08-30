import Libc
import OS

// MARK: - PollEvent

/// Linux only. PollEvent defines the event types the caller is interested
/// in, and the user-data associated with the event.
public struct PollEvent {
  public let types: Types
  public let data: UserData

  /// Creates a PollEvent with the specified event types and user data.
  public init(_ types: Types = [], data: UserData = .u64(0)) {
    self.types = types
    self.data = data
  }

  init(epollEvent ev: epoll_event) {
    self.types = Types(rawValue: ev.events)
    self.data = .u64(ev.data.u64)
  }

  func toCStruct() -> epoll_event {
    var eev = epoll_event()
    eev.events = types.rawValue

    switch data {
    case .fd(let fd):
      eev.data.fd = fd
    case .u32(let u):
      eev.data.u32 = u
    case .u64(let u):
      eev.data.u64 = u
    case .ptr(let p):
      eev.data.ptr = p
    }

    return eev
  }
}

// MARK: - PollEvent+Types

extension PollEvent {
  /// Linux only. The available event types.
  public struct Types: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let `in` = Types(rawValue: EPOLLIN.rawValue)
    public static let out = Types(rawValue: EPOLLOUT.rawValue)
    public static let rdhup = Types(rawValue: EPOLLRDHUP.rawValue)
    public static let pri = Types(rawValue: EPOLLPRI.rawValue)
    public static let err = Types(rawValue: EPOLLERR.rawValue)
    public static let hup = Types(rawValue: EPOLLHUP.rawValue)
    public static let et = Types(rawValue: EPOLLET.rawValue)
    public static let oneShot = Types(rawValue: EPOLLONESHOT.rawValue)
    // TODO: those are from Linux 3.5 and 4.5 respectively:
    public static let wakeUp = Types(rawValue: EPOLLWAKEUP.rawValue)
    public static let exclusive = Types(rawValue: EPOLLEXCLUSIVE.rawValue)
  }
}
