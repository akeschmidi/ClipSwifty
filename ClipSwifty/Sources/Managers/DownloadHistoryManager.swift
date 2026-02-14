import Foundation
import os.log

private let historyLogger = Logger(subsystem: "com.clipswifty", category: "DownloadHistory")

@MainActor
final class DownloadHistoryManager: ObservableObject {
    static let shared = DownloadHistoryManager()

    @Published var items: [DownloadHistoryItem] = []
    @Published var searchText: String = ""

    private let maxEntries = 500

    private var dataFileURL: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/ClipSwifty/download_history.json")
        }
        let appFolder = appSupport.appendingPathComponent("ClipSwifty")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("download_history.json")
    }

    var filteredItems: [DownloadHistoryItem] {
        guard !searchText.isEmpty else { return items }
        let query = searchText.lowercased()
        return items.filter { item in
            (item.title?.lowercased().contains(query) ?? false) ||
            (item.uploader?.lowercased().contains(query) ?? false) ||
            item.url.lowercased().contains(query)
        }
    }

    private init() {
        loadHistory()
    }

    func addToHistory(_ item: DownloadItem) {
        let historyItem = DownloadHistoryItem(from: item)
        items.insert(historyItem, at: 0)

        // Enforce max entries
        if items.count > maxEntries {
            items = Array(items.prefix(maxEntries))
        }

        saveHistory()
        historyLogger.info("Added to history: \(item.title ?? item.url)")
    }

    func isDuplicate(url: String) -> DownloadHistoryItem? {
        let normalized = normalizeURL(url)
        return items.first { normalizeURL($0.url) == normalized }
    }

    func clearHistory() {
        items.removeAll()
        saveHistory()
        historyLogger.info("History cleared")
    }

    func removeItem(_ item: DownloadHistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    private func normalizeURL(_ url: String) -> String {
        var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Remove trailing slashes
        while normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        // Remove common tracking parameters
        if let urlComponents = URLComponents(string: normalized) {
            var components = urlComponents
            let filteredItems = components.queryItems?.filter { item in
                // Keep only essential params like v= for YouTube, remove tracking
                let keepParams = ["v", "list", "index"]
                return keepParams.contains(item.name)
            }
            components.queryItems = filteredItems?.isEmpty == true ? nil : filteredItems
            normalized = components.string ?? normalized
        }

        // Normalize youtu.be to youtube.com
        if normalized.contains("youtu.be/") {
            if let range = normalized.range(of: "youtu.be/") {
                let videoId = String(normalized[range.upperBound...]).components(separatedBy: "?").first ?? ""
                normalized = "https://www.youtube.com/watch?v=\(videoId)"
            }
        }

        return normalized
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: dataFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([DownloadHistoryItem].self, from: data)
            historyLogger.info("Loaded \(self.items.count) history items")
        } catch {
            historyLogger.error("Failed to load history: \(error.localizedDescription)")
        }
    }

    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: dataFileURL, options: [.atomic])
        } catch {
            historyLogger.error("Failed to save history: \(error.localizedDescription)")
        }
    }
}
