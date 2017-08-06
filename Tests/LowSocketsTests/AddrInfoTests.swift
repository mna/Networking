import XCTest
@testable import LowSockets

class AddrInfoTests: XCTestCase {
  func testLocalhost() {
    do {
      let (cname, addrs) = try AddrInfo.get(service: "http", flags: .canonName)
      print(cname, addrs)
    } catch {
      XCTFail("\(error)")
    }
  }
}
