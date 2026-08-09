import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedRecords: [ToothRecord]
    @Query private var storedProfiles: [ChildProfile]

    @AppStorage("selectedChildID") private var selectedChildID = ChildProfile.primaryChildID
    @State private var selectedTab: AppTab = .teeth
    @State private var selectedTooth: ToothDefinition?

    private var sortedProfiles: [ChildProfile] {
        storedProfiles.sorted {
            if $0.childID == ChildProfile.primaryChildID { return true }
            if $1.childID == ChildProfile.primaryChildID { return false }
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame
                ? $0.childID < $1.childID
                : comparison == .orderedAscending
        }
    }

    private var selectedProfile: ChildProfile? {
        storedProfiles.first { $0.childID == selectedChildID }
            ?? storedProfiles.first { $0.childID == ChildProfile.primaryChildID }
            ?? sortedProfiles.first
    }

    private var recordByToothID: [String: ToothRecord] {
        Dictionary(
            uniqueKeysWithValues: storedRecords
                .filter { $0.childID == selectedProfile?.childID }
                .map { ($0.toothID, $0) }
        )
    }

    private var snapshots: [ToothSnapshot] {
        ToothCatalog.all.map {
            ToothSnapshot(definition: $0, record: recordByToothID[$0.id])
        }
    }

    private var birthDate: Date? {
        selectedProfile?.birthDate
    }

    var body: some View {
        VStack(spacing: 0) {
            if let selectedProfile {
                ProfileSwitcherView(
                    profiles: sortedProfiles,
                    selectedProfile: selectedProfile,
                    onSelect: selectProfile,
                    onCreate: createProfile,
                    onRename: renameProfile,
                    onDelete: deleteProfile
                )
                Divider()
            }

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
                        profileName: selectedProfile?.name ?? "",
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
        }
        .tint(PetitesDentsStyle.coral)
        .task { repairSelectionIfNeeded() }
        .onChange(of: storedProfiles.map(\.childID).sorted()) {
            repairSelectionIfNeeded()
        }
        .onChange(of: selectedChildID) {
            selectedTooth = nil
        }
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
        let record = ToothRecord(
            childID: selectedProfile?.childID ?? ChildProfile.primaryChildID,
            toothID: definition.id
        )
        modelContext.insert(record)
        return record
    }

    private func saveBirthDate(_ date: Date?) throws {
        guard let selectedProfile else { throw ChildProfileError.profileNotFound }
        try ChildProfileStore.setBirthDate(
            date,
            for: selectedProfile,
            records: storedRecords,
            in: modelContext
        )
    }

    private func validateEventDate(_ date: Date) throws {
        try ChildProfileStore.validateEventDate(date, for: selectedProfile)
    }

    private func selectProfile(_ childID: String) {
        selectedChildID = childID
    }

    private func createProfile(_ name: String) throws -> String {
        try ChildProfileStore.create(name: name, in: modelContext).childID
    }

    private func renameProfile(_ childID: String, _ name: String) throws {
        try ChildProfileStore.rename(childID: childID, name: name, in: modelContext)
    }

    private func deleteProfile(_ childID: String) throws -> String {
        try ChildProfileStore.delete(childID: childID, in: modelContext)
    }

    private func repairSelectionIfNeeded() {
        guard let selectedProfile else { return }
        if selectedChildID != selectedProfile.childID {
            selectedChildID = selectedProfile.childID
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
