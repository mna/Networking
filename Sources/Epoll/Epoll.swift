import Libc
import OS
import Foundation

// to avoid ambiguity between the Epoll methods and the system calls.
private let cclose = close

// MARK: - Epoll

public class Epoll: FileDescriptorRepresentable {

  // MARK: - Properties

  public let fileDescriptor: Int32

  // MARK: - Constructors

  public init(flags: Flags = []) throws {
    let ret = epoll_create1(flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  public func add(fd: FileDescriptorRepresentable, event: Event) throws {
    try apply(EPOLL_CTL_ADD, fd: fd.fileDescriptor, event: event)
  }

  public func update(fd: FileDescriptorRepresentable, event: Event) throws {
    try apply(EPOLL_CTL_MOD, fd: fd.fileDescriptor, event: event)
  }

  public func remove(fd: FileDescriptorRepresentable) throws {
    try apply(EPOLL_CTL_DEL, fd: fd.fileDescriptor, event: nil)
  }

  private func apply(_ op: Int32, fd: Int32, event: Event?) throws {
    let ret: Int32
    if let event = event {
      var ev = event.toCStruct()
      ret = epoll_ctl(fileDescriptor, op, fd, &ev)
    } else {
      ret = epoll_ctl(fileDescriptor, op, fd, nil)
    }
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  public func poll(into events: inout [Event], timeout: TimeInterval? = nil, blockedSignals signals: SignalSet? = nil) throws -> Int {
    var eevs = Array<epoll_event>(repeating: epoll_event(), count: events.count)

    var ms = Int32(-1)
    if let timeout = timeout {
      ms = Int32(timeout * 1000)
    }

    let ret: Int32
    if let signals = signals {
      var sigmask = signals.toCStruct()
      ret = epoll_pwait(fileDescriptor, &eevs, Int32(eevs.count), ms, &sigmask)
    } else {
      ret = epoll_pwait(fileDescriptor, &eevs, Int32(eevs.count), ms, nil)
    }
    try CError.makeAndThrow(fromReturnCode: ret)

    for i in 0..<Int(ret) {
      events[i] = Event(epollEvent: eevs[i])
    }
    return Int(ret)
  }

  public func close() throws {
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

// MARK: - Epoll+Flags

extension Epoll {
  public struct Flags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let cloExec = Flags(rawValue: Int32(EPOLL_CLOEXEC))
  }
}
