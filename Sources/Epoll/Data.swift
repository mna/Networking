// MARK: - Data

enum Data {
  case fd(Int32)
  case u32(UInt32)
  case u64(UInt64)
  case ptr(UnsafeMutableRawPointer)

  init?(asU32 u64: UInt64) {
    guard let u32 = UInt32(exactly: u64) else {
      return nil
    }
    self = .u32(u32)
  }

  init?(asFD u64: UInt64) {
    guard let i32 = Int32(exactly: u64) else {
      return nil
    }
    self = .fd(i32)
  }

  init?(asPtr u64: UInt64) {
    guard let u = UInt(exactly: u64),
      let p = UnsafeMutableRawPointer(bitPattern: u) else {
      return nil
    }
    self = .ptr(p)
  }
}
