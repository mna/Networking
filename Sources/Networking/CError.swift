import Libc

// MARK: - CError

public struct CError: Swift.Error {
  public let code: Int32
  public let message: String

  private init?(fromReturnCode code: Int32, errorValue: Int32 = -1) {
    guard code == errorValue else {
      return nil
    }

    self.code = errno
    self.message = String(validatingUTF8: strerror(errno)) ?? ""
  }

  private init?(fromGAICode code: Int32) {
    // getaddrinfo is an error if != 0
    guard code != 0 else {
      return nil
    }

    self.code = code
    self.message = String(validatingUTF8: gai_strerror(code)) ?? ""
  }

  public static func makeAndThrow(fromReturnCode code: Int32, errorValue: Int32 = -1) throws {
    if let err = CError(fromReturnCode: code, errorValue: errorValue) {
      throw err
    }
  }

  public static func makeAndThrow(fromGAICode code: Int32) throws {
    if let err = CError(fromGAICode: code) {
      throw err
    }
  }
}

// MARK: - CError+CustomStringConvertible

extension CError: CustomStringConvertible {
  public var description: String {
    return "error \(code): \(message)"
  }
}
