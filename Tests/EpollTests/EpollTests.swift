import XCTest
import OS
import Foundation
@testable import Epoll

// Epoll does not support adding regular files to watch for
// read-write, unlike kqueue (because those files are always
// ready to read/write). It fails with operation not permitted.
// Other FDs must be used for tests.

class EpollTests: XCTestCase {
  func testEpollClose() throws {
    let ep = try Epoll()
    try ep.close()
  }

  func testEpollEmpty() throws {
    let ep = try Epoll()
    var events = Array<Event>(repeating: Event(), count: 1)
    do {
      let ret = try ep.wait(into: &events, timeout: 0)
      XCTAssertEqual(0, ret)
    } catch {
      XCTFail("want no error, got \(error)")
    }
  }

  func testEpollTimerFD() throws {
    let ep = try Epoll()
    var events = Array<Event>(repeating: Event(), count: 2)
    let tfd = try Timer()

    let start = Date()
    try tfd.set(initial: 0.01)

    try ep.add(fd: tfd, event: Event([.in], data: .u32(42)))
    let n = try ep.wait(into: &events, timeout: 1.0)
    let dur = Date().timeIntervalSince(start)
    let ev0 = events[0]

    XCTAssertEqual(n, 1)
    XCTAssertEqual(ev0.types, Event.Types.in)
    XCTAssertEqual(Data(asU32: ev0.data), Data.u32(42))
    XCTAssertEqualWithAccuracy(dur, TimeInterval(0.01), accuracy: 0.01)
  }
}

extension EpollTests {
  static var allTests : [(String, (EpollTests) -> () throws -> Void)] {
    return [
      ("testEpollClose", testEpollClose),
      ("testEpollEmpty", testEpollEmpty),
      ("testEpollTimerFD", testEpollTimerFD),
    ]
  }
}
