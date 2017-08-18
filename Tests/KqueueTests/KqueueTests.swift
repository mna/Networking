import XCTest
@testable import Kqueue

class AddressTests: XCTestCase {
  func testKqueueClose() throws {
    let kq = try Kqueue()
    try kq.close()
  }

  func testKqueueEmpty() throws {
    let kq = try Kqueue()
    var events = Array<Kevent>()
    do {
      let ret = try kq.query(with: [], into: &events)
      XCTAssertEqual(0, ret)
    } catch {
      XCTFail("want no error, got \(error)")
    }
  }
}
