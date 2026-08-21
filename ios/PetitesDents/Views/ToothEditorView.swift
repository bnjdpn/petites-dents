import PhotosUI
import SwiftUI

struct ToothEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let definition: ToothDefinition
    let record: ToothRecord?
    let birthDate: Date?
    let canAddPhoto: Bool
    let canRecordShedding: Bool
    let onSaveNote: (String) throws -> Void
    let onMarkTeething: (Date, String) throws -> Void
    let onMarkErupted: (Date, String) throws -> Void
    let onMarkShed: (Date, String) throws -> Void
    let onReset: () throws -> Void
    let onAddPhoto: (Data) throws -> Void
    let onDeletePhoto: (String) throws -> Void
    let photoThumbnail: (String) -> Data?
    let onRequestUnlock: () -> Void

    @State private var selectedDate: Date
    @State private var note: String
    @State private var errorMessage: String?
    @State private var isConfirmingReset = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isImportingPhoto = false

    init(
        definition: ToothDefinition,
        record: ToothRecord?,
        birthDate: Date?,
        canAddPhoto: Bool,
        canRecordShedding: Bool,
        onSaveNote: @escaping (String) throws -> Void,
        onMarkTeething: @escaping (Date, String) throws -> Void,
        onMarkErupted: @escaping (Date, String) throws -> Void,
        onMarkShed: @escaping (Date, String) throws -> Void,
        onReset: @escaping () throws -> Void,
        onAddPhoto: @escaping (Data) throws -> Void,
        onDeletePhoto: @escaping (String) throws -> Void,
        photoThumbnail: @escaping (String) -> Data?,
        onRequestUnlock: @escaping () -> Void
    ) {
        self.definition = definition
        self.record = record
        self.birthDate = birthDate
        self.canAddPhoto = canAddPhoto
        self.canRecordShedding = canRecordShedding
        self.onSaveNote = onSaveNote
        self.onMarkTeething = onMarkTeething
        self.onMarkErupted = onMarkErupted
        self.onMarkShed = onMarkShed
        self.onReset = onReset
        self.onAddPhoto = onAddPhoto
        self.onDeletePhoto = onDeletePhoto
        self.photoThumbnail = photoThumbnail
        self.onRequestUnlock = onRequestUnlock
        _selectedDate = State(
            initialValue: (record?.sheddingDate ?? record?.eruptedDate ?? record?.teethingDate)
                .map { CivilDate.pickerDate(from: $0) } ?? Date()
        )
        _note = State(initialValue: record?.note ?? "")
    }

    private var photoIDs: [String] { record?.photoIDs ?? [] }

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

                photoSection

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

                    if definition.phase == .primary {
                        Button("editor.mark_shed") {
                            if canRecordShedding {
                                perform { try onMarkShed(selectedDate, note) }
                            } else {
                                dismiss()
                                onRequestUnlock()
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("editor.mark_shed")

                        if !canRecordShedding {
                            Label("editor.shed_locked", systemImage: "lock")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

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

    @ViewBuilder
    private var photoSection: some View {
        Section("photos.title") {
            if photoIDs.isEmpty {
                Text("photos.empty")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoIDs, id: \.self) { photoID in
                            photoThumbnailView(photoID)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("photos.carousel")
            }

            if canAddPhoto {
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("photos.add", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("photos.add")
                .disabled(isImportingPhoto)
            } else {
                Button {
                    dismiss()
                    onRequestUnlock()
                } label: {
                    Label("photos.unlock", systemImage: "lock")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("photos.unlock")
            }

            if isImportingPhoto {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("photos.importing")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Text("photos.privacy")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            isImportingPhoto = true
            Task {
                defer {
                    isImportingPhoto = false
                    pickerItem = nil
                }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        errorMessage = String(localized: "photos.error_unreadable")
                        return
                    }
                    try onAddPhoto(data)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func photoThumbnailView(_ photoID: String) -> some View {
        let image = photoThumbnail(photoID).flatMap(UIImage.init(data:))
        return Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PetitesDentsStyle.coralSoft)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button("photos.delete", role: .destructive) {
                perform(dismissOnSuccess: false) { try onDeletePhoto(photoID) }
            }
        }
        .accessibilityIdentifier("photo.\(photoID)")
        .accessibilityLabel("photos.accessibility")
    }

    private func perform(dismissOnSuccess: Bool = true, _ action: () throws -> Void) {
        do {
            try action()
            if dismissOnSuccess { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
