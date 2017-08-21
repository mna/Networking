#if os(Linux)

import Libc

// to avoid ambiguity between the SignalFileDescriptor methods and the system calls.
private let cclose = close

public class SignalFileDescriptor: FileDescriptorRepresentable {
  private static let siginfoSize: Int = MemoryLayout<signalfd_siginfo>.stride

  public let fileDescriptor: Int32

  init(_ fd: Int32) {
    self.fileDescriptor = fd
  }

  deinit {
    try? close()
  }

  public func next() throws -> Signal {
    var si = signalfd_siginfo()
    let ret = read(fileDescriptor, &si, SignalFileDescriptor.siginfoSize)
    try CError.makeAndThrow(fromReturnCode: Int32(ret))

    if let signal = Signal.make(Int32(si.ssi_signo)) {
      return signal
    }
    fatalError("unknown Signal \(ret)")
  }

  public func close() throws {
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}

#endif
