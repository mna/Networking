import XCTest
@testable import LowSockets

class IPAddressTests: XCTestCase {
  func testInitParsing() {
    _ = IPAddress(parsing: "123.45.67.1")
  }
}
