import SwiftUI
import UIKit

struct MoreView: View {
    let snapshots: [ToothSnapshot]

    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("more.title")
                    .font(.largeTitle.bold())
                Text("more.subtitle")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Label("more.export_title", systemImage: "doc.richtext")
                        .font(.headline)
                        .foregroundStyle(PetitesDentsStyle.coral)
                    Text("more.export_body")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("more.export_button") {
                        do {
                            shareItem = ShareItem(url: try TeethPDFExporter.create(snapshots: snapshots))
                        } catch {
                            exportError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PetitesDentsStyle.coral)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("more.export_pdf")
                }
                .cardStyle()

                TipJarSection()
                    .cardStyle()

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
