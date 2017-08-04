import XCTest
@testable import LowSockets

class ResolverTests: XCTestCase {
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
}
