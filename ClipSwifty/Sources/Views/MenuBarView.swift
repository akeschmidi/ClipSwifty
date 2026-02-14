import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var viewModel: DownloadViewModel
    @State private var quickURL: String = ""
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)

                Text("ClipSwifty")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                if viewModel.activeDownloadCount > 0 {
                    Text("\(viewModel.activeDownloadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.blue, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    // Quick paste URL
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)

                            TextField("URL einfügen...", text: $quickURL)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .onSubmit {
                                    startQuickDownload()
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                        )

                        Button {
                            startQuickDownload()
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(quickURL.isEmpty ? .gray : .blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(quickURL.isEmpty)
                    }

                    // Downloads Section
                    if !viewModel.downloads.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Downloads")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            VStack(spacing: 6) {
                                ForEach(viewModel.downloads.prefix(4)) { item in
                                    MenuBarDownloadRow(item: item)
                                }
                            }

                            if viewModel.downloads.count > 4 {
                                HStack {
                                    Spacer()
                                    Text("+\(viewModel.downloads.count - 4) weitere")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 280)

            Divider()

            // Action buttons
            HStack(spacing: 0) {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        if window.contentViewController != nil &&
                           !window.title.contains("Menu") &&
                           window.level == .normal {
                            window.makeKeyAndOrderFront(nil)
                            break
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "macwindow")
                        Text("Fenster öffnen")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Divider()
                    .frame(height: 20)

                Button {
                    NSWorkspace.shared.open(AppSettings.shared.outputDirectory)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("Downloads")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Divider()
                    .frame(height: 20)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                        Text("Beenden")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 320)
        .onAppear {
            checkClipboardForURL()
        }
    }

    private func startQuickDownload() {
        guard !quickURL.isEmpty else { return }
        viewModel.urlInput = quickURL.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.startDownload()
        quickURL = ""
    }

    private func checkClipboardForURL() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }

        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        let videoPatterns = [
            "youtube.com/watch", "youtu.be/", "youtube.com/shorts/",
            "youtube.com/playlist", "vimeo.com/", "dailymotion.com/",
            "twitch.tv/", "twitter.com/", "x.com/", "tiktok.com/",
            "instagram.com/", "facebook.com/"
        ]

        let lowercased = trimmed.lowercased()
        if videoPatterns.contains(where: { lowercased.contains($0) }) {
            quickURL = trimmed
        }
    }
}

struct MenuBarDownloadRow: View {
    let item: DownloadItem

    private var progress: Double? {
        if case .downloading(let p) = item.status { return p }
        if case .paused(let p) = item.status { return p }
        return nil
    }

    var body: some View {
        HStack(spacing: 10) {
            // Status icon
            statusIcon
                .frame(width: 20, height: 20)

            // Title and progress
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "Laden...")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let progress = progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                            Capsule()
                                .fill(item.status.isPaused ? Color.orange : Color.blue)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 4)
                } else {
                    Text(item.status.displayText)
                        .font(.system(size: 10))
                        .foregroundStyle(statusColor)
                }
            }

            Spacer(minLength: 0)

            // Progress info for downloading items
            if let progress = progress {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let speed = item.downloadSpeed {
                        Text(speed)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .fetchingInfo, .pending, .preparing:
            ProgressView()
                .scaleEffect(0.6)
        case .downloading:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 16))
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16))
        case .converting:
            Image(systemName: "waveform")
                .foregroundStyle(.orange)
                .font(.system(size: 14))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 16))
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        default: return .secondary
        }
    }
}

#Preview {
    MenuBarView(viewModel: DownloadViewModel())
}
