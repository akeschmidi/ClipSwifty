import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.clipswifty", category: "App")

@main
struct ClipSwiftyApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var updateManager = UpdateManager.shared
    @State private var showDisclaimer = false

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 600)
                .sheet(isPresented: $showDisclaimer) {
                    DisclaimerView(isPresented: $showDisclaimer)
                }
                .overlay(alignment: .bottom) {
                    if updateManager.isUpdating {
                        UpdateBanner(message: updateManager.updateMessage, isProgress: true)
                    } else if updateManager.updateAvailable {
                        UpdateAvailableBanner(
                            currentVersion: updateManager.currentVersion ?? "unknown",
                            latestVersion: updateManager.latestVersion ?? "unknown",
                            onUpdate: {
                                Task {
                                    await updateManager.performUpdate()
                                }
                            },
                            onDismiss: {
                                updateManager.updateAvailable = false
                            }
                        )
                    }
                }
                .onAppear {
                    checkFirstLaunch()
                    // Silent background check
                    updateManager.checkForUpdatesInBackground()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 900, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for yt-dlp Updates...") {
                    Task {
                        await updateManager.performUpdate()
                    }
                }
            }
        }

        Settings {
            SettingsView()
        }
    }

    private func checkFirstLaunch() {
        if !settings.hasSeenDisclaimer {
            showDisclaimer = true
            logger.info("First launch - showing disclaimer")
        }
    }
}

// MARK: - Update Banner (Progress)

struct UpdateBanner: View {
    let message: String
    var isProgress: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if isProgress {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Text(message)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 8)
    }
}

// MARK: - Update Available Banner

struct UpdateAvailableBanner: View {
    let currentVersion: String
    let latestVersion: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("yt-dlp Update verfügbar")
                    .font(.caption.bold())
                Text("\(currentVersion) → \(latestVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Update") {
                onUpdate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
