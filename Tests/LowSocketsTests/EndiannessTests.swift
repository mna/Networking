import XCTest
@testable import LowSockets

class EndiannessTests: XCTestCase {
  func testNtoh() {
    let big = Int16(0x1234)
    let little = Int16(0x3412)

    let got = Endianness.ntoh(big)
    switch Endianness.host {
    case .big:
      XCTAssertEqual(got, big)
    case .little:
      XCTAssertEqual(got, little)
    }
  }
}

#if os(Linux)
  extension EndiannessTests {
    static var allTests : [(String, (EndiannessTests) -> () throws -> Void)] {
      return [
        ("testNtoh", testNtoh),
      ]
    }
  }
#endif 
