import XCTest
@testable import OS

class UserDataTests: XCTestCase {
  func testCastFD() throws {
    let cases: [(a: UserData, b: UserData?)] = [
      (.u64(0), .fd(0)),
      (.u64(1), .fd(1)),
      (.u64(10), .fd(10)),
      (.u64(1234567890), .fd(1234567890)),
      (.u64(12345678901), nil),
    ]

    for c in cases {
      let got = UserData(asFD: c.a)
      if let b = c.b {
        XCTAssertEqual(got, b)
      } else {
        XCTAssertNil(got)
      }
    }
  }

  func testCastU32() throws {
    let cases: [(a: UserData, b: UserData?)] = [
      (.u64(0), .u32(0)),
      (.u64(1), .u32(1)),
      (.u64(10), .u32(10)),
      (.u64(1234567890), .u32(1234567890)),
      (.u64(12345678901), nil),
    ]

    for c in cases {
      let got = UserData(asU32: c.a)
      if let b = c.b {
        XCTAssertEqual(got, b)
      } else {
        XCTAssertNil(got)
      }
    }
  }

  func testCastPtr() throws {
    let cases: [(a: UserData, b: UserData?)] = [
      (.u64(0), nil),
      (.u64(1), .ptr(UnsafeMutableRawPointer(bitPattern: UInt(1))!)),
    ]

    for c in cases {
      let got = UserData(asPtr: c.a)
      if let b = c.b {
        XCTAssertEqual(got, b)
      } else {
        XCTAssertNil(got)
      }
    }
  }

  func testPtrAndBack() throws {
    var i: Int = 1
    let d = UserData.ptr(&i)
    guard case let .ptr(p) = d else {
      XCTFail("not a pointer")
      return
    }

    let u = UInt(bitPattern: p)
    XCTAssertGreaterThan(u, 0)

    let u64 = UserData.u64(UInt64(u))
    guard let ptr = UserData(asPtr: u64) else {
      XCTFail("failed to cast u64 as ptr")
      return
    }

    guard case let .ptr(pp) = ptr else {
      XCTFail("not a pointer 2")
      return
    }

    XCTAssertEqual(pp, p)
    let ii = pp.load(as: Int.self)
    XCTAssertEqual(ii, i)
  }
}

#if os(Linux)

extension UserDataTests {
  static var allTests : [(String, (UserDataTests) -> () throws -> Void)] {
    return [
      ("testCastFD", testCastFD),
      ("testCastU32", testCastU32),
      ("testCastPtr", testCastPtr),
      ("testPtrAndBack", testPtrAndBack),
    ]
  }
}

#endif
