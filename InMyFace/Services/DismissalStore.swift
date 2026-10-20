import Foundation

/// タイトルやURLを含まない、回キーと保存期限だけの台帳。
final class DismissalStore {
    struct Entry: Codable {
        let key: OccurrenceKey
        var end: Date
    }

    private let url: URL?
    private var needsSave = false
    private(set) var entries: [OccurrenceKey: Date] = [:]

    init(url: URL?) { self.url = url }

    var dismissedIDs: Set<OccurrenceKey> { Set(entries.keys) }

    func load(now: Date) throws {
        guard let url else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            try pruneBackups(now: now)
            return
        }
        let data = try Data(contentsOf: url)
        let loaded: [Entry]
        do {
            loaded = try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            let backup = url.deletingLastPathComponent().appendingPathComponent(
                "dismissed-corrupt-\(UUID().uuidString).json")
            try FileManager.default.moveItem(at: url, to: backup)
            try FileManager.default.setAttributes(
                [.modificationDate: now], ofItemAtPath: backup.path)
            try pruneBackups(now: now, keeping: backup)
            throw error
        }
        entries = loaded.reduce(into: [:]) { result, entry in result[entry.key] = entry.end }
        let previous = entries
        prune(now: now)
        needsSave = entries != previous
        if needsSave { try save() }
        try pruneBackups(now: now)
    }

    func dismiss(_ event: EventSnapshot, now: Date) throws {
        // 保存失敗でも、このプロセス内では同じ回を抑止する。
        entries[event.id] = event.end
        needsSave = true
        prune(now: now)
        try save()
    }

    func reconcile(events: [EventSnapshot], now: Date) throws {
        let previous = entries
        for event in events where entries[event.id] != nil { entries[event.id] = event.end }
        prune(now: now)
        if entries != previous { needsSave = true }
        if needsSave { try save() }
        try pruneBackups(now: now)
    }

    private func pruneBackups(now: Date, keeping newest: URL? = nil) throws {
        guard let directory = url?.deletingLastPathComponent(),
            FileManager.default.fileExists(atPath: directory.path)
        else { return }
        let prefix = "dismissed-corrupt-"
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])
        let backups = try files.compactMap { file -> (url: URL, date: Date)? in
            let name = file.lastPathComponent
            guard name.hasPrefix(prefix), name.hasSuffix(".json"),
                UUID(uuidString: String(name.dropFirst(prefix.count).dropLast(5))) != nil
            else { return nil }
            let values = try file.resourceValues(forKeys: [
                .contentModificationDateKey, .isRegularFileKey,
            ])
            guard values.isRegularFile == true else { return nil }
            return (file, values.contentModificationDate ?? .distantPast)
        }.sorted {
            if $0.url == newest || $1.url == newest {
                return $0.url == newest && $1.url != newest
            }
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.url.lastPathComponent < $1.url.lastPathComponent
        }
        for (index, backup) in backups.enumerated()
        where index > 0 || backup.date.addingTimeInterval(7 * 24 * 60 * 60) <= now {
            try FileManager.default.removeItem(at: backup.url)
        }
    }

    private func prune(now: Date) {
        entries = entries.filter { $0.value.addingTimeInterval(7 * 24 * 60 * 60) > now }
    }

    private func save() throws {
        guard let url else {
            needsSave = false
            return
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(entries.map { Entry(key: $0.key, end: $0.value) })
        try data.write(to: url, options: .atomic)
        needsSave = false
    }
}
