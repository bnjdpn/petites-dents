import Foundation
import StoreKit

/// The single thing Petites Dents sells. One payment, no subscription, no
/// advertising, no account — and Family Sharing on, so one purchase covers
/// both parents.
enum SouvenirsCatalog {
    static let productID = "com.bnjdpn.petitesdents.souvenirs"

    /// Every product whose ownership unlocks the Carnet Souvenirs. Identifiers
    /// stay in this set for ever: a purchase made once is honoured for ever,
    /// even if the product is later withdrawn from sale.
    static let entitlementProductIDs: Set<String> = [productID]

    /// Free tier: the very first photo of a child is free, and stays free for
    /// ever. Photos already stored are never hidden nor deleted.
    static let freePhotoLimitPerChild = 1
}

private enum StoreServiceError: Error {
    case failedVerification
}

@Observable
@MainActor
final class StoreService {
    private(set) var product: Product?
    private(set) var ownedEntitlementProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var didLoadProducts = false
    private(set) var didLoadEntitlements = false
    var message: String?

    private let userDefaults: UserDefaults
    private let arguments: [String]
    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        userDefaults: UserDefaults = AppDefaults.shared,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.userDefaults = userDefaults
        self.arguments = arguments
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }

    // MARK: - Access

    /// Capture and UI-test runs open every gate. The paywall capture is the
    /// exception: granting the unlock there would replace the offer with the
    /// thank-you card, so that run keeps the real, unpurchased state.
    var isStoreBypassEnabled: Bool {
        LaunchEnvironment.isStoreBypassEnabled(arguments)
            && !LaunchEnvironment.shouldOpenPaywallAtLaunch(arguments)
    }

    var isLegacyUnlocked: Bool {
        LegacyEntitlement.isUnlocked(userDefaults: userDefaults)
    }

    var isPurchased: Bool {
        !ownedEntitlementProductIDs.isEmpty
    }

    /// The one place the app asks "does this person have the Carnet?".
    var hasSouvenirs: Bool {
        isStoreBypassEnabled || isLegacyUnlocked || isPurchased
    }

    /// The second dentition — shedding dates, replacements and six-year molars.
    var canTrackPermanentTeeth: Bool { hasSouvenirs }

    /// Exporting or printing the illustrated keepsake. The preview itself is
    /// always visible: nobody pays for a page they have not seen.
    var canExportKeepsake: Bool { hasSouvenirs }

    /// The very first photo of a child is free for ever; the album is the paid
    /// part. Photos already on the device are never taken away.
    func canAddPhoto(existingPhotoCount: Int) -> Bool {
        hasSouvenirs || existingPhotoCount < SouvenirsCatalog.freePhotoLimitPerChild
    }

    // MARK: - Products

    func loadProductsIfNeeded() async {
        guard product == nil, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            didLoadProducts = true
        }
        do {
            let loaded = try await Product.products(for: [SouvenirsCatalog.productID])
            product = loaded.first { $0.id == SouvenirsCatalog.productID }
            if product == nil {
                message = NSLocalizedString("paywall.unavailable", comment: "")
            }
        } catch {
            product = nil
            message = NSLocalizedString("paywall.unavailable", comment: "")
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.revocationDate == nil,
                  SouvenirsCatalog.entitlementProductIDs.contains(transaction.productID) else {
                continue
            }
            owned.insert(transaction.productID)
        }
        ownedEntitlementProductIDs = owned
        didLoadEntitlements = true
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlements()
                message = nil
            case .pending:
                message = NSLocalizedString("paywall.pending", comment: "")
            case .userCancelled:
                break
            @unknown default:
                message = NSLocalizedString("paywall.failed", comment: "")
            }
        } catch {
            message = NSLocalizedString("paywall.failed", comment: "")
        }
    }

    func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPurchased
                ? NSLocalizedString("paywall.restored", comment: "")
                : NSLocalizedString("paywall.nothing_to_restore", comment: "")
        } catch {
            message = NSLocalizedString("paywall.failed", comment: "")
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            value
        case .unverified:
            throw StoreServiceError.failedVerification
        }
    }
}
