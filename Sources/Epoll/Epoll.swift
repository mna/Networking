import Glibc
import Cepoll
import OS

// to avoid ambiguity between the Epoll methods and the system calls.
private let cclose = close

// MARK: - Epoll

class Epoll: FileDescriptorRepresentable {

  // MARK: - Properties

  public let fileDescriptor: Int32

  // MARK: - Constructors

  init(flags: Flags = []) throws {
    let ret = epoll_create1(flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  func add(fd: FileDescriptorRepresentable, events: Events) throws {
    try apply(EPOLL_CTL_ADD, fd: fd.fileDescriptor, events: events)
  }

  func update(fd: FileDescriptorRepresentable, events: Events) throws {
    try apply(EPOLL_CTL_MOD, fd: fd.fileDescriptor, events: events)
  }

  func remove(fd: FileDescriptorRepresentable) throws {
    try apply(EPOLL_CTL_DEL, fd: fd.fileDescriptor, events: [])
  }

  // TODO: currently, always sets the epoll_event.data field to the same fd as fd.
  private func apply(_ op: Int32, fd: Int32, events: Events) throws {
    var ev = epoll_event()
    ev.events = events.rawValue
    ev.data.fd = fd

    let ret = epoll_ctl(fileDescriptor, op, fd, &ev)
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  func close() throws {
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

// MARK: - Epoll+Flags

extension Epoll {
  struct Flags: OptionSet {
    let rawValue: Int32

    init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    static let cloExec = Flags(rawValue: Int32(EPOLL_CLOEXEC))
  }
}

// MARK: - Epoll+Events

extension Epoll {
  struct Events: OptionSet {
    let rawValue: UInt32

    init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    static let `in` = Events(rawValue: EPOLLIN.rawValue)
    static let out = Events(rawValue: EPOLLOUT.rawValue)
    static let rdhup = Events(rawValue: EPOLLRDHUP.rawValue)
    static let pri = Events(rawValue: EPOLLPRI.rawValue)
    static let err = Events(rawValue: EPOLLERR.rawValue)
    static let hup = Events(rawValue: EPOLLHUP.rawValue)
    static let et = Events(rawValue: EPOLLET.rawValue)
    static let oneShot = Events(rawValue: EPOLLONESHOT.rawValue)
    // TODO: those are from Linux 3.5 and 4.5 respectively:
    static let wakeUp = Events(rawValue: EPOLLWAKEUP.rawValue)
    static let exclusive = Events(rawValue: EPOLLEXCLUSIVE.rawValue)
  }
}
