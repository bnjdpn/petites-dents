import StoreKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query private var storedRecords: [ToothRecord]
    @Query private var storedProfiles: [ChildProfile]

    @AppStorage("selectedChildID", store: AppDefaults.shared) private var selectedChildID = ChildProfile.primaryChildID
    @State private var store = StoreService()
    @State private var selectedTab: AppTab = .teeth
    @State private var selectedTooth: ToothDefinition?
    @State private var phase: ToothPhase = .primary
    @State private var isShowingPaywall = false

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

    private var activeChildID: String {
        selectedProfile?.childID ?? ChildProfile.primaryChildID
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

    private var permanentSnapshots: [ToothSnapshot] {
        PermanentToothCatalog.all.map {
            ToothSnapshot(definition: $0, record: recordByToothID[$0.id])
        }
    }

    private var photoCountForChild: Int {
        recordByToothID.values.reduce(0) { $0 + $1.photoIDs.count }
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
                    MouthView(
                        snapshots: snapshots,
                        permanentSnapshots: permanentSnapshots,
                        canTrackPermanentTeeth: store.canTrackPermanentTeeth,
                        phase: $phase,
                        onSelect: select,
                        onRequestUnlock: presentPaywall
                    )
                }
                .tabItem {
                    Label("tab.teeth", systemImage: "face.smiling")
                        .accessibilityIdentifier("tab.teeth")
                }
                .tag(AppTab.teeth)

                NavigationStack {
                    HistoryView(
                        snapshots: snapshots,
                        permanentSnapshots: permanentSnapshots,
                        birthDate: birthDate,
                        onSelect: select,
                        photoThumbnail: { snapshot, photoID in
                            ToothPhotoStore.data(
                                photoID: photoID,
                                childID: activeChildID,
                                toothID: snapshot.definition.id,
                                thumbnail: true
                            )
                        }
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
                        permanentSnapshots: permanentSnapshots,
                        profileName: selectedProfile?.name ?? "",
                        birthDate: birthDate,
                        store: store,
                        onSaveBirthDate: saveBirthDate,
                        makeKeepsakeDocument: makeKeepsakeDocument,
                        onRequestUnlock: presentPaywall
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
        .task {
            await store.refreshEntitlements()
            await store.loadProductsIfNeeded()
            repairSelectionIfNeeded()
            if LaunchEnvironment.shouldOpenPaywallAtLaunch() {
                isShowingPaywall = true
            }
        }
        .onChange(of: storedProfiles.map(\.childID).sorted()) {
            repairSelectionIfNeeded()
        }
        .onChange(of: selectedChildID) {
            selectedTooth = nil
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(store: store, document: makeKeepsakeDocument())
        }
        .sheet(item: $selectedTooth) { definition in
            ToothEditorView(
                definition: definition,
                record: recordByToothID[definition.id],
                birthDate: birthDate,
                canAddPhoto: store.canAddPhoto(existingPhotoCount: photoCountForChild),
                canRecordShedding: store.canTrackPermanentTeeth,
                onSaveNote: { note in
                    let record = record(for: definition)
                    record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    try modelContext.save()
                },
                onMarkTeething: { date, note in
                    try validateEventDate(date)
                    record(for: definition).markTeething(on: date, note: note)
                    try modelContext.save()
                    registerToothValueEvent()
                },
                onMarkErupted: { date, note in
                    try validateEventDate(date)
                    try record(for: definition).markErupted(on: date, note: note)
                    try modelContext.save()
                    registerToothValueEvent()
                },
                onMarkShed: { date, note in
                    try validateEventDate(date)
                    try record(for: definition).markShed(on: date, note: note)
                    try modelContext.save()
                    registerToothValueEvent()
                },
                onReset: {
                    if let record = recordByToothID[definition.id] {
                        ToothPhotoStore.deleteAll(
                            childID: activeChildID,
                            toothID: definition.id
                        )
                        modelContext.delete(record)
                        try modelContext.save()
                    }
                },
                onAddPhoto: { data in
                    let photoID = try ToothPhotoStore.store(
                        imageData: data,
                        childID: activeChildID,
                        toothID: definition.id
                    )
                    let record = record(for: definition)
                    record.photoIDs.append(photoID)
                    try modelContext.save()
                },
                onDeletePhoto: { photoID in
                    guard let record = recordByToothID[definition.id] else { return }
                    record.photoIDs.removeAll { $0 == photoID }
                    try modelContext.save()
                    ToothPhotoStore.delete(
                        photoID: photoID,
                        childID: activeChildID,
                        toothID: definition.id
                    )
                },
                photoThumbnail: { photoID in
                    ToothPhotoStore.data(
                        photoID: photoID,
                        childID: activeChildID,
                        toothID: definition.id,
                        thumbnail: true
                    )
                },
                onRequestUnlock: presentPaywall
            )
        }
    }

    private func presentPaywall() {
        isShowingPaywall = true
    }

    private func makeKeepsakeDocument() -> KeepsakeDocument {
        KeepsakeDocumentBuilder.make(
            profileName: selectedProfile?.name ?? "",
            birthDate: birthDate,
            childID: activeChildID,
            primary: snapshots,
            permanent: permanentSnapshots
        )
    }

    private func select(_ snapshot: ToothSnapshot) {
        selectedTooth = snapshot.definition
    }

    private func registerToothValueEvent() {
        let arguments = ProcessInfo.processInfo.arguments
        guard !LaunchEnvironment.isUITesting(arguments),
              !LaunchEnvironment.isScreenshotRun(arguments) else {
            return
        }
        guard ReviewPromptTracker.registerValueEvent() else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            requestReview()
        }
    }

    private func record(for definition: ToothDefinition) -> ToothRecord {
        if let existing = recordByToothID[definition.id] {
            return existing
        }
        let record = ToothRecord(
            childID: activeChildID,
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
        let next = try ChildProfileStore.delete(childID: childID, in: modelContext)
        ToothPhotoStore.deleteAll(childID: childID)
        return next
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
