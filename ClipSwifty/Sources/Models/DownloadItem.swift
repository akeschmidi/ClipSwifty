import Foundation

enum DownloadStatus: Equatable, Codable {
    case fetchingInfo
    case pending
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
        case .downloading(let progress):
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
        case .fetchingInfo, .downloading, .converting:
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
