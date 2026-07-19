import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedRecords: [ToothRecord]
    @Query private var storedProfiles: [ChildProfile]

    @State private var selectedTab: AppTab = .teeth
    @State private var selectedTooth: ToothDefinition?

    private var recordByToothID: [String: ToothRecord] {
        Dictionary(
            uniqueKeysWithValues: storedRecords
                .filter { $0.childID == ToothRecord.primaryChildID }
                .map { ($0.toothID, $0) }
        )
    }

    private var snapshots: [ToothSnapshot] {
        ToothCatalog.all.map {
            ToothSnapshot(definition: $0, record: recordByToothID[$0.id])
        }
    }

    private var primaryProfile: ChildProfile? {
        storedProfiles.first { $0.childID == ChildProfile.primaryChildID }
    }

    private var birthDate: Date? {
        primaryProfile?.birthDate
    }

    private var earliestRecordedDate: Date? {
        storedRecords
            .flatMap { [$0.teethingDate, $0.eruptedDate].compactMap { $0 } }
            .min()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MouthView(snapshots: snapshots, onSelect: select)
            }
            .tabItem {
                Label("tab.teeth", systemImage: "face.smiling")
                    .accessibilityIdentifier("tab.teeth")
            }
            .tag(AppTab.teeth)

            NavigationStack {
                HistoryView(
                    snapshots: snapshots,
                    birthDate: birthDate,
                    onSelect: select
                )
            }
            .tabItem {
                Label("tab.history", systemImage: "clock.arrow.circlepath")
                    .accessibilityIdentifier("tab.history")
            }
            .tag(AppTab.history)

            NavigationStack {
                MoreView(
                    snapshots: snapshots,
                    birthDate: birthDate,
                    onSaveBirthDate: saveBirthDate
                )
            }
            .tabItem {
                Label("tab.more", systemImage: "ellipsis.circle")
                    .accessibilityIdentifier("tab.more")
            }
            .tag(AppTab.more)
        }
        .tint(PetitesDentsStyle.coral)
        .sheet(item: $selectedTooth) { definition in
            ToothEditorView(
                definition: definition,
                record: recordByToothID[definition.id],
                birthDate: birthDate,
                onSaveNote: { note in
                    let record = record(for: definition)
                    record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    try modelContext.save()
                },
                onMarkTeething: { date, note in
                    try validateEventDate(date)
                    record(for: definition).markTeething(on: date, note: note)
                    try modelContext.save()
                },
                onMarkErupted: { date, note in
                    try validateEventDate(date)
                    try record(for: definition).markErupted(on: date, note: note)
                    try modelContext.save()
                },
                onReset: {
                    if let record = recordByToothID[definition.id] {
                        modelContext.delete(record)
                        try modelContext.save()
                    }
                }
            )
        }
    }

    private func select(_ snapshot: ToothSnapshot) {
        selectedTooth = snapshot.definition
    }

    private func record(for definition: ToothDefinition) -> ToothRecord {
        if let existing = recordByToothID[definition.id] {
            return existing
        }
        let record = ToothRecord(toothID: definition.id)
        modelContext.insert(record)
        return record
    }

    private func saveBirthDate(_ date: Date?) throws {
        if let date,
           let earliestRecordedDate,
           CivilDate.normalized(date) > earliestRecordedDate {
            throw ChildProfileError.birthDateAfterRecordedEvent
        }
        if let primaryProfile {
            primaryProfile.setBirthDate(date)
        } else if date != nil {
            let profile = ChildProfile(birthDate: date)
            modelContext.insert(profile)
        }
        try modelContext.save()
    }

    private func validateEventDate(_ date: Date) throws {
        if let birthDate,
           CivilDate.normalized(date) < birthDate {
            throw ChildProfileError.eventBeforeBirthDate
        }
    }
}

private enum AppTab: Hashable {
    case teeth
    case history
    case more
}

#Preview {
    ContentView()
        .modelContainer(for: [ToothRecord.self, ChildProfile.self], inMemory: true)
}
