import XCTest
@testable import LowSocketsTests
 
XCTMain([
    testCase(AddressTests.allTests),
    testCase(AddrInfoTests.allTests),
    testCase(EndiannessTests.allTests),
    testCase(IPAddressTests.allTests),
    testCase(SocketTests.allTests),
])