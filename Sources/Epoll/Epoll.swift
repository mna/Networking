import Glibc
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

    static let cloExec = Flags(rawValue: EPOLL_CLOEXEC)
  }
}
