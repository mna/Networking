import XCTest
@testable import LowSocketsTests
@testable import EpollTests
@testable import OSTests

XCTMain([
    // LowSockets
    testCase(AddressTests.allTests),
    testCase(EndiannessTests.allTests),
    testCase(IPAddressTests.allTests),
    testCase(SocketTests.allTests),

    // Epoll
    testCase(EpollTests.allTests),

    // OS
    testCase(SignalSetTests.allTests),
    testCase(TimerTests.allTests),
    testCase(EventTests.allTests),
])
