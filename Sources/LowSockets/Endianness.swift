// MARK: - Endianness

enum Endianness {
  case little
  case big

  static private(set) var host: Endianness = {
    let number: UInt32 = 0x12345678
    let converted = number.bigEndian
    if number == converted {
      return .big
    } else {
      return .little
    }
  }()

  // BUG: why isn't byteSwapped defined on Integer protocol?

  static func ntoh(_ n: Int) -> Int {
    if host == .big {
      return n
    }
    return n.byteSwapped
  }

  static func ntoh(_ n: Int16) -> Int16 {
    if host == .big {
      return n
    }
    return n.byteSwapped
  }

  static func ntoh(_ n: Int32) -> Int32 {
    if host == .big {
      return n
    }
    return n.byteSwapped
  }

  static func ntoh(_ n: Int64) -> Int64 {
    if host == .big {
      return n
    }
    return n.byteSwapped
  }

  static func ntoh(_ n: UInt) -> UInt {
    if host == .big {
      return n
    }
    return n.byteSwapped
  }

  static func ntoh(_ n: UInt16) -> UInt16 {
    if host == .big {
      return n
    }
    return n.byteSwapped
  }

  static func ntoh(_ n: UInt32) -> UInt32 {
    if host == .big {
      return n
    }
    return n.byteSwapped
  }

  static func ntoh(_ n: UInt64) -> UInt64 {
    if host == .big {
      return n
    }
    return n.byteSwapped
  }
}

