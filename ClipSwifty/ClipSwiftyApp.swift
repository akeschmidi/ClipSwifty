import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.clipswifty", category: "App")

/// AppDelegate handles app lifecycle events like termination
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Kill all running yt-dlp processes to avoid zombie processes
        YtDlpManager.shared.cancelAllDownloads()
        logger.info("App terminating - all downloads cancelled")
    }
}

@main
struct ClipSwiftyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var updateManager = UpdateManager.shared
    @StateObject private var downloadViewModel = DownloadViewModel()
    @State private var showDisclaimer = false

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: downloadViewModel)
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
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
                Button("Nach yt-dlp Updates suchen...") {
                    Task {
                        await updateManager.performUpdate()
                    }
                }
            }
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarView(viewModel: downloadViewModel)
        } label: {
            Label {
                Text("ClipSwifty")
            } icon: {
                if downloadViewModel.activeDownloadCount > 0 {
                    Image(systemName: "arrow.down.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                } else {
                    Image(systemName: "arrow.down.circle")
                }
            }
        }
        .menuBarExtraStyle(.window)
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
