import Foundation

struct VideoInfo: Codable {
    let title: String?
    let thumbnail: String?
    let duration: Double?
    let uploader: String?
    let viewCount: Int?
    let description: String?

    init(title: String? = nil, thumbnail: String? = nil, duration: Double? = nil,
         uploader: String? = nil, viewCount: Int? = nil, description: String? = nil) {
        self.title = title
        self.thumbnail = thumbnail
        self.duration = duration
        self.uploader = uploader
        self.viewCount = viewCount
        self.description = description
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    enum CodingKeys: String, CodingKey {
        case title
        case thumbnail
        case duration
        case uploader
        case viewCount = "view_count"
        case description
    }
}
