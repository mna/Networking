import Libc

// MARK: - Family

public enum Family {
  case inet
  case inet6
  case unix
  case unspec

  var value: Int32 {
    guard let v = Family.toValues[self] else {
      fatalError("unknown Family enum: \(self)")
    }
    return v
  }

  func make(_ value: Int32) -> Family? {
    return fromValues[value]
  }

  private static let toValues: [Family: Int32] = [
    .inet: AF_INET,
    .inet6: AF_INET6,
    .unix: AF_LOCAL,
    .unspec: AF_UNSPEC,
  ]

  private static let fromValues: [Int32: Family] = [
    AF_INET: .inet,
    AF_INET6: .inet6,
    AF_LOCAL: .unix,
    AF_UNIX: .unix,
    AF_UNSPEC: .unspec,
  ]
}

// MARK: - SocketType

public struct SocketType: Equatable {
  let value: Int32

  init(value: Int32) {
    self.value = value
  }

  public static let stream = SocketType(value: SOCK_STREAM)
  public static let datagram = SocketType(value: SOCK_DGRAM)
  public static let unknown = SocketType(value: -1)

  static func make(_ v: Int32) -> SocketType {
    switch v {
    case SocketType.stream.value:
      return .stream
    case SocketType.datagram.value:
      return .datagram
    default:
      return .unknown
    }
  }

  public static func ==(lhs: SocketType, rhs: SocketType) -> Bool {
    return lhs.value == rhs.value
  }
}

// MARK: - SocketProtocol

public struct SocketProtocol: Equatable {
  let value: Int32

  init(value: Int32) {
    self.value = value
  }

  public static let tcp = SocketProtocol(value: IPPROTO_TCP)
  public static let udp = SocketProtocol(value: IPPROTO_UDP)
  public static let unix = SocketProtocol(value: 0)
  public static let unknown = SocketProtocol(value: -1)

  public static func make(_ v: Int32) -> SocketProtocol {
    switch v {
    case SocketProtocol.tcp.value:
      return .tcp
    case SocketProtocol.udp.value:
      return .udp
    case SocketProtocol.unix.value:
      return .unix
    default:
      return .unknown
    }
  }

  public static func ==(lhs: SocketProtocol, rhs: SocketProtocol) -> Bool {
    return lhs.value == rhs.value
  }
}
