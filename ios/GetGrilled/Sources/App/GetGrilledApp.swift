import SwiftUI

@main
struct GetGrilledApp: App {
    init() {
        configureNavigationBarAppearance()
        PurchasesService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(DesignTokens.accentStrong)
                .font(.onest(16))
                .background(DesignTokens.bg.ignoresSafeArea())
        }
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(DesignTokens.surface)
        if let titleFont = UIFont(name: Font.OnestWeight.semibold.postScriptName, size: 17) {
            appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: UIColor(DesignTokens.ink)]
        }
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(DesignTokens.accentStrong)
    }
}
