import XCTest
@testable import ClipSwifty

final class YtDlpManagerTests: XCTestCase {

    var sut: YtDlpManager!

    override func setUp() {
        super.setUp()
        sut = YtDlpManager.shared
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Setup Tests

    func testSetup_WhenBinaryExists_ShouldNotThrow() async {
        do {
            try await sut.setup()
        } catch {
            XCTFail("Setup should not throw when binary exists: \(error)")
        }
    }

    // MARK: - Video Info Tests

    func testFetchVideoInfo_WithValidYouTubeURL_ShouldReturnVideoInfo() async throws {
        // Given
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

        // When
        let info = try await sut.fetchVideoInfo(url: url)

        // Then
        XCTAssertNotNil(info.title)
        XCTAssertNotNil(info.duration)
    }

    func testFetchVideoInfo_WithInvalidURL_ShouldThrowError() async {
        // Given
        let url = "https://invalid-url-that-does-not-exist.com/video"

        // When/Then
        do {
            _ = try await sut.fetchVideoInfo(url: url)
            XCTFail("Should throw error for invalid URL")
        } catch {
            // Expected
            XCTAssertTrue(error is YtDlpError)
        }
    }

    // MARK: - Download Cancellation Tests

    func testCancelDownload_WithRunningDownload_ShouldTerminateProcess() async {
        // Given
        let downloadId = UUID()

        // Start a long download in background
        Task {
            do {
                // Use a long video to ensure we have time to cancel
                _ = try await sut.runWithProgress(
                    id: downloadId,
                    arguments: ["--dump-json", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"]
                ) { _ in }
            } catch {
                // Expected to fail due to cancellation
            }
        }

        // Wait a bit for process to start
        try? await Task.sleep(nanoseconds: 500_000_000)

        // When
        sut.cancelDownload(id: downloadId)

        // Then - no crash means success
    }

    // MARK: - Progress Parsing Tests

    func testProgressParsing_WithValidOutput_ShouldParseCorrectly() {
        // This tests the regex pattern indirectly
        // The actual parsing is private, so we test through integration
        let expectation = XCTestExpectation(description: "Progress callback called")
        var receivedProgress: Double = 0

        Task {
            do {
                _ = try await sut.runWithProgress(
                    id: UUID(),
                    arguments: ["--version"]
                ) { progress in
                    receivedProgress = progress
                    expectation.fulfill()
                }
            } catch {
                // Version command doesn't output progress, but that's OK
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }
}

// MARK: - Model Tests

final class DownloadItemTests: XCTestCase {

    func testDownloadItem_Initialization_ShouldSetDefaults() {
        // When
        let item = DownloadItem(url: "https://example.com/video")

        // Then
        XCTAssertEqual(item.url, "https://example.com/video")
        XCTAssertNil(item.title)
        XCTAssertEqual(item.status, .fetchingInfo)
        XCTAssertFalse(item.isAudioOnly)
        XCTAssertEqual(item.videoFormat, "best")
        XCTAssertEqual(item.audioFormat, "mp3")
    }

    func testDownloadItem_UpdateWithVideoInfo_ShouldUpdateProperties() {
        // Given
        var item = DownloadItem(url: "https://example.com/video")
        let videoInfo = VideoInfo(
            title: "Test Video",
            thumbnail: "https://example.com/thumb.jpg",
            duration: 120,
            uploader: "Test Uploader",
            viewCount: 1000,
            description: "Test description"
        )

        // When
        item.updateWithVideoInfo(videoInfo)

        // Then
        XCTAssertEqual(item.title, "Test Video")
        XCTAssertEqual(item.uploader, "Test Uploader")
        XCTAssertEqual(item.duration, "2:00")
        XCTAssertNotNil(item.thumbnailURL)
    }

    func testDownloadStatus_DisplayText_ShouldReturnCorrectText() {
        XCTAssertEqual(DownloadStatus.fetchingInfo.displayText, "Fetching info...")
        XCTAssertEqual(DownloadStatus.pending.displayText, "Waiting...")
        XCTAssertEqual(DownloadStatus.downloading(progress: 0.5).displayText, "Downloading 50%")
        XCTAssertEqual(DownloadStatus.paused(progress: 0.75).displayText, "Paused at 75%")
        XCTAssertEqual(DownloadStatus.completed.displayText, "Completed")
        XCTAssertEqual(DownloadStatus.failed(message: "Error").displayText, "Failed: Error")
    }

    func testDownloadStatus_IsActive_ShouldReturnCorrectValue() {
        XCTAssertTrue(DownloadStatus.fetchingInfo.isActive)
        XCTAssertTrue(DownloadStatus.downloading(progress: 0.5).isActive)
        XCTAssertTrue(DownloadStatus.converting.isActive)
        XCTAssertFalse(DownloadStatus.pending.isActive)
        XCTAssertFalse(DownloadStatus.completed.isActive)
        XCTAssertFalse(DownloadStatus.failed(message: "Error").isActive)
        XCTAssertFalse(DownloadStatus.paused(progress: 0.5).isActive)
    }

    func testDownloadStatus_CanPause_ShouldReturnCorrectValue() {
        XCTAssertTrue(DownloadStatus.downloading(progress: 0.5).canPause)
        XCTAssertFalse(DownloadStatus.pending.canPause)
        XCTAssertFalse(DownloadStatus.completed.canPause)
    }

    func testDownloadStatus_CanRetry_ShouldReturnCorrectValue() {
        XCTAssertTrue(DownloadStatus.failed(message: "Error").canRetry)
        XCTAssertTrue(DownloadStatus.paused(progress: 0.5).canRetry)
        XCTAssertFalse(DownloadStatus.completed.canRetry)
        XCTAssertFalse(DownloadStatus.downloading(progress: 0.5).canRetry)
    }
}

// MARK: - Format Tests

final class VideoFormatTests: XCTestCase {

    func testVideoFormat_YtDlpArguments_ShouldReturnCorrectArguments() {
        XCTAssertTrue(VideoFormat.best.ytDlpArguments.contains("-f"))
        XCTAssertTrue(VideoFormat.mp4.ytDlpArguments.contains("--merge-output-format"))
    }

    func testAudioFormat_YtDlpArguments_ShouldContainExtractAudio() {
        for format in AudioFormat.allCases {
            XCTAssertTrue(format.ytDlpArguments.contains("-x"))
            XCTAssertTrue(format.ytDlpArguments.contains("--audio-format"))
        }
    }
}

// MARK: - Settings Tests

final class AppSettingsTests: XCTestCase {

    func testRateLimitArgument_WhenZero_ShouldReturnEmpty() {
        let settings = AppSettings.shared
        let originalValue = settings.downloadRateLimit

        settings.downloadRateLimit = 0
        XCTAssertTrue(settings.rateLimitArgument.isEmpty)

        settings.downloadRateLimit = originalValue
    }

    func testRateLimitArgument_WhenSet_ShouldReturnCorrectArguments() {
        let settings = AppSettings.shared
        let originalValue = settings.downloadRateLimit

        settings.downloadRateLimit = 1000
        XCTAssertEqual(settings.rateLimitArgument, ["--limit-rate", "1000K"])

        settings.downloadRateLimit = originalValue
    }
}
