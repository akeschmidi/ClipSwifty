import Foundation

enum DownloadStatus: Equatable, Codable {
    case fetchingInfo
    case pending
    case preparing(status: String)  // New: shows what yt-dlp is doing
    case downloading(progress: Double)
    case paused(progress: Double)
    case converting
    case completed
    case failed(message: String)

    var displayText: String {
        switch self {
        case .fetchingInfo:
            return "Fetching info..."
        case .pending:
            return "Waiting..."
        case .preparing(let status):
            return status
        case .downloading(let progress):
            if progress < 0.01 {
                return "Starting download..."
            }
            return "Downloading \(Int(progress * 100))%"
        case .paused(let progress):
            return "Paused at \(Int(progress * 100))%"
        case .converting:
            return "Converting..."
        case .completed:
            return "Completed"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    var isActive: Bool {
        switch self {
        case .fetchingInfo, .preparing, .downloading, .converting:
            return true
        default:
            return false
        }
    }

    var canRetry: Bool {
        switch self {
        case .failed, .paused:
            return true
        default:
            return false
        }
    }

    var canPause: Bool {
        switch self {
        case .downloading:
            return true
        default:
            return false
        }
    }
}

struct DownloadItem: Identifiable, Equatable, Codable {
    let id: UUID
    let url: String
    var title: String?
    var thumbnailURL: URL?
    var duration: String?
    var uploader: String?
    var status: DownloadStatus
    var outputPath: URL?
    let createdAt: Date

    // Download progress info
    var downloadSpeed: String?  // e.g. "2.5 MiB/s"
    var eta: String?            // e.g. "3:42"

    // Queue management
    var queuePosition: Int = 0

    // Format settings for retry/resume
    var isAudioOnly: Bool
    var videoFormat: String
    var audioFormat: String
    var isPlaylist: Bool
    var playlistIndex: Int?
    var playlistTitle: String?

    init(
        id: UUID = UUID(),
        url: String,
        title: String? = nil,
        thumbnailURL: URL? = nil,
        duration: String? = nil,
        uploader: String? = nil,
        status: DownloadStatus = .fetchingInfo,
        outputPath: URL? = nil,
        createdAt: Date = Date(),
        downloadSpeed: String? = nil,
        eta: String? = nil,
        isAudioOnly: Bool = false,
        videoFormat: String = "best",
        audioFormat: String = "mp3",
        isPlaylist: Bool = false,
        playlistIndex: Int? = nil,
        playlistTitle: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.uploader = uploader
        self.status = status
        self.outputPath = outputPath
        self.createdAt = createdAt
        self.downloadSpeed = downloadSpeed
        self.eta = eta
        self.isAudioOnly = isAudioOnly
        self.videoFormat = videoFormat
        self.audioFormat = audioFormat
        self.isPlaylist = isPlaylist
        self.playlistIndex = playlistIndex
        self.playlistTitle = playlistTitle
    }

    mutating func updateWithVideoInfo(_ info: VideoInfo) {
        self.title = info.title
        self.thumbnailURL = info.thumbnail.flatMap { URL(string: $0) }
        self.duration = info.formattedDuration
        self.uploader = info.uploader
    }
}
