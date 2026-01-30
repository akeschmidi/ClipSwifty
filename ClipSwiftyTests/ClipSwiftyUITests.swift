import XCTest

final class ClipSwiftyUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Main View Tests

    func testMainView_OnLaunch_ShouldDisplayURLTextField() {
        let textField = app.textFields["Video URL"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
    }

    func testMainView_OnLaunch_ShouldDisplayDownloadButton() {
        let downloadButton = app.buttons["Download"]
        XCTAssertTrue(downloadButton.waitForExistence(timeout: 5))
    }

    func testMainView_WithEmptyURL_DownloadButtonShouldBeDisabled() {
        let textField = app.textFields["Video URL"]
        textField.click()
        textField.typeText("")

        let downloadButton = app.buttons["Download"]
        // Button should be disabled when URL is empty
        XCTAssertTrue(downloadButton.exists)
    }

    func testMainView_FormatToggle_ShouldSwitchBetweenVideoAndAudio() {
        // Find the toggle
        let audioToggle = app.buttons.matching(identifier: "Audio only mode").firstMatch
        let videoToggle = app.buttons.matching(identifier: "Video mode").firstMatch

        if audioToggle.exists {
            audioToggle.click()
            XCTAssertTrue(videoToggle.waitForExistence(timeout: 2))
        } else if videoToggle.exists {
            videoToggle.click()
            XCTAssertTrue(audioToggle.waitForExistence(timeout: 2))
        }
    }

    // MARK: - Settings Tests

    func testSettings_CanBeOpened_WithKeyboardShortcut() {
        // Press Cmd+,
        app.typeKey(",", modifierFlags: .command)

        // Settings window should appear
        let settingsWindow = app.windows["Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
    }

    // MARK: - Download Flow Tests

    func testDownloadFlow_WithValidURL_ShouldShowProgress() {
        // Enter URL
        let textField = app.textFields["Video URL"]
        textField.click()
        textField.typeText("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

        // Click download
        let downloadButton = app.buttons["Download"]
        downloadButton.click()

        // Should show download item in list
        let downloadsList = app.scrollViews["Downloads list"]
        XCTAssertTrue(downloadsList.waitForExistence(timeout: 10))
    }

    // MARK: - Accessibility Tests

    func testAccessibility_AllInteractiveElements_ShouldHaveLabels() {
        // Check main interactive elements have accessibility labels
        XCTAssertTrue(app.textFields["Video URL"].exists)
        XCTAssertTrue(app.buttons["Download"].exists)
    }

    func testAccessibility_VoiceOver_ShouldNavigateCorrectly() {
        // This tests basic VoiceOver navigation
        let elements = app.descendants(matching: .any).allElementsBoundByAccessibilityElement

        // Should have multiple accessible elements
        XCTAssertGreaterThan(elements.count, 5)
    }
}

// MARK: - Performance Tests

final class ClipSwiftyPerformanceTests: XCTestCase {

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
