// MARK: - Data

enum Data {
  case fd(Int32)
  case u32(UInt32)
  case u64(UInt64)
  case ptr(UnsafeMutableRawPointer)

  // TODO: helper methods to switch u64 returned from epoll_wait to
  // fd, u32 or ptr
}
