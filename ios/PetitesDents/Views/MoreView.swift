import SwiftUI
import UIKit

struct MoreView: View {
    let snapshots: [ToothSnapshot]
    let permanentSnapshots: [ToothSnapshot]
    let profileName: String
    let birthDate: Date?
    let store: StoreService
    let onSaveBirthDate: (Date?) throws -> Void
    let makeKeepsakeDocument: () -> KeepsakeDocument
    let onRequestUnlock: () -> Void

    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var showingBirthDateEditor = false
    @State private var draftBirthDate = Date()

    private var latestAllowedBirthDate: Date {
        let earliestRecordedDate = (snapshots + permanentSnapshots)
            .compactMap { snapshot in
                [
                    snapshot.record?.teethingDate,
                    snapshot.record?.eruptedDate,
                    snapshot.record?.sheddingDate,
                ]
                .compactMap { $0 }
                .min()
            }
            .min()
        return earliestRecordedDate ?? CivilDate.normalized(Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("more.title")
                    .font(.largeTitle.bold())
                Text("more.subtitle")
                    .foregroundStyle(.secondary)

                birthDateCard
                clinicalExportCard
                keepsakeCard
                helpCard

                Text("more.medical_disclaimer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .frame(maxWidth: .infinity)
        }
        .background(PetitesDentsStyle.cream.ignoresSafeArea())
        .accessibilityIdentifier("screen.more")
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.url])
        }
        .sheet(isPresented: $showingBirthDateEditor) {
            birthDateEditor
        }
        .alert(
            "common.error",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Cards

    private var birthDateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("more.birth_date_title", systemImage: "birthday.cake")
                .font(.headline)
                .foregroundStyle(PetitesDentsStyle.sage)
            Text("more.birth_date_body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(
                birthDate.map { CivilDate.formatted($0, style: .long) }
                    ?? String(localized: "more.birth_date_not_set")
            )
            .font(.subheadline.weight(.semibold))
            Button(
                birthDate == nil ? "more.birth_date_add" : "more.birth_date_edit"
            ) {
                draftBirthDate = birthDate.map { CivilDate.pickerDate(from: $0) } ?? Date()
                showingBirthDateEditor = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("more.birth_date_edit")

            if birthDate != nil {
                Button("more.birth_date_remove", role: .destructive) {
                    do {
                        try onSaveBirthDate(nil)
                    } catch {
                        exportError = error.localizedDescription
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .cardStyle()
        .accessibilityIdentifier("more.birth_date")
    }

    private var clinicalExportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("more.export_title", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(PetitesDentsStyle.sage)
            Text("more.export_body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("more.export_free")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PetitesDentsStyle.sage)
            Button("more.export_button") {
                do {
                    shareItem = ShareItem(
                        url: try TeethPDFExporter.create(
                            snapshots: snapshots,
                            birthDate: birthDate,
                            profileName: profileName
                        )
                    )
                } catch {
                    exportError = error.localizedDescription
                }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("more.export_pdf")
        }
        .cardStyle()
    }

    private var keepsakeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("more.keepsake_title", systemImage: "printer")
                .font(.headline)
                .foregroundStyle(PetitesDentsStyle.coral)
            Text("more.keepsake_body")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("more.keepsake_button") {
                guard store.canExportKeepsake else {
                    onRequestUnlock()
                    return
                }
                do {
                    shareItem = ShareItem(
                        url: try KeepsakePDFRenderer.render(makeKeepsakeDocument())
                    )
                } catch {
                    exportError = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(PetitesDentsStyle.coral)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("more.keepsake")

            if !store.canExportKeepsake {
                Label("more.keepsake_locked", systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("more.restore") {
                Task { await store.restorePurchases() }
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("more.restore")

            if let message = store.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("more.store_message")
            }
        }
        .cardStyle()
        .accessibilityIdentifier("more.keepsake_card")
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("more.help_title", systemImage: "lock.shield")
                .font(.headline)
            Link(
                destination: URL(string: "https://bnjdpn.github.io/petites-dents/#contact")!
            ) {
                Label("more.support", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Link(
                destination: URL(string: "https://bnjdpn.github.io/petites-dents/privacy.html")!
            ) {
                Label("more.privacy", systemImage: "hand.raised")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
    }

    private var birthDateEditor: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "more.birth_date_label",
                    selection: $draftBirthDate,
                    in: ...CivilDate.pickerDate(from: latestAllowedBirthDate),
                    displayedComponents: .date
                )
                .accessibilityIdentifier("more.birth_date_picker")
            }
            .navigationTitle("more.birth_date_title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        showingBirthDateEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        do {
                            try onSaveBirthDate(draftBirthDate)
                            showingBirthDateEditor = false
                        } catch {
                            exportError = error.localizedDescription
                        }
                    }
                    .accessibilityIdentifier("more.save_birth_date")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension View {
    func cardStyle() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
