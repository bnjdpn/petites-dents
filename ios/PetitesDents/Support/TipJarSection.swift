import StoreKit
import SwiftUI

struct TipJarSection: View {
    static let productIDs = [
        "com.bnjdpn.petitesdents.tip.cafe",
        "com.bnjdpn.petitesdents.tip.merci",
        "com.bnjdpn.petitesdents.tip.soutien",
    ]

    @State private var products: [Product] = []
    @State private var message: String?

    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshots")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("tips.title", systemImage: "heart.circle.fill")
                .font(.headline)
                .foregroundStyle(PetitesDentsStyle.coral)
            Text("tips.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isScreenshotMode {
                screenshotProducts
            } else if products.isEmpty {
                ProgressView("tips.loading")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(products, id: \.id) { product in
                    Button {
                        Task { await purchase(product) }
                    } label: {
                        HStack {
                            Text(product.displayName)
                            Spacer()
                            Text(product.displayPrice)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("tip.\(product.id)")
                }
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            guard !isScreenshotMode else { return }
            await loadProducts()
        }
        .accessibilityIdentifier("tips.section")
    }

    private var screenshotProducts: some View {
        VStack(spacing: 10) {
            screenshotProduct(name: "tips.cafe", price: screenshotPrice(0.99))
            screenshotProduct(name: "tips.merci", price: screenshotPrice(2.99))
            screenshotProduct(name: "tips.soutien", price: screenshotPrice(5.99))
        }
    }

    private func screenshotPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = Locale.current.region?.identifier == "GB" ? "GBP" :
            (Locale.current.language.languageCode?.identifier == "fr" ? "EUR" : "USD")
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func screenshotProduct(name: LocalizedStringKey, price: String) -> some View {
        Button(action: {}) {
            HStack {
                Text(name)
                Spacer()
                Text(price)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    @MainActor
    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted {
                Self.productIDs.firstIndex(of: $0.id) ?? .max <
                    Self.productIDs.firstIndex(of: $1.id) ?? .max
            }
        } catch {
            message = String(localized: "tips.unavailable")
        }
    }

    @MainActor
    private func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            if case let .success(verification) = result,
               case let .verified(transaction) = verification {
                await transaction.finish()
                message = String(localized: "tips.thanks")
            }
        } catch {
            message = String(localized: "tips.unavailable")
        }
    }
}
