import Libc

// MARK: - IPAddress

/// IPAddress represents an IP (v4 or v6) address.
public struct IPAddress: Equatable {

  // MARK: - IPAddress+Equatable

  static public func ==(lhs: IPAddress, rhs: IPAddress) -> Bool {
    return lhs.bytes.elementsEqual(rhs.bytes)
  }

  let bytes: [UInt8]

  // MARK: - Constructors

  /// Creates an IPAddress by parsing the string which must be in "1.2.3.4" or
  /// "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff" formats (IPv4 or IPv6).
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
      guard inet_pton(Family.inet.value, s, &addr) == 1 else {
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
    guard inet_pton(Family.inet6.value, s, &addr) == 1 else {
      return nil
    }
    self.bytes = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<in6_addr>.size) {
        Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<in6_addr>.size))
      }
    }
    return
  }

  init?(bytes: [UInt8]) {
    guard bytes.count == 4 || bytes.count == 16 else {
      return nil
    }
    self.bytes = bytes
  }

  /// Creates an IPv4 address. The four UInt8 arguments represent the
  /// 4 bytes of the address, matching the IPv4 display format.
  init(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) {
    self.bytes = [b0, b1, b2, b3]
  }

  /// Creates an IPv6 address. The UInt16 arguments can be passed as
  /// hexadecimal to match the IPv6 display format.
  init(_ bb0: UInt16, _ bb1: UInt16, _ bb2: UInt16, _ bb3: UInt16,
       _ bb4: UInt16, _ bb5: UInt16, _ bb6: UInt16, _ bb7: UInt16) {

    self.bytes = [
      UInt8(truncatingBitPattern: bb0 >> 8), UInt8(bb0 & 0xFF),
      UInt8(truncatingBitPattern: bb1 >> 8), UInt8(bb1 & 0xFF),
      UInt8(truncatingBitPattern: bb2 >> 8), UInt8(bb2 & 0xFF),
      UInt8(truncatingBitPattern: bb3 >> 8), UInt8(bb3 & 0xFF),
      UInt8(truncatingBitPattern: bb4 >> 8), UInt8(bb4 & 0xFF),
      UInt8(truncatingBitPattern: bb5 >> 8), UInt8(bb5 & 0xFF),
      UInt8(truncatingBitPattern: bb6 >> 8), UInt8(bb6 & 0xFF),
      UInt8(truncatingBitPattern: bb7 >> 8), UInt8(bb7 & 0xFF),
    ]
  }

  // MARK: - Properties

  /// Indicates the address family (ip4 or ip6).
  var family: Family {
    switch bytes.count {
    case 4:
      return .inet
    case 16:
      return .inet6
    default:
      fatalError("unknown family for byte count \(bytes.count)")
    }
  }
}
