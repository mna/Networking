import XCTest
@testable import Sockets

class SocketsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(Sockets().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
