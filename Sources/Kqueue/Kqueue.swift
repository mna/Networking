import Darwin.C
import Networking

// to avoid ambiguity between the Kqueue methods and the system calls.
private let cclose = close

// MARK: - Kqueue

class Kqueue: FileDescriptorRepresentable {

  // MARK: - Properties

  public let fileDescriptor: Int32

  // MARK: - Constructors

  init() throws {
    let ret = kqueue()
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  func close() throws {
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}
