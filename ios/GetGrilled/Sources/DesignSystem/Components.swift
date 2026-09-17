import SwiftUI

/// Shared building blocks matching the approved Design System v2 web mockup 1:1 —
/// see the `.field-label`, `.segmented`, `.btn-*`, `.fake-input`, `.pill`, `.card`,
/// `.ring` classes in the mockup's CSS.

/// `.field-label` — small uppercase caption above a form field.
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.onest(11.5, .bold))
            .tracking(0.4)
            .foregroundStyle(DesignTokens.inkFaint)
    }
}

/// `.fake-input` — the sunken rounded field background used for text fields.
struct FakeFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.onest(15))
            .foregroundStyle(DesignTokens.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(DesignTokens.surfaceSunken, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(DesignTokens.line, lineWidth: 1))
    }
}

extension View {
    func fakeFieldStyle() -> some View { modifier(FakeFieldBackground()) }
}

/// `.segmented` — pill-shaped segmented control with a sunken track. The selected pill is one
/// shared shape that slides between options (`matchedGeometryEffect`) rather than cross-fading,
/// so the control reads as one physical thumb moving — not two states swapping.
struct SegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(MotionTokens.standard(reduceMotion: reduceMotion)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.onest(13, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(selection == option ? DesignTokens.ink : DesignTokens.inkSoft)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(DesignTokens.surface)
                                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "thumb", in: namespace)
                            }
                        }
                }
            }
        }
        .padding(3)
        .background(DesignTokens.surfaceSunken, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignTokens.line, lineWidth: 1))
    }
}

/// `.btn-primary` — pill-radius accent button with dark-on-accent label text. Presses respond
/// on touch-down (SwiftUI's `isPressed` already fires there) with an instant scale, not just a
/// fade, so the press reads as physical contact — and springs back rather than cutting.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.onest(14.5, .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(DesignTokens.onAccent)
            .background(DesignTokens.accent, in: RoundedRectangle(cornerRadius: 12))
            .opacity(!isEnabled ? 0.5 : (configuration.isPressed ? 0.85 : 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(MotionTokens.momentum(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

/// `.btn-secondary` — sunken surface button with a hairline border.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.onest(14.5, .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(DesignTokens.ink)
            .background(DesignTokens.surfaceSunken, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignTokens.line, lineWidth: 1))
            .opacity(!isEnabled ? 0.5 : (configuration.isPressed ? 0.85 : 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(MotionTokens.momentum(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var ggPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var ggSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// `.pill` — small status badge, success/warn/danger tones.
struct StatusPill: View {
    enum Tone { case success, warn, danger, neutral }
    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.onest(11, .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    private var background: Color {
        switch tone {
        case .success: return DesignTokens.successWash
        case .warn: return DesignTokens.warnWash
        case .danger: return DesignTokens.dangerWash
        case .neutral: return DesignTokens.surface
        }
    }

    private var foreground: Color {
        switch tone {
        case .success: return DesignTokens.success
        case .warn: return DesignTokens.warn
        case .danger: return DesignTokens.danger
        case .neutral: return DesignTokens.inkFaint
        }
    }
}

/// `.card` / `.round-summary-card` / `.plan-card` — sunken rounded container.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(DesignTokens.surfaceSunken, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DesignTokens.line, lineWidth: 1))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}

/// `.ring` — conic-gradient percentage ring used on plan cards.
struct RingProgress: View {
    let percent: Int
    var size: CGFloat = 56
    var big: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(DesignTokens.line, lineWidth: big ? 8 : 4)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(DesignTokens.accent, style: StrokeStyle(lineWidth: big ? 8 : 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(MotionTokens.standard(reduceMotion: reduceMotion), value: percent)
            Text("\(percent)%")
                .font(.onest(big ? 18 : 12, .bold))
                .foregroundStyle(DesignTokens.ink)
                .contentTransition(.numericText())
                .animation(MotionTokens.standard(reduceMotion: reduceMotion), value: percent)
        }
        .frame(width: size, height: size)
    }
}

/// `.round-progress` — the row of round segments (done/active/upcoming) at the top of a round.
struct RoundProgressBar: View {
    let total: Int
    let currentOrder: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < currentOrder ? DesignTokens.success : (index == currentOrder ? DesignTokens.accent : DesignTokens.line))
                    .frame(height: 5)
            }
        }
        .animation(MotionTokens.standard(reduceMotion: reduceMotion), value: currentOrder)
    }
}

/// Press-scale for small icon/pill controls that don't have their own `ButtonStyle` — instant
/// down-scale on touch, spring release, matching the primary/secondary button feel.
struct IconPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(MotionTokens.momentum(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

/// `.speaker-btn` — the small circular TTS toggle tucked into a speech bubble's corner.
struct NarratorSpeakerButton: View {
    @ObservedObject var narrator: Narrator

    var body: some View {
        Button {
            if narrator.isSpeaking {
                narrator.stop()
            } else if narrator.isMuted {
                narrator.isMuted = false
                narrator.replay()
            } else {
                narrator.isMuted = true
            }
        } label: {
            Image(systemName: narrator.isMuted ? "speaker.slash.fill" : (narrator.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2"))
                .font(.system(size: 10))
                .foregroundStyle(DesignTokens.inkFaint)
                .frame(width: 22, height: 22)
                .background(DesignTokens.surface, in: Circle())
                .overlay(Circle().stroke(DesignTokens.line, lineWidth: 1))
        }
        .buttonStyle(IconPressStyle())
    }
}

/// `.chip` — small pill action button (Not sure / Repeat question / Skip round).
struct ChipButton: View {
    let title: String
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.onest(11.5, .semibold))
                .foregroundStyle(DesignTokens.inkSoft)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(DesignTokens.surfaceSunken, in: Capsule())
                .overlay(Capsule().stroke(DesignTokens.line, lineWidth: 1))
        }
        .buttonStyle(IconPressStyle())
        .disabled(disabled)
    }
}
