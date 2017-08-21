import XCTest
@testable import OS

class SignalSetTests: XCTestCase {
  func testEmptySet() throws {
    var set = try SignalSet(fill: false)
    for i in 1..<100 {
      if let sig = Signal.make(Int32(i)) {
        let ret = try set.contains(signal: sig)
        XCTAssertFalse(ret, "signal \(sig)")
      }
    }
  }

  func testFillSet() throws {
    var set = try SignalSet(fill: true)
    for i in 1..<100 {
      if let sig = Signal.make(Int32(i)) {
        let ret = try set.contains(signal: sig)
        XCTAssertTrue(ret, "signal \(sig)")
      }
    }
  }

  func testInsertSet() throws {
    var set = try SignalSet(insert: [.term, .int])
    for i in 1..<100 {
      if let sig = Signal.make(Int32(i)) {
        switch sig {
        case .term, .int:
          let ret = try set.contains(signal: sig)
          XCTAssertTrue(ret, "signal \(sig)")
        default:
          let ret = try set.contains(signal: sig)
          XCTAssertFalse(ret, "signal \(sig)")
        }
      }
    }
  }
}


#if os(Linux)
  extension SignalSetTests {
    static var allTests : [(String, (SignalSetTests) -> () throws -> Void)] {
      return [
        ("testEmptySet", testEmptySet),
        ("testFillSet", testFillSet),
        ("testInsertSet", testInsertSet),
      ]
    }
  }
#endif
