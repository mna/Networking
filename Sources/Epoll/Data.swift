// MARK: - Data

public enum Data {
  case fd(Int32)
  case u32(UInt32)
  case u64(UInt64)
  case ptr(UnsafeMutableRawPointer)

  public init?(asU32 d: Data) {
    guard case let .u64(u) = d, let u32 = UInt32(exactly: u) else {
      return nil
    }
    self = .u32(u32)
  }

  public init?(asFD d: Data) {
    guard case let .u64(u) = d, let i32 = Int32(exactly: u) else {
      return nil
    }
    self = .fd(i32)
  }

  public init?(asPtr d: Data) {
    guard case let .u64(u64) = d, let u = UInt(exactly: u64) else {
      return nil
    }
    guard let p = UnsafeMutableRawPointer(bitPattern: u) else {
      return nil
    }
    self = .ptr(p)
  }
}

// MARK: - Data+Equatable

extension Data: Equatable {
  public static func ==(lhs: Data, rhs: Data) -> Bool {
    switch (lhs, rhs) {
    case let (.fd(l), .fd(r)):
      return l == r
    case let (.u32(l), .u32(r)):
      return l == r
    case let (.u64(l), .u64(r)):
      return l == r
    case let (.ptr(l), .ptr(r)):
      return l == r
    default:
      return false
    }
  }
}
