import Libc

// MARK: - Family

struct Family: Equatable {
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

  static func ==(lhs: Family, rhs: Family) -> Bool {
    return lhs.value == rhs.value
  }
}

// MARK: - SocketType

struct SocketType: Equatable {
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

  static func ==(lhs: SocketType, rhs: SocketType) -> Bool {
    return lhs.value == rhs.value
  }
}

// MARK: - SocketProtocol

struct SocketProtocol: Equatable {
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

  static func ==(lhs: SocketProtocol, rhs: SocketProtocol) -> Bool {
    return lhs.value == rhs.value
  }
}
