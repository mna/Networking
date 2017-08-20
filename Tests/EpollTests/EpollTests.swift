import XCTest
import OS
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
    XCTFail("not implemented")
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
