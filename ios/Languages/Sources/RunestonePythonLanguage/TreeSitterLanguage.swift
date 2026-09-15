import Foundation
import Runestone
import TreeSitterPython

public extension TreeSitterLanguage {
    static var python: TreeSitterLanguage {
        let highlightsQueryURL = Bundle.module.url(forResource: "highlights", withExtension: "scm")!
        let highlightsQuery = TreeSitterLanguage.Query(contentsOf: highlightsQueryURL)
        return TreeSitterLanguage(
            tree_sitter_python(),
            highlightsQuery: highlightsQuery
        )
    }
}
