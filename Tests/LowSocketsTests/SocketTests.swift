import XCTest
import Libc
import Foundation
import Dispatch
@testable import LowSockets

class SocketTests: XCTestCase {
  func testDefaultSocket() throws {
    let sock = try Socket()
    XCTAssertEqual(sock.family, Family.inet)
    XCTAssertEqual(sock.type, SocketType.stream)
    XCTAssertEqual(sock.proto, SocketProtocol.tcp)
    XCTAssertTrue(sock.fileDescriptor > 0)
    XCTAssertTrue(try sock.isBlocking())
  }

  func testCreateFromFD() throws {
    // create a socket
    let fd = socket(Family.inet6.value, SocketType.datagram.value, SocketProtocol.udp.value)
    try CError.makeAndThrow(fromReturnCode: fd)

    let sock = try Socket(fd: fd)
    #if os(Linux)
      XCTAssertEqual(sock.family, Family.inet6)
    #else
      XCTAssertNil(sock.family)
    #endif
    XCTAssertEqual(sock.proto, SocketProtocol.udp)
    XCTAssertEqual(sock.type, SocketType.datagram)
    XCTAssertEqual(sock.fileDescriptor, fd)
  }

  func testSetNonBlocking() throws {
    let sock = try Socket()

    // non-blocking works
    try sock.setNonBlocking()
    XCTAssertFalse(try sock.isBlocking())

    // idempotent operation
    try sock.setNonBlocking()
    XCTAssertFalse(try sock.isBlocking())

    // blocking reverts
    try sock.setBlocking()
    XCTAssertTrue(try sock.isBlocking())

    // idempotent too
    try sock.setBlocking()
    XCTAssertTrue(try sock.isBlocking())

    // non-blocking still works
    try sock.setNonBlocking()
    XCTAssertFalse(try sock.isBlocking())
  }

  func testSetLinger() throws {
    let sock = try Socket()
    try sock.setLinger(timeout: 0)
    XCTAssertEqual(TimeInterval(0), try sock.getLinger())
    try sock.setLinger(timeout: TimeInterval(1.234))
    XCTAssertEqual(TimeInterval(1), try sock.getLinger())
    try sock.setLinger(timeout: TimeInterval(20))
    XCTAssertEqual(TimeInterval(20), try sock.getLinger())
    try sock.setLinger(timeout: nil)
    XCTAssertNil(try sock.getLinger())
  }

  func testSetTimeouts() throws {
    let sock = try Socket()
    let cases: [TimeInterval] = [
      0,
      1.234,
      10,
      20.000499,
      -1,
    ]

    let within = 0.005
    for c in cases {
      try sock.setReadTimeout(c)
      var want = c
      if c < 0 {
        want = 0
      }
      XCTAssertEqualWithAccuracy(want, try sock.getReadTimeout(), accuracy: within)
    }
    for c in cases {
      try sock.setWriteTimeout(c)
      var want = c
      if c < 0 {
        want = 0
      }
      XCTAssertEqualWithAccuracy(want, try sock.getWriteTimeout(), accuracy: within)
    }
  }

  func testSendReceive() throws {
    let server = PortServer("localhost", 8897)
    do {
      try server.listen()
    } catch {
      XCTFail("server.listen failed: \(error)")
      return
    }

    let data = "hello, world"

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        try server.serve { s in
          var buf = [UInt8](repeating: 0, count: 12)
          let n = try s.receive(&buf)

          XCTAssertEqual(data.utf8.count, n)
          XCTAssertEqual(data, String(bytes: buf, encoding: .utf8))

          expect.fulfill()
          return false
        }
      } catch {
        XCTFail("server.run failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .inet)
      try sock.connect(to: "localhost:8897")

      let bytes: [UInt8] = data.utf8.map({ UInt8($0) })
      let n = try sock.send(bytes)
      XCTAssertEqual(data.utf8.count, n)
    } catch {
      XCTFail("client socket failed with \(error)")
    }

    waitForExpectations(timeout: 10)
  }

