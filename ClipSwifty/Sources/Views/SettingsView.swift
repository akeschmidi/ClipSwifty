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
                    Text("Downloads speichern in:")
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
                    Text("Geschwindigkeitslimit:")
                    Spacer()
                    Picker("", selection: $settings.downloadRateLimit) {
                        Text("Unbegrenzt").tag(0)
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
                    Text("Parallele Verbindungen:")
                    Spacer()
                    Picker("", selection: $settings.concurrentFragments) {
                        Text("1 (Langsam)").tag(1)
                        Text("2").tag(2)
                        Text("4 (Standard)").tag(4)
                        Text("6").tag(6)
                        Text("8 (Schnell)").tag(8)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            } header: {
                Label("Downloads", systemImage: "arrow.down.circle")
            } footer: {
                Text("Mehr parallele Verbindungen = schnellere Downloads, kann aber bei langsamen Verbindungen Probleme verursachen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Format Preferences
            Section {
                Picker("Bevorzugtes Videoformat:", selection: $settings.preferredVideoFormat) {
                    ForEach(VideoFormat.allCases) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }

                Picker("Bevorzugtes Audioformat:", selection: $settings.preferredAudioFormat) {
                    ForEach(AudioFormat.allCases) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }

                Toggle("Kapitel in Videos einbetten", isOn: $settings.embedChapters)

                Toggle("Vorschaubild als Bild speichern", isOn: $settings.saveThumbnail)

                Toggle("Untertitel herunterladen", isOn: $settings.downloadSubtitles)
            } header: {
                Label("Formate", systemImage: "film")
            } footer: {
                Text("Kapitel werden in MP4-Dateien eingebettet, wenn verfügbar. Untertitel werden als .srt-Dateien gespeichert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Notifications & Clipboard
            Section {
                Toggle("Benachrichtigung bei Download-Abschluss", isOn: $settings.notificationsEnabled)

                Toggle("Zwischenablage überwachen", isOn: $settings.clipboardMonitoring)
            } header: {
                Label("Benachrichtigungen", systemImage: "bell")
            } footer: {
                Text("Die Zwischenablage-Überwachung zeigt ein Popup, wenn du eine Video-URL kopierst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Auto-Organization
            Section {
                Picker("Downloads organisieren:", selection: $settings.organizationPattern) {
                    ForEach(OrganizationPattern.allCases) { pattern in
                        Text(pattern.displayName).tag(pattern)
                    }
                }

                if settings.organizationPattern != .none {
                    HStack {
                        Text("Vorschau:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.organizationPattern.previewExample)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Organisation", systemImage: "folder.badge.gearshape")
            } footer: {
                Text("Downloads automatisch in Unterordner nach Kanal, Datum oder Playlist organisieren.")
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
                            Text("Letztes Update: vor \(lastUpdate, style: .relative)")
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
                        Button("Jetzt aktualisieren") {
                            Task {
                                await updateManager.performUpdate()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Nach Updates suchen") {
                            updateManager.checkForUpdatesInBackground()
                        }
                    }
                }

                // Force reinstall option
                HStack {
                    Text("Probleme?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("yt-dlp neu installieren") {
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
                Text("yt-dlp wird zum Herunterladen von Videos benötigt. Halte es aktuell für beste Kompatibilität.")
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

                if let ytdlpURL = URL(string: "https://github.com/yt-dlp/yt-dlp") {
                    Link(destination: ytdlpURL) {
                        HStack {
                            Text("yt-dlp auf GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Label("Über", systemImage: "info.circle")
            }

            // Support
            Section {
                Link(destination: URL(string: "https://buymeacoffee.com/akeschmidii") ?? URL(fileURLWithPath: "/")) {
                    HStack(spacing: 12) {
                        Text("☕")
                            .font(.system(size: 24))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buy me a coffee")
                                .font(.system(size: 14, weight: .medium))
                            Text("Unterstütze die Entwicklung")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "https://github.com/akeschmidi/ClipSwifty") ?? URL(fileURLWithPath: "/")) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Stern auf GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Unterstützung", systemImage: "heart")
            } footer: {
                Text("ClipSwifty ist kostenlos und Open Source. Deine Unterstützung hilft, dass es so bleibt!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 900)
    }

    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Auswählen"

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url
        }
    }
}

#Preview {
    SettingsView()
}
