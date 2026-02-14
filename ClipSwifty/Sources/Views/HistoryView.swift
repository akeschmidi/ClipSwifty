import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var historyManager = DownloadHistoryManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download-Verlauf")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(historyManager.items.count) Downloads")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Fertig") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(20)

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Suche...", text: $historyManager.searchText)
                    .textFieldStyle(.plain)

                if !historyManager.searchText.isEmpty {
                    Button {
                        historyManager.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            // List
            if historyManager.filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: historyManager.searchText.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(historyManager.searchText.isEmpty ? "Noch keine Downloads" : "Keine Ergebnisse")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(historyManager.filteredItems) { item in
                        HistoryRowView(item: item) {
                            historyManager.removeItem(item)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Footer
            if !historyManager.items.isEmpty {
                Divider()
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        historyManager.clearHistory()
                    } label: {
                        Label("Verlauf löschen", systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 500, maxWidth: 500, minHeight: 400, maxHeight: 600)
    }
}

struct HistoryRowView: View {
    let item: DownloadHistoryItem
    let onRemove: () -> Void
    @State private var isHovering = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "Unbekannt")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let uploader = item.uploader {
                        Label(uploader, systemImage: "person.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let duration = item.duration {
                        Text(duration)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let fileSize = item.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(Self.dateFormatter.string(from: item.completedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isHovering {
                if let path = item.outputPath {
                    Button {
                        let url = URL(fileURLWithPath: path)
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    } label: {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Im Finder zeigen")
                }

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Aus Verlauf entfernen")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .onHover { isHovering = $0 }
        .contentShape(Rectangle())
    }
}
