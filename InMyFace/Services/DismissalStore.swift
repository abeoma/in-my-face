import Foundation

/// タイトルやURLを含まない、回キーと保存期限だけの台帳。
final class DismissalStore {
    struct Entry: Codable {
        let key: OccurrenceKey
        var end: Date
    }

    private let url: URL?
    private(set) var entries: [OccurrenceKey: Date] = [:]

    init(url: URL?) { self.url = url }

    var dismissedIDs: Set<OccurrenceKey> { Set(entries.keys) }

    func load(now: Date) throws {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url)
        let loaded: [Entry]
        do {
            loaded = try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            let backup = url.deletingLastPathComponent().appendingPathComponent(
                "dismissed-corrupt-\(UUID().uuidString).json")
            try FileManager.default.moveItem(at: url, to: backup)
            throw error
        }
        entries = loaded.reduce(into: [:]) { result, entry in result[entry.key] = entry.end }
        prune(now: now)
    }

    func dismiss(_ event: EventSnapshot, now: Date) throws {
        // 保存失敗でも、このプロセス内では同じ回を抑止する。
        entries[event.id] = event.end
        prune(now: now)
        try save()
    }

    func reconcile(events: [EventSnapshot], now: Date) throws {
        let previous = entries
        for event in events where entries[event.id] != nil { entries[event.id] = event.end }
        prune(now: now)
        if entries != previous { try save() }
    }

    private func prune(now: Date) {
        entries = entries.filter { $0.value.addingTimeInterval(7 * 24 * 60 * 60) > now }
    }

    private func save() throws {
        guard let url else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(entries.map { Entry(key: $0.key, end: $0.value) })
        try data.write(to: url, options: .atomic)
    }
}
