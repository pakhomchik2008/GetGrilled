import SwiftUI

extension Color {
    /// OKLCH → sRGB, per the CSS Color Module 4 conversion matrices (Björn Ottosson's Oklab).
    /// SwiftUI's `Color` can't parse `oklch()` strings, so every design-system token below is
    /// specified with the exact same (L, C, H) triples the web mockup used, converted here
    /// instead of by hand — see docs/v2-technical-spec.md §9.
    static func oklch(_ l: Double, _ c: Double, _ h: Double, alpha: Double = 1) -> Color {
        let hr = h * .pi / 180
        let a = c * cos(hr)
        let b = c * sin(hr)

        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b

        let lc = l_ * l_ * l_
        let mc = m_ * m_ * m_
        let sc = s_ * s_ * s_

        let r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        func gammaEncode(_ x: Double) -> Double {
            let clamped = min(max(x, 0), 1)
            return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        }

        return Color(red: gammaEncode(r), green: gammaEncode(g), blue: gammaEncode(bl), opacity: alpha)
    }

    /// Resolves to `light` or `dark` based on the system/app color scheme, independent of
    /// `@Environment(\.colorScheme)` threading — matches how the web mockup's
    /// `prefers-color-scheme` media query switched its token tables.
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// Design System v2 tokens. Values copied 1:1 from the approved web mockup's `:root` /
/// `prefers-color-scheme: dark` CSS custom properties.
enum DesignTokens {
    static let bg = Color.dynamic(light: .oklch(0.97, 0.01, 90), dark: .oklch(0.22, 0.018, 260))
    static let surface = Color.dynamic(light: .oklch(1, 0, 0), dark: .oklch(0.27, 0.02, 260))
    static let surfaceSunken = Color.dynamic(light: .oklch(0.94, 0.012, 90), dark: .oklch(0.24, 0.018, 260))
    static let ink = Color.dynamic(light: .oklch(0.25, 0.02, 260), dark: .oklch(0.95, 0.01, 90))
    static let inkSoft = Color.dynamic(light: .oklch(0.5, 0.015, 260), dark: .oklch(0.74, 0.015, 260))
    static let inkFaint = Color.dynamic(light: .oklch(0.68, 0.012, 260), dark: .oklch(0.55, 0.015, 260))
    static let line = Color.dynamic(light: .oklch(0.88, 0.012, 90), dark: .oklch(0.36, 0.02, 260))
    static let accent = Color.dynamic(light: .oklch(0.72, 0.09, 260), dark: .oklch(0.78, 0.1, 260))
    static let accentStrong = Color.dynamic(light: .oklch(0.6, 0.11, 260), dark: .oklch(0.85, 0.09, 260))
    static let accentWash = Color.dynamic(light: .oklch(0.93, 0.03, 260), dark: .oklch(0.32, 0.05, 260))
    static let success = Color.dynamic(light: .oklch(0.75, 0.1, 152), dark: .oklch(0.72, 0.12, 152))
    static let successWash = Color.dynamic(light: .oklch(0.93, 0.04, 152), dark: .oklch(0.3, 0.06, 152))
    static let warn = Color.dynamic(light: .oklch(0.8, 0.09, 75), dark: .oklch(0.78, 0.1, 75))
    static let warnWash = Color.dynamic(light: .oklch(0.94, 0.04, 75), dark: .oklch(0.32, 0.06, 75))
    static let danger = Color.dynamic(light: .oklch(0.72, 0.11, 22), dark: .oklch(0.7, 0.14, 22))
    static let dangerWash = Color.dynamic(light: .oklch(0.94, 0.04, 22), dark: .oklch(0.32, 0.07, 22))
    static let codeBg = Color.dynamic(light: .oklch(0.96, 0.008, 90), dark: .oklch(0.19, 0.015, 260))

    /// Text drawn on top of `accent` (e.g. primary button labels) — fixed in both themes,
    /// same as the mockup's un-media-queried `color: oklch(.2 .02 260)` on `.btn-primary`.
    static let onAccent = Color.oklch(0.2, 0.02, 260)
}
