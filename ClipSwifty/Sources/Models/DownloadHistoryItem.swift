import Foundation

struct DownloadHistoryItem: Identifiable, Codable {
    let id: UUID
    let url: String
    let title: String?
    let completedAt: Date
    let outputPath: String?
    let duration: String?
    let uploader: String?
    let fileSize: Int?

    init(id: UUID = UUID(), url: String, title: String?, completedAt: Date = Date(),
         outputPath: String?, duration: String?, uploader: String?, fileSize: Int?) {
        self.id = id
        self.url = url
        self.title = title
        self.completedAt = completedAt
        self.outputPath = outputPath
        self.duration = duration
        self.uploader = uploader
        self.fileSize = fileSize
    }

    init(from item: DownloadItem) {
        self.id = UUID()
        self.url = item.url
        self.title = item.title
        self.completedAt = Date()
        self.outputPath = item.outputPath?.path
        self.duration = item.duration
        self.uploader = item.uploader
        self.fileSize = item.estimatedFileSize
    }
}
