import SwiftUI
import AppKit

struct MainView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @State private var isHoveringDownload = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                toolbarArea
                VStack(spacing: 20) {
                    inputCard
                    downloadsList
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showPlaylistDialog) {
            PlaylistDownloadDialog(
                playlistInfo: viewModel.playlistInfo,
                onDownload: { limit in
                    viewModel.startPlaylistDownload(limit: limit)
                },
                onDownloadSingle: {
                    viewModel.downloadSingleFromPlaylist()
                },
                onCancel: {
                    viewModel.cancelPlaylistDialog()
                }
            )
        }
        .onAppear {
            checkClipboardForURL()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkClipboardForURL()
            }
        }
    }

    private func checkClipboardForURL() {
        // Only auto-paste if the input field is empty
        guard viewModel.urlInput.isEmpty else { return }

        // Check clipboard for a valid video URL
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }

        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's a valid video URL
        let videoPatterns = [
            "youtube.com/watch",
            "youtu.be/",
            "youtube.com/shorts/",
            "youtube.com/playlist",
            "vimeo.com/",
            "dailymotion.com/",
            "twitch.tv/",
            "twitter.com/",
            "x.com/",
            "tiktok.com/",
            "instagram.com/",
            "facebook.com/"
        ]

        let lowercased = trimmed.lowercased()
        let isVideoURL = videoPatterns.contains { lowercased.contains($0) }

        if isVideoURL {
            viewModel.urlInput = trimmed
        }
    }

    // MARK: - Toolbar

    private var toolbarArea: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("ClipSwifty")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Video Downloader")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("ClipSwifty Video Downloader")

            Spacer()

            HStack(spacing: 12) {
                Button(action: viewModel.selectOutputDirectory) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        Text(viewModel.outputDirectory.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 120)
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Save to: \(viewModel.outputDirectory.path)")
                .accessibilityLabel("Output folder: \(viewModel.outputDirectory.lastPathComponent)")
                .accessibilityHint("Double-click to change download location")

                SettingsLink {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Settings")
                .accessibilityLabel("Open settings")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 14))
                        .accessibilityHidden(true)

                    TextField("Paste video URL...", text: $viewModel.urlInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .onSubmit { viewModel.startDownload() }
                        .accessibilityLabel("Video URL")
                        .accessibilityHint("Enter a video URL to download")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

                Button(action: viewModel.startDownload) {
                    Group {
                        if viewModel.isFetchingPlaylist {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: viewModel.urlInput.isEmpty || viewModel.isFetchingPlaylist
                            ? [.gray.opacity(0.5), .gray.opacity(0.3)]
                            : [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .scaleEffect(isHoveringDownload && !viewModel.urlInput.isEmpty ? 1.05 : 1.0)
                .animation(.spring(response: 0.3), value: isHoveringDownload)
                .onHover { isHoveringDownload = $0 }
                .disabled(viewModel.urlInput.isEmpty || viewModel.isFetchingPlaylist)
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel("Download")
                .accessibilityHint("Start downloading the video")
            }

            HStack(spacing: 16) {
                // Video/Audio Toggle - Modern Pill Style
                MediaTypeToggle(isAudioOnly: $viewModel.isAudioOnly)

                // Format Picker
                if viewModel.isAudioOnly {
                    AudioFormatPicker(selection: $viewModel.selectedAudioFormat)
                } else if !viewModel.availableQualities.isEmpty {
                    // Dynamic quality picker based on available formats
                    DynamicQualityPicker(
                        qualities: viewModel.availableQualities,
                        selection: $viewModel.selectedQuality
                    )
                } else {
                    // Fallback to static picker when no qualities loaded yet
                    VideoFormatPicker(selection: $viewModel.selectedVideoFormat)
                }

                Spacer()

                // Prefetch indicator (shows video info as it loads)
                if viewModel.isPrefetching || viewModel.prefetchedTitle != nil {
                    HStack(spacing: 6) {
                        if viewModel.isPrefetching {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text(viewModel.prefetchStatusMessage.isEmpty ? "Laden..." : viewModel.prefetchStatusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .animation(.easeInOut, value: viewModel.prefetchStatusMessage)
                        } else if let title = viewModel.prefetchedTitle {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text(title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(viewModel.isPrefetching
                                ? Color.blue.opacity(0.15)
                                : Color.green.opacity(0.15))
                    )
                    .foregroundStyle(viewModel.isPrefetching ? .blue : .green)
                    .frame(maxWidth: 300)
                    .animation(.spring(response: 0.3), value: viewModel.prefetchStatusMessage)
                }

                // Playlist indicator (shows when playlist detected)
                if viewModel.isPlaylistDetected || viewModel.isFetchingPlaylist {
                    HStack(spacing: 6) {
                        if viewModel.isFetchingPlaylist {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Loading playlist...")
                                .font(.system(size: 12, weight: .medium))
                        } else {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.system(size: 14))
                            Text("Playlist")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.purple.opacity(0.2), .indigo.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                    .foregroundStyle(.purple)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Downloads List

    private var downloadsList: some View {
        Group {
            if viewModel.downloads.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.downloads) { item in
                            DownloadRowView(
                                item: item,
                                onPause: { viewModel.pauseDownload(item) },
                                onResume: { viewModel.resumeDownload(item) },
                                onRetry: { viewModel.retryDownload(item) },
                                onCancel: { viewModel.cancelDownload(item) },
                                onRemove: {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel.removeItem(item)
                                    }
                                },
                                onShowInFinder: { viewModel.showInFinder(item) }
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(4)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("Downloads list")
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.linearGradient(
                    colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("No downloads yet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Paste a URL above to get started")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No downloads yet. Paste a URL above to get started.")
    }
}

// MARK: - Playlist Download Dialog

struct PlaylistDownloadDialog: View {
    let playlistInfo: DownloadViewModel.PlaylistInfo?
    let onDownload: (Int?) -> Void
    let onDownloadSingle: () -> Void
    let onCancel: () -> Void

    @State private var selectedOption: DownloadOption = .first10

    enum DownloadOption: Hashable {
        case singleVideo
        case first10
        case first25
        case first50
        case first100
        case all

        var limit: Int? {
            switch self {
            case .singleVideo: return 1
            case .first10: return 10
            case .first25: return 25
            case .first50: return 50
            case .first100: return 100
            case .all: return nil
            }
        }

        var label: String {
            switch self {
            case .singleVideo: return "Just this video"
            case .first10: return "First 10 videos"
            case .first25: return "First 25 videos"
            case .first50: return "First 50 videos"
            case .first100: return "First 100 videos"
            case .all: return "All videos"
            }
        }

        var icon: String {
            switch self {
            case .singleVideo: return "play.rectangle"
            default: return "list.bullet.rectangle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("Playlist Detected")
                    .font(.system(size: 18, weight: .semibold))

                if let info = playlistInfo {
                    VStack(spacing: 4) {
                        if let title = info.title {
                            Text(title)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(info.videoCount) videos in playlist")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Options
            VStack(spacing: 10) {
                Text("What would you like to download?")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    // Single video option
                    optionButton(for: .singleVideo, isDisabled: false)

                    Divider()
                        .padding(.vertical, 4)

                    // Playlist options
                    ForEach([DownloadOption.first10, .first25, .first50, .first100, .all], id: \.self) { option in
                        let isDisabled: Bool = {
                            guard let limit = option.limit, let count = playlistInfo?.videoCount else { return false }
                            return limit > count
                        }()
                        optionButton(for: option, isDisabled: isDisabled)
                    }
                }
            }

            // Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)

                Button {
                    if selectedOption == .singleVideo {
                        onDownloadSingle()
                    } else {
                        onDownload(selectedOption.limit)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear {
            // Auto-select a reasonable default based on playlist size
            if let count = playlistInfo?.videoCount {
                if count <= 10 {
                    selectedOption = .all
                } else if count <= 25 {
                    selectedOption = .first10
                } else {
                    selectedOption = .first25
                }
            }
        }
    }

    private func optionButton(for option: DownloadOption, isDisabled: Bool) -> some View {
        let isSelected = selectedOption == option

        return Button {
            selectedOption = option
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? (option == .singleVideo ? .blue : .purple) : .secondary)
                    .font(.system(size: 16))

                Image(systemName: option.icon)
                    .foregroundStyle(isSelected ? (option == .singleVideo ? .blue : .purple) : .secondary)
                    .font(.system(size: 14))

                Text(option.label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))

                Spacer()

                if let limit = option.limit, limit > 1, let count = playlistInfo?.videoCount, limit > count {
                    Text("(\(count) available)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                        ? (option == .singleVideo ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                        : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected
                        ? (option == .singleVideo ? Color.blue.opacity(0.3) : Color.purple.opacity(0.3))
                        : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isDisabled ? .tertiary : .primary)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Media Type Toggle

struct MediaTypeToggle: View {
    @Binding var isAudioOnly: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Video Option
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isAudioOnly = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 13))
                    Text("Video")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(minWidth: 80)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(!isAudioOnly
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ))
                            : AnyShapeStyle(Color.clear)
                        )
                        .shadow(color: !isAudioOnly ? .blue.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
                )
                .foregroundStyle(!isAudioOnly ? .white : .secondary)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            // Audio Option
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isAudioOnly = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 13))
                    Text("Audio")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(minWidth: 80)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isAudioOnly
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ))
                            : AnyShapeStyle(Color.clear)
                        )
                        .shadow(color: isAudioOnly ? .orange.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
                )
                .foregroundStyle(isAudioOnly ? .white : .secondary)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}

// MARK: - Format Pickers

struct VideoFormatPicker: View {
    @Binding var selection: VideoFormat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(VideoFormat.allCases) { format in
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        selection = format
                    }
                } label: {
                    Text(format.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selection == format ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                        .foregroundStyle(selection == format ? .primary : .secondary)
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(format.displayName)
                .accessibilityAddTraits(selection == format ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Video quality")
    }
}

struct AudioFormatPicker: View {
    @Binding var selection: AudioFormat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AudioFormat.allCases) { format in
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        selection = format
                    }
                } label: {
                    Text(format.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(minWidth: 50)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selection == format ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                        .foregroundStyle(selection == format ? .primary : .secondary)
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(format.displayName)
                .accessibilityAddTraits(selection == format ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Audio format")
    }
}

struct DynamicQualityPicker: View {
    let qualities: [AvailableQuality]
    @Binding var selection: AvailableQuality?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(qualities) { quality in
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            selection = quality
                        }
                    } label: {
                        Text(quality.label)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selection == quality ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .foregroundStyle(selection == quality ? .primary : .secondary)
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(quality.label)
                    .accessibilityAddTraits(selection == quality ? .isSelected : [])
                }
            }
            .padding(4)
        }
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Video quality")
    }
}

// MARK: - Download Row

struct DownloadRowView: View {
    let item: DownloadItem
    let onPause: () -> Void
    let onResume: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onShowInFinder: () -> Void
    @State private var isHovering = false

    private var isCompleted: Bool {
        if case .completed = item.status { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title ?? "Loading...")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    if let uploader = item.uploader {
                        Label(uploader, systemImage: "person.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Uploader: \(uploader)")
                    }
                    if let duration = item.duration {
                        Text(duration)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .accessibilityLabel("Duration: \(duration)")
                    }
                }

                statusView
            }

            Spacer(minLength: 0)

            // Action buttons
            actionButtons
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.background.opacity(isHovering ? 0.8 : 0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.quaternary.opacity(isHovering ? 1 : 0.5), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCompleted {
                onShowInFinder()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(isCompleted ? "Click to show in Finder" : "")
    }

    private var accessibilityDescription: String {
        let title = item.title ?? "Loading"
        let status = item.status.displayText
        return "\(title), \(status)"
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Pause/Resume/Retry button
            if item.status.canPause {
                Button(action: onPause) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Pause download")
                .accessibilityLabel("Pause")
            } else if item.status.canRetry {
                Button(action: item.status.isPaused ? onResume : onRetry) {
                    Image(systemName: item.status.isPaused ? "play.circle.fill" : "arrow.clockwise.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(item.status.isPaused ? .green : .blue)
                }
                .buttonStyle(.plain)
                .help(item.status.isPaused ? "Resume download" : "Retry download")
                .accessibilityLabel(item.status.isPaused ? "Resume" : "Retry")
            }

            // Cancel button for active downloads
            if item.status.isActive {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Cancel download")
                .accessibilityLabel("Cancel")
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.5)
            .help("Remove from list")
            .accessibilityLabel("Remove")
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if let thumbnailURL = item.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderContent
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.7)
                    @unknown default:
                        placeholderContent
                    }
                }
            } else {
                placeholderContent
            }
        }
        .frame(width: 100, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private var placeholderContent: some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
        }
    }

    private var statusView: some View {
        HStack(spacing: 8) {
            statusIcon

            switch item.status {
            case .downloading(let progress):
                progressBar(progress: progress)
                Text(String(format: "%3d%%", Int(progress * 100)))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            case .paused(let progress):
                progressBar(progress: progress)
                Text(String(format: "%3d%%", Int(progress * 100)))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            default:
                Text(item.status.displayText)
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(item.status.displayText)")
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(width: 100, height: 6)
    }

    private var statusIcon: some View {
        Group {
            switch item.status {
            case .fetchingInfo:
                ProgressView()
                    .scaleEffect(0.5)
            case .pending:
                Image(systemName: "clock.fill")
                    .foregroundStyle(.secondary)
            case .preparing:
                ProgressView()
                    .scaleEffect(0.5)
            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
            case .converting:
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 14))
        .frame(width: 18)
        .accessibilityHidden(true)
    }

    private var statusColor: Color {
        switch item.status {
        case .fetchingInfo, .pending: return .secondary
        case .preparing: return .blue
        case .downloading: return .blue
        case .paused: return .orange
        case .converting: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Status Extension

extension DownloadStatus {
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

#Preview {
    MainView()
        .frame(width: 650, height: 550)
}
