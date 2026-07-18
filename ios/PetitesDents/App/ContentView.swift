import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedRecords: [ToothRecord]

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
                HistoryView(snapshots: snapshots, onSelect: select)
            }
            .tabItem {
                Label("tab.history", systemImage: "clock.arrow.circlepath")
                    .accessibilityIdentifier("tab.history")
            }
            .tag(AppTab.history)

            NavigationStack {
                MoreView(snapshots: snapshots)
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
                onSaveNote: { note in
                    let record = record(for: definition)
                    record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    try modelContext.save()
                },
                onMarkTeething: { date, note in
                    record(for: definition).markTeething(on: date, note: note)
                    try modelContext.save()
                },
                onMarkErupted: { date, note in
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
}

private enum AppTab: Hashable {
    case teeth
    case history
    case more
}

#Preview {
    ContentView()
        .modelContainer(for: ToothRecord.self, inMemory: true)
}
