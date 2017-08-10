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

  static func make(_ value: Int32) -> Family? {
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

public enum SocketType {
  case stream
  case datagram

  var value: Int32 {
    guard let v = SocketType.toValues[self] else {
      fatalError("unknown SocketType enum: \(self)")
    }
    return v
  }

  static func make(_ value: Int32) -> SocketType? {
    return fromValues[value]
  }

  private static let toValues: [SocketType: Int32] = [
    .stream: SOCK_STREAM,
    .datagram: SOCK_DGRAM,
  ]

  private static let fromValues: [Int32: SocketType] = [
    SOCK_STREAM: .stream,
    SOCK_DGRAM: .datagram,
  ]
}

// MARK: - SocketProtocol

public enum SocketProtocol {
  case tcp
  case udp
  case unix

  var value: Int32 {
    guard let v = SocketProtocol.toValues[self] else {
      fatalError("unknown SocketProtocol enum: \(self)")
    }
    return v
  }

  static func make(_ value: Int32) -> SocketProtocol? {
    return fromValues[value]
  }

  private static let toValues: [SocketProtocol: Int32] = [
    .tcp: IPPROTO_TCP,
    .udp: IPPROTO_UDP,
    .unix: 0,
  ]

  private static let fromValues: [Int32: SocketProtocol] = [
    IPPROTO_TCP: .tcp,
    IPPROTO_UDP: .udp,
    0: .unix,
  ]
}
