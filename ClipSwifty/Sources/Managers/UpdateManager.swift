import Foundation
import os.log

private let logger = Logger(subsystem: "com.clipswifty", category: "UpdateManager")

struct GitHubRelease: Codable {
    let tagName: String
    let publishedAt: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case publishedAt = "published_at"
        case name
    }
}

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var isUpdating = false
    @Published var updateMessage = ""
    @Published var currentVersion: String?
    @Published var latestVersion: String?
    @Published var updateAvailable = false

    private let ytDlpManager = YtDlpManager.shared
    private let settings = AppSettings.shared
    private var lastBackgroundCheck: Date?

    private init() {
        // Load cached version from UserDefaults - don't call yt-dlp on startup!
        currentVersion = UserDefaults.standard.string(forKey: "cachedYtDlpVersion")
    }

    /// Silent background check for updates - no UI shown unless update available
    func checkForUpdatesInBackground() {
        // Skip if checked recently (within last 6 hours)
        if let lastCheck = lastBackgroundCheck,
           Date().timeIntervalSince(lastCheck) < 21600 {
            logger.info("Skipping background check - checked recently")
            return
        }

        Task {
            await performBackgroundCheck()
        }
    }

    private func performBackgroundCheck() async {
        logger.info("Performing background update check...")

        do {
            // Fetch latest release from GitHub API only - NO yt-dlp call!
            guard let latest = try await fetchLatestRelease() else {
                logger.warning("Could not fetch latest release")
                return
            }

            latestVersion = latest.tagName
            lastBackgroundCheck = Date()

            // Use cached version or assume we have the bundled version
            let current = currentVersion ?? "2026.01.29"  // Bundled version

            // Compare versions
            if isNewerVersion(latest.tagName, than: current) {
                logger.info("Update available: \(current) -> \(latest.tagName)")
                updateAvailable = true
            } else {
                logger.info("yt-dlp is up to date: \(current)")
                updateAvailable = false
            }

        } catch {
            logger.error("Background check failed: \(error.localizedDescription)")
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease? {
        let url = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func isNewerVersion(_ latest: String, than current: String) -> Bool {
        // yt-dlp versions are like "2026.01.29" or "2024.12.23"
        // Simple string comparison works for this format
        let latestClean = latest.replacingOccurrences(of: ".", with: "")
        let currentClean = current.replacingOccurrences(of: ".", with: "")

        // Convert to integers for comparison
        if let latestInt = Int(latestClean), let currentInt = Int(currentClean) {
            return latestInt > currentInt
        }

        // Fallback to string comparison
        return latest > current
    }

    /// Perform the actual update - called when user clicks update
    func performUpdate() async {
        guard updateAvailable || latestVersion != nil else { return }

        isUpdating = true
        updateMessage = "Updating yt-dlp..."
        logger.info("Starting yt-dlp update")

        do {
            let oldVersion = currentVersion

            // Try to update
            let success = try await ytDlpManager.update()

            if success {
                let newVersion = await ytDlpManager.getVersion()
                currentVersion = newVersion
                // Cache the version
                if let version = newVersion {
                    UserDefaults.standard.set(version, forKey: "cachedYtDlpVersion")
                }

                if oldVersion != newVersion {
                    logger.info("yt-dlp updated: \(oldVersion ?? "unknown") -> \(newVersion ?? "unknown")")
                    updateMessage = "Updated to \(newVersion ?? "latest")"
                } else {
                    logger.info("yt-dlp is already up to date")
                    updateMessage = "Already up to date"
                }

                settings.lastYtDlpUpdate = Date()
                updateAvailable = false
            } else {
                logger.warning("yt-dlp update returned false, trying force update")
                updateMessage = "Trying alternative update..."

                try await ytDlpManager.forceUpdate()
                let newVersion = await ytDlpManager.getVersion()
                currentVersion = newVersion
                // Cache the version
                if let version = newVersion {
                    UserDefaults.standard.set(version, forKey: "cachedYtDlpVersion")
                }
                settings.lastYtDlpUpdate = Date()
                updateMessage = "Update complete"
                updateAvailable = false
            }

        } catch {
            logger.error("yt-dlp update failed: \(error.localizedDescription)")
            updateMessage = "Update failed"
        }

        // Hide message after delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isUpdating = false
        updateMessage = ""
    }

    /// Legacy method for compatibility - now does background check
    func checkAndUpdate(force: Bool = false) {
        if force {
            // User explicitly requested update
            Task {
                await performUpdate()
            }
        } else {
            // Just do background check
            checkForUpdatesInBackground()
        }
    }

    /// Force a complete reinstall of yt-dlp
    func forceReinstall() async {
        isUpdating = true
        updateMessage = "Reinstalling yt-dlp..."

        do {
            try await ytDlpManager.forceUpdate()
            currentVersion = await ytDlpManager.getVersion()
            settings.lastYtDlpUpdate = Date()
            updateMessage = "Reinstall complete"
            updateAvailable = false
        } catch {
            logger.error("yt-dlp reinstall failed: \(error.localizedDescription)")
            updateMessage = "Reinstall failed"
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isUpdating = false
        updateMessage = ""
    }
}
