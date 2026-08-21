import SwiftUI

struct HistoryEntry: Identifiable {
    enum Kind {
        case erupted
        case shed
        case permanentErupted

        var localizedLabel: String {
            switch self {
            case .erupted: NSLocalizedString("history.kind.erupted", comment: "")
            case .shed: NSLocalizedString("history.kind.shed", comment: "")
            case .permanentErupted: NSLocalizedString("history.kind.permanent", comment: "")
            }
        }

        var symbol: String {
            switch self {
            case .erupted: "sparkles"
            case .shed: "wind"
            case .permanentErupted: "arrow.up.circle"
            }
        }
    }

    let id: String
    let snapshot: ToothSnapshot
    let date: Date
    let kind: Kind
}

struct HistoryView: View {
    let snapshots: [ToothSnapshot]
    let permanentSnapshots: [ToothSnapshot]
    let birthDate: Date?
    let onSelect: (ToothSnapshot) -> Void
    let photoThumbnail: (ToothSnapshot, String) -> Data?

    static func entries(
        primary: [ToothSnapshot],
        permanent: [ToothSnapshot]
    ) -> [HistoryEntry] {
        var entries: [HistoryEntry] = []
        for snapshot in primary + permanent {
            guard let record = snapshot.record else { continue }
            if let eruptedDate = record.eruptedDate {
                entries.append(
                    HistoryEntry(
                        id: "\(snapshot.id)-erupted",
                        snapshot: snapshot,
                        date: eruptedDate,
                        kind: snapshot.definition.phase == .permanent ? .permanentErupted : .erupted
                    )
                )
            }
            if let sheddingDate = record.sheddingDate {
                entries.append(
                    HistoryEntry(
                        id: "\(snapshot.id)-shed",
                        snapshot: snapshot,
                        date: sheddingDate,
                        kind: .shed
                    )
                )
            }
        }
        return entries.sorted {
            $0.date == $1.date
                ? $0.snapshot.definition.fdi < $1.snapshot.definition.fdi
                : $0.date > $1.date
        }
    }

    private var history: [HistoryEntry] {
        Self.entries(primary: snapshots, permanent: permanentSnapshots)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("history.title")
                    .font(.largeTitle.bold())
                Text("history.subtitle")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                if history.isEmpty {
                    ContentUnavailableView(
                        "history.empty_title",
                        systemImage: "sparkles",
                        description: Text("history.empty_body")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(history) { entry in
                        Button {
                            onSelect(entry.snapshot)
                        } label: {
                            HistoryCard(
                                entry: entry,
                                birthDate: birthDate,
                                photoThumbnail: photoThumbnail
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
        }
        .background(PetitesDentsStyle.cream.ignoresSafeArea())
        .accessibilityIdentifier("screen.history")
    }
}

private struct HistoryCard: View {
    let entry: HistoryEntry
    let birthDate: Date?
    let photoThumbnail: (ToothSnapshot, String) -> Data?

    private var thumbnail: UIImage? {
        guard let photoID = entry.snapshot.photoIDs.first else { return nil }
        return photoThumbnail(entry.snapshot, photoID).flatMap(UIImage.init(data:))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: entry.kind.symbol)
                    .font(.title3)
                    .foregroundStyle(
                        entry.kind == .shed ? PetitesDentsStyle.coral : PetitesDentsStyle.sage
                    )
                    .frame(width: 30)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.snapshot.definition.localizedName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(dateLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("history.age.\(entry.snapshot.definition.fdi)")
                if let note = entry.snapshot.record?.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("history.\(entry.snapshot.definition.fdi)")
    }

    private var dateLine: String {
        let formattedDate = CivilDate.formatted(entry.date, style: .medium)
        let age = birthDate.flatMap {
            CalendarAgeFormatter.string(birthDate: $0, eventDate: entry.date)
        }
        guard let age else {
            return String(
                format: NSLocalizedString("history.event_on", comment: "Event date"),
                entry.kind.localizedLabel,
                formattedDate
            )
        }
        return String(
            format: NSLocalizedString("history.event_on_with_age", comment: "Event date and age"),
            entry.kind.localizedLabel,
            formattedDate,
            age
        )
    }
}
