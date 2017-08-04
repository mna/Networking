import Libc

// MARK: - IPAddress

struct IPAddress {
  let bytes: [UInt8]

  init?(parsing s: String) {
    guard !s.isEmpty else {
      return nil
    }

    let chars = [Character](s.characters)
    let i4 = chars.index(of: ".") ?? chars.count
    let i6 = chars.index(of: ":") ?? chars.count
    if i4 < i6 {
      var addr = in_addr()
      guard inet_pton(Family.ip4.value, s, &addr) == 1 else {
        return nil
      }
      self.bytes = withUnsafePointer(to: &addr.s_addr) {
        $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<in_addr>.size) {
          Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<in_addr>.size))
        }
      }
      print(bytes)

    } else {
      var addr = in6_addr()
      guard inet_pton(Family.ip6.value, s, &addr) == 1 else {
        return nil
      }
      print(addr)
    }
    return nil
  }

  init(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) {
    self.bytes = [b0, b1, b2, b3]
  }

  var family: Family {
    switch bytes.count {
    case 4:
      return .ip4
    case 6:
      return .ip6
    default:
      return .unknown
    }
  }
}
