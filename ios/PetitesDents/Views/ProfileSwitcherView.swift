import SwiftUI

struct ProfileSwitcherView: View {
    let profiles: [ChildProfile]
    let selectedProfile: ChildProfile
    let onSelect: (String) -> Void
    let onCreate: (String) throws -> String
    let onRename: (String, String) throws -> Void
    let onDelete: (String) throws -> String

    @State private var showingProfiles = false

    var body: some View {
        Button {
            showingProfiles = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(PetitesDentsStyle.coral)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedProfile.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("profile.switch_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: NSLocalizedString(
                    "profile.selector_accessibility",
                    comment: "Selected child and profile count"
                ),
                selectedProfile.name,
                profiles.count
            )
        )
        .accessibilityHint("profile.switch_hint")
        .accessibilityIdentifier("profile.selector")
        .sheet(isPresented: $showingProfiles) {
            ProfilesSheet(
                profiles: profiles,
                selectedProfile: selectedProfile,
                onSelect: onSelect,
                onCreate: onCreate,
                onRename: onRename,
                onDelete: onDelete
            )
        }
    }
}

private struct ProfilesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let profiles: [ChildProfile]
    let selectedProfile: ChildProfile
    let onSelect: (String) -> Void
    let onCreate: (String) throws -> String
    let onRename: (String, String) throws -> Void
    let onDelete: (String) throws -> String

    @State private var editorMode: ProfileEditorMode?
    @State private var confirmingDeletion = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("profile.children") {
                    ForEach(profiles, id: \.childID) { profile in
                        Button {
                            onSelect(profile.childID)
                            dismiss()
                        } label: {
                            HStack {
                                Text(profile.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if profile.childID == selectedProfile.childID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PetitesDentsStyle.sage)
                                        .accessibilityLabel("profile.selected")
                                }
                            }
                        }
                        .accessibilityIdentifier("profile.row.\(profile.childID)")
                    }
                }

                Section("profile.manage") {
                    Button {
                        editorMode = ProfileEditorMode(kind: .add, initialName: "")
                    } label: {
                        Label("profile.add", systemImage: "person.badge.plus")
                    }
                    .accessibilityIdentifier("profile.add")

                    Button {
                        editorMode = ProfileEditorMode(
                            kind: .rename,
                            initialName: selectedProfile.name
                        )
                    } label: {
                        Label("profile.rename", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("profile.rename")

                    Button(role: .destructive) {
                        confirmingDeletion = true
                    } label: {
                        Label("profile.delete", systemImage: "trash")
                    }
                    .disabled(profiles.count <= 1)
                    .accessibilityIdentifier("profile.delete")
                }
            }
            .navigationTitle("profile.title")
            .accessibilityIdentifier("profile.sheet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("profile.done") { dismiss() }
                        .accessibilityIdentifier("profile.done")
                }
            }
            .sheet(item: $editorMode) { mode in
                ProfileEditorView(mode: mode) { name in
                    switch mode.kind {
                    case .add:
                        onSelect(try onCreate(name))
                    case .rename:
                        try onRename(selectedProfile.childID, name)
                    }
                }
            }
            .confirmationDialog(
                "profile.delete_title",
                isPresented: $confirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("profile.delete", role: .destructive) {
                    do {
                        onSelect(try onDelete(selectedProfile.childID))
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text(
                    String(
                        format: NSLocalizedString(
                            "profile.delete_body",
                            comment: "Delete selected child profile"
                        ),
                        selectedProfile.name
                    )
                )
            }
            .alert(
                "common.error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ProfileEditorMode: Identifiable {
    enum Kind {
        case add
        case rename
    }

    let id = UUID()
    let kind: Kind
    let initialName: String
}

private struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: ProfileEditorMode
    let onSave: (String) throws -> Void

    @State private var name: String
    @State private var errorMessage: String?

    init(mode: ProfileEditorMode, onSave: @escaping (String) throws -> Void) {
        self.mode = mode
        self.onSave = onSave
        _name = State(initialValue: mode.initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("profile.name", text: $name)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .accessibilityIdentifier("profile.name")
            }
            .navigationTitle(
                mode.kind == .add ? "profile.add_title" : "profile.rename_title"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .accessibilityIdentifier("profile.save")
                }
            }
            .alert(
                "common.error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        do {
            try onSave(name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
