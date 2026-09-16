import RevenueCat
import SwiftUI

/// Shown either from the Account sheet or reactively when the backend rejects a session
/// with the weekly free-limit error (see RoundSessionViewModel.limitReached).
struct PaywallView: View {
    @ObservedObject var purchases = PurchasesService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("GetGrilled Pro").font(.onest(24, .bold)).foregroundStyle(DesignTokens.ink)
                        Text("Unlimited Test and Competition sessions, every week.")
                            .font(.onest(14))
                            .foregroundStyle(DesignTokens.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    if purchases.offerings == nil && purchases.errorMessage == nil {
                        ProgressView().padding(.top, 24)
                    }

                    if let current = purchases.offerings?.current {
                        VStack(spacing: 10) {
                            ForEach(current.availablePackages, id: \.identifier) { package in
                                packageRow(package)
                            }
                        }
                    } else if let message = purchases.errorMessage {
                        Text(message)
                            .font(.onest(13))
                            .foregroundStyle(DesignTokens.danger)
                            .padding()
                            .background(DesignTokens.dangerWash, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button("Restore purchases") {
                        Task { await purchases.restorePurchases() }
                    }
                    .font(.onest(13, .medium))
                    .foregroundStyle(DesignTokens.inkSoft)
                    .disabled(purchases.isLoading)
                }
                .padding()
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
                        .font(.onest(15, .semibold))
                        .foregroundStyle(DesignTokens.ink)
                    Text(package.storeProduct.localizedDescription)
                        .font(.onest(12))
                        .foregroundStyle(DesignTokens.inkSoft)
                }
                Spacer()
                Text(package.storeProduct.localizedPriceString)
                    .font(.onest(15, .bold))
                    .foregroundStyle(DesignTokens.accentStrong)
            }
            .padding(14)
            .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DesignTokens.line, lineWidth: 1))
        }
        .disabled(purchases.isLoading)
    }
}

#Preview {
    PaywallView()
}
