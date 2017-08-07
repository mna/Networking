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
          XCTAssertEqual(addr.port, c.1)
        }
      } catch {
        XCTFail("\(c.0) failed with \(error)")
      }
    }
  }

  func testResolveIP() {
    let cases: [String: [IPAddress]] = [
      "localhost": [IPAddress(127, 0, 0, 1), IPAddress(0, 0, 0, 0, 0, 0, 0, 1)], // loopback addresses
      "broadcasthost": [IPAddress(255, 255, 255, 255)],
    ]

    for c in cases {
      do {
        let (_, got) = try AddrInfo.get(host: c.key, type: .stream)
        let gotSet = Set<IPAddress>(got.map({ $0.ip }))
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
