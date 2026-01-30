import Foundation

enum AppConstants {
    static let appName = "ClipSwifty"
    static let appSupportFolderName = "ClipSwifty"
}

enum Resources {
    static let ytDlpName = "yt-dlp_macos"
    static let ffmpegName = "ffmpeg"

    static var appSupportURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(AppConstants.appSupportFolderName)
    }

    static var ytDlpURL: URL? {
        appSupportURL?.appendingPathComponent(ytDlpName)
    }

    static var ffmpegURL: URL? {
        appSupportURL?.appendingPathComponent(ffmpegName)
    }

    static var bundledYtDlpURL: URL? {
        // Try bundle Resources first
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent(ytDlpName),
           FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }
        // Fallback: check Application Support
        if let appSupportPath = ytDlpURL,
           FileManager.default.fileExists(atPath: appSupportPath.path) {
            return appSupportPath
        }
        return nil
    }

    static var bundledFfmpegURL: URL? {
        // Try bundle Resources first
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent(ffmpegName),
           FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }
        // Fallback: check Application Support
        if let appSupportPath = ffmpegURL,
           FileManager.default.fileExists(atPath: appSupportPath.path) {
            return appSupportPath
        }
        return nil
    }
}
