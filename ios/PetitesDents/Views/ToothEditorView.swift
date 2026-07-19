import SwiftUI

struct ToothEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let definition: ToothDefinition
    let record: ToothRecord?
    let birthDate: Date?
    let onSaveNote: (String) throws -> Void
    let onMarkTeething: (Date, String) throws -> Void
    let onMarkErupted: (Date, String) throws -> Void
    let onReset: () throws -> Void

    @State private var selectedDate: Date
    @State private var note: String
    @State private var errorMessage: String?
    @State private var isConfirmingReset = false

    init(
        definition: ToothDefinition,
        record: ToothRecord?,
        birthDate: Date?,
        onSaveNote: @escaping (String) throws -> Void,
        onMarkTeething: @escaping (Date, String) throws -> Void,
        onMarkErupted: @escaping (Date, String) throws -> Void,
        onReset: @escaping () throws -> Void
    ) {
        self.definition = definition
        self.record = record
        self.birthDate = birthDate
        self.onSaveNote = onSaveNote
        self.onMarkTeething = onMarkTeething
        self.onMarkErupted = onMarkErupted
        self.onReset = onReset
        _selectedDate = State(
            initialValue: (record?.eruptedDate ?? record?.teethingDate)
                .map { CivilDate.pickerDate(from: $0) } ?? Date()
        )
        _note = State(initialValue: record?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(definition.localizedName)
                        .font(.subheadline.weight(.semibold))
                    LabeledContent("editor.current_status") {
                        Text((record?.status ?? .ghost).localizedName)
                            .foregroundStyle(.secondary)
                    }
                    Text(definition.typicalAge)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("editor.date") {
                    DatePicker(
                        "editor.choose_date",
                        selection: $selectedDate,
                        in: (birthDate.map { CivilDate.pickerDate(from: $0) } ?? .distantPast)...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("editor.date")
                }

                Section("editor.note") {
                    TextEditor(text: $note)
                        .frame(minHeight: 110)
                        .accessibilityLabel("editor.note_placeholder")
                        .accessibilityIdentifier("editor.note")
                }

                Section {
                    Button("editor.mark_teething") {
                        perform { try onMarkTeething(selectedDate, note) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PetitesDentsStyle.coral)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("editor.mark_teething")

                    Button("editor.mark_erupted") {
                        perform { try onMarkErupted(selectedDate, note) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PetitesDentsStyle.sage)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("editor.mark_erupted")

                    Button("editor.save_note") {
                        perform { try onSaveNote(note) }
                    }
                    .frame(maxWidth: .infinity)
                }

                if record != nil {
                    Section {
                        Button("editor.reset", role: .destructive) {
                            isConfirmingReset = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(definition.kind.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                        .accessibilityIdentifier("editor.close")
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
            .confirmationDialog(
                "editor.reset_title",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button("editor.reset", role: .destructive) {
                    perform { try onReset() }
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("editor.reset_body")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
