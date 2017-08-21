import Libc

// MARK: - Event

struct Event {
  let types: Types
  let data: Data?

  init(_ types: Types = [], data: Data? = nil) {
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
    eev.data.u64 = 0

    if let data = data {
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
    }

    return eev
  }
}

// MARK: - Event+Types

extension Event {
  struct Types: OptionSet {
    let rawValue: UInt32

    init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    static let `in` = Types(rawValue: EPOLLIN.rawValue)
    static let out = Types(rawValue: EPOLLOUT.rawValue)
    static let rdhup = Types(rawValue: EPOLLRDHUP.rawValue)
    static let pri = Types(rawValue: EPOLLPRI.rawValue)
    static let err = Types(rawValue: EPOLLERR.rawValue)
    static let hup = Types(rawValue: EPOLLHUP.rawValue)
    static let et = Types(rawValue: EPOLLET.rawValue)
    static let oneShot = Types(rawValue: EPOLLONESHOT.rawValue)
    // TODO: those are from Linux 3.5 and 4.5 respectively:
    static let wakeUp = Types(rawValue: EPOLLWAKEUP.rawValue)
    static let exclusive = Types(rawValue: EPOLLEXCLUSIVE.rawValue)
  }
}
