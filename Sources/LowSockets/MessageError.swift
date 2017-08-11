// MARK: - MessageError

/// MessageError is a String-based error that can be created with additional
/// contextual key-value pairs.
public struct MessageError: Swift.Error {
  public let message: String

  public init(_ message: String, context: [String: String] = [:]) {
    if context.isEmpty {
      self.message = message
    } else {
      let prefix = context.map({ "\($0.key): \($0.value)" }).joined(separator: ", ")
      self.message = "\(prefix): \(message)"
    }
  }
}

// MARK: - MessageError+CustomStringConvertible

extension MessageError: CustomStringConvertible {
  public var description: String {
    return message
  }
}
