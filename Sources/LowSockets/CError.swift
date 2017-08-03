import Libc

// MARK: - CError

struct CError: Swift.Error {
  let code: Int32
  let message: String

  private init?(fromReturnCode code: Int32, errorValue: Int32 = -1) {
    guard code == errorValue else {
      return nil
    }

    self.code = errno
    self.message = String(validatingUTF8: strerror(errno)) ?? ""
  }

  static func makeAndThrow(fromReturnCode code: Int32, errorValue: Int32 = -1) throws {
    if let err = CError(fromReturnCode: code, errorValue: errorValue) {
      throw err
    }
  }
}

// MARK: - CError+CustomStringConvertible

extension CError: CustomStringConvertible {
  var description: String {
    return "error \(code): \(message)"
  }
}
