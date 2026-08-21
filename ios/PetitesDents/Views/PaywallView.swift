import StoreKit
import SwiftUI

/// The single paid offer of Petites Dents. One payment, no subscription, so
/// the App Store subscription disclosure block does not apply — but the price
/// always comes from `Product.displayPrice` and Restore is always one tap
/// away, on this screen and in the More tab.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    let store: StoreService
    let document: KeepsakeDocument?

    @State private var previewImage: UIImage?

    private static let standardEULA = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!
    private static let privacyURL = URL(
        string: "https://bnjdpn.github.io/petites-dents/privacy.html"
    )!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    preview
                    features
                    scopeNote
                    purchaseBlock
                    legalBlock
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .background(PetitesDentsStyle.cream.ignoresSafeArea())
            .navigationTitle("paywall.nav_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                        .accessibilityIdentifier("paywall.close")
                }
            }
        }
        .accessibilityIdentifier("screen.paywall")
        .task {
            await store.loadProductsIfNeeded()
            await store.refreshEntitlements()
            renderPreviewIfNeeded()
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("paywall.eyebrow")
                .font(.caption.weight(.semibold))
                .kerning(1.6)
                .foregroundStyle(PetitesDentsStyle.coral)
            Text("paywall.title")
                .font(.largeTitle.bold())
                .foregroundStyle(PetitesDentsStyle.ink)
            Text("paywall.promise")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PetitesDentsStyle.coralSoft, lineWidth: 1)
                    )
                    .accessibilityIdentifier("paywall.preview")
                    .accessibilityLabel("paywall.preview_accessibility")
                Text("paywall.preview_caption")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PetitesDentsStyle.coralSoft.opacity(0.35))
                    .frame(height: 220)
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("paywall.preview_loading")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("paywall.preview_placeholder")
            }
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(
                symbol: "calendar.badge.clock",
                title: "paywall.feature.second_dentition_title",
                body: "paywall.feature.second_dentition_body"
            )
            featureRow(
                symbol: "printer",
                title: "paywall.feature.keepsake_title",
                body: "paywall.feature.keepsake_body"
            )
            featureRow(
                symbol: "photo.on.rectangle.angled",
                title: "paywall.feature.photos_title",
                body: "paywall.feature.photos_body"
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func featureRow(
        symbol: String,
        title: LocalizedStringKey,
        body: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(PetitesDentsStyle.coral)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scopeNote: some View {
        Text("paywall.scope")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var purchaseBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.hasSouvenirs {
                Label("paywall.already_owned", systemImage: "checkmark.seal")
                    .font(.headline)
                    .foregroundStyle(PetitesDentsStyle.sage)
                    .accessibilityIdentifier("paywall.owned")
                Text("paywall.already_owned_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let product = store.product {
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    HStack {
                        Text("paywall.buy")
                        Spacer(minLength: 8)
                        Text(product.displayPrice)
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("paywall.price")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PetitesDentsStyle.coral)
                .controlSize(.large)
                .disabled(store.isPurchasing)
                .accessibilityIdentifier("paywall.buy")

                Text("paywall.terms_summary")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if store.isLoadingProducts || !store.didLoadProducts {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("paywall.loading")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("paywall.loading")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("paywall.unavailable", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(PetitesDentsStyle.coral)
                    Text("paywall.unavailable_body")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("paywall.retry") {
                        Task { await store.loadProductsIfNeeded() }
                    }
                    .buttonStyle(.bordered)
                }
                .accessibilityIdentifier("paywall.unavailable")
            }

            Button {
                Task { await store.restorePurchases() }
            } label: {
                if store.isRestoring {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("paywall.restore")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(store.isRestoring)
            .accessibilityIdentifier("paywall.restore")

            if let message = store.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("paywall.message")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var legalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Link(destination: Self.privacyURL) {
                Label("paywall.privacy", systemImage: "hand.raised")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("paywall.privacy")
            Link(destination: Self.standardEULA) {
                Label("paywall.terms", systemImage: "doc.text")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("paywall.terms")
            Text("paywall.privacy_note")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func renderPreviewIfNeeded() {
        guard previewImage == nil, let document else { return }
        previewImage = KeepsakePDFRenderer.plateImage(document, width: 620)
    }
}
