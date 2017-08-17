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

// MARK: - Kqueue+Flags

extension Kqueue {
  struct Flags: OptionSet {
    let rawValue: Int32

    init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    static let add: Flags = Flags(rawValue: EV_ADD)
    static let enable: Flags = Flags(rawValue: EV_ENABLE)
    static let disable: Flags = Flags(rawValue: EV_DISABLE)
    static let dispatch: Flags = Flags(rawValue: EV_DISPATCH)
    static let delete: Flags = Flags(rawValue: EV_DELETE)
    static let receipt: Flags = Flags(rawValue: EV_RECEIPT)
    static let oneShot: Flags = Flags(rawValue: EV_ONESHOT)
    static let clear: Flags = Flags(rawValue: EV_CLEAR)
    static let eof: Flags = Flags(rawValue: EV_EOF)
    static let error: Flags = Flags(rawValue: EV_ERROR)
  }
}
