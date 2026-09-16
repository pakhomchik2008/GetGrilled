import SwiftUI

/// Design System v2 type — Onest (UI) + IBM Plex Mono (code). Bundled as static per-weight
/// TTFs and registered via `UIAppFonts` in Info.plist; see docs/v2-technical-spec.md §9.
/// Falls back to San Francisco automatically if a font file is ever missing from the bundle
/// (Font.custom's built-in behavior) rather than crashing.
extension Font {
    enum OnestWeight {
        case regular, medium, semibold, bold, extrabold

        var postScriptName: String {
            switch self {
            case .regular: return "Onest-Regular"
            case .medium: return "Onest-Medium"
            case .semibold: return "Onest-SemiBold"
            case .bold: return "Onest-Bold"
            case .extrabold: return "Onest-ExtraBold"
            }
        }
    }

    enum PlexMonoWeight {
        case regular, medium, semibold, bold

        var postScriptName: String {
            switch self {
            case .regular: return "IBMPlexMono-Regular"
            case .medium: return "IBMPlexMono-Medium"
            case .semibold: return "IBMPlexMono-SemiBold"
            case .bold: return "IBMPlexMono-Bold"
            }
        }
    }

    static func onest(_ size: CGFloat, _ weight: OnestWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    static func plexMono(_ size: CGFloat, _ weight: PlexMonoWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }
}
