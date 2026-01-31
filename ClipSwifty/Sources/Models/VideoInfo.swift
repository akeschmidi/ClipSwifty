import Foundation

struct FormatInfo: Codable, Identifiable, Hashable {
    let formatId: String
    let ext: String?
    let height: Int?
    let width: Int?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let filesize: Int?
    let tbr: Double?  // Total bitrate

    var id: String { formatId }

    enum CodingKeys: String, CodingKey {
        case formatId = "format_id"
        case ext
        case height
        case width
        case fps
        case vcodec
        case acodec
        case filesize
        case tbr
    }

    var qualityLabel: String {
        guard let h = height, h > 0 else { return "Audio" }
        if h >= 2160 { return "4K" }
        if h >= 1440 { return "1440p" }
        if h >= 1080 { return "1080p" }
        if h >= 720 { return "720p" }
        if h >= 480 { return "480p" }
        if h >= 360 { return "360p" }
        return "\(h)p"
    }

    var isVideoOnly: Bool {
        acodec == "none" || acodec == nil
    }

    var isAudioOnly: Bool {
        (vcodec == "none" || vcodec == nil) && height == nil
    }
}

struct AvailableQuality: Identifiable, Hashable {
    let height: Int
    let label: String
    let formatSelector: String

    var id: Int { height }

    static func fromFormats(_ formats: [FormatInfo]) -> [AvailableQuality] {
        // Get unique heights that have video
        var heights = Set<Int>()
        for format in formats {
            if let h = format.height, h > 0, format.vcodec != "none" {
                heights.insert(h)
            }
        }

        // Create quality options sorted by height descending
        var qualities: [AvailableQuality] = []

        let sortedHeights = heights.sorted(by: >)
        for h in sortedHeights {
            let label: String
            if h >= 2160 { label = "4K" }
            else if h >= 1440 { label = "1440p" }
            else if h >= 1080 { label = "1080p" }
            else if h >= 720 { label = "720p" }
            else if h >= 480 { label = "480p" }
            else if h >= 360 { label = "360p" }
            else { label = "\(h)p" }

            // Skip duplicates (e.g., multiple 1080p entries)
            if !qualities.contains(where: { $0.label == label }) {
                let selector = "bestvideo[height<=\(h)]+bestaudio/best[height<=\(h)]"
                qualities.append(AvailableQuality(height: h, label: label, formatSelector: selector))
            }
        }

        return qualities
    }
}

struct VideoInfo: Codable {
    let title: String?
    let thumbnail: String?
    let duration: Double?
    let uploader: String?
    let viewCount: Int?
    let description: String?
    let formats: [FormatInfo]?

    init(title: String? = nil, thumbnail: String? = nil, duration: Double? = nil,
         uploader: String? = nil, viewCount: Int? = nil, description: String? = nil,
         formats: [FormatInfo]? = nil) {
        self.title = title
        self.thumbnail = thumbnail
        self.duration = duration
        self.uploader = uploader
        self.viewCount = viewCount
        self.description = description
        self.formats = formats
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var availableQualities: [AvailableQuality] {
        guard let formats = formats else { return [] }
        return AvailableQuality.fromFormats(formats)
    }

    enum CodingKeys: String, CodingKey {
        case title
        case thumbnail
        case duration
        case uploader
        case viewCount = "view_count"
        case description
        case formats
    }
}
