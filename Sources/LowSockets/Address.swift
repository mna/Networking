import Libc

public struct Family {
  public let value: Int32

  init(value: Int32) {
    self.value = value
  }

  public static let ip4 = Family(value: AF_INET)
  public static let ip6 = Family(value: AF_INET6)
  public static let unix = Family(value: AF_LOCAL)
  public static let unknown = Family(value: -1)

  static func make(_ v: Int32) -> Family {
    switch v {
    case Family.ip4.value:
      return .ip4
    case Family.ip6.value:
      return .ip6
    case Family.unix.value:
      return .unix
    default:
      return .unknown
    }
  }
}

public struct SocketType {
  public let value: Int32

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
}

public struct SocketProtocol {
  public let value: Int32

  init(value: Int32) {
    self.value = value
  }

  public static let tcp = SocketProtocol(value: IPPROTO_TCP)
  public static let udp = SocketProtocol(value: IPPROTO_UDP)
  public static let unix = SocketProtocol(value: 0)
  public static let unknown = SocketProtocol(value: -1)

  static func make(_ v: Int32) -> SocketProtocol {
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
}
