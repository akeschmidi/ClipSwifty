import Foundation

enum VideoFormat: String, CaseIterable, Identifiable {
    case best = "best"
    case quality4k = "4k"
    case quality1440p = "1440p"
    case quality1080p = "1080p"
    case quality720p = "720p"
    case quality480p = "480p"
    case quality360p = "360p"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .best: return "Beste"
        case .quality4k: return "4K (2160p)"
        case .quality1440p: return "1440p"
        case .quality1080p: return "1080p"
        case .quality720p: return "720p"
        case .quality480p: return "480p"
        case .quality360p: return "360p"
        }
    }

    var ytDlpArguments: [String] {
        switch self {
        case .best:
            return ["-f", "bestvideo+bestaudio/best", "--merge-output-format", "mp4"]
        case .quality4k:
            return ["-f", "bestvideo[height<=2160]+bestaudio/best[height<=2160]", "--merge-output-format", "mp4"]
        case .quality1440p:
            return ["-f", "bestvideo[height<=1440]+bestaudio/best[height<=1440]", "--merge-output-format", "mp4"]
        case .quality1080p:
            return ["-f", "bestvideo[height<=1080]+bestaudio/best[height<=1080]", "--merge-output-format", "mp4"]
        case .quality720p:
            return ["-f", "bestvideo[height<=720]+bestaudio/best[height<=720]", "--merge-output-format", "mp4"]
        case .quality480p:
            return ["-f", "bestvideo[height<=480]+bestaudio/best[height<=480]", "--merge-output-format", "mp4"]
        case .quality360p:
            return ["-f", "bestvideo[height<=360]+bestaudio/best[height<=360]", "--merge-output-format", "mp4"]
        }
    }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3 = "mp3"
    case m4a = "m4a"
    case wav = "wav"
    case flac = "flac"

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var ytDlpArguments: [String] {
        ["-x", "--audio-format", rawValue]
    }
}
