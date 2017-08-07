import XCTest
@testable import LowSockets

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
}
