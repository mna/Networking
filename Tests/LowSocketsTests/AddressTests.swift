import XCTest
@testable import LowSockets

// MARK: - IPAddress+Hashable

extension IPAddress: Hashable {
  public var hashValue: Int {
    // stupid implementation just for tests
    return "\(bytes)".hashValue
  }
}

// MARK: - AddressTests

class AddressTests: XCTestCase {
  // Test cases from Go net/ip_test.go
  let splitJoinCases: [(host: String, port: String, join: String)] = [
    ("www.google.com", "80", "www.google.com:80"),
    ("127.0.0.1", "1234", "127.0.0.1:1234"),
    ("::1", "80", "[::1]:80"),
    ("fe80::1%lo0", "80", "[fe80::1%lo0]:80"),
    ("localhost%lo0", "80", "[localhost%lo0]:80"),
    ("", "0", ":0"),
    ("google.com", "https%foo", "google.com:https%foo"),
    ("127.0.0.1", "", "127.0.0.1:"),
    ("www.google.com", "", "www.google.com:"),
  ]

  // Test cases from Go net/ip_test.go
  let splitFailureCases: [(hostPort: String, err: String)] = [
    ("www.google.com", "missing port"),
    ("127.0.0.1", "missing port"),
    ("[::1]", "missing port"),
    ("[fe80::1%lo0]", "missing port"),
    ("[localhost%lo0]", "missing port"),
    ("localhost%lo0", "missing port"),
    ("::1", "too many colons"),
    ("fe80::1%lo0", "too many colons"),
    ("fe80::1%lo0:80", "too many colons"),
    ("localhost%lo0:80", "missing brackets"),
    ("[foo:bar]", "missing port"),
    ("[foo:bar]baz", "missing port"),
    ("[foo]bar:baz", "missing port"),
    ("[foo]:[bar]:baz", "too many colons"),
    ("[foo]:[bar]baz", "unexpected '['"),
    ("foo[bar]:baz", "unexpected '['"),
    ("foo]bar:baz", "unexpected ']'"),
  ]

  func testJoinHostPort() {
    let cases: [(host: String, port: String, join: String)] = [
      ("", "", ":"),
      ("a", "", "a:"),
      ("a", "b", "a:b"),
      ("a:b", "c", "[a:b]:c"),
      ("a%b", "c", "[a%b]:c"),
      ("a%b:c", "d", "[a%b:c]:d"),
      ("%", "c", "[%]:c"),
      (":", "c", "[:]:c"),
      ("%:", "c", "[%:]:c"),
      ("%a", "c", "[%a]:c"),
      (":a", "c", "[:a]:c"),
      ("%:a", "c", "[%:a]:c"),
      ("a%", "c", "[a%]:c"),
      ("a:", "c", "[a:]:c"),
      ("a%:", "c", "[a%:]:c"),
    ]

    for c in cases + splitJoinCases {
      let got = Address.join(host: c.host, port: c.port)
      XCTAssertEqual(c.join, got)
    }
  }

  func testSplitHostPort() {
    for c in splitJoinCases {
      do {
        let got = try Address.split(hostPort: c.join)

        XCTAssertEqual(c.host, got.0)
        XCTAssertEqual(c.port, got.1)
      } catch {
        XCTFail("unexpected error: \(error)")
      }
    }

    for c in splitFailureCases {
      do {
        _ = try Address.split(hostPort: c.hostPort)
        XCTFail("expected error: \(c.hostPort)")
      } catch {
        let msg = "\(error)"
        if !msg.contains(c.err) {
          XCTFail("expected \(c.err), got \(msg)")
        }
      }
    }
  }

  func testResolveService() {
    let cases: [(String, Int)] = [
      ("http", 80),
      ("https", 443),
    ]

    for c in cases {
      do {
        let (_, addrs) = try Address.resolve(service: c.0, proto: .tcp)
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
        "localhost": [.ip4Loopback], // loopback addresses
      ]
    #else
      let cases: [String: [IPAddress]] = [
        "localhost": [.ip4Loopback, .ip6Loopback], // loopback addresses
        "broadcasthost": [IPAddress(255, 255, 255, 255)],
      ]
    #endif

    for c in cases {
      do {
        let (_, got) = try Address.resolve(host: c.key, type: .stream)
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
        if !wantSet.isSubset(of: gotSet) {
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
      let (cname, _) = try Address.resolve(host: "www.twitter.com", flags: [.default, .canonName], type: .stream)
      XCTAssertEqual("twitter.com.", cname)
    } catch {
      XCTFail("\(error)")
    }
  }
}

#if os(Linux)
  extension AddressTests {
    static var allTests : [(String, (AddressTests) -> () throws -> Void)] {
      return [
        ("testJoinHostPort", testJoinHostPort),
        ("testSplitHostPort", testSplitHostPort),
        ("testResolveService", testResolveService),
        ("testResolveIP", testResolveIP),
        ("testResolveCNAME", testResolveCNAME),
      ]
    }
  }
#endif
