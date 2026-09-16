import Foundation
import RevenueCat

/// Wraps the RevenueCat SDK. `isPro` here is only for immediate UI feedback (enabling/
/// disabling the paywall, showing "you're Pro") — it is NOT what gates the weekly session
/// limits. That gating happens server-side, reading `users.subscription_status`, which
/// `/api/revenuecat/webhook` keeps in sync from RevenueCat's own entitlement events. A client
/// could be offline or lie about `isPro`; the backend never trusts it.
@MainActor
final class PurchasesService: NSObject, ObservableObject {
    static let shared = PurchasesService()

    @Published private(set) var isPro = false
    @Published private(set) var offerings: Offerings?
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private var isConfigured = false

    func configure() {
        guard !isConfigured else { return }
        guard !Config.revenueCatAPIKey.isEmpty else {
            errorMessage = "RevenueCat isn't configured yet."
            return
        }
        isConfigured = true
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        Purchases.shared.delegate = self
        refreshCustomerInfo()
        loadOfferings()
    }

    /// Call whenever the Supabase auth user id becomes known (anonymous session included —
    /// that id is stable across the anonymous-to-permanent upgrade) so RevenueCat's
    /// `app_user_id` matches what the webhook writes against.
    func logIn(userId: String) {
        guard isConfigured else { return }
        Task {
            do {
                _ = try await Purchases.shared.logIn(userId)
                refreshCustomerInfo()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadOfferings() {
        guard isConfigured else { return }
        Purchases.shared.getOfferings { [weak self] offerings, error in
            Task { @MainActor in
                self?.offerings = offerings
                if let error { self?.errorMessage = error.localizedDescription }
            }
        }
    }

    func purchase(_ package: Package) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            applyEntitlement(result.customerInfo)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            applyEntitlement(info)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshCustomerInfo() {
        Purchases.shared.getCustomerInfo { [weak self] info, _ in
            guard let self, let info else { return }
            Task { @MainActor in self.applyEntitlement(info) }
        }
    }

    private func applyEntitlement(_ info: CustomerInfo) {
        isPro = info.entitlements[Config.revenueCatProEntitlementId]?.isActive == true
    }
}

extension PurchasesService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in applyEntitlement(customerInfo) }
    }
}
