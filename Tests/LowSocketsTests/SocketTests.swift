import XCTest
import Libc
import OS
import Foundation
import Dispatch
@testable import LowSockets

class SocketTests: XCTestCase {
  func testDefaultSocket() throws {
    let sock = try Socket()
    defer { try? sock.close() }

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
    defer { try? sock.close() }

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
    defer { try? sock.close() }

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
    defer { try? sock.close() }

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
    defer { try? sock.close() }

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

  func testConnectToNonMatchingAddress() throws {
    let sock = try Socket(family: .inet)
    defer { try? sock.close() }

    let addr = Address(path: "/tmp/test.sock")!
    do {
      try sock.connect(to: addr)
      XCTFail("want error, got none")
    } catch let ce as CError {
      if ce.code != EAFNOSUPPORT {
        XCTFail("want EAFNOSUPPORT, got \(ce.code): \(ce.message)")
      }
    }
  }

  func testSendToReceiveFrom() throws {
    let addr1 = Address(path: "/tmp/test1.sock")!
    let addr2 = Address(path: "/tmp/test2.sock")!
    defer {
      unlink("/tmp/test1.sock")
      unlink("/tmp/test2.sock")
    }

    var data1 = [UInt8](repeating: 0, count: 10)
    var data2 = [UInt8](repeating: 0, count: 10)
    var addrRecv: Address = addr2
    do {
      let sock1 = try Socket(family: .unix, type: .datagram)
      let sock2 = try Socket(family: .unix, type: .datagram)
      defer {
        try? sock1.close()
        try? sock2.close()
      }

      try sock1.bind(to: addr1)
      try sock2.bind(to: addr2)

      data1 = [1, 2, 3, 4]
      var n1 = try sock1.send(data1[0..<4], to: addr2)
      var n2 = try sock2.receive(&data2, from: &addrRecv)

      XCTAssertEqual(n1, 4)
      XCTAssertEqual(n1, n2)
      XCTAssertEqual(addrRecv, addr1)
      XCTAssertEqual(data1[0..<4], [1, 2, 3, 4])
      XCTAssertEqual(data1[0..<4], data2[0..<4])

      data2 = [5, 6, 7]
      n2 = try sock2.send(data2[0..<3], to: addr1)
      n1 = try sock1.receive(&data1, from: &addrRecv)

      XCTAssertEqual(n2, 3)
      XCTAssertEqual(n1, n2)
      XCTAssertEqual(addrRecv, addr2)
      XCTAssertEqual(data1[0..<3], [5, 6, 7])
      XCTAssertEqual(data1[0..<3], data2[0..<3])
    } catch {
      XCTFail("\(error)")
    }
  }

  func xtestShutdown() throws {
    // TODO: panics, does not exit cleanly
    let server = try Socket(family: .inet)
    defer { try? server.close() }

    try server.bind(toHost: "localhost", port: 8896)
    try server.listen()

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        let remote = try server.accept()
        defer { try? remote.close() }

        var buf = [UInt8](repeating: 0, count: 10)
        let n = try remote.receive(&buf)

        expect.fulfill()
      } catch {
        XCTFail("server.accept failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .inet)
      defer { try? sock.close() }

      try sock.connect(to: "localhost:8896")
      try sock.shutdown()

      let bytes: [UInt8] = [1, 2, 3, 4]
      let _ = try sock.send(bytes)
    } catch {
      XCTFail("send on shutdown write failed: \(error)")
    }

    waitForExpectations(timeout: 10)
  }

  func testSendReceive() throws {
    let server = try Socket(family: .inet)
    defer { try? server.close() }
    do {
      try server.bind(toHost: "localhost", port: 8897)
      try server.listen()
    } catch {
      XCTFail("server failed: \(error)")
      return
    }

    let data = "hello, world"

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        let remote = try server.accept()
        defer { try? remote.close() }

        var buf = [UInt8](repeating: 0, count: 12)
        let n = try remote.receive(&buf)

        XCTAssertEqual(data.utf8.count, n)
        XCTAssertEqual(data, String(bytes: buf, encoding: .utf8))

        expect.fulfill()
      } catch {
        XCTFail("server.accept failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .inet)
      defer { try? sock.close() }

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
    let server = try Socket(family: .inet)
    defer { try? server.close() }

    do {
      try server.bind(toHost: "localhost", port: 0)
      try server.listen()
    } catch {
      XCTFail("server.listen failed: \(error)")
      return
    }

    let bound = try server.boundAddress()
    switch bound {
    case .ip4(let ip, let port):
      XCTAssertEqual(ip, IPAddress(127, 0, 0, 1))
      XCTAssertGreaterThan(port, 30000)
    default:
      XCTFail("unexpected bound address type")
    }
  }

  func testConnectTCP4() throws {
    let server = try Socket(family: .inet)
    defer { try? server.close() }

    try server.bind(toHost: "localhost", port: 8899)
    try server.listen()

    let bound = try server.boundAddress()
    XCTAssertEqual(bound, Address.ip4(ip: IPAddress(127, 0, 0, 1), port: 8899))

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        let remote = try server.accept()
        defer { try? remote.close() }

        let addr = try remote.peerAddress()
        switch addr {
        case .ip4(_, let port):
          XCTAssertGreaterThan(port, 30000)
        default:
          XCTFail("unexpected address type \(addr)")
        }

        expect.fulfill()
      } catch {
        XCTFail("server.accept failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .inet)
      defer { try? sock.close() }

      try sock.connect(to: "localhost:8899")
    } catch {
      XCTFail("client socket failed with \(error)")
    }

    waitForExpectations(timeout: 10)
  }

  func testConnectTCP6() throws {
    let server = try Socket(family: .inet6)
    defer { try? server.close() }

    try server.bind(toHost: "localhost", port: 8898)
    try server.listen()

    #if os(Linux)
      let wantAddr = IPAddress(bytes: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 127, 0, 0, 1])!
    #else
      let wantAddr = IPAddress.ip6Loopback
    #endif

    let bound = try server.boundAddress()
    XCTAssertEqual(bound, Address.ip6(ip: wantAddr, port: 8898, scopeID: 0))

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        let remote = try server.accept()
        defer { try? remote.close() }

        let addr = try remote.peerAddress()
        switch addr {
        case .ip6(_, let port, _):
          XCTAssertGreaterThan(port, 30000)
        default:
          XCTFail("unexpected address type \(addr)")
        }

        expect.fulfill()
      } catch {
        XCTFail("server.accept failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .inet6)
      defer { try? sock.close() }

      try sock.connect(to: "localhost:8898")
    } catch {
      XCTFail("client socket failed with \(error)")
    }

    waitForExpectations(timeout: 10)
  }

  func testConnectUnix() throws {
    let path = "/tmp/test.sock"
    defer { unlink(path) }

    let server = try Socket(family: .unix)
    defer { try? server.close() }

    try server.bind(toPath: path)
    try server.listen()

    let bound = try server.boundAddress()
    XCTAssertEqual(bound, Address.unix(path: path))

    // run server in background and close it after a connection
    let expect = expectation(description: "server stops after a connection")
    DispatchQueue.global(qos: .background).async {
      do {
        let remote = try server.accept()
        defer { try? remote.close() }
        expect.fulfill()
      } catch {
        XCTFail("server.accept failed with \(error)")
      }
    }

    do {
      let sock = try Socket(family: .unix)
      defer { try? sock.close() }

      try sock.connect(toPath: path)
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
        ("testConnectToNonMatchingAddress", testConnectToNonMatchingAddress),
        ("testSendToReceiveFrom", testSendToReceiveFrom),
        ("testSendReceive", testSendReceive),
        ("testListenTCPUnspecifiedPort", testListenTCPUnspecifiedPort),
        ("testConnectTCP4", testConnectTCP4),
        ("testConnectTCP6", testConnectTCP6),
        ("testConnectUnix", testConnectUnix),
        //("testShutdown", testShutdown),
      ]
    }
  }
#endif
