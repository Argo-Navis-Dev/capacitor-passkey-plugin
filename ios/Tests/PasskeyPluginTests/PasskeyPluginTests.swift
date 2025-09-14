import XCTest
@testable import PasskeyPlugin

class PasskeyPluginTests: XCTestCase {
    func testEcho() {
        //TODO implement actual tests
        let implementation = PasskeyPlugin()
        let value = "Hello, World!"
        let result = implementation.echo(value)
        XCTAssertEqual(value, result)
    }
}
