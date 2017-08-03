// MARK: - Error

struct Error: Swift.Error {
  let msg: String

  init(_ msg: String, context: [String: String] = [:]) {
    if context.isEmpty {
      self.msg = msg
    } else {
      let prefix = context.map({ "\($0.key): \($0.value)" }).joined(separator: ", ")
      self.msg = "\(prefix): \(msg)"
    }
  }
}
