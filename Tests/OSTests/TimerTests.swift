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
    defer { try? t.close() }

    let old = try t.set(initial: 0.001)
    XCTAssertEqual(old.initial, TimeInterval(0))
    XCTAssertEqual(old.interval, TimeInterval(0))

    usleep(10_000)
    do {
      let n = try t.expirations()
      XCTAssertEqual(n, 1)
    } catch {
      XCTFail("timer.expirations failed with \(error)")
    }
  }

  func testInterval() throws {
    let t = try Timer(flags: [.nonBlock])
    defer { try? t.close() }

    try t.set(initial: 0.1, thenEach: 0.1)

    usleep(300_000)
    do {
      let n = try t.expirations()
      XCTAssertGreaterThanOrEqual(n, 2)
      XCTAssertLessThan(n, 4)
    } catch {
      XCTFail("timer.expirations failed with \(error)")
    }
  }

  func testUnset() throws {
    let t = try Timer(flags: [.nonBlock])
    defer { try? t.close() }

    try t.set(initial: 0.001, thenEach: 0.01)

    usleep(10_000)
    do {
      let n = try t.expirations()
      XCTAssertGreaterThanOrEqual(n, 1)
      XCTAssertLessThan(n, 3)

      let old = try t.unset()
      XCTAssertEqualWithAccuracy(old.initial, TimeInterval(0.001), accuracy: 0.001)
      XCTAssertEqualWithAccuracy(old.interval, TimeInterval(0.01), accuracy: 0.001)
    } catch {
      XCTFail("timer.expirations failed with \(error)")
    }

    usleep(10_000)
    do {
      _ = try t.expirations()
      XCTFail("want EGAIN, got no error")
    } catch let ce as CError {
      // expects EAGAIN, no expiration
      if ce.code != EAGAIN {
        XCTFail("timer.expirations failed with \(ce.code): \(ce.message)")
      }
    } catch {
      XCTFail("timer.expirations failed with \(error)")
    }
  }

  func testGet() throws {
    let t = try Timer()
    defer { try? t.close() }

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
