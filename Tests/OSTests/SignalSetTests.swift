import XCTest
import Libc
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

  func testInsertRemoveSet() throws {
    let signals = (1..<100).flatMap({ Signal.make(Int32($0)) })
    XCTAssertTrue(signals.contains(.int))
    XCTAssertTrue(signals.contains(.term))

    var set = try SignalSet(insert: [.term, .int])
    try signals.forEach {
      let ret = try set.contains(signal: $0)
      switch $0 {
      case .term, .int:
        XCTAssertTrue(ret, "signal \($0)")
      default:
        XCTAssertFalse(ret, "signal \($0)")
      }
    }

    try set.remove(signal: .term)
    try signals.forEach {
      let ret = try set.contains(signal: $0)
      switch $0 {
      case .int:
        XCTAssertTrue(ret, "signal \($0)")
      default:
        XCTAssertFalse(ret, "signal \($0)")
      }
    }

    try set.insert(signal: .term)
    try signals.forEach {
      let ret = try set.contains(signal: $0)
      switch $0 {
      case .term, .int:
        XCTAssertTrue(ret, "signal \($0)")
      default:
        XCTAssertFalse(ret, "signal \($0)")
      }
    }
  }
}


#if os(Linux)

extension SignalSetTests {
  func testFileDescriptor() throws {
    var set = try SignalSet(insert: [.usr1])
    let sfd = try set.fileDescriptor(flags: [.nonBlock])

    // block the signal and send it so it is sent on the fd
    var mask = set.toCStruct()
    var ret = sigprocmask(SIG_BLOCK, &mask, nil)
    defer {
      sigprocmask(SIG_UNBLOCK, &mask, nil)
    }

    try CError.makeAndThrow(fromReturnCode: ret)

    let pid = getpid()
    ret = kill(pid, Signal.usr1.value)
    try CError.makeAndThrow(fromReturnCode: ret)

    let sig = try sfd.next()
    XCTAssertEqual(Signal.usr1, sig)

    // reading again should return EAGAIN
    do {
      _ = try sfd.next()
      XCTFail("want error, got none")
    } catch let ce as CError {
      XCTAssertEqual(ce.code, EAGAIN)
    }

    try sfd.close()
  }
}

extension SignalSetTests {
  static var allTests : [(String, (SignalSetTests) -> () throws -> Void)] {
    return [
      ("testEmptySet", testEmptySet),
      ("testFillSet", testFillSet),
      ("testInsertRemoveSet", testInsertRemoveSet),
      ("testFileDescriptor", testFileDescriptor),
    ]
  }
}

#endif
