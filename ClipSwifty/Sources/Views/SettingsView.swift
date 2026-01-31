import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var updateManager = UpdateManager.shared

    var body: some View {
        Form {
            // Appearance
            Section {
                Picker("Erscheinungsbild:", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            } header: {
                Label("Darstellung", systemImage: "paintbrush")
            }

            // Download Settings
            Section {
                // Output Directory
                HStack {
                    Text("Save downloads to:")
                    Spacer()
                    Button(action: selectOutputDirectory) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text(settings.outputDirectory.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                // Rate Limit
                HStack {
                    Text("Download speed limit:")
                    Spacer()
                    Picker("", selection: $settings.downloadRateLimit) {
                        Text("Unlimited").tag(0)
                        Text("500 KB/s").tag(500)
                        Text("1 MB/s").tag(1000)
                        Text("2 MB/s").tag(2000)
                        Text("5 MB/s").tag(5000)
                        Text("10 MB/s").tag(10000)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                // Concurrent fragments
                HStack {
                    Text("Parallel connections:")
                    Spacer()
                    Picker("", selection: $settings.concurrentFragments) {
                        Text("1 (Slow)").tag(1)
                        Text("2").tag(2)
                        Text("4 (Default)").tag(4)
                        Text("6").tag(6)
                        Text("8 (Fast)").tag(8)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            } header: {
                Label("Downloads", systemImage: "arrow.down.circle")
            } footer: {
                Text("More parallel connections = faster downloads, but may cause issues on slow connections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Format Preferences
            Section {
                Picker("Preferred video format:", selection: $settings.preferredVideoFormat) {
                    ForEach(VideoFormat.allCases) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }

                Picker("Preferred audio format:", selection: $settings.preferredAudioFormat) {
                    ForEach(AudioFormat.allCases) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }

                Toggle("Embed chapters in videos", isOn: $settings.embedChapters)

                Toggle("Save thumbnail as image", isOn: $settings.saveThumbnail)

                Toggle("Download subtitles", isOn: $settings.downloadSubtitles)
            } header: {
                Label("Formats", systemImage: "film")
            } footer: {
                Text("Chapters are embedded in MP4 files when available. Subtitles are saved as .srt files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Notifications & Clipboard
            Section {
                Toggle("Notify when download completes", isOn: $settings.notificationsEnabled)

                Toggle("Clipboard monitoring", isOn: $settings.clipboardMonitoring)
            } header: {
                Label("Notifications", systemImage: "bell")
            } footer: {
                Text("Clipboard monitoring shows a popup when you copy a video URL.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Auto-Organization
            Section {
                Picker("Organize downloads:", selection: $settings.organizationPattern) {
                    ForEach(OrganizationPattern.allCases) { pattern in
                        Text(pattern.displayName).tag(pattern)
                    }
                }

                if settings.organizationPattern != .none {
                    HStack {
                        Text("Preview:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.organizationPattern.previewExample)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Organization", systemImage: "folder.badge.gearshape")
            } footer: {
                Text("Automatically organize downloads into subfolders based on channel, date, or playlist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // yt-dlp Settings
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("yt-dlp")
                            if let version = updateManager.currentVersion {
                                Text("v\(version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2), in: Capsule())
                            }
                            if updateManager.updateAvailable, let latest = updateManager.latestVersion {
                                Text("→ \(latest)")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue, in: Capsule())
                            }
                        }

                        if let lastUpdate = settings.lastYtDlpUpdate {
                            Text("Last updated: \(lastUpdate, style: .relative) ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if updateManager.isUpdating {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(updateManager.updateMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if updateManager.updateAvailable {
                        Button("Update Now") {
                            Task {
                                await updateManager.performUpdate()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Check for Updates") {
                            updateManager.checkForUpdatesInBackground()
                        }
                    }
                }

                // Force reinstall option
                HStack {
                    Text("Having issues?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reinstall yt-dlp") {
                        Task {
                            await updateManager.forceReinstall()
                        }
                    }
                    .font(.caption)
                    .disabled(updateManager.isUpdating)
                }
            } header: {
                Label("yt-dlp", systemImage: "terminal")
            } footer: {
                Text("yt-dlp is required for downloading videos. Keep it updated for best compatibility with video platforms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // About
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com/yt-dlp/yt-dlp")!) {
                    HStack {
                        Text("yt-dlp on GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 800)
    }

    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url
        }
    }
}

#Preview {
    SettingsView()
}
