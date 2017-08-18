import XCTest
import Networking
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

  func testKqueueWithFile() throws {
    let file = "/tmp/filetest.txt"
    let fd = open(file, O_CREAT, 0o666)
    try CError.makeAndThrow(fromReturnCode: fd)
    defer {
      close(fd)
      unlink(file)
    }

    // watch for write availability on fd
    var events = Array<Kevent>(repeating: Kevent(), count: 1)
    let ev = Kevent(fd: fd, filter: .write)
    let kq = try Kqueue()

    // should be immediately available
    let ret = try kq.query(with: [ev], into: &events)
    XCTAssertEqual(1, ret)

    let ev0 = events[0]
    XCTAssertEqual(ev0.identifier, Int(fd))
  }
}
