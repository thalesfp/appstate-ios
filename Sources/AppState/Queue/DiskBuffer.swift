import Foundation

public final class DiskBuffer {
    private let fileURL: URL
    private let maxBytes: Int
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL, filename: String = "events.jsonl", maxBytes: Int, fileManager: FileManager = .default) throws {
        self.fileURL = directory.appendingPathComponent(filename)
        self.maxBytes = maxBytes
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    public func append(_ event: Event) throws {
        var line = try encoder.encode(event)
        line.append(0x0A)

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }

        try handle.seekToEnd()
        try handle.write(contentsOf: line)

        try enforceCap()
    }

    public func readAll() throws -> [Event] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)

        guard !data.isEmpty else {
            return []
        }

        var events: [Event] = []
        var start = data.startIndex

        while start < data.endIndex {
            let end = data[start...].firstIndex(of: 0x0A) ?? data.endIndex
            let slice = data[start..<end]

            if !slice.isEmpty {
                let event = try decoder.decode(Event.self, from: slice)
                events.append(event)
            }

            start = end == data.endIndex ? end : data.index(after: end)
        }

        return events
    }

    public func clear() throws {
        try Data().write(to: fileURL)
    }

    public func remove(_ count: Int) throws {
        guard count > 0 else { return }

        let events = try readAll()

        guard count < events.count else {
            try clear()
            return
        }

        let remaining = Array(events.dropFirst(count))
        try rewrite(remaining)
    }

    private func enforceCap() throws {
        let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)

        guard let size = attrs[.size] as? Int, size > maxBytes else {
            return
        }

        let events = try readAll()
        var dropped = 0
        var remainingSize = size

        while remainingSize > maxBytes && dropped < events.count {
            let line = try encoder.encode(events[dropped])
            remainingSize -= line.count + 1
            dropped += 1
        }

        let kept = Array(events.dropFirst(dropped))
        try rewrite(kept)
    }

    private func rewrite(_ events: [Event]) throws {
        var data = Data()

        for event in events {
            data.append(try encoder.encode(event))
            data.append(0x0A)
        }

        try data.write(to: fileURL)
    }
}
