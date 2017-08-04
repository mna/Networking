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
      // parse as IPv4 address
      var addr = in_addr()
      guard inet_pton(Family.ip4.value, s, &addr) == 1 else {
        return nil
      }
      self.bytes = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<in_addr>.size) {
          Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<in_addr>.size))
        }
      }
      return
    }

    // parse as IPv6 address
    var addr = in6_addr()
    guard inet_pton(Family.ip6.value, s, &addr) == 1 else {
      return nil
    }
    self.bytes = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<in6_addr>.size) {
        Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<in6_addr>.size))
      }
    }
    return
  }

  init(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) {
    self.bytes = [b0, b1, b2, b3]
  }

  init(_ bb0: UInt16, _ bb1: UInt16, _ bb2: UInt16, _ bb3: UInt16,
       _ bb4: UInt16, _ bb5: UInt16, _ bb6: UInt16, _ bb7: UInt16) {

    self.bytes = [
      UInt8(bb0 >> 1), UInt8(bb0 & 0xFF),
      UInt8(bb1 >> 1), UInt8(bb1 & 0xFF),
      UInt8(bb2 >> 1), UInt8(bb2 & 0xFF),
      UInt8(bb3 >> 1), UInt8(bb3 & 0xFF),
      UInt8(bb4 >> 1), UInt8(bb4 & 0xFF),
      UInt8(bb5 >> 1), UInt8(bb5 & 0xFF),
      UInt8(bb6 >> 1), UInt8(bb6 & 0xFF),
      UInt8(bb7 >> 1), UInt8(bb7 & 0xFF),
    ]
  }

  var family: Family {
    switch bytes.count {
    case 4:
      return .ip4
    case 16:
      return .ip6
    default:
      return .unknown
    }
  }
}
