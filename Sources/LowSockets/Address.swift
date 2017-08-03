import Libc

// MARK: - Family

struct Family {
  let value: Int32

  init(value: Int32) {
    self.value = value
  }

  static let ip4 = Family(value: AF_INET)
  static let ip6 = Family(value: AF_INET6)
  static let unix = Family(value: AF_LOCAL)
  static let unknown = Family(value: -1)

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

// MARK: - SocketType

struct SocketType {
  let value: Int32

  init(value: Int32) {
    self.value = value
  }

  static let stream = SocketType(value: SOCK_STREAM)
  static let datagram = SocketType(value: SOCK_DGRAM)
  static let unknown = SocketType(value: -1)

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

// MARK: - SocketProtocol

struct SocketProtocol {
  let value: Int32

  init(value: Int32) {
    self.value = value
  }

  static let tcp = SocketProtocol(value: IPPROTO_TCP)
  static let udp = SocketProtocol(value: IPPROTO_UDP)
  static let unix = SocketProtocol(value: 0)
  static let unknown = SocketProtocol(value: -1)

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
