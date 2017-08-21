#if os(Linux)

import XCTest
import Dispatch
import Foundation
@testable import OS

class TimerTests: XCTestCase {
  func testClose() throws {
    let t = try Timer()
    try t.close()
  }

  func testInitial() throws {
    let t = try Timer(flags: [.nonBlock])
    let old = try t.set(initial: 0.001)
    XCTAssertEqual(old.initial, TimeInterval(0))
    XCTAssertEqual(old.interval, TimeInterval(0))

    let expect = expectation(description: "checks after timer")
    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .milliseconds(10)) {
      do {
        let n = try t.expirations()
        XCTAssertEqual(n, 1)
        expect.fulfill()
      } catch {
        XCTFail("timer.expirations failed with \(error)")
      }
    }

    waitForExpectations(timeout: 10)
  }

  func testInterval() throws {
    let t = try Timer(flags: [.nonBlock])
    try t.set(initial: 0.001, thenEach: 0.01)

    let expect = expectation(description: "checks after timer")
    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .milliseconds(100)) {
      do {
        let n = try t.expirations()
        XCTAssertGreaterThanOrEqual(n, 10)
        XCTAssertLessThan(n, 12)
        expect.fulfill()
      } catch {
        XCTFail("timer.expirations failed with \(error)")
      }
    }

    waitForExpectations(timeout: 10)
  }

  func testUnset() throws {
    let t = try Timer(flags: [.nonBlock])
    try t.set(initial: 0.001, thenEach: 0.01)

    let exp1 = expectation(description: "unsets after timer")
    let exp2 = expectation(description: "checks after unset")

    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .milliseconds(10)) {
      do {
        let n = try t.expirations()
        XCTAssertGreaterThanOrEqual(n, 1)
        XCTAssertLessThan(n, 3)

        let old = try t.unset()
        XCTAssertEqualWithAccuracy(old.initial, TimeInterval(0.001), accuracy: 0.001)
        XCTAssertEqualWithAccuracy(old.interval, TimeInterval(0.01), accuracy: 0.001)

        exp1.fulfill()
      } catch {
        XCTFail("timer.expirations failed with \(error)")
      }
    }

    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .milliseconds(10)) {
      do {
        _ = try t.expirations()
        XCTFail("want EGAIN, got no error")
      } catch let ce as CError {
        // expects EAGAIN, no expiration
        if ce.code != EAGAIN {
          XCTFail("timer.expirations failed with \(ce.code): \(ce.message)")
        }
        exp2.fulfill()
      } catch {
        XCTFail("timer.expirations failed with \(error)")
      }
    }

    waitForExpectations(timeout: 10)
  }

  func testGet() throws {
    let t = try Timer()
    try t.set(initial: 0.001, thenEach: 0.01)
    let old = try t.get()
    XCTAssertEqualWithAccuracy(old.initial, TimeInterval(0.001), accuracy: 0.001)
    XCTAssertEqualWithAccuracy(old.interval, TimeInterval(0.01), accuracy: 0.001)
  }
}

extension TimerTests {
  static var allTests : [(String, (TimerTests) -> () throws -> Void)] {
    return [
      ("testClose", testClose),
      ("testInitial", testInitial),
      ("testInterval", testInterval),
      ("testUnset", testUnset),
      ("testGet", testGet),
    ]
  }
}

#endif
