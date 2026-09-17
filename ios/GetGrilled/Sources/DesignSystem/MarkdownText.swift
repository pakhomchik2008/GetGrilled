import SwiftUI

/// Renders interviewer message text with light inline Markdown — **bold** for key terms,
/// `backticks` for code/API names — so the prompts can emphasize the one word that matters
/// without a full rich-text pipeline. Falls back to plain text if parsing fails.
struct MarkdownText: View {
    let content: String
    var size: CGFloat
    var weight: Font.OnestWeight = .regular
    var color: Color

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        guard var parsed = try? AttributedString(markdown: content, options: options) else {
            var plain = AttributedString(content)
            plain.font = .onest(size, weight)
            plain.foregroundColor = color
            return plain
        }

        for run in parsed.runs {
            let intent = run.inlinePresentationIntent
            if intent?.contains(.code) == true {
                parsed[run.range].font = .plexMono(size - 1, .medium)
                parsed[run.range].foregroundColor = DesignTokens.accentStrong
            } else if intent?.contains(.stronglyEmphasized) == true {
                parsed[run.range].font = .onest(size, .bold)
                parsed[run.range].foregroundColor = color
            } else {
                parsed[run.range].font = .onest(size, weight)
                parsed[run.range].foregroundColor = color
            }
        }
        return parsed
    }
}
