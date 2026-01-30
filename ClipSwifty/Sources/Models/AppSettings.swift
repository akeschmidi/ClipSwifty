import Foundation

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
        outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
}
