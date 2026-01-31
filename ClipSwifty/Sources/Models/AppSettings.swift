import Foundation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum FormatPreset: String, CaseIterable, Identifiable {
    case bestQuality = "bestQuality"
    case balanced = "balanced"
    case mobile = "mobile"
    case podcastAudio = "podcastAudio"
    case musicAudio = "musicAudio"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bestQuality: return "Beste Qualität"
        case .balanced: return "Ausgewogen"
        case .mobile: return "Mobil (720p)"
        case .podcastAudio: return "Podcast (MP3)"
        case .musicAudio: return "Musik (M4A)"
        case .custom: return "Benutzerdefiniert"
        }
    }

    var icon: String {
        switch self {
        case .bestQuality: return "sparkles"
        case .balanced: return "scale.3d"
        case .mobile: return "iphone"
        case .podcastAudio: return "mic.fill"
        case .musicAudio: return "music.note"
        case .custom: return "slider.horizontal.3"
        }
    }

    var description: String {
        switch self {
        case .bestQuality: return "4K/1080p Video, beste Qualität"
        case .balanced: return "1080p Video, gute Qualität"
        case .mobile: return "720p Video, kleine Dateien"
        case .podcastAudio: return "Nur Audio als MP3"
        case .musicAudio: return "Nur Audio als M4A (bessere Qualität)"
        case .custom: return "Eigene Einstellungen"
        }
    }

    var isAudioOnly: Bool {
        switch self {
        case .podcastAudio, .musicAudio: return true
        default: return false
        }
    }

    var videoFormat: String {
        switch self {
        case .bestQuality: return "best"
        case .balanced: return "1080p"
        case .mobile: return "720p"
        default: return "best"
        }
    }

    var audioFormat: String {
        switch self {
        case .podcastAudio: return "mp3"
        case .musicAudio: return "m4a"
        default: return "mp3"
        }
    }
}

