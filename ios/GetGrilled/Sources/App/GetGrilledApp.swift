import SwiftUI

@main
struct GetGrilledApp: App {
    init() {
        configureNavigationBarAppearance()
        configureTabBarAppearance()
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
        if let largeTitleFont = UIFont(name: Font.OnestWeight.extrabold.postScriptName, size: 26) {
            appearance.largeTitleTextAttributes = [.font: largeTitleFont, .foregroundColor: UIColor(DesignTokens.ink)]
        }
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(DesignTokens.accentStrong)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(DesignTokens.surface)
        appearance.shadowColor = UIColor(DesignTokens.line)
        if let font = UIFont(name: Font.OnestWeight.semibold.postScriptName, size: 10.5) {
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.font: font, .foregroundColor: UIColor(DesignTokens.inkFaint)]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.font: font, .foregroundColor: UIColor(DesignTokens.accentStrong)]
        }
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(DesignTokens.inkFaint)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(DesignTokens.accentStrong)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
