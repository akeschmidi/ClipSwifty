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

                Text("Wichtiger Hinweis")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Content
            VStack(alignment: .leading, spacing: 16) {
                DisclaimerSection(
                    icon: "doc.on.doc",
                    title: "Urheberrecht beachten",
                    text: "Lade nur Inhalte herunter, für die du eine Berechtigung hast. Respektiere das Urheberrecht und die Nutzungsbedingungen der Plattformen."
                )

                DisclaimerSection(
                    icon: "person.fill.checkmark",
                    title: "Persönliche Nutzung",
                    text: "Diese App ist ausschließlich zum Herunterladen von Inhalten für den persönlichen, nicht-kommerziellen Gebrauch gedacht."
                )

                DisclaimerSection(
                    icon: "hand.raised.fill",
                    title: "Deine Verantwortung",
                    text: "Du bist allein verantwortlich für die Nutzung dieser App. Die Entwickler haften nicht für Missbrauch."
                )

                DisclaimerSection(
                    icon: "link",
                    title: "Drittanbieter-Tool",
                    text: "Diese App verwendet yt-dlp, ein Open-Source-Tool. ClipSwifty ist nicht mit Videoplattformen verbunden."
                )
            }
            .padding()
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            // Agreement
            VStack(spacing: 12) {
                Text("Mit der Nutzung dieser App erklärst du dich damit einverstanden, sie verantwortungsvoll und im Einklang mit geltendem Recht zu verwenden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: acceptDisclaimer) {
                    Text("Verstanden und einverstanden")
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
