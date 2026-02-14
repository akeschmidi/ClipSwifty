import Foundation
import os.log

private let logger = Logger(subsystem: "com.clipswifty", category: "YtDlpManager")

enum YtDlpError: LocalizedError {
    case binaryNotFound
    case copyFailed(Error)
    case permissionsFailed(Error)
    case executionFailed(String)
    case appSupportUnavailable
    case invalidVideoInfo
    case cancelled

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "yt-dlp binary not found in app bundle"
        case .copyFailed(let error):
            return "Failed to copy yt-dlp: \(error.localizedDescription)"
        case .permissionsFailed(let error):
            return "Failed to set permissions: \(error.localizedDescription)"
        case .executionFailed(let message):
            return "yt-dlp execution failed: \(message)"
        case .appSupportUnavailable:
            return "Application Support directory unavailable"
        case .invalidVideoInfo:
            return "Could not parse video information"
        case .cancelled:
            return "Download was cancelled"
        }
    }
}

protocol YtDlpManagerProtocol {
    func setup() async throws
    func run(arguments: [String]) async throws -> ProcessOutput
    func runWithProgress(id: UUID, arguments: [String], onProgress: @escaping (Double) -> Void) async throws -> ProcessOutput
    func fetchVideoInfo(url: String) async throws -> VideoInfo
    func fetchVideoInfoFast(url: String) async throws -> VideoInfo
    func update() async throws -> Bool
    func cancelDownload(id: UUID)
}

struct ProcessOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let wasCancelled: Bool

    init(stdout: String, stderr: String, exitCode: Int32, wasCancelled: Bool = false) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.wasCancelled = wasCancelled
    }
}

/// Thread-safe collector for process output, usable from @Sendable closures.
private final class ProcessOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _stdout = Data()
    private var _stderr = Data()

    func appendStdout(_ data: Data) { lock.lock(); _stdout.append(data); lock.unlock() }
    func appendStderr(_ data: Data) { lock.lock(); _stderr.append(data); lock.unlock() }
    var stdout: Data { lock.lock(); defer { lock.unlock() }; return _stdout }
    var stderr: Data { lock.lock(); defer { lock.unlock() }; return _stderr }
}

/// Thread-safe collector for string-based process output with progress parsing.
private final class StreamOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _stdout = ""
    private var _stderr = ""
    private var _wasCancelled = false
    let maxBufferSize = 512 * 1024  // 512KB cap per buffer

    func appendStdout(_ text: String) { lock.lock(); if _stdout.count < maxBufferSize { _stdout += text }; lock.unlock() }
    func appendStderr(_ text: String) { lock.lock(); if _stderr.count < maxBufferSize { _stderr += text }; lock.unlock() }

    var stdout: String { lock.lock(); defer { lock.unlock() }; return _stdout }
    var stderr: String { lock.lock(); defer { lock.unlock() }; return _stderr }

    var wasCancelled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _wasCancelled }
        set { lock.lock(); _wasCancelled = newValue; lock.unlock() }
    }
}

final class YtDlpManager: YtDlpManagerProtocol {

    static let shared = YtDlpManager()

