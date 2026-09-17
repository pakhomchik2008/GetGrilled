import RevenueCat
import SwiftUI

/// Shown either from the Account sheet or reactively when the backend rejects a session
/// with the weekly free-limit error (see RoundSessionViewModel.limitReached).
struct PaywallView: View {
    @ObservedObject var purchases = PurchasesService.shared
    @Environment(\.dismiss) private var dismiss

    private let benefits = [
        "Unlimited Test & Competition sessions",
        "Full communication & efficiency breakdown, not just correctness",
        "Full session history, kept forever"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("FREE TIER")
                        .font(.onest(12, .bold))
                        .tracking(0.4)
                        .foregroundStyle(DesignTokens.accentStrong)

                    Text("Unlock unlimited sessions")
                        .font(.onest(19, .bold))
                        .foregroundStyle(DesignTokens.ink)

                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(benefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 7) {
                                Text("✓").font(.onest(12, .bold)).foregroundStyle(DesignTokens.success)
                                Text(benefit).font(.onest(12.5)).foregroundStyle(DesignTokens.inkSoft)
                            }
                        }
                    }

                    if purchases.offerings == nil && purchases.errorMessage == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 12)
                    }

                    if let current = purchases.offerings?.current {
                        VStack(spacing: 10) {
                            ForEach(current.availablePackages, id: \.identifier) { package in
                                packageRow(package)
                            }
                        }
                        .padding(.top, 4)
                    } else if let message = purchases.errorMessage {
                        Text(message)
                            .font(.onest(12.5))
                            .foregroundStyle(DesignTokens.danger)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignTokens.dangerWash, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button("Restore purchases") {
                        Task { await purchases.restorePurchases() }
                    }
                    .font(.onest(13, .semibold))
                    .foregroundStyle(DesignTokens.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                    .disabled(purchases.isLoading)
                }
                .padding(16)
                .background(DesignTokens.surfaceSunken, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignTokens.line, lineWidth: 1))
                .padding(20)
            }
            .background(DesignTokens.bg.ignoresSafeArea())
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: purchases.isPro) { isPro in
                if isPro { dismiss() }
            }
        }
    }

    private func packageRow(_ package: Package) -> some View {
        Button {
            Task { await purchases.purchase(package) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.onest(14.5, .semibold))
                        .foregroundStyle(DesignTokens.ink)
                    Text(package.storeProduct.localizedDescription)
                        .font(.onest(11.5))
                        .foregroundStyle(DesignTokens.inkSoft)
                }
                Spacer()
                Text(package.storeProduct.localizedPriceString)
                    .font(.onest(14.5, .bold))
                    .foregroundStyle(DesignTokens.accentStrong)
            }
            .padding(13)
            .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignTokens.line, lineWidth: 1))
        }
        .disabled(purchases.isLoading)
    }
}

#Preview {
    PaywallView()
}
