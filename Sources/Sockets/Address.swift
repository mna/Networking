import LowSockets

/*
public enum IPVersion {
  case any
  case v4
  case v6
}

public enum UnixType {
  case stream
  case datagram
  // TODO: case packet?
}

public enum Network {
  case tcp(IPVersion)
  case udp(IPVersion)
  case unix(UnixType)
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
    return .tcp(.any)
  }
}

public struct UDPAddress: AddressProtocol {
  public var network: Network {
    return .udp(.any)
  }
}

public struct UnixAddress: AddressProtocol {
  private let isDatagram: Bool

  public var network: Network {
    return isDatagram ? .unix(.datagram) : .unix(.stream)
  }
}

*/
