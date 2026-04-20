import XCTest
@testable import AppState

final class DiskBufferTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_givenEmptyBuffer_whenAppendingAndReading_thenReturnsEvent() throws {
        let buffer = try DiskBuffer(directory: tempDir, maxBytes: 1024)
        let event = Event(name: "session.start")

        try buffer.append(event)

        let loaded = try buffer.readAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "session.start")
    }

    func test_givenBufferWithEvents_whenReinstantiated_thenEventsSurvive() throws {
        let first = try DiskBuffer(directory: tempDir, maxBytes: 1024)
        try first.append(Event(name: "a"))
        try first.append(Event(name: "b"))

        let second = try DiskBuffer(directory: tempDir, maxBytes: 1024)
        let loaded = try second.readAll()

        XCTAssertEqual(loaded.map(\.name), ["a", "b"])
    }

    func test_givenBufferOverCap_whenAppending_thenDropsOldestEvents() throws {
        let buffer = try DiskBuffer(directory: tempDir, maxBytes: 200)

        for i in 0..<20 {
            try buffer.append(Event(name: "event-\(i)", message: String(repeating: "x", count: 20)))
        }

        let loaded = try buffer.readAll()

        XCTAssertLessThan(loaded.count, 20, "buffer should have dropped oldest events to stay under cap")
        XCTAssertEqual(loaded.last?.name, "event-19", "newest event must survive")
    }

    func test_givenBufferWithEvents_whenRemovingPrefix_thenKeepsSuffix() throws {
        let buffer = try DiskBuffer(directory: tempDir, maxBytes: 4096)
        try buffer.append(Event(name: "a"))
        try buffer.append(Event(name: "b"))
        try buffer.append(Event(name: "c"))

        try buffer.remove(2)

        XCTAssertEqual(try buffer.readAll().map(\.name), ["c"])
    }

    func test_givenBufferWithEvents_whenRemovingMoreThanSize_thenClears() throws {
        let buffer = try DiskBuffer(directory: tempDir, maxBytes: 4096)
        try buffer.append(Event(name: "a"))
        try buffer.append(Event(name: "b"))

        try buffer.remove(10)

        XCTAssertEqual(try buffer.readAll(), [])
    }

    func test_givenNewBuffer_whenReading_thenReturnsEmpty() throws {
        let buffer = try DiskBuffer(directory: tempDir, maxBytes: 1024)
        XCTAssertEqual(try buffer.readAll(), [])
    }
}
