import Libc
import OS
import Foundation

// MARK: - Epoll

/// Linux only. Epoll implements the Linux epoll mechanism.
public struct Epoll: FileDescriptor {

  // MARK: - Properties

  /// The file descriptor for this epoll instance.
  public let fileDescriptor: Int32

  // MARK: - Constructors

  /// Creates an epoll instance with the specified flags.
  public init(flags: Flags = []) throws {
    let ret = epoll_create1(flags.rawValue)
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  // MARK: - Methods

  /// Adds the file descriptor to the list of FDs watched by this epoll instance.
  /// The `event` argument defines what event types to watch for and optional
  /// user data associated with the event.
  public func add(fd: FileDescriptor, event: PollEvent) throws {
    try apply(EPOLL_CTL_ADD, fd: fd.fileDescriptor, event: event)
  }

  /// Updates the event types and user data associated with the file descriptor
  /// for this epoll instance.
  public func update(fd: FileDescriptor, event: PollEvent) throws {
    try apply(EPOLL_CTL_MOD, fd: fd.fileDescriptor, event: event)
  }

  /// Removes the file descriptor from the list of FDs watched by this epoll instance.
  public func remove(fd: FileDescriptor) throws {
    try apply(EPOLL_CTL_DEL, fd: fd.fileDescriptor, event: nil)
  }

  private func apply(_ op: Int32, fd: Int32, event: PollEvent?) throws {
    let ret: Int32
    if let event = event {
      var ev = event.toCStruct()
      ret = epoll_ctl(fileDescriptor, op, fd, &ev)
    } else {
      ret = epoll_ctl(fileDescriptor, op, fd, nil)
    }
    try CError.makeAndThrow(fromReturnCode: ret)
  }

  /// Polls for and returns available events into `events`, blocking as required.
  /// If a timeout is set, unblocks after this delay if no events are available.
  /// Signals may be blocked atomically by providing a SignalSet to `blockedSignals`.
  /// Returns the number of events available in `events`. No more than `events.count` events
  /// will be returned.
  public func poll(into events: inout [PollEvent], timeout: TimeInterval? = nil, blockedSignals signals: SignalSet? = nil) throws -> Int {
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
      events[i] = PollEvent(epollEvent: eevs[i])
    }
    return Int(ret)
  }

  /// Releases the resources for this file descriptor.
  public func close() throws {
    let ret = Libc.close(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

// MARK: - Epoll+Flags

extension Epoll {
  /// Linux only. Flags available to configure the epoll instance.
  public struct Flags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let cloExec = Flags(rawValue: Int32(EPOLL_CLOEXEC))
  }
}
