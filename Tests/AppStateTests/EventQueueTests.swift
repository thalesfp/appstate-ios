import XCTest
@testable import AppState

final class EventQueueTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_givenEmptyQueue_whenFlushing_thenReportsIdle() async throws {
        let queue = try makeQueue(transport: FakeTransport())

        let outcome = await queue.flush()

        XCTAssertEqual(outcome, .idle)
    }

    func test_givenEnqueuedEvents_whenFlushing_thenTransportReceivesAll() async throws {
        let transport = FakeTransport()
        let queue = try makeQueue(transport: transport)

        await queue.enqueue(Event(name: "a"))
        await queue.enqueue(Event(name: "b"))
        await queue.enqueue(Event(name: "c"))

        let outcome = await queue.flush()

        XCTAssertEqual(outcome, .sent(3))
        let sent = await transport.sent
        XCTAssertEqual(sent.map(\.name), ["a", "b", "c"])
    }

    func test_givenSuccessfulFlush_whenFlushingAgain_thenBufferIsEmpty() async throws {
        let transport = FakeTransport()
        let queue = try makeQueue(transport: transport)

        await queue.enqueue(Event(name: "a"))
        _ = await queue.flush()
        let second = await queue.flush()

        XCTAssertEqual(second, .idle)
    }

    func test_givenTransportReturnsRetryable_whenFlushing_thenReportsPartialAndKeepsEvents() async throws {
        let transport = FakeTransport(behavior: .alwaysRetryable(reason: "network"))
        let queue = try makeQueue(transport: transport)

        await queue.enqueue(Event(name: "a"))
        await queue.enqueue(Event(name: "b"))

        let outcome = await queue.flush()

        XCTAssertEqual(outcome, .partial(sent: 0, pending: 2))
    }

    func test_givenTransportReturnsRejected_whenFlushing_thenDropsEvents() async throws {
        let transport = FakeTransport(behavior: .alwaysReject(status: 400, body: "bad"))
        let queue = try makeQueue(transport: transport)

        await queue.enqueue(Event(name: "a"))

        let outcome = await queue.flush()

        XCTAssertEqual(outcome, .sent(1))
    }

    func test_givenRetryableThenAccept_whenFlushingTwice_thenAllEventuallySent() async throws {
        let transport = FakeTransport(behavior: .alwaysRetryable(reason: "net"))
        let queue = try makeQueue(transport: transport)

        await queue.enqueue(Event(name: "a"))
        await queue.enqueue(Event(name: "b"))

        _ = await queue.flush()
        await transport.setBehavior(.alwaysAccept)

        let second = await queue.flush()

        XCTAssertEqual(second, .sent(2))
        let sent = await transport.sent
        XCTAssertEqual(sent.filter { $0.name == "a" || $0.name == "b" }.count, 3, "a sent once on retry attempt, a+b sent on success")
    }

    private func makeQueue(transport: Transport) throws -> EventQueue {
        let buffer = try DiskBuffer(directory: tempDir, maxBytes: 10 * 1024)
        return EventQueue(
            transport: transport,
            buffer: buffer,
            clock: InstantClock(),
            batchSize: 20,
            flushInterval: 5,
            maxRetryDelay: 1
        )
    }
}
