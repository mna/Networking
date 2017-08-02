import Libc

public struct Error: Swift.Error {
  public let code: Int32
  public let message: String

  private init?(fromReturnCode code: Int32, errorValue: Int32 = -1) {
    guard code == errorValue else {
      return nil
    }

    self.code = errno
    self.message = String(validatingUTF8: strerror(errno)) ?? ""
  }

  static func makeAndThrow(fromReturnCode code: Int32, errorValue: Int32 = -1) throws {
    if let err = Error(fromReturnCode: code, errorValue: errorValue) {
      throw err
    }
  }
}

extension Error: CustomStringConvertible {
  public var description: String {
    return "error \(code): \(message)"
  }
}
