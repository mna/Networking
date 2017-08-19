import XCTest
@testable import LowSockets

// MARK: - IPAddress+Hashable

extension IPAddress: Hashable {
  public var hashValue: Int {
    // stupid implementation just for tests
    return "\(bytes)".hashValue
  }
}

class AddrInfoTests: XCTestCase {
  func testResolveService() {
    let cases: [(String, Int)] = [
      ("http", 80),
      ("https", 443),
    ]

    for c in cases {
      do {
        let (_, addrs) = try AddrInfo.get(service: c.0, proto: .tcp)
        for addr in addrs {
          switch addr {
          case .ip4(_, let port):
            XCTAssertEqual(port, c.1)
          case .ip6(_, let port, _):
            XCTAssertEqual(port, c.1)
          default:
            XCTFail("unexpected address type: \(addr)")
          }
        }
      } catch {
        XCTFail("\(c.0) failed with \(error)")
      }
    }
  }

  func testResolveIP() {
    #if os(Linux)
      // presume Linux doesn't have ipv6 enabled, nor broadcasthost
      let cases: [String: [IPAddress]] = [
        "localhost": [.ipv4Loopback], // loopback addresses
      ]
    #else
      let cases: [String: [IPAddress]] = [
        "localhost": [.ipv4Loopback, .ipv6Loopback], // loopback addresses
        "broadcasthost": [IPAddress(255, 255, 255, 255)],
      ]
    #endif

    for c in cases {
      do {
        let (_, got) = try AddrInfo.get(host: c.key, type: .stream)
        let gotSet = Set<IPAddress>(got.flatMap({
          switch $0 {
          case .ip4(let ip, _):
            return ip
          case .ip6(let ip, _, _):
            return ip
          default:
            XCTFail("unexpected address type \($0)")
            return nil
          }
        }))
        let wantSet = Set<IPAddress>(c.value)
        if gotSet != wantSet {
          XCTFail("want \(wantSet), got \(gotSet)")
        }
      } catch {
        XCTFail("\(c.key): failed with \(error)")
      }
    }
  }

  func testResolveCNAME() {
    // TODO: works only if connected to internet, maybe find something else or
    // skip if no connection.
    do {
      let (cname, _) = try AddrInfo.get(host: "www.twitter.com", flags: [.default, .canonName], type: .stream)
      XCTAssertEqual("twitter.com.", cname)
    } catch {
      XCTFail("\(error)")
    }
  }
}

#if os(Linux)
  extension AddrInfoTests {
    static var allTests : [(String, (AddrInfoTests) -> () throws -> Void)] {
      return [
        ("testResolveService", testResolveService),
        ("testResolveIP", testResolveIP),
        ("testResolveCNAME", testResolveCNAME),
      ]
    }
  }
#endif
