import SwiftUI
import UIKit
import Runestone
import RunestoneJavaScriptLanguage
import RunestonePythonLanguage

/// Minimal Runestone-backed code editor with tree-sitter syntax highlighting for Python/JavaScript.
struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    var language: CodeLanguage

    func makeUIView(context: Context) -> TextView {
        let textView = TextView()
        textView.editorDelegate = context.coordinator
        // Runestone's theme colors the gutter/text/selection but never the view's own
        // background, so without this it stays UIView's default white in dark mode.
        textView.backgroundColor = .secondarySystemBackground
        textView.insertionPointColor = .label
        textView.selectionBarColor = .label
        textView.selectionHighlightColor = UIColor.label.withAlphaComponent(0.2)
        textView.showLineNumbers = true
        textView.lineSelectionDisplayType = .line
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.characterPairs = [
            BasicCharacterPair(leading: "(", trailing: ")"),
            BasicCharacterPair(leading: "{", trailing: "}"),
            BasicCharacterPair(leading: "[", trailing: "]"),
            BasicCharacterPair(leading: "\"", trailing: "\""),
            BasicCharacterPair(leading: "'", trailing: "'")
        ]
        textView.setLanguageMode(TreeSitterLanguageMode(language: treeSitterLanguage(for: language)))
        textView.text = text
        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        if context.coordinator.language != language {
            context.coordinator.language = language
            textView.setLanguageMode(TreeSitterLanguageMode(language: treeSitterLanguage(for: language)))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, language: language)
    }

    private func treeSitterLanguage(for language: CodeLanguage) -> TreeSitterLanguage {
        switch language {
        case .python: return .python
        case .javascript: return .javaScript
        }
    }

    final class Coordinator: NSObject, TextViewDelegate {
        var text: Binding<String>
        var language: CodeLanguage

        init(text: Binding<String>, language: CodeLanguage) {
            self.text = text
            self.language = language
        }

        func textViewDidChange(_ textView: TextView) {
            text.wrappedValue = textView.text
        }
    }
}
