import XCTest
@testable import LowSocketsTests
@testable import EpollTests
 
XCTMain([
    testCase(AddressTests.allTests),
    testCase(AddrInfoTests.allTests),
    testCase(EndiannessTests.allTests),
    testCase(IPAddressTests.allTests),
    testCase(SocketTests.allTests),
])