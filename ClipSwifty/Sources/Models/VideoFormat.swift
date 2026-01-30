import Foundation

enum VideoFormat: String, CaseIterable, Identifiable {
    case best = "best"
    case mp4 = "mp4"
    case webm = "webm"
    case mkv = "mkv"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .best: return "Best Quality"
        case .mp4: return "MP4"
        case .webm: return "WebM"
        case .mkv: return "MKV"
        }
    }

    var ytDlpArguments: [String] {
        switch self {
        case .best:
            return ["-f", "best"]
        case .mp4:
            return ["-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best", "--merge-output-format", "mp4"]
        case .webm:
            return ["-f", "bestvideo[ext=webm]+bestaudio[ext=webm]/best[ext=webm]/best", "--merge-output-format", "webm"]
        case .mkv:
            return ["-f", "bestvideo+bestaudio/best", "--merge-output-format", "mkv"]
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
