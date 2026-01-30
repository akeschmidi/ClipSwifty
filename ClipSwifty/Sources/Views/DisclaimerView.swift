import SwiftUI

struct DisclaimerView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)

                Text("Important Notice")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Content
            VStack(alignment: .leading, spacing: 16) {
                DisclaimerSection(
                    icon: "doc.on.doc",
                    title: "Copyright Compliance",
                    text: "Only download content you have permission to download. Respect copyright laws and the terms of service of content platforms."
                )

                DisclaimerSection(
                    icon: "person.fill.checkmark",
                    title: "Personal Use",
                    text: "This app is intended for downloading content for personal, non-commercial use only."
                )

                DisclaimerSection(
                    icon: "hand.raised.fill",
                    title: "Your Responsibility",
                    text: "You are solely responsible for how you use this app. The developers are not liable for any misuse."
                )

                DisclaimerSection(
                    icon: "link",
                    title: "Third-Party Tool",
                    text: "This app uses yt-dlp, an open-source tool. ClipSwifty is not affiliated with any video platforms."
                )
            }
            .padding()
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            // Agreement
            VStack(spacing: 12) {
                Text("By using this app, you agree to use it responsibly and in compliance with applicable laws.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: acceptDisclaimer) {
                    Text("I Understand and Agree")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 500)
    }

    private func acceptDisclaimer() {
        settings.hasSeenDisclaimer = true
        isPresented = false
    }
}

struct DisclaimerSection: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    DisclaimerView(isPresented: .constant(true))
}
