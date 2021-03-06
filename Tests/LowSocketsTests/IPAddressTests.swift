import XCTest
@testable import LowSockets

class IPAddressTests: XCTestCase {
  let validAddresses: [(p: String, b: [UInt8], af: Family)] = [
    (p: "0.0.0.0", b: [0, 0, 0, 0], af: .inet),
    (p: "255.0.0.0", b: [255, 0, 0, 0], af: .inet),
    (p: "0.255.0.0", b: [0, 255, 0, 0], af: .inet),
    (p: "0.0.255.0", b: [0, 0, 255, 0], af: .inet),
    (p: "0.0.0.255", b: [0, 0, 0, 255], af: .inet),
    (p: "255.255.255.255", b: [255, 255, 255, 255], af: .inet),
    (p: "127.0.0.1", b: [127, 0, 0, 1], af: .inet),
    (p: "205.49.120.187", b: [205, 49, 120, 187], af: .inet),
    (p: "244.18.80.214", b: [244, 18, 80, 214], af: .inet),
    (p: "7.221.166.201", b: [7, 221, 166, 201], af: .inet),
    (p: "36.192.70.144", b: [36, 192, 70, 144], af: .inet),
    (p: "181.133.151.88", b: [181, 133, 151, 88], af: .inet),

    (p: "::0", b: [UInt8](repeating: 0, count: 16), af: .inet6),
    (p: "::1", b: [UInt8](repeating: 0, count: 15) + [1], af: .inet6),
    (p: "2001:0db8:0000:0042:0000:8a2e:0370:7334", b: [32, 1, 13, 184, 0, 0, 0, 66, 0, 0, 138, 46, 3, 112, 115, 52], af: .inet6),
    (p: "2001:db8::ff00:42:8329", b: [32, 1, 13, 184, 0, 0, 0, 0, 0, 0, 255, 0, 0, 66, 131, 41], af: .inet6),

    (p: "::ffff:192.0.2.128", b: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 192, 0, 2, 128], af: .inet6),
  ]

  let invalidAddresses: [String] = [
    "",
    ":",
    ".",
    "%",
    "[::00]",
    "127.0.0.1.",
    "127.0.0",
    "0::0::0",
  ]

  func testInitParsing() {
    for c in validAddresses {
      guard let got = IPAddress(parsing: c.p) else {
        XCTFail("\(c.p): parsing failed")
        continue
      }
      XCTAssertEqual(c.b, got.bytes)
    }

    for c in invalidAddresses {
      let got = IPAddress(parsing: c)
      if let got = got {
        XCTFail("\(c): did not fail: \(got)")
      }
    }
  }

  func testInitBytes() {
    let casesIP4: [[UInt8]] = [
      [0, 0, 0, 0],
      [127, 0, 0, 1],
      [192, 128, 14, 10],
    ]

    for c in casesIP4 {
      let ip = IPAddress(c[0], c[1], c[2], c[3])
      XCTAssertEqual(c, ip.bytes)
      XCTAssertEqual(Family.inet, ip.family)
    }

    let casesIP6: [([UInt16], [UInt8])] = [
      ([0, 0, 0, 0, 0, 0, 0, 1], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
      ([0xFFFF, 0, 0, 0, 0, 0, 0, 0], [0xff, 0xff, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      ([0x2001, 0x0db8, 0, 0x0042, 0, 0x8a2e, 0x0370, 0x7334], [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0x42, 0, 0, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34]),
    ]

    for c in casesIP6 {
      let ip = IPAddress(c.0[0], c.0[1], c.0[2], c.0[3], c.0[4], c.0[5], c.0[6], c.0[7])
      _ = ip
      XCTAssertEqual(c.1, ip.bytes)
      XCTAssertEqual(Family.inet6, ip.family)
    }

    let casesSeq = casesIP4 + casesIP6.map({ $0.1 })
    for c in casesSeq {
      guard let ip = IPAddress(bytes: c) else {
        XCTFail("\(c): failed to create address")
        continue
      }
      XCTAssertEqual(c, ip.bytes)
    }

    let invalidSeq: [[UInt8]] = [[], [0], [1, 2], [1, 2, 3, 4, 5]]
    for c in invalidSeq {
      if IPAddress(bytes: c) != nil {
        XCTFail("\(c): returned valid address")
      }
    }
  }
}

#if os(Linux)
  extension IPAddressTests {
    static var allTests : [(String, (IPAddressTests) -> () throws -> Void)] {
      return [
        ("testInitParsing", testInitParsing),
        ("testInitBytes", testInitBytes),
      ]
    }
  }
#endif 
