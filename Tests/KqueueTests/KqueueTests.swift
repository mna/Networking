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

  func testKqueueFileWrite() throws {
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

  func testKqueueFileRead() throws {
    let file = "/tmp/filetest2.txt"
    let fd = open(file, O_RDWR|O_CREAT, 0o666)
    try CError.makeAndThrow(fromReturnCode: fd)
    defer {
      close(fd)
      unlink(file)
    }

    let expect = expectation(description: "kqueue notifies file read")
    DispatchQueue.global(qos: .background).async {
      do {
        // watch for read availability on fd
        var events = Array(repeating: Kevent(), count: 1)
        let ev = Kevent(fd: fd)
        let kq = try Kqueue()

        let ret = try kq.query(with: [ev], into: &events, timeout: 2)
        XCTAssertEqual(1, ret)
        let ev0 = events[0]
        XCTAssertEqual(ev0.identifier, Int(fd))
        XCTAssertEqual(ev0.data, 3)

        expect.fulfill()
      } catch {
        XCTFail("kqueue failed with \(error)")
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
      let b: [UInt8] = [1, 2, 3]
      do {
        try CError.makeAndThrow(fromReturnCode: Int32(write(fd, b, b.count)))
        try CError.makeAndThrow(fromReturnCode: fsync(fd))
      } catch {
        XCTFail("write or fsync failed: \(error)")
      }
    }

    waitForExpectations(timeout: 10)
  }

  // TODO: testKqueueTimer
  // TODO: testKqueueUser
  // TODO: testKqueueSocket
}
