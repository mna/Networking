import XCTest
import OS
import LowSockets
import Dispatch
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
      let ret = try ep.poll(into: &events, timeout: 0)
      XCTAssertEqual(0, ret)
    } catch {
      XCTFail("want no error, got \(error)")
    }
  }

  func testEpollTimeout() throws {
    let ep = try Epoll()
    var events = Array<Event>(repeating: Event(), count: 2)
    let tfd = try Timer()
    try tfd.set(initial: 2.0)

    let timeout: TimeInterval = 0.1
    let start = Date()
    let ret = try ep.poll(into: &events, timeout: timeout)

    let dur = Date().timeIntervalSince(start)
    XCTAssertEqual(0, ret)
    XCTAssertGreaterThanOrEqual(dur, timeout)
  }

  func testEpollTimerFD() throws {
    let ep = try Epoll()
    var events = Array<Event>(repeating: Event(), count: 2)
    let tfd = try Timer()

    let start = Date()
    try tfd.set(initial: 0.01)

    try ep.add(fd: tfd, event: Event([.in], data: .u32(42)))
    let n = try ep.poll(into: &events, timeout: 1.0)
    let dur = Date().timeIntervalSince(start)
    let ev0 = events[0]

    XCTAssertEqual(n, 1)
    XCTAssertEqual(ev0.types, Event.Types.in)
    XCTAssertEqual(Data(asU32: ev0.data), Data.u32(42))
    XCTAssertEqualWithAccuracy(dur, TimeInterval(0.01), accuracy: 0.01)
  }

  func testEpollSocket() throws {
    let path = "/tmp/test.sock"
    let addr = Address.unix(path: path)
    let sock = try Socket(family: .unix)
    try sock.bind(to: addr)
    try sock.listen()
    defer {
      try? sock.close()
      unlink(path)
    }

    // add the listening socket to epoll
    let ep = try Epoll()
    try ep.add(fd: sock, event: Event([.in], data: .fd(sock.fileDescriptor)))

    // wait for a connection
    let expect = expectation(description: "epoll notifies accepted connection")
    DispatchQueue.global(qos: .background).async {
      do {
        var events = Array<Event>(repeating: Event(), count: 2)
        let ret = try ep.poll(into: &events)
        XCTAssertEqual(1, ret)
        let ev0 = events[0]
        if case let .fd(fd)? = Data(asFD: ev0.data) {
          XCTAssertEqual(fd, sock.fileDescriptor)
        } else {
          XCTFail("data could not be read as fd")
        }

        let _ = try sock.accept()

        expect.fulfill()
      } catch {
        XCTFail("epoll failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .unix)
      try sock.connect(to: addr)
    } catch {
      XCTFail("client socket failed with \(error)")
    }

    waitForExpectations(timeout: 10)
  }

  func testEpollSignal() throws {
    let ep = try Epoll()
    var sigs = try SignalSet(insert: [.int])

    // TODO: should this be required? Why doesn't epoll_pwait do its job?
    try sigs.block()

    let fd = try sigs.fileDescriptor()
    try ep.add(fd: fd, event: Event([.in]))

    // send the signal
    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .milliseconds(100)) {
      let pid = getpid()
      kill(pid, Signal.int.value)
    }

    var events = Array<Event>(repeating: Event(), count: 2)
    let n = try ep.poll(into: &events, timeout: 1.0, blockedSignals: sigs)
    XCTAssertEqual(n, 1)

    let ev0 = events[0]
    XCTAssertEqual(ev0.types, Event.Types.in)
    let sig = try fd.next()
    XCTAssertEqual(sig, Signal.int)
  }
}

extension EpollTests {
  static var allTests : [(String, (EpollTests) -> () throws -> Void)] {
    return [
      ("testEpollClose", testEpollClose),
      ("testEpollEmpty", testEpollEmpty),
      ("testEpollTimeout", testEpollTimeout),
      ("testEpollTimerFD", testEpollTimerFD),
      ("testEpollSignal", testEpollSignal),
      ("testEpollSocket", testEpollSocket),
    ]
  }
}
