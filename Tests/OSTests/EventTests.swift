#if os(Linux)

import XCTest
@testable import OS

class EventTests: XCTestCase {
  func testClose() throws {
    let e = try Event()
    try e.close()
  }

  func testInitialRead() throws {
    let e = try Event(initialValue: 10)
    let got = try e.read()
    XCTAssertEqual(got, UInt64(10))
  }

  func testWrite() throws {
    let e = try Event(initialValue: 10, flags: [.nonBlock])
    try e.write(5)
    let got = try e.read()
    XCTAssertEqual(got, UInt64(15))

    // should now be 0, would block
    do {
      _ = try e.read()
      XCTFail("want error, got none")
    } catch let ce as CError {
      if ce.code != EAGAIN {
        XCTFail("want EAGAIN, got \(ce.code): \(ce.message)")
      }
    }
  }

  func testSemaphore() throws {
    let e = try Event(initialValue: 2, flags: [.semaphore, .nonBlock])

    let v1 = try e.read()
    XCTAssertEqual(v1, UInt64(1))
    let v2 = try e.read()
    XCTAssertEqual(v2, UInt64(1))

    // now would block
    do {
      _ = try e.read()
    } catch let ce as CError {
      if ce.code != EAGAIN {
        XCTFail("want EAGAIN, got \(ce.code): \(ce.message)")
      }
    }
  }
}

extension EventTests {
  static var allTests : [(String, (EventTests) -> () throws -> Void)] {
    return [
      ("testClose", testClose),
      ("testInitialRead", testInitialRead),
      ("testWrite", testWrite),
      ("testSemaphore", testSemaphore),
    ]
  }
}

#endif
