import Libc
import OS

// MARK: - AddrInfo

public enum AddrInfo {

  // MARK: - Static Methods

  // TODO: move as static method on Address (i.e. Address.resolve?)
  public static func `get`(host: String? = nil, service: String? = nil, flags: Flags = .default, family: Family? = nil, type: SocketType? = nil, proto: SocketProtocol? = nil) throws -> (String, [Address]) {
    var hints = addrinfo()
    hints.ai_flags = flags.rawValue

    if let family = family {
      hints.ai_family = family.value
    }
    if let type = type {
      hints.ai_socktype = type.value
    }
    if let proto = proto {
      hints.ai_protocol = proto.value
    }

    var info: UnsafeMutablePointer<addrinfo>?
    defer {
      if info != nil {
        freeaddrinfo(info)
      }
    }

    let service = service?.lowercased()
    let ret: Int32
    switch (host, service) {
    case let (host?, nil):
      ret = getaddrinfo(host, nil, &hints, &info)
    case let (nil, service?):
      ret = getaddrinfo(nil, service, &hints, &info)
    case let (host?, service?):
      ret = getaddrinfo(host, service, &hints, &info)
    case (nil, nil):
      ret = getaddrinfo(nil, nil, &hints, &info)
    }
    try CError.makeAndThrow(fromGAICode: ret)

    var list = info
    var firstLoop = true
    var cname = ""
    var addrs: [Address] = []

    while true {
      guard let addr = list else {
        break
      }

      if firstLoop && flags.contains(.canonName) {
        if addr.pointee.ai_canonname != nil {
          cname = String(validatingUTF8: addr.pointee.ai_canonname) ?? ""
          if let last = cname.characters.last, last != "." {
            cname.append(".")
          }
        }
        firstLoop = false
      }

      switch addr.pointee.ai_family {
      case Family.inet.value:
        let addr: Address? = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sai in
          Address(sockaddr: sai.pointee)
        }
        if let addr = addr {
          addrs.append(addr)
        }

      case Family.inet6.value:
        let addr: Address? = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sai in
          Address(sockaddr: sai.pointee)
        }
        if let addr = addr {
          addrs.append(addr)
        }

      default:
        break
      }
      list = addr.pointee.ai_next
    }
    return (cname, addrs)
  }
}

// MARK: - AddrInfo+Flags

extension AddrInfo {
  public struct Flags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let addrConfig = Flags(rawValue: AI_ADDRCONFIG)
    public static let all = Flags(rawValue: AI_ALL)
    public static let canonName = Flags(rawValue: AI_CANONNAME)
    public static let numericHost = Flags(rawValue: AI_NUMERICHOST)
    public static let numericServ = Flags(rawValue: AI_NUMERICSERV)
    public static let passive = Flags(rawValue: AI_PASSIVE)
    public static let v4Mapped = Flags(rawValue: AI_V4MAPPED)

    #if os(Linux)
      public static let `default`: Flags = [v4Mapped, addrConfig]
    #else
      public static let v4MappedCfg = Flags(rawValue: AI_V4MAPPED_CFG)
      public static let `default`: Flags = [v4MappedCfg, addrConfig]
    #endif
  }
}
