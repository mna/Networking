import Libc

// MARK: - AddrInfo

public struct AddrInfo {
  private init() {}

  // MARK: - Flags

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

  // MARK: - Static Methods

  public static func `get`(host: String? = nil, service: String? = nil, flags: Flags = .default, family: Family = .unknown, type: SocketType = .unknown, proto: SocketProtocol = .unknown) throws -> (String, [Address]) {

    var hints = addrinfo()
    hints.ai_flags = flags.rawValue

    if family != .unknown {
      hints.ai_family = family.value
    }
    if type != .unknown {
      hints.ai_socktype = type.value
    }
    if proto != .unknown {
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
      case Family.ip4.value:
        var port = 0

        let bytes: [UInt8] = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sai in
          let count = MemoryLayout.stride(ofValue: sai.pointee.sin_addr)
          port = Int(Endianness.ntoh(sai.pointee.sin_port))
          return withUnsafePointer(to: &sai.pointee.sin_addr) { sad in
            return sad.withMemoryRebound(to: UInt8.self, capacity: count) {
              return Array(UnsafeBufferPointer(start: $0, count: count))
            }
          }
        }
        if let ip = IPAddress(bytes: bytes) {
          addrs.append(Address(ip: ip, port: port))
        }

      case Family.ip6.value:
        var port = 0
        var scopeID = 0

        let bytes: [UInt8] = addr.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sai in
          port = Int(Endianness.ntoh(sai.pointee.sin6_port))
          scopeID = Int(sai.pointee.sin6_scope_id)

          let count = MemoryLayout.stride(ofValue: sai.pointee.sin6_addr)
          return withUnsafePointer(to: &sai.pointee.sin6_addr) { sad in
            return sad.withMemoryRebound(to: UInt8.self, capacity: count) {
              return Array(UnsafeBufferPointer(start: $0, count: count))
            }
          }
        }
        if let ip = IPAddress(bytes: bytes) {
          addrs.append(Address(ip: ip, port: port, scopeID: scopeID))
        }

      default:
        break
      }
      list = addr.pointee.ai_next
    }
    return (cname, addrs)
  }
}
