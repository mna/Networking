import XCTest
@testable import LowSockets

// MARK: - IPAddress+Hashable

extension IPAddress: Hashable {
  public var hashValue: Int {
    // stupid implementation just for tests
    return "\(bytes)".hashValue
  }
}

// MARK: - ResolverTests

class ResolverTests: XCTestCase {
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
      let got = Resolver.join(host: c.host, port: c.port)
      XCTAssertEqual(c.join, got)
    }
  }

  func testSplitHostPort() {
    for c in splitJoinCases {
      do {
        let got = try Resolver.split(hostPort: c.join)

        XCTAssertEqual(c.host, got.0)
        XCTAssertEqual(c.port, got.1)
      } catch {
        XCTFail("unexpected error: \(error)")
      }
    }

    for c in splitFailureCases {
      do {
        _ = try Resolver.split(hostPort: c.hostPort)
        XCTFail("expected error: \(c.hostPort)")
      } catch {
        let msg = "\(error)"
        if !msg.contains(c.err) {
          XCTFail("expected \(c.err), got \(msg)")
        }
      }
    }
  }

  func testLookupIP() {
    let cases: [String: [IPAddress]] = [
      "localhost": [IPAddress(127, 0, 0, 1), IPAddress(0, 0, 0, 0, 0, 0, 0, 1)], // loopback addresses
      "broadcasthost": [IPAddress(255, 255, 255, 255)],
    ]

    for c in cases {
      do {
        let got = try Resolver.lookupIP(forHost: c.key)
        let gotSet = Set<IPAddress>(got)
        let wantSet = Set<IPAddress>(c.value)
        if gotSet != wantSet {
          XCTFail("want \(wantSet), got \(gotSet)")
        }
      } catch {
        XCTFail("\(c.key): failed with \(error)")
      }
    }
  }

  func testLookupPort() {
    let cases: [(String, Int)] = [
      ("http", 80),
      ("https", 443),
    ]

    for c in cases {
      do {
        let port = try Resolver.lookupPort(forService: c.0)
        XCTAssertEqual(c.1, port)
      } catch {
        XCTFail("\(error)")
      }
    }
  }

  func testLookupCNAME() {
    // TODO: works only if connected to internet, maybe find something else or
    // skip if no connection.
    do {
      let cname = try Resolver.lookupCNAME(forHost: "www.twitter.com")
      XCTAssertEqual("twitter.com.", cname)
    } catch {
      XCTFail("\(error)")
    }
  }
}
