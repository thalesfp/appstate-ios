import XCTest
@testable import AppState

final class AutoContextTests: XCTestCase {
    func test_whenTakingSnapshot_thenIncludesExpectedKeys() {
        let ctx = AutoContext.snapshot()

        XCTAssertNotNil(ctx["sdk"])
        XCTAssertNotNil(ctx["sdk_version"])
        XCTAssertNotNil(ctx["os"])
        XCTAssertNotNil(ctx["os_version"])
        XCTAssertNotNil(ctx["device_model"])
        XCTAssertNotNil(ctx["locale"])
    }

    func test_whenTakingSnapshot_thenSdkNameIsAppstateIOS() {
        let ctx = AutoContext.snapshot()

        XCTAssertEqual(ctx["sdk"], .string("appstate-ios"))
    }
}
