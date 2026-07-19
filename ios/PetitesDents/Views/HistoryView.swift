import SwiftUI

struct HistoryView: View {
    let snapshots: [ToothSnapshot]
    let birthDate: Date?
    let onSelect: (ToothSnapshot) -> Void

    private var history: [ToothSnapshot] {
        snapshots
            .filter { $0.record?.eruptedDate != nil }
            .sorted { ($0.record?.eruptedDate ?? .distantPast) > ($1.record?.eruptedDate ?? .distantPast) }
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
                    ForEach(history) { snapshot in
                        Button {
                            onSelect(snapshot)
                        } label: {
                            HistoryCard(snapshot: snapshot, birthDate: birthDate)
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
    let snapshot: ToothSnapshot
    let birthDate: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(PetitesDentsStyle.sage)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.definition.localizedName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let eruptedDate = snapshot.record?.eruptedDate {
                    let formattedDate = CivilDate.formatted(eruptedDate, style: .medium)
                    let age = birthDate.flatMap {
                        CalendarAgeFormatter.string(birthDate: $0, eventDate: eruptedDate)
                    }
                    Text(
                        age.map {
                            String(
                                format: NSLocalizedString(
                                    "history.erupted_on_with_age",
                                    comment: "Eruption date and baby age"
                                ),
                                formattedDate,
                                $0
                            )
                        } ?? String(
                            format: NSLocalizedString("history.erupted_on", comment: "Eruption date"),
                            formattedDate
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("history.age.\(snapshot.definition.fdi)")
                }
                if let note = snapshot.record?.note, !note.isEmpty {
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
        .accessibilityIdentifier("history.\(snapshot.definition.fdi)")
    }
}
