import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.clipswifty", category: "DownloadViewModel")

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var urlInput: String = "" {
        didSet {
            updatePlaylistDetection()
        }
    }
    @Published var selectedVideoFormat: VideoFormat = .best
    @Published var selectedAudioFormat: AudioFormat = .mp3
    @Published var isAudioOnly: Bool = false
    @Published var isPlaylistDetected: Bool = false
    @Published var downloadFullPlaylist: Bool = false
    @Published var showPlaylistDialog: Bool = false
    @Published var playlistInfo: PlaylistInfo?
    @Published var isFetchingPlaylist: Bool = false

    struct PlaylistInfo {
        let url: String
        let title: String?
        let videoCount: Int
        let videos: [(url: String, title: String?)]
    }
    @Published var downloads: [DownloadItem] = []
    @Published var isDownloading: Bool = false
    @Published var errorMessage: String?
    @Published var outputDirectory: URL

    private let ytDlpManager = YtDlpManager.shared
    private var saveTask: Task<Void, Never>?
    private var lastSaveTime: Date = .distantPast

    // Throttled save - only save every 2 seconds max during downloads
    private func scheduleSave(immediate: Bool = false) {
        saveTask?.cancel()

        if immediate || Date().timeIntervalSince(lastSaveTime) > 2.0 {
            saveDownloads()
            lastSaveTime = Date()
        } else {
            saveTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                saveDownloads()
                lastSaveTime = Date()
            }
        }
    }

    private var dataFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("ClipSwifty")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("downloads.json")
    }

    init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        loadDownloads()
    }

    private func loadDownloads() {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: dataFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([DownloadItem].self, from: data)
            // Reset any in-progress downloads to paused state
            self.downloads = loaded.map { item in
                var mutableItem = item
                switch item.status {
                case .downloading(let progress):
                    mutableItem.status = .paused(progress: progress)
                case .fetchingInfo:
                    mutableItem.status = .pending
                case .converting:
                    mutableItem.status = .paused(progress: 0.99)
                default:
                    break
                }
                return mutableItem
            }
            logger.info("Loaded \(self.downloads.count) downloads")
        } catch {
            logger.error("Failed to load downloads: \(error.localizedDescription)")
        }
    }

    private func saveDownloads() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(downloads)
            try data.write(to: dataFileURL)
        } catch {
            logger.error("Failed to save downloads: \(error.localizedDescription)")
        }
    }

    // MARK: - Playlist Detection

    private func updatePlaylistDetection() {
        let url = urlInput.lowercased()
        isPlaylistDetected = url.contains("list=") ||
                            url.contains("/playlist") ||
                            url.contains("&list=")

        // Reset playlist toggle when URL changes
        if !isPlaylistDetected {
            downloadFullPlaylist = false
        }
    }

    // MARK: - Public Actions

    func startDownload() {
        guard !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a URL"
            return
        }

        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // If playlist detected, always show dialog to let user choose
        if isPlaylistDetected {
            Task {
                await fetchPlaylistInfo(url: url)
            }
            urlInput = ""
            return
        }

        // Single video download - start immediately with downloading status
        // Generate thumbnail URL immediately (no network request needed for YouTube)
        let thumbnailURL = extractThumbnailURL(from: url)

        let item = DownloadItem(
            url: url,
            thumbnailURL: thumbnailURL,
            status: .downloading(progress: 0),
            isAudioOnly: isAudioOnly,
            videoFormat: selectedVideoFormat.rawValue,
            audioFormat: selectedAudioFormat.rawValue,
            isPlaylist: false
        )
        downloads.insert(item, at: 0)
        scheduleSave(immediate: true)

        Task {
            await processDownload(itemId: item.id, url: url)
        }

        urlInput = ""
        downloadFullPlaylist = false
    }

    private func fetchPlaylistInfo(url: String) async {
        logger.info("Fetching playlist info for dialog: \(url)")
        isFetchingPlaylist = true

        do {
            try await ytDlpManager.setup()

            // Use -J for single JSON output (much faster than line-by-line)
            // Optimized for speed with minimal extraction
            let output = try await ytDlpManager.run(arguments: [
                "--flat-playlist",
                "-J",  // Single JSON output - faster parsing
                "--playlist-end", "100",
                "--no-warnings",
                "--ignore-errors",
                "--socket-timeout", "10",
                "--extractor-args", "youtube:skip=dash,hls",  // Skip format extraction
                url
            ])

            guard output.exitCode == 0 else {
                isFetchingPlaylist = false
                errorMessage = "Failed to fetch playlist: \(output.stderr)"
                return
            }

            // Parse single JSON object
            guard let data = output.stdout.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                isFetchingPlaylist = false
                errorMessage = "Failed to parse playlist data"
                return
            }

            let playlistTitle = json["title"] as? String ?? "Playlist"
            var videos: [(url: String, title: String?)] = []

            // Get entries array
            if let entries = json["entries"] as? [[String: Any]] {
                for entry in entries {
                    let videoUrl: String
                    if let entryUrl = entry["url"] as? String {
                        videoUrl = entryUrl
                    } else if let id = entry["id"] as? String {
                        videoUrl = "https://www.youtube.com/watch?v=\(id)"
                    } else {
                        continue
                    }
                    let videoTitle = entry["title"] as? String
                    videos.append((url: videoUrl, title: videoTitle))
                }
            }

            playlistInfo = PlaylistInfo(
                url: url,
                title: playlistTitle,
                videoCount: videos.count,
                videos: videos
            )
            isFetchingPlaylist = false
            showPlaylistDialog = true

            logger.info("Playlist info fetched: \(videos.count) videos")

        } catch {
            isFetchingPlaylist = false
            errorMessage = "Playlist error: \(error.localizedDescription)"
        }
    }

    func startPlaylistDownload(limit: Int?) {
        guard let info = playlistInfo else { return }

        showPlaylistDialog = false

        let videosToDownload = limit.map { Array(info.videos.prefix($0)) } ?? info.videos

        for (index, video) in videosToDownload.enumerated() {
            // Generate thumbnail URL directly from video ID (no network request needed)
            let thumbnailURL = extractThumbnailURL(from: video.url)

            let item = DownloadItem(
                url: video.url,
                title: video.title,
                thumbnailURL: thumbnailURL,
                status: index == 0 ? .downloading(progress: 0) : .pending,
                isAudioOnly: isAudioOnly,
                videoFormat: selectedVideoFormat.rawValue,
                audioFormat: selectedAudioFormat.rawValue,
                isPlaylist: true,
                playlistIndex: index + 1,
                playlistTitle: info.title
            )

            downloads.append(item)
        }

        scheduleSave(immediate: true)
        logger.info("Added \(videosToDownload.count) videos from playlist")

        let playlistItems = downloads.filter { $0.playlistTitle == info.title }

        // Start TWO parallel tasks:
        // 1. Download videos (max 5 concurrent)
        // 2. Prefetch info for waiting videos
        Task {
            async let downloading: () = downloadPlaylistParallel(items: playlistItems)
            async let prefetching: () = prefetchPlaylistInfo(items: playlistItems)
            _ = await (downloading, prefetching)
        }

        playlistInfo = nil
    }

    /// Extract YouTube video ID and generate thumbnail URL directly (no network request!)
    private func extractThumbnailURL(from url: String) -> URL? {
        // Extract video ID from various YouTube URL formats
        let patterns = [
            "v=([a-zA-Z0-9_-]{11})",           // youtube.com/watch?v=ID
            "youtu\\.be/([a-zA-Z0-9_-]{11})",  // youtu.be/ID
            "/embed/([a-zA-Z0-9_-]{11})",      // youtube.com/embed/ID
            "/v/([a-zA-Z0-9_-]{11})"           // youtube.com/v/ID
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let idRange = Range(match.range(at: 1), in: url) {
                let videoId = String(url[idRange])
                // YouTube thumbnail URL pattern - hqdefault is 480x360
                return URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
            }
        }
        return nil
    }

    /// Prefetch video info only for items missing BOTH title AND thumbnail
    private func prefetchPlaylistInfo(items: [DownloadItem]) async {
        // Skip items that already have titles (from playlist fetch)
        let itemsNeedingInfo = items.filter { $0.title == nil && $0.thumbnailURL == nil }
        guard !itemsNeedingInfo.isEmpty else {
            logger.info("All playlist items already have info - skipping prefetch")
            return
        }

        logger.info("Prefetching info for \(itemsNeedingInfo.count) playlist items")

        // Fetch info for up to 10 items concurrently
        await withTaskGroup(of: Void.self) { group in
            var pending = itemsNeedingInfo.makeIterator()
            var activeCount = 0
            let maxConcurrent = 10

            while activeCount < maxConcurrent, let item = pending.next() {
                activeCount += 1
                group.addTask {
                    await self.fetchAndUpdateInfo(itemId: item.id, url: item.url)
                }
            }

            for await _ in group {
                activeCount -= 1
                if let item = pending.next() {
                    activeCount += 1
                    group.addTask {
                        await self.fetchAndUpdateInfo(itemId: item.id, url: item.url)
                    }
                }
            }
        }
    }

    private func downloadPlaylistParallel(items: [DownloadItem]) async {
        let maxConcurrent = 5  // Download up to 5 videos at once

        await withTaskGroup(of: Void.self) { group in
            var pending = items.makeIterator()
            var activeCount = 0

            // Start initial batch
            while activeCount < maxConcurrent, let item = pending.next() {
                activeCount += 1
                group.addTask {
                    await self.processDownload(itemId: item.id, url: item.url)
                }
            }

            // As each completes, start the next
            for await _ in group {
                activeCount -= 1
                if let item = pending.next() {
                    activeCount += 1
                    group.addTask {
                        await self.processDownload(itemId: item.id, url: item.url)
                    }
                }
            }
        }
    }

    func cancelPlaylistDialog() {
        showPlaylistDialog = false
        playlistInfo = nil
    }

    func downloadSingleFromPlaylist() {
        guard let info = playlistInfo else { return }

        showPlaylistDialog = false

        // Download just the first video (the one in the URL)
        let item = DownloadItem(
            url: info.url,
            status: .fetchingInfo,
            isAudioOnly: isAudioOnly,
            videoFormat: selectedVideoFormat.rawValue,
            audioFormat: selectedAudioFormat.rawValue,
            isPlaylist: false
        )
        downloads.insert(item, at: 0)
        scheduleSave(immediate: true)

        Task {
            await processDownload(itemId: item.id, url: info.url)
        }

        playlistInfo = nil
    }

    func retryDownload(_ item: DownloadItem) {
        guard let idx = downloads.firstIndex(where: { $0.id == item.id }) else { return }

        logger.info("Retrying download: \(item.id)")
        downloads[idx].status = .pending

        Task {
            // If we have video info, skip fetching
            if item.title != nil {
                await performDownload(itemId: item.id, url: item.url, item: item)
            } else {
                await processDownload(itemId: item.id, url: item.url)
            }
        }
    }

    func pauseDownload(_ item: DownloadItem) {
        guard let idx = downloads.firstIndex(where: { $0.id == item.id }) else { return }

        if case .downloading(let progress) = item.status {
            logger.info("Pausing download: \(item.id)")
            ytDlpManager.cancelDownload(id: item.id)
            downloads[idx].status = .paused(progress: progress)
            scheduleSave(immediate: true)
        }
    }

    func resumeDownload(_ item: DownloadItem) {
        guard let idx = downloads.firstIndex(where: { $0.id == item.id }) else { return }

        if case .paused = item.status {
            logger.info("Resuming download: \(item.id)")
            downloads[idx].status = .pending

            Task {
                await performDownload(itemId: item.id, url: item.url, item: item)
            }
        }
    }

    func cancelDownload(_ item: DownloadItem) {
        guard let idx = downloads.firstIndex(where: { $0.id == item.id }) else { return }

        logger.info("Cancelling download: \(item.id)")
        ytDlpManager.cancelDownload(id: item.id)
        downloads[idx].status = .failed(message: "Cancelled")
        scheduleSave(immediate: true)
    }

    func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    func clearCompleted() {
        downloads.removeAll { item in
            if case .completed = item.status { return true }
            return false
        }
        scheduleSave(immediate: true)
    }

    func removeItem(_ item: DownloadItem) {
        // Cancel if running
        if item.status.isActive {
            ytDlpManager.cancelDownload(id: item.id)
        }
        downloads.removeAll { $0.id == item.id }
        scheduleSave(immediate: true)
    }

    func showInFinder(_ item: DownloadItem) {
        if let outputPath = item.outputPath {
            NSWorkspace.shared.selectFile(outputPath.path, inFileViewerRootedAtPath: outputPath.deletingLastPathComponent().path)
        } else {
            // Open the output directory if no specific file
            NSWorkspace.shared.open(outputDirectory)
        }
    }

    // MARK: - Private Methods

    private func processDownload(itemId: UUID, url: String) async {
        guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }

        do {
            try await ytDlpManager.setup()

            let item = downloads[idx]

            // Only fetch info if we don't have title yet
            let needsInfo = item.title == nil

            if needsInfo {
                // Generate thumbnail immediately (no network request)
                if item.thumbnailURL == nil, let thumbURL = extractThumbnailURL(from: url) {
                    downloads[idx].thumbnailURL = thumbURL
                }

                // Start download and info fetch in PARALLEL
                async let infoTask: () = fetchAndUpdateInfo(itemId: itemId, url: url)
                async let downloadTask: () = performDownload(itemId: itemId, url: url, item: downloads[idx])
                _ = await (infoTask, downloadTask)
            } else {
                // Already have info - just download
                await performDownload(itemId: itemId, url: url, item: item)
            }

        } catch {
            guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }
            downloads[idx].status = .failed(message: error.localizedDescription)
            scheduleSave(immediate: true)
        }
    }

    private func fetchAndUpdateInfo(itemId: UUID, url: String) async {
        do {
            let videoInfo = try await ytDlpManager.fetchVideoInfoFast(url: url)
            guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }
            downloads[idx].updateWithVideoInfo(videoInfo)
            scheduleSave()
        } catch {
            // Info fetch failed - not critical, download continues
            logger.warning("Info fetch failed for \(itemId): \(error.localizedDescription)")
        }
    }

    private func performDownload(itemId: UUID, url: String, item: DownloadItem) async {
        guard let index = downloads.firstIndex(where: { $0.id == itemId }) else { return }

        downloads[index].status = .downloading(progress: 0)

        var arguments = buildArguments(for: url, item: item)
        // Add continue flag for resume support
        arguments += ["--continue", "-o", outputDirectory.appendingPathComponent("%(title)s.%(ext)s").path]

        do {
            let output = try await ytDlpManager.runWithProgress(id: itemId, arguments: arguments) { [weak self] progress in
                Task { @MainActor in
                    guard let self = self,
                          let idx = self.downloads.firstIndex(where: { $0.id == itemId }) else { return }

                    // Get current progress to prevent jumping backwards (video+audio have multiple phases)
                    let currentProgress: Double
                    if case .downloading(let p) = self.downloads[idx].status {
                        currentProgress = p
                    } else {
                        currentProgress = 0
                    }

                    // Only update if progress increased
                    if progress > currentProgress {
                        self.downloads[idx].status = .downloading(progress: progress)
                        self.scheduleSave() // Throttled save during progress
                    }
                }
            }

            guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }

            if output.wasCancelled {
                // Already handled by pause/cancel
                if case .paused = downloads[idx].status {
                    // Keep paused state
                } else {
                    downloads[idx].status = .failed(message: "Cancelled")
                }
            } else if output.exitCode == 0 {
                downloads[idx].status = .completed
                // Try to find the downloaded file
                if let title = downloads[idx].title {
                    let expectedFile = findDownloadedFile(title: title)
                    downloads[idx].outputPath = expectedFile
                }
                logger.info("Download completed: \(itemId)")
            } else {
                let errorMsg = output.stderr.isEmpty ? "Unknown error" : String(output.stderr.prefix(200))
                downloads[idx].status = .failed(message: errorMsg)
            }
            scheduleSave(immediate: true) // Immediate save on completion/failure
        } catch {
            guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }
            downloads[idx].status = .failed(message: error.localizedDescription)
            scheduleSave(immediate: true)
        }

        isDownloading = false
    }

    private func findDownloadedFile(title: String) -> URL? {
        // Clean the title to match filesystem naming
        let cleanTitle = title
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: outputDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            // Find files matching the title
            let matchingFiles = contents.filter { url in
                url.lastPathComponent.hasPrefix(cleanTitle) ||
                url.lastPathComponent.contains(cleanTitle.prefix(30))
            }

            // Return the most recently created matching file
            return matchingFiles
                .compactMap { url -> (URL, Date)? in
                    guard let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else { return nil }
                    return (url, date)
                }
                .sorted { $0.1 > $1.1 }
                .first?.0

        } catch {
            logger.error("Failed to find downloaded file: \(error.localizedDescription)")
            return nil
        }
    }

    private func buildArguments(for url: String, item: DownloadItem) -> [String] {
        var args: [String] = []

        if item.isAudioOnly {
            if let format = AudioFormat(rawValue: item.audioFormat) {
                args += format.ytDlpArguments
            } else {
                args += AudioFormat.mp3.ytDlpArguments
            }
        } else {
            if let format = VideoFormat(rawValue: item.videoFormat) {
                args += format.ytDlpArguments
            } else {
                args += VideoFormat.best.ytDlpArguments
            }
        }

        // Performance optimizations
        let fragments = AppSettings.shared.concurrentFragments
        args += [
            "--concurrent-fragments", "\(fragments)", // Download fragments in parallel
            "--buffer-size", "16K",                   // Larger buffer for faster IO
            "--http-chunk-size", "10M",               // Larger chunks
            "--retries", "3",                         // Quick retries
            "--fragment-retries", "3",
            "--no-check-certificates",                // Skip cert validation (faster)
        ]

        // Add rate limit if configured
        args += AppSettings.shared.rateLimitArgument

        // Add newline for progress parsing
        args += ["--newline"]

        // Only add --no-playlist for non-playlist downloads
        if !item.isPlaylist {
            args += ["--no-playlist"]
        }

        args += [url]

        return args
    }
}
