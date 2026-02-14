import Foundation
import SwiftUI
import os.log
import UserNotifications

private let logger = Logger(subsystem: "com.clipswifty", category: "DownloadViewModel")

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var urlInput: String = "" {
        didSet {
            updatePlaylistDetection()
            prefetchVideoInfo()
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
    @Published var isPrefetching: Bool = false
    @Published var prefetchedTitle: String?
    @Published var prefetchStatusMessage: String = ""
    @Published var availableQualities: [AvailableQuality] = []
    @Published var selectedQuality: AvailableQuality?

    // F1: Estimated file size for pre-download display
    @Published var estimatedFileSize: Int?

    // F4: History & duplicate detection
    @Published var showDuplicateWarning: Bool = false
    @Published var duplicateHistoryItem: DownloadHistoryItem?
    @Published var showHistory: Bool = false
    private let historyManager = DownloadHistoryManager.shared
    private var pendingDuplicateURL: String?

    // F3: Batch mode
    var detectedURLs: [String] {
        urlInput.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
    }
    var isBatchMode: Bool { detectedURLs.count > 1 }

    // Clipboard monitoring
    @Published var clipboardDetectedURL: String?
    @Published var showClipboardPopup: Bool = false
    private var clipboardMonitorTask: Task<Void, Never>?
    private var lastClipboardContent: String = ""
    private var lastClipboardChangeCount: Int = 0

    // Format preset
    @Published var selectedPreset: FormatPreset = .custom {
        didSet {
            applyPreset(selectedPreset)
        }
    }

    private var statusMessageTask: Task<Void, Never>?
    private let funnyLoadingMessages = [
        "🔍 Schnüffle am Video...",
        "🎬 Frage YouTube höflich...",
        "📡 Verbinde mit dem Internet-Dings...",
        "🧙‍♂️ Zaubere Metadaten herbei...",
        "🎯 Suche die beste Qualität...",
        "🍿 Bereite Popcorn vor...",
        "🔮 Lese die Kristallkugel...",
        "🎪 Jongliere mit Bytes...",
        "🚀 Lade Raketentreibstoff...",
        "🐢 Warte auf die Schildkröte...",
        "☕ Koche erstmal Kaffee...",
        "🎸 Stimme die Gitarre...",
        "🌈 Male einen Regenbogen...",
        "🎲 Würfle die Formate...",
        "🔧 Schraube am Decoder...",
        "📺 Putze den Bildschirm...",
        "🎭 Probe die Vorstellung...",
        "🌟 Sammle Sternstaub..."
    ]

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

    /// Number of currently active downloads
    var activeDownloadCount: Int {
        downloads.filter { $0.status.isActive }.count
    }

    private let ytDlpManager = YtDlpManager.shared
    private let notificationCenter = UNUserNotificationCenter.current()
    private var saveTask: Task<Void, Never>?
    private var lastSaveTime: Date = .distantPast

    // Prefetch cache for video info (max 20 entries to bound memory)
    private var prefetchCache: [String: VideoInfo] = [:]
    private var prefetchCacheOrder: [String] = []
    private let maxPrefetchCacheSize = 20
    private var prefetchTask: Task<Void, Never>?
    private var lastPrefetchURL: String = ""

    /// Insert into prefetch cache with LRU eviction
    private func cachePrefetch(url: String, info: VideoInfo) {
        prefetchCache[url] = info
        prefetchCacheOrder.removeAll { $0 == url }
        prefetchCacheOrder.append(url)
        while prefetchCacheOrder.count > maxPrefetchCacheSize {
            let oldest = prefetchCacheOrder.removeFirst()
            prefetchCache.removeValue(forKey: oldest)
        }
    }

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
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/ClipSwifty/downloads.json")
        }
        let appFolder = appSupport.appendingPathComponent("ClipSwifty")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("downloads.json")
    }

    init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        self.selectedPreset = .custom
        loadDownloads()
        requestNotificationPermission()
        startClipboardMonitoring()
    }

    deinit {
        clipboardMonitorTask?.cancel()
    }

    // MARK: - Format Presets

    private func applyPreset(_ preset: FormatPreset) {
        guard preset != .custom else { return }
        isAudioOnly = preset.isAudioOnly
        if !preset.isAudioOnly {
            if let format = VideoFormat(rawValue: preset.videoFormat) {
                selectedVideoFormat = format
            }
        } else {
            if let format = AudioFormat(rawValue: preset.audioFormat) {
                selectedAudioFormat = format
            }
        }
        AppSettings.shared.selectedPreset = preset
    }

    // MARK: - Clipboard Monitoring

    private func startClipboardMonitoring() {
        lastClipboardChangeCount = NSPasteboard.general.changeCount
        clipboardMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s
                guard !Task.isCancelled, let self = self else { break }
                self.checkClipboard()
            }
        }
    }

    @MainActor
    private func checkClipboard() {
        guard AppSettings.shared.clipboardMonitoring else { return }

        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        // Only check if clipboard changed
        guard currentChangeCount != lastClipboardChangeCount else { return }
        lastClipboardChangeCount = currentChangeCount

        guard let content = pasteboard.string(forType: .string) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Don't show popup for same URL
        guard trimmed != lastClipboardContent else { return }

        // Check if it's a video URL
        if isValidVideoURL(trimmed) {
            lastClipboardContent = trimmed
            clipboardDetectedURL = trimmed
            showClipboardPopup = true

            // Auto-hide after 5 seconds
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self.clipboardDetectedURL == trimmed {
                    self.showClipboardPopup = false
                }
            }
        }
    }

    func downloadFromClipboard() {
        guard let url = clipboardDetectedURL else { return }
        urlInput = url
        showClipboardPopup = false
        startDownload()
    }

    func dismissClipboardPopup() {
        showClipboardPopup = false
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func sendDownloadCompleteNotification(title: String) {
        guard AppSettings.shared.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Download abgeschlossen"
        content.body = title
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    private func loadDownloads() {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: dataFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([DownloadItem].self, from: data)
            // Reset any in-progress downloads to safe states after restart
            self.downloads = loaded.map { item in
                var mutableItem = item
                switch item.status {
                case .downloading(let progress):
                    mutableItem.status = .paused(progress: progress)
                case .fetchingInfo, .preparing:
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
            let data = try encoder.encode(downloads)
            try data.write(to: dataFileURL, options: [.atomic])
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

    /// Prefetch video info in the background as user types/pastes URL
    private func prefetchVideoInfo() {
        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear indicator if URL is empty or invalid
        if url.isEmpty || isPlaylistDetected || !isValidVideoURL(url) || isBatchMode {
            prefetchTask?.cancel()
            prefetchTask = nil
            isPrefetching = false
            prefetchedTitle = nil
            availableQualities = []
            selectedQuality = nil
            estimatedFileSize = nil
            lastPrefetchURL = ""
            return
        }

        // Don't prefetch same URL
        guard url != lastPrefetchURL else { return }

        // Cancel any existing prefetch
        prefetchTask?.cancel()
        lastPrefetchURL = url
        prefetchedTitle = nil
        availableQualities = []
        selectedQuality = nil

        // Check cache first
        if let cached = prefetchCache[url] {
            prefetchedTitle = cached.title
            availableQualities = cached.availableQualities
            if let first = availableQualities.first {
                selectedQuality = first  // Default to best quality
            }
            // F1: Calculate estimated file size
            estimatedFileSize = cached.estimatedFileSize(
                forMaxHeight: selectedQuality?.height,
                isAudioOnly: isAudioOnly
            )
            logger.info("⏱️ [PREFETCH] Cache hit for: \(url)")
            return
        }

        // Start prefetch with small delay (debounce for typing)
        prefetchTask = Task {
            // Wait a bit in case user is still typing
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }

            isPrefetching = true
            startFunnyStatusMessages()
            logger.info("⏱️ [PREFETCH] Starting prefetch for: \(url)")
            let startTime = Date()

            do {
                // Use full info fetch to get available formats
                let info = try await ytDlpManager.fetchVideoInfo(url: url)
                guard !Task.isCancelled else {
                    stopFunnyStatusMessages()
                    return
                }

                // Cache the result
                cachePrefetch(url: url, info: info)
                prefetchedTitle = info.title
                availableQualities = info.availableQualities
                if let first = availableQualities.first {
                    selectedQuality = first  // Default to best quality
                }
                // F1: Calculate estimated file size
                estimatedFileSize = info.estimatedFileSize(
                    forMaxHeight: selectedQuality?.height,
                    isAudioOnly: isAudioOnly
                )

                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                let qualityCount = self.availableQualities.count
                logger.info("⏱️ [PREFETCH] Completed in \(elapsed)ms: \(info.title ?? "unknown"), \(qualityCount) qualities")
            } catch {
                guard !Task.isCancelled else {
                    stopFunnyStatusMessages()
                    return
                }
                logger.warning("⏱️ [PREFETCH] Failed: \(error.localizedDescription)")
            }

            stopFunnyStatusMessages()
            isPrefetching = false
        }
    }

    private func startFunnyStatusMessages() {
        prefetchStatusMessage = funnyLoadingMessages.randomElement() ?? "Laden..."
        statusMessageTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Change every 2 seconds
                guard !Task.isCancelled else { break }
                prefetchStatusMessage = funnyLoadingMessages.randomElement() ?? "Laden..."
            }
        }
    }

    private func stopFunnyStatusMessages() {
        statusMessageTask?.cancel()
        statusMessageTask = nil
        prefetchStatusMessage = ""
    }

    private func isValidVideoURL(_ url: String) -> Bool {
        let patterns = [
            "youtube.com/watch",
            "youtu.be/",
            "vimeo.com/",
            "dailymotion.com/",
            "twitch.tv/",
            "twitter.com/",
            "x.com/",
            "tiktok.com/",
            "instagram.com/",
            "facebook.com/"
        ]
        let lowercased = url.lowercased()
        return patterns.contains { lowercased.contains($0) }
    }

    // MARK: - Public Actions

    /// Recalculate estimated file size when quality or audio mode changes
    func recalculateFileSize() {
        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cached = prefetchCache[url] else {
            estimatedFileSize = nil
            return
        }
        estimatedFileSize = cached.estimatedFileSize(
            forMaxHeight: selectedQuality?.height,
            isAudioOnly: isAudioOnly
        )
    }

    /// F4: Confirm duplicate download after user accepts warning
    func confirmDuplicateDownload() {
        showDuplicateWarning = false
        guard let url = pendingDuplicateURL else { return }
        pendingDuplicateURL = nil
        startSingleDownload(url: url)
    }

    /// F4: Cancel duplicate download
    func cancelDuplicateDownload() {
        showDuplicateWarning = false
        pendingDuplicateURL = nil
        duplicateHistoryItem = nil
    }

    func startDownload() {
        let startTime = Date()
        logger.info("⏱️ [START] startDownload triggered")

        guard !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Bitte eine URL eingeben"
            return
        }

        // F3: Batch mode
        if isBatchMode {
            startBatchDownload()
            return
        }

        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPlaylist = isPlaylistDetected
        logger.info("⏱️ [INFO] URL: \(url), isPlaylistDetected: \(isPlaylist)")

        // F4: Duplicate check
        if let existing = historyManager.isDuplicate(url: url) {
            duplicateHistoryItem = existing
            pendingDuplicateURL = url
            showDuplicateWarning = true
            return
        }

        // If playlist detected, always show dialog to let user choose
        if isPlaylistDetected {
            logger.info("⏱️ [INFO] Starting playlist fetch...")
            Task {
                await fetchPlaylistInfo(url: url)
            }
            urlInput = ""
            return
        }

        startSingleDownload(url: url)
        logger.info("⏱️ [TIMING] startDownload setup completed in \(Int(Date().timeIntervalSince(startTime) * 1000))ms")
    }

    private func startSingleDownload(url: String) {
        // Single video download - start immediately with downloading status
        // Generate thumbnail URL immediately (no network request needed for YouTube)
        let thumbnailURL = extractThumbnailURL(from: url)

        // Use prefetched info if available
        let cachedInfo = prefetchCache[url]
        let prefetchedVideoTitle = cachedInfo?.title
        let prefetchedThumbnail = cachedInfo?.thumbnail.flatMap { URL(string: $0) }
        let prefetchedDuration = cachedInfo?.formattedDuration
        let prefetchedUploader = cachedInfo?.uploader

        // Use selected quality or fall back to best
        let qualityLabel = selectedQuality?.label ?? "best"
        let formatSelector = selectedQuality?.formatSelector ?? "bestvideo+bestaudio/best"

        if cachedInfo != nil {
            logger.info("⏱️ [PREFETCH] Using cached info for download: \(prefetchedVideoTitle ?? "unknown"), quality: \(qualityLabel)")
        }

        // F1: Estimated file size
        let estSize = cachedInfo?.estimatedFileSize(
            forMaxHeight: selectedQuality?.height,
            isAudioOnly: isAudioOnly
        )

        // Check disk space before starting download
        if let spaceError = checkDiskSpace(estimatedBytes: estSize) {
            errorMessage = spaceError
            return
        }

        let item = DownloadItem(
            url: url,
            title: prefetchedVideoTitle,
            thumbnailURL: prefetchedThumbnail ?? thumbnailURL,
            duration: prefetchedDuration,
            uploader: prefetchedUploader,
            status: .downloading(progress: 0),
            isAudioOnly: isAudioOnly,
            videoFormat: formatSelector,
            audioFormat: selectedAudioFormat.rawValue,
            isPlaylist: false,
            estimatedFileSize: estSize
        )
        downloads.insert(item, at: 0)
        scheduleSave(immediate: true)

        // Cancel prefetch and clear indicator immediately
        prefetchTask?.cancel()
        prefetchTask = nil
        isPrefetching = false
        prefetchedTitle = nil
        availableQualities = []
        selectedQuality = nil
        estimatedFileSize = nil
        prefetchCache.removeValue(forKey: url)

        logger.info("⏱️ [INFO] Item added to downloads, starting processDownload task...")
        Task {
            await processDownload(itemId: item.id, url: url)
        }

        urlInput = ""
        downloadFullPlaylist = false
    }

    // F3: Batch download
    private func startBatchDownload() {
        let urls = detectedURLs
        logger.info("⏱️ [BATCH] Starting batch download for \(urls.count) URLs")

        var items: [DownloadItem] = []
        for (index, url) in urls.enumerated() {
            let thumbnailURL = extractThumbnailURL(from: url)
            let item = DownloadItem(
                url: url,
                thumbnailURL: thumbnailURL,
                status: index == 0 ? .downloading(progress: 0) : .pending,
                isAudioOnly: isAudioOnly,
                videoFormat: selectedQuality?.formatSelector ?? selectedVideoFormat.rawValue,
                audioFormat: selectedAudioFormat.rawValue,
                isPlaylist: false
            )
            items.append(item)
            downloads.insert(item, at: downloads.count)
        }

        scheduleSave(immediate: true)

        // Clear input
        prefetchTask?.cancel()
        prefetchTask = nil
        isPrefetching = false
        prefetchedTitle = nil
        availableQualities = []
        selectedQuality = nil
        estimatedFileSize = nil
        urlInput = ""

        Task {
            await downloadPlaylistParallel(items: items)
        }
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
                let mapped = ErrorMapper.map(stderr: output.stderr)
                errorMessage = mapped.userMessage
                return
            }

            // Parse single JSON object
            guard let data = output.stdout.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                isFetchingPlaylist = false
                errorMessage = "Playlist-Daten konnten nicht verarbeitet werden"
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
            errorMessage = "Playlist-Fehler: \(error.localizedDescription)"
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

        // Fetch info for up to 4 items concurrently
        await withTaskGroup(of: Void.self) { group in
            var pending = itemsNeedingInfo.makeIterator()
            var activeCount = 0
            let maxConcurrent = 4

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
        downloads[idx].retryCount = 0  // F5: Reset retry count on manual retry
        let updatedItem = downloads[idx]  // Capture value copy before async

        Task {
            // If we have video info, skip fetching
            if updatedItem.title != nil {
                await performDownload(itemId: updatedItem.id, url: updatedItem.url, item: updatedItem)
            } else {
                await processDownload(itemId: updatedItem.id, url: updatedItem.url)
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
        downloads[idx].status = .failed(message: "Abgebrochen")
        scheduleSave(immediate: true)
    }

    func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Auswählen"

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

    // MARK: - Queue Management

    func moveItemUp(_ item: DownloadItem) {
        guard let idx = downloads.firstIndex(where: { $0.id == item.id }),
              idx > 0 else { return }
        downloads.swapAt(idx, idx - 1)
        scheduleSave(immediate: true)
    }

    func moveItemDown(_ item: DownloadItem) {
        guard let idx = downloads.firstIndex(where: { $0.id == item.id }),
              idx < downloads.count - 1 else { return }
        downloads.swapAt(idx, idx + 1)
        scheduleSave(immediate: true)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        downloads.move(fromOffsets: source, toOffset: destination)
        scheduleSave(immediate: true)
    }

    func pauseAll() {
        for idx in downloads.indices {
            if case .downloading(let progress) = downloads[idx].status {
                ytDlpManager.cancelDownload(id: downloads[idx].id)
                downloads[idx].status = .paused(progress: progress)
            }
        }
        scheduleSave(immediate: true)
    }

    func resumeAll() {
        let pausedItems = downloads.filter { item in
            if case .paused = item.status { return true }
            return false
        }

        for item in pausedItems {
            resumeDownload(item)
        }
    }

    var hasPausedDownloads: Bool {
        downloads.contains { item in
            if case .paused = item.status { return true }
            return false
        }
    }

    var hasActiveDownloads: Bool {
        downloads.contains { $0.status.isActive }
    }

    // MARK: - Private Methods

    private func checkDiskSpace(estimatedBytes: Int?) -> String? {
        guard let estimatedBytes = estimatedBytes, estimatedBytes > 0 else {
            return nil // No estimate available, proceed optimistically
        }

        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: outputDirectory.path)
            guard let freeSpace = attrs[.systemFreeSize] as? Int64 else { return nil }

            let requiredSpace = Int64(Double(estimatedBytes) * 1.5)
            if freeSpace < requiredSpace {
                let freeFormatted = ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
                let neededFormatted = ByteCountFormatter.string(fromByteCount: Int64(estimatedBytes), countStyle: .file)
                return "Nicht genügend Speicherplatz. Frei: \(freeFormatted), benötigt: ca. \(neededFormatted)"
            }
        } catch {
            logger.warning("Could not check disk space: \(error.localizedDescription)")
        }

        return nil
    }

    /// Safely mutate a download item by ID. Returns false if item no longer exists.
    @discardableResult
    private func updateDownload(_ itemId: UUID, _ mutation: (inout DownloadItem) -> Void) -> Bool {
        guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return false }
        mutation(&downloads[idx])
        return true
    }

    private func processDownload(itemId: UUID, url: String) async {
        let startTime = Date()
        logger.info("⏱️ [START] processDownload for \(itemId)")

        guard downloads.firstIndex(where: { $0.id == itemId }) != nil else {
            logger.warning("⏱️ [ABORT] Item not found: \(itemId)")
            return
        }

        do {
            let setupStart = Date()
            try await ytDlpManager.setup()
            logger.info("⏱️ [TIMING] setup took \(Int(Date().timeIntervalSince(setupStart) * 1000))ms")

            // Re-lookup index after await - user may have deleted items during setup
            guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else {
                logger.warning("⏱️ [ABORT] Item removed during setup: \(itemId)")
                return
            }

            // Generate thumbnail immediately if not present (no network request)
            if downloads[idx].thumbnailURL == nil, let thumbURL = extractThumbnailURL(from: url) {
                downloads[idx].thumbnailURL = thumbURL
                logger.info("⏱️ [TIMING] thumbnail URL generated locally")
            }

            // SKIP separate info fetch - we get title from yt-dlp output during download
            // This saves ~25-30 seconds!
            logger.info("⏱️ [START] download (title will be extracted from output)")
            await performDownload(itemId: itemId, url: url, item: downloads[idx])

            logger.info("⏱️ [DONE] processDownload took \(Int(Date().timeIntervalSince(startTime) * 1000))ms total")

        } catch {
            logger.error("⏱️ [ERROR] processDownload failed after \(Int(Date().timeIntervalSince(startTime) * 1000))ms: \(error.localizedDescription)")
            guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }
            downloads[idx].status = .failed(message: error.localizedDescription)
            scheduleSave(immediate: true)
        }
    }

    private func fetchAndUpdateInfo(itemId: UUID, url: String) async {
        let startTime = Date()
        logger.info("⏱️ [START] fetchAndUpdateInfo for \(itemId)")

        do {
            let videoInfo = try await ytDlpManager.fetchVideoInfoFast(url: url)
            logger.info("⏱️ [TIMING] fetchVideoInfoFast took \(Int(Date().timeIntervalSince(startTime) * 1000))ms")

            guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }
            downloads[idx].updateWithVideoInfo(videoInfo)
            scheduleSave()

            logger.info("⏱️ [DONE] fetchAndUpdateInfo completed in \(Int(Date().timeIntervalSince(startTime) * 1000))ms - title: \(videoInfo.title ?? "nil")")
        } catch {
            logger.warning("⏱️ [ERROR] fetchAndUpdateInfo failed after \(Int(Date().timeIntervalSince(startTime) * 1000))ms: \(error.localizedDescription)")
        }
    }

    private func performDownload(itemId: UUID, url: String, item: DownloadItem) async {
        let startTime = Date()
        logger.info("⏱️ [START] performDownload for \(itemId)")

        guard updateDownload(itemId, { $0.status = .preparing(status: "Verbinde...") }) else {
            logger.warning("⏱️ [ABORT] performDownload - item not found")
            return
        }

        let buildArgsStart = Date()
        var arguments = buildArguments(for: url, item: item)
        // Add continue flag for resume support and output template
        arguments += ["--continue", "-o", buildOutputTemplate()]
        logger.info("⏱️ [TIMING] buildArguments took \(Int(Date().timeIntervalSince(buildArgsStart) * 1000))ms")
        logger.info("⏱️ [DEBUG] yt-dlp arguments: \(arguments.joined(separator: " "))")

        let ytdlpStart = Date()
        var firstProgressTime: Date?
        var extractedTitle: String?

        do {
            let output = try await ytDlpManager.runWithProgressAndOutput(id: itemId, arguments: arguments) { [weak self] progress, outputLine in
                // Handle output line (for title extraction and status updates)
                if let line = outputLine {
                    // Update preparation status based on yt-dlp output
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.updateDownload(itemId) { item in
                            guard case .preparing = item.status else { return }
                            if line.contains("[youtube]") && line.contains("Extracting") {
                                item.status = .preparing(status: "Video-Infos laden...")
                            } else if line.contains("[info]") {
                                item.status = .preparing(status: "Formate abrufen...")
                            } else if line.contains("[download] Destination") {
                                item.status = .preparing(status: "Download startet...")
                            }
                        }
                    }

                    // Extract title from yt-dlp output (e.g., "[download] Destination: /path/Title.mp4")
                    if extractedTitle == nil {
                        if line.contains("[download] Destination:") || line.contains("[Merger]") || line.contains("Merging formats") {
                            // Extract filename from path
                            if let lastSlash = line.lastIndex(of: "/") {
                                let filename = String(line[line.index(after: lastSlash)...])
                                // Remove extension and clean up
                                if let dotIndex = filename.lastIndex(of: ".") {
                                    let title = String(filename[..<dotIndex])
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                        .replacingOccurrences(of: "\"", with: "")
                                    if !title.isEmpty {
                                        extractedTitle = title
                                        Task { @MainActor in
                                            guard let self = self else { return }
                                            self.updateDownload(itemId) { item in
                                                guard item.title == nil else { return }
                                                item.title = title
                                            }
                                            logger.info("⏱️ [INFO] Extracted title: \(title)")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Extract speed and ETA from download progress line
                    // Format: "[download]  50.0% of 100.00MiB at 2.50MiB/s ETA 00:20"
                    if line.contains("[download]") && line.contains("% of") {
                        var extractedSpeed: String?
                        var extractedEta: String?

                        // Extract speed (e.g., "2.50MiB/s" or "500KiB/s")
                        if let atIndex = line.range(of: " at ") {
                            let afterAt = line[atIndex.upperBound...]
                            if let speedEnd = afterAt.range(of: "/s") {
                                let speedStr = String(afterAt[..<speedEnd.upperBound])
                                    .trimmingCharacters(in: .whitespaces)
                                extractedSpeed = speedStr
                            }
                        }

                        // Extract ETA (e.g., "00:20" or "01:23:45")
                        if let etaIndex = line.range(of: "ETA ") {
                            let afterEta = line[etaIndex.upperBound...]
                            let etaStr = String(afterEta)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .components(separatedBy: " ").first ?? ""
                            if !etaStr.isEmpty && etaStr != "Unknown" {
                                extractedEta = etaStr
                            }
                        }

                        if extractedSpeed != nil || extractedEta != nil {
                            Task { @MainActor in
                                guard let self = self else { return }
                                self.updateDownload(itemId) { item in
                                    if let speed = extractedSpeed { item.downloadSpeed = speed }
                                    if let eta = extractedEta { item.eta = eta }
                                }
                            }
                        }
                    }

                    return  // Output line only, no progress update
                }

                // Handle progress update
                if progress >= 0 {
                    if firstProgressTime == nil {
                        firstProgressTime = Date()
                        let elapsed = Int(Date().timeIntervalSince(ytdlpStart) * 1000)
                        Task { @MainActor in
                            logger.info("⏱️ [TIMING] first progress received after \(elapsed)ms")
                        }
                    }

                    Task { @MainActor in
                        guard let self = self else { return }
                        self.updateDownload(itemId) { item in
                            // Get current progress to prevent jumping backwards (video+audio have multiple phases)
                            let currentProgress: Double
                            if case .downloading(let p) = item.status {
                                currentProgress = p
                            } else {
                                currentProgress = 0
                            }
                            // Only update if progress increased
                            if progress > currentProgress {
                                item.status = .downloading(progress: progress)
                            }
                        }
                        self.scheduleSave() // Throttled save during progress
                    }
                }
            }

            // Post-download: handle result
            guard let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }

            if output.wasCancelled {
                // Already handled by pause/cancel
                if case .paused = downloads[idx].status {
                    // Keep paused state
                } else {
                    updateDownload(itemId) { $0.status = .failed(message: "Abgebrochen") }
                }
            } else if output.exitCode == 0 {
                // Capture title before mutation for notification
                let completedTitle = downloads[idx].title
                updateDownload(itemId) { item in
                    item.status = .completed
                    item.downloadSpeed = nil
                    item.eta = nil
                }
                // Find downloaded file and update path
                if let title = completedTitle {
                    let expectedFile = findDownloadedFile(title: title)
                    updateDownload(itemId) { $0.outputPath = expectedFile }
                    sendDownloadCompleteNotification(title: title)
                }
                // F4: Add to history
                if let completedItem = downloads.first(where: { $0.id == itemId }) {
                    historyManager.addToHistory(completedItem)
                }
                logger.info("⏱️ [DONE] Download completed in \(Int(Date().timeIntervalSince(startTime) * 1000))ms: \(itemId)")
            } else {
                // F2: Map error to user-friendly message
                let mapped = ErrorMapper.map(stderr: output.stderr)
                logger.error("⏱️ [ERROR] Download failed after \(Int(Date().timeIntervalSince(startTime) * 1000))ms: \(mapped.originalMessage.prefix(200))")

                // Read current retry state safely
                let retryCount = downloads[idx].retryCount
                let maxRetries = downloads[idx].maxRetries

                updateDownload(itemId) { $0.errorDetail = mapped.originalMessage }

                // F5: Auto-retry if retryable
                if mapped.isRetryable && retryCount < maxRetries {
                    updateDownload(itemId) { $0.retryCount += 1 }
                    let currentRetry = retryCount + 1
                    let delaySeconds = [5, 15, 45][min(max(currentRetry - 1, 0), 2)]

                    logger.info("⏱️ [RETRY] Attempt \(currentRetry)/\(maxRetries) in \(delaySeconds)s for \(itemId)")

                    // Countdown with status updates
                    for remaining in stride(from: delaySeconds, through: 1, by: -1) {
                        guard updateDownload(itemId, { _ in }) else { return }
                        // Check if cancelled during retry wait
                        if let current = downloads.first(where: { $0.id == itemId }),
                           case .failed = current.status { return }
                        updateDownload(itemId) { $0.status = .preparing(status: "Retry \(currentRetry)/\(maxRetries) in \(remaining)s...") }
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }

                    // Check again if still valid before retrying
                    guard let retryItem = downloads.first(where: { $0.id == itemId }),
                          case .preparing = retryItem.status else { return }
                    scheduleSave(immediate: true)
                    await performDownload(itemId: itemId, url: url, item: retryItem)
                    return
                } else {
                    updateDownload(itemId) { $0.status = .failed(message: mapped.userMessage) }
                }
            }
            scheduleSave(immediate: true) // Immediate save on completion/failure
        } catch {
            let mapped = ErrorMapper.map(stderr: error.localizedDescription)
            updateDownload(itemId) { item in
                item.errorDetail = error.localizedDescription
                item.status = .failed(message: mapped.userMessage)
            }
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

    private func buildOutputTemplate() -> String {
        let pattern = AppSettings.shared.organizationPattern
        let basePath = outputDirectory.path
        return "\(basePath)/\(pattern.folderTemplate)%(title)s.%(ext)s"
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
            // Check if videoFormat is a custom format selector (contains yt-dlp syntax)
            if item.videoFormat.contains("[") || item.videoFormat.contains("+") {
                // Custom format selector from quality picker
                args += ["-f", item.videoFormat, "--merge-output-format", "mp4"]
            } else if let format = VideoFormat(rawValue: item.videoFormat) {
                args += format.ytDlpArguments
            } else {
                args += VideoFormat.best.ytDlpArguments
            }
        }

        // Performance optimizations - speed up extraction and download
        let fragments = AppSettings.shared.concurrentFragments
        args += [
            "--concurrent-fragments", "\(fragments)", // Download fragments in parallel
            "--buffer-size", "16K",                   // Larger buffer for faster IO
            "--http-chunk-size", "10M",               // Larger chunks
            "--retries", "3",                         // Quick retries
            "--fragment-retries", "3",
            "--no-check-certificates",                // Skip cert validation (faster)
            "--no-warnings",                          // Skip warnings
            "--no-check-formats",                     // Don't verify format URLs (faster)
            "--extractor-retries", "1",               // Fewer extractor retries
            "--socket-timeout", "10",                 // Shorter socket timeout
        ]

        // Add rate limit if configured
        args += AppSettings.shared.rateLimitArgument

        // Embed chapters (only for video downloads)
        if AppSettings.shared.embedChapters && !item.isAudioOnly {
            args += ["--embed-chapters"]
        }

        // Save thumbnail
        if AppSettings.shared.saveThumbnail {
            args += ["--write-thumbnail", "--convert-thumbnails", "jpg"]
        }

        // Download subtitles
        if AppSettings.shared.downloadSubtitles {
            args += ["--write-subs", "--write-auto-subs", "--sub-langs", "all", "--convert-subs", "srt"]
        }

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
