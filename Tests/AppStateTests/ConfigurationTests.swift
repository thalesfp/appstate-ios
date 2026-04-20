import XCTest
@testable import AppState

final class ConfigurationTests: XCTestCase {
    func test_givenEmptyAPIKey_whenInitializing_thenThrowsMissingAPIKey() {
        XCTAssertThrowsError(try Configuration(apiKey: "")) { error in
            XCTAssertEqual(error as? ConfigurationError, .missingAPIKey)
        }
    }

    func test_givenZeroBatchSize_whenInitializing_thenThrowsInvalidBatchSize() {
        XCTAssertThrowsError(try Configuration(apiKey: "k", batchSize: 0)) { error in
            XCTAssertEqual(error as? ConfigurationError, .invalidBatchSize(0))
        }
    }

    func test_givenZeroFlushInterval_whenInitializing_thenThrowsInvalidFlushInterval() {
        XCTAssertThrowsError(try Configuration(apiKey: "k", flushInterval: 0)) { error in
            XCTAssertEqual(error as? ConfigurationError, .invalidFlushInterval(0))
        }
    }

    func test_givenOnlyAPIKey_whenInitializing_thenUsesDefaultBaseURLAndLifecycleOff() throws {
        let config = try Configuration(apiKey: "k")

        XCTAssertEqual(config.baseURL, Configuration.defaultBaseURL)
        XCTAssertFalse(config.observeLifecycle)
        XCTAssertTrue(config.autoContext)
    }

    func test_givenValidInput_whenInitializing_thenStoresValues() throws {
        let config = try Configuration(
            apiKey: "k",
            baseURL: URL(string: "https://x")!,
            batchSize: 10,
            flushInterval: 2,
            autoContext: false,
            observeLifecycle: true
        )

        XCTAssertEqual(config.apiKey, "k")
        XCTAssertEqual(config.batchSize, 10)
        XCTAssertEqual(config.flushInterval, 2)
        XCTAssertFalse(config.autoContext)
        XCTAssertTrue(config.observeLifecycle)
    }
}