    private let fileManager = FileManager.default
    // Safe regex init - pattern is a compile-time constant, so this will never fail,
    // but we avoid try! on principle to prevent crashes from being possible.
    private let progressRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        return (try? NSRegularExpression(
            pattern: #"\[download\]\s+(\d+(?:\.\d+)?)%"#,
            options: []
        )) ?? NSRegularExpression()
    }()

    // Track running processes for cancellation
    private var runningProcesses: [UUID: Process] = [:]
    private let processLock = NSLock()
    private let maxConcurrentProcesses = 8

    /// Async-safe process count check (avoids calling NSLock from async context)
    private nonisolated func runningProcessCount() -> Int {
        processLock.lock()
        defer { processLock.unlock() }
        return runningProcesses.count
    }

    // Cache setup check - don't verify binary every time
    private var isSetupComplete = false

    private init() {}

    func setup() async throws {
        // Skip if already verified
        if isSetupComplete { return }

        guard let ytDlpURL = Resources.bundledYtDlpURL,
              fileManager.fileExists(atPath: ytDlpURL.path) else {
            logger.error("yt-dlp binary not found")
            throw YtDlpError.binaryNotFound
        }
        isSetupComplete = true
        logger.info("yt-dlp setup complete")
    }

    func fetchVideoInfo(url: String) async throws -> VideoInfo {
        logger.info("Fetching video info for: \(url)")
        // Optimized: skip download, no format extraction, just get metadata
        let output = try await run(arguments: [
            "--dump-json",
            "--no-playlist",
            "--no-warnings",
            "--skip-download",
            "--no-check-certificates",
            "--socket-timeout", "10",
            url
        ])

        guard output.exitCode == 0 else {
            logger.error("yt-dlp failed: \(output.stderr)")
            throw YtDlpError.executionFailed(output.stderr.isEmpty ? "Unknown error (exit code \(output.exitCode))" : output.stderr)
        }

        guard let data = output.stdout.data(using: .utf8) else {
            throw YtDlpError.invalidVideoInfo
        }

        do {
            let decoder = JSONDecoder()
            let info = try decoder.decode(VideoInfo.self, from: data)
            logger.info("Successfully fetched info: \(info.title ?? "unknown")")
            return info
        } catch {
            logger.error("JSON decode error: \(error.localizedDescription)")
            throw YtDlpError.invalidVideoInfo
        }
    }

    /// Fast info fetch - only gets title and thumbnail, much faster
    func fetchVideoInfoFast(url: String) async throws -> VideoInfo {
        let startTime = Date()
        logger.info("⏱️ [START] fetchVideoInfoFast for: \(url)")

        // Use --print to get only what we need - much faster
        let output = try await run(arguments: [
            "--no-playlist",
            "--no-warnings",
            "--no-check-certificates",
            "--socket-timeout", "10",
            "--skip-download",
            "--print", "%(title)s|||%(thumbnail)s|||%(duration)s|||%(uploader)s",
            url
        ])

        logger.info("⏱️ [TIMING] yt-dlp --print took \(Int(Date().timeIntervalSince(startTime) * 1000))ms")

        guard output.exitCode == 0 else {
            logger.error("yt-dlp failed: \(output.stderr)")
            throw YtDlpError.executionFailed(output.stderr.isEmpty ? "Unknown error (exit code \(output.exitCode))" : output.stderr)
        }

        let parts = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|||")
        guard parts.count >= 4 else {
            throw YtDlpError.invalidVideoInfo
        }

        let title = parts[0].isEmpty || parts[0] == "NA" ? nil : parts[0]
        let thumbnail = parts[1].isEmpty || parts[1] == "NA" ? nil : parts[1]
        let durationStr = parts[2]
        let uploader = parts[3].isEmpty || parts[3] == "NA" ? nil : parts[3]

        // Parse duration
        var duration: Double?
        if let d = Double(durationStr) {
            duration = d
        }

        logger.info("Fast fetched info: \(title ?? "unknown")")
        return VideoInfo(
            title: title,
            thumbnail: thumbnail,
            duration: duration,
            uploader: uploader,
            viewCount: nil,
            description: nil
        )
    }

    func run(arguments: [String]) async throws -> ProcessOutput {
        let startTime = Date()
        logger.info("⏱️ [START] yt-dlp run: \(arguments.first ?? "?")")

        guard let ytDlpURL = Resources.bundledYtDlpURL,
              fileManager.fileExists(atPath: ytDlpURL.path) else {
            throw YtDlpError.binaryNotFound
        }

        let result = try await executeProcess(at: ytDlpURL, arguments: arguments)
        logger.info("⏱️ [DONE] yt-dlp run took \(Int(Date().timeIntervalSince(startTime) * 1000))ms (exit: \(result.exitCode))")
        return result
    }

    func runWithProgress(id: UUID, arguments: [String], onProgress: @escaping (Double) -> Void) async throws -> ProcessOutput {
        return try await runWithProgressAndOutput(id: id, arguments: arguments) { progress, _ in
            onProgress(progress)
        }
    }

    func runWithProgressAndOutput(id: UUID, arguments: [String], onProgress: @escaping (Double, String?) -> Void) async throws -> ProcessOutput {
        let startTime = Date()
        logger.info("⏱️ [START] yt-dlp runWithProgress: \(id)")

        guard let ytDlpURL = Resources.bundledYtDlpURL,
              fileManager.fileExists(atPath: ytDlpURL.path) else {
            throw YtDlpError.binaryNotFound
        }

        let result = try await executeProcessWithProgressAndOutput(id: id, at: ytDlpURL, arguments: arguments, onProgress: onProgress)
        logger.info("⏱️ [DONE] yt-dlp runWithProgress took \(Int(Date().timeIntervalSince(startTime) * 1000))ms (exit: \(result.exitCode))")
        return result
    }

    // Legacy method without ID for backwards compatibility
    func runWithProgress(arguments: [String], onProgress: @escaping (Double) -> Void) async throws -> ProcessOutput {
        return try await runWithProgress(id: UUID(), arguments: arguments, onProgress: onProgress)
    }

    func cancelDownload(id: UUID) {
        processLock.lock()
        defer { processLock.unlock() }

        if let process = runningProcesses[id], process.isRunning {
            logger.info("Cancelling download: \(id)")
            process.terminate()
            runningProcesses.removeValue(forKey: id)
        }
    }

    /// Terminate all running yt-dlp processes (called on app quit)
    func cancelAllDownloads() {
        processLock.lock()
        let processes = runningProcesses
        runningProcesses.removeAll()
        processLock.unlock()

        for (id, process) in processes where process.isRunning {
            logger.info("Terminating process on shutdown: \(id)")
            process.terminate()
        }
    }

    func update() async throws -> Bool {
        logger.info("Checking for yt-dlp updates")

        // First try --update flag
        let output = try await run(arguments: ["--update"])

        if output.exitCode == 0 {
            logger.info("yt-dlp update successful")
            return true
        }

        // If --update fails, try --update-to latest
        logger.info("Trying alternative update method")
        let altOutput = try await run(arguments: ["--update-to", "latest"])

        if altOutput.exitCode == 0 {
            logger.info("yt-dlp update (alternative) successful")
            return true
        }

        logger.error("yt-dlp update failed: \(output.stderr)")
        return false
    }

    func getVersion() async -> String? {
        do {
            let output = try await run(arguments: ["--version"])
            if output.exitCode == 0 {
                return output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            logger.error("Failed to get yt-dlp version: \(error.localizedDescription)")
        }
        return nil
    }

    func forceUpdate() async throws {
        logger.info("Force updating yt-dlp...")

        // Copy bundled binary to Application Support and make it updatable
        guard let bundledURL = Resources.bundledYtDlpURL,
              let appSupportURL = Resources.ytDlpURL else {
            throw YtDlpError.binaryNotFound
        }

        let appSupportDir = appSupportURL.deletingLastPathComponent()

        // Create Application Support directory if needed
        try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        // Copy binary to Application Support
        if fileManager.fileExists(atPath: appSupportURL.path) {
            try fileManager.removeItem(at: appSupportURL)
        }
        try fileManager.copyItem(at: bundledURL, to: appSupportURL)

        // Set executable permissions
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: appSupportURL.path)

        logger.info("yt-dlp copied to Application Support, attempting update...")

        // Now try to update from Application Support location
        let output = try await executeProcess(
            at: appSupportURL,
            arguments: ["--update"]
        )

        if output.exitCode != 0 {
            logger.warning("Update from Application Support failed, using bundled version")
        }
    }

    // MARK: - Private Methods

    private func executeProcess(at url: URL, arguments: [String]) async throws -> ProcessOutput {
        // Wait until we're below the process limit
        while runningProcessCount() >= maxConcurrentProcesses {
            try await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { throw CancellationError() }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = url
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            setupEnvironment(for: process)

            let collector = ProcessOutputCollector()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { collector.appendStdout(data) }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { collector.appendStderr(data) }
            }

            process.terminationHandler = { _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                collector.appendStdout(remainingStdout)
                collector.appendStderr(remainingStderr)

                let output = ProcessOutput(
                    stdout: String(data: collector.stdout, encoding: .utf8) ?? "",
                    stderr: String(data: collector.stderr, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )

                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: YtDlpError.executionFailed(error.localizedDescription))
            }
        }
    }

    private func executeProcessWithProgress(
        id: UUID,
        at url: URL,
        arguments: [String],
        onProgress: @escaping (Double) -> Void
    ) async throws -> ProcessOutput {
        return try await executeProcessWithProgressAndOutput(id: id, at: url, arguments: arguments) { progress, _ in
            onProgress(progress)
        }
    }

    private func executeProcessWithProgressAndOutput(
        id: UUID,
        at url: URL,
        arguments: [String],
        onProgress: @escaping (Double, String?) -> Void
    ) async throws -> ProcessOutput {
        // Wait until we're below the process limit
        while runningProcessCount() >= maxConcurrentProcesses {
            try await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { throw CancellationError() }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = url
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            setupEnvironment(for: process)

            // Track this process
            processLock.lock()
            runningProcesses[id] = process
            processLock.unlock()

            let collector = StreamOutputCollector()

            stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                collector.appendStdout(text)
                self?.parseProgressAndOutput(from: text, callback: onProgress)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                collector.appendStderr(text)
                self?.parseProgressAndOutput(from: text, callback: onProgress)
            }

            process.terminationHandler = { [weak self] proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                // Check if was cancelled (SIGTERM = 15)
                collector.wasCancelled = proc.terminationStatus == 15 || proc.terminationReason == .uncaughtSignal

                // Remove from tracking
                self?.processLock.lock()
                self?.runningProcesses.removeValue(forKey: id)
                self?.processLock.unlock()

                let output = ProcessOutput(
                    stdout: collector.stdout,
                    stderr: collector.stderr,
                    exitCode: proc.terminationStatus,
                    wasCancelled: collector.wasCancelled
                )
                continuation.resume(returning: output)
            }

            do {
                logger.info("Starting download: \(id)")
                try process.run()
            } catch {
                processLock.lock()
                runningProcesses.removeValue(forKey: id)
                processLock.unlock()
                continuation.resume(throwing: YtDlpError.executionFailed(error.localizedDescription))
            }
        }
    }

    private func setupEnvironment(for process: Process) {
        process.environment = ProcessInfo.processInfo.environment
        if let ffmpegURL = Resources.bundledFfmpegURL {
            let path = process.environment?["PATH"] ?? ""
            process.environment?["PATH"] = ffmpegURL.deletingLastPathComponent().path + ":" + path
        }
    }

    private func parseProgress(from text: String, callback: @escaping (Double) -> Void) {
        parseProgressAndOutput(from: text) { progress, _ in
            callback(progress)
        }
    }

    private func parseProgressAndOutput(from text: String, callback: @escaping (Double, String?) -> Void) {
        // Parse progress percentage
        let range = NSRange(text.startIndex..., in: text)
        let matches = progressRegex.matches(in: text, options: [], range: range)

        for match in matches {
            if let percentRange = Range(match.range(at: 1), in: text),
               let percent = Double(text[percentRange]) {
                DispatchQueue.main.async {
                    callback(min(1.0, max(0.0, percent / 100.0)), nil)
                }
            }
        }

        // Also pass output lines for title extraction
        let lines = text.components(separatedBy: .newlines)
        for line in lines where !line.isEmpty {
            DispatchQueue.main.async {
                callback(-1, line)  // -1 means no progress update, just output line
            }
        }
    }
}