  func testListenTCPUnspecifiedPort() throws {
    let server = PortServer("localhost", 0)
    do {
      try server.listen()
    } catch {
      XCTFail("server.listen failed: \(error)")
      return
    }

    XCTAssertEqual(server.sock?.boundAddress, Address.ip4(ip: IPAddress(127, 0, 0, 1), port: 0))
    let bound = try server.sock!.loadBoundAddress()
    switch bound {
    case .ip4(let ip, let port):
      XCTAssertEqual(ip, IPAddress(127, 0, 0, 1))
      XCTAssertTrue(port > 30000)
    default:
      XCTFail("unexpected bound address type")
    }

    XCTAssertNil(server.sock?.peerAddress)
  }

  func testConnectTCP4() throws {
    let server = PortServer("localhost", 8899)
    do {
      try server.listen()
    } catch {
      XCTFail("server.listen failed: \(error)")
      return
    }

    XCTAssertEqual(server.sock?.boundAddress, Address.ip4(ip: IPAddress(127, 0, 0, 1), port: 8899))
    let bound = try server.sock!.loadBoundAddress()
    XCTAssertEqual(bound, Address.ip4(ip: IPAddress(127, 0, 0, 1), port: 8899))

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        try server.serve { s in
          switch s.peerAddress {
          case .ip4(_, let port)?:
            XCTAssertTrue(port > 30000, "port is \(port)")
          default:
            XCTFail("unexpected address type \(String(describing: s.peerAddress))")
          }
          expect.fulfill()
          return false
        }
      } catch {
        XCTFail("server.run failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .inet)
      try sock.connect(to: "localhost:8899")
    } catch {
      XCTFail("client socket failed with \(error)")
    }

    waitForExpectations(timeout: 10)
  }

  func testConnectTCP6() throws {
    let server = PortServer("localhost", 8898, family: .inet6)
    do {
      try server.listen()
    } catch {
      XCTFail("server.listen failed: \(error)")
      return
    }

    XCTAssertEqual(server.sock?.boundAddress, Address.ip6(ip: IPAddress(0, 0, 0, 0, 0, 0, 0, 1), port: 8898, scopeID: 0))
    let bound = try server.sock!.loadBoundAddress()
    XCTAssertEqual(bound, Address.ip6(ip: IPAddress(0, 0, 0, 0, 0, 0, 0, 1), port: 8898, scopeID: 0))

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        try server.serve { s in
          switch s.peerAddress {
          case .ip6(_, let port, _)?:
            XCTAssertTrue(port > 30000, "port is \(port)")
          default:
            XCTFail("unexpected address type \(String(describing: s.peerAddress))")
          }
          expect.fulfill()
          return false
        }
      } catch {
        XCTFail("server.run failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .inet6)
      try sock.connect(to: "localhost:8898")
    } catch {
      XCTFail("client socket failed with \(error)")
    }

    waitForExpectations(timeout: 10)
  }

  func testConnectUnix() throws {
    let server = UnixServer("/tmp/test.sock")
    try server.listen()

    XCTAssertEqual(server.sock?.boundAddress, Address.unix(path: "/tmp/test.sock"))
    let bound = try server.sock!.loadBoundAddress()
    XCTAssertEqual(bound, Address.unix(path: "/tmp/test.sock"))

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        try server.serve { s in
          switch s.peerAddress {
          case .unix?:
            break
          default:
            XCTFail("unexpected address type \(String(describing: s.peerAddress))")
          }
          expect.fulfill()
          return false
        }
      } catch {
        XCTFail("server.run failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .unix)
      try sock.connect(toPath: "/tmp/test.sock")
    } catch {
      XCTFail("client socket failed with \(error)")
    }

    waitForExpectations(timeout: 10)
  }
}

#if os(Linux)
  extension SocketTests {
    static var allTests : [(String, (SocketTests) -> () throws -> Void)] {
      return [
        ("testDefaultSocket", testDefaultSocket),
        ("testCreateFromFD", testCreateFromFD),
        ("testSetNonBlocking", testSetNonBlocking),
        ("testSetLinger", testSetLinger),
        ("testSetTimeouts", testSetTimeouts),
        ("testSendReceive", testSendReceive),
        ("testListenTCPUnspecifiedPort", testListenTCPUnspecifiedPort),
        ("testConnectTCP4", testConnectTCP4),
        ("testConnectTCP6", testConnectTCP6),
        ("testConnectUnix", testConnectUnix),
      ]
    }
  }
#endif
