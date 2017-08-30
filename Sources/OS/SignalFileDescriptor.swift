#if os(Linux)

import Libc

// MARK: - SignalFileDescriptor

/// SignalFileDescriptor is a file descriptor for a signal(s) as described in
/// signalfd(2).
public struct SignalFileDescriptor: FileDescriptor {
  private static let siginfoSize: Int = MemoryLayout<signalfd_siginfo>.stride

  /// The file descriptor for the signal.
  public let fileDescriptor: Int32

  init(_ fd: Int32) {
    self.fileDescriptor = fd
  }

  /// Reads the next signal from the file descriptor. See signalfd(2) for details
  /// on the behaviour of this call.
  public func next() throws -> Signal {
    var si = signalfd_siginfo()
    let ret = read(fileDescriptor, &si, SignalFileDescriptor.siginfoSize)
    try CError.makeAndThrow(fromReturnCode: Int32(ret))

    if let signal = Signal.make(Int32(si.ssi_signo)) {
      return signal
    }
    fatalError("unknown Signal \(ret)")
  }

  /// Releases the resources for this file descriptor.
  public func close() throws {
    let ret = Libc.close(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

#endif
