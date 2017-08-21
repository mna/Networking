import XCTest
@testable import LowSocketsTests
@testable import EpollTests
@testable import OSTests

XCTMain([
    testCase(AddressTests.allTests),
    testCase(AddrInfoTests.allTests),
    testCase(EndiannessTests.allTests),
    testCase(IPAddressTests.allTests),
    testCase(SocketTests.allTests),

    testCase(EpollTests.allTests),

    testCase(SignalSetTests.allTests),
    testCase(TimerTests.allTests),
])
