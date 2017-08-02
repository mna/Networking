import LowSockets

public enum Network {
  case tcp
  case udp
  case unix
  case unixgram
}

public protocol AddressProtocol {
  // network defines the protocol and socket type:
  // - tcp: stream
  // - udp: datagram
  // - unix: stream
  // - unixgram: datagram
  //
  // The Family is easy to infer from the Address.
  var network: Network { get }
}

public struct TCPAddress: AddressProtocol {
  public var network: Network {
    return .tcp
  }
}

public struct UDPAddress: AddressProtocol {
  public var network: Network {
    return .udp
  }
}

public struct UnixAddress: AddressProtocol {
  private let isDatagram: Bool

  public var network: Network {
    return isDatagram ? .unixgram : .unix
  }
}