enum OrganizationPattern: String, CaseIterable, Identifiable {
    case none = "none"
    case byChannel = "byChannel"
    case byDate = "byDate"
    case byChannelDate = "byChannelDate"
    case byPlaylist = "byPlaylist"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Keine Organisation"
        case .byChannel: return "Nach Kanal"
        case .byDate: return "Nach Datum"
        case .byChannelDate: return "Nach Kanal & Datum"
        case .byPlaylist: return "Nach Playlist"
        }
    }

    var folderTemplate: String {
        switch self {
        case .none: return ""
        case .byChannel: return "%(uploader)s/"
        case .byDate: return "%(upload_date>%Y-%m)s/"
        case .byChannelDate: return "%(uploader)s/%(upload_date>%Y-%m)s/"
        case .byPlaylist: return "%(playlist_title,uploader)s/"
        }
    }

    var previewExample: String {
        switch self {
        case .none: return "Downloads/Video.mp4"
        case .byChannel: return "Downloads/MrBeast/Video.mp4"
        case .byDate: return "Downloads/2024-01/Video.mp4"
        case .byChannelDate: return "Downloads/MrBeast/2024-01/Video.mp4"
        case .byPlaylist: return "Downloads/My Playlist/Video.mp4"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let hasSeenDisclaimer = "hasSeenDisclaimer"
        static let downloadRateLimit = "downloadRateLimit"
        static let outputDirectory = "outputDirectory"
        static let lastYtDlpUpdate = "lastYtDlpUpdate"
        static let autoUpdateYtDlp = "autoUpdateYtDlp"
        static let preferredVideoFormat = "preferredVideoFormat"
        static let preferredAudioFormat = "preferredAudioFormat"
        static let concurrentFragments = "concurrentFragments"
        static let appearanceMode = "appearanceMode"
        static let embedChapters = "embedChapters"
        static let saveThumbnail = "saveThumbnail"
        static let organizationPattern = "organizationPattern"
        static let downloadSubtitles = "downloadSubtitles"
        static let notificationsEnabled = "notificationsEnabled"
        static let clipboardMonitoring = "clipboardMonitoring"
        static let selectedPreset = "selectedPreset"
    }

    // MARK: - Properties

    @Published var hasSeenDisclaimer: Bool {
        didSet { defaults.set(hasSeenDisclaimer, forKey: Keys.hasSeenDisclaimer) }
    }

    /// Download rate limit in KB/s (0 = unlimited)
    @Published var downloadRateLimit: Int {
        didSet { defaults.set(downloadRateLimit, forKey: Keys.downloadRateLimit) }
    }

    @Published var outputDirectory: URL {
        didSet { defaults.set(outputDirectory.path, forKey: Keys.outputDirectory) }
    }

    @Published var lastYtDlpUpdate: Date? {
        didSet { defaults.set(lastYtDlpUpdate, forKey: Keys.lastYtDlpUpdate) }
    }

    @Published var autoUpdateYtDlp: Bool {
        didSet { defaults.set(autoUpdateYtDlp, forKey: Keys.autoUpdateYtDlp) }
    }

    @Published var preferredVideoFormat: String {
        didSet { defaults.set(preferredVideoFormat, forKey: Keys.preferredVideoFormat) }
    }

    @Published var preferredAudioFormat: String {
        didSet { defaults.set(preferredAudioFormat, forKey: Keys.preferredAudioFormat) }
    }

    /// Number of concurrent fragment downloads (1-8)
    @Published var concurrentFragments: Int {
        didSet { defaults.set(concurrentFragments, forKey: Keys.concurrentFragments) }
    }

    /// Appearance mode (system, light, dark)
    @Published var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    /// Embed chapters in MP4 videos
    @Published var embedChapters: Bool {
        didSet { defaults.set(embedChapters, forKey: Keys.embedChapters) }
    }

    /// Save video thumbnail as JPG
    @Published var saveThumbnail: Bool {
        didSet { defaults.set(saveThumbnail, forKey: Keys.saveThumbnail) }
    }

    /// Organization pattern for downloads
    @Published var organizationPattern: OrganizationPattern {
        didSet { defaults.set(organizationPattern.rawValue, forKey: Keys.organizationPattern) }
    }

    /// Download subtitles when available
    @Published var downloadSubtitles: Bool {
        didSet { defaults.set(downloadSubtitles, forKey: Keys.downloadSubtitles) }
    }

    /// Show notifications when downloads complete
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    /// Monitor clipboard for video URLs
    @Published var clipboardMonitoring: Bool {
        didSet { defaults.set(clipboardMonitoring, forKey: Keys.clipboardMonitoring) }
    }

    /// Selected format preset
    @Published var selectedPreset: FormatPreset {
        didSet { defaults.set(selectedPreset.rawValue, forKey: Keys.selectedPreset) }
    }

    // MARK: - Computed Properties

    var rateLimitArgument: [String] {
        guard downloadRateLimit > 0 else { return [] }
        return ["--limit-rate", "\(downloadRateLimit)K"]
    }

    var shouldCheckForUpdates: Bool {
        guard autoUpdateYtDlp else { return false }
        guard let lastUpdate = lastYtDlpUpdate else { return true }
        // Check once per day
        return Date().timeIntervalSince(lastUpdate) > 86400
    }

    // MARK: - Init

    private init() {
        self.hasSeenDisclaimer = defaults.bool(forKey: Keys.hasSeenDisclaimer)
        self.downloadRateLimit = defaults.integer(forKey: Keys.downloadRateLimit)
        self.autoUpdateYtDlp = defaults.object(forKey: Keys.autoUpdateYtDlp) as? Bool ?? true
        self.lastYtDlpUpdate = defaults.object(forKey: Keys.lastYtDlpUpdate) as? Date
        self.preferredVideoFormat = defaults.string(forKey: Keys.preferredVideoFormat) ?? "best"
        self.preferredAudioFormat = defaults.string(forKey: Keys.preferredAudioFormat) ?? "mp3"
        self.concurrentFragments = defaults.object(forKey: Keys.concurrentFragments) as? Int ?? 4

        // Appearance mode
        if let modeString = defaults.string(forKey: Keys.appearanceMode),
           let mode = AppearanceMode(rawValue: modeString) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }

        // New settings
        self.embedChapters = defaults.object(forKey: Keys.embedChapters) as? Bool ?? true
        self.saveThumbnail = defaults.object(forKey: Keys.saveThumbnail) as? Bool ?? false

        // Organization pattern
        if let patternString = defaults.string(forKey: Keys.organizationPattern),
           let pattern = OrganizationPattern(rawValue: patternString) {
            self.organizationPattern = pattern
        } else {
            self.organizationPattern = .none
        }

        // Subtitles and notifications
        self.downloadSubtitles = defaults.object(forKey: Keys.downloadSubtitles) as? Bool ?? false
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true

        // Clipboard monitoring
        self.clipboardMonitoring = defaults.object(forKey: Keys.clipboardMonitoring) as? Bool ?? false

        // Format preset
        if let presetString = defaults.string(forKey: Keys.selectedPreset),
           let preset = FormatPreset(rawValue: presetString) {
            self.selectedPreset = preset
        } else {
            self.selectedPreset = .custom
        }

        // Output directory
        if let path = defaults.string(forKey: Keys.outputDirectory),
           FileManager.default.fileExists(atPath: path) {
            self.outputDirectory = URL(fileURLWithPath: path)
        } else {
            self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
    }

    // MARK: - Methods

    func resetToDefaults() {
        hasSeenDisclaimer = false
        downloadRateLimit = 0
        autoUpdateYtDlp = true
        preferredVideoFormat = "best"
        preferredAudioFormat = "mp3"
        appearanceMode = .system
        embedChapters = true
        saveThumbnail = false
        organizationPattern = .none
        downloadSubtitles = false
        notificationsEnabled = true
        clipboardMonitoring = false
        selectedPreset = .custom
        outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
}
