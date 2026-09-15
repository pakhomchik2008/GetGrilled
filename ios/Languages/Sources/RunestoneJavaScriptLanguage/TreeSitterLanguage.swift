import Foundation
import Runestone
import TreeSitterJavaScript

public extension TreeSitterLanguage {
    static var javaScript: TreeSitterLanguage {
        let highlightsQueryURL = Bundle.module.url(forResource: "highlights", withExtension: "scm")!
        let injectionsQueryURL = Bundle.module.url(forResource: "injections", withExtension: "scm")!
        let highlightsQuery = TreeSitterLanguage.Query(contentsOf: highlightsQueryURL)
        let injectionsQuery = TreeSitterLanguage.Query(contentsOf: injectionsQueryURL)
        return TreeSitterLanguage(
            tree_sitter_javascript(),
            highlightsQuery: highlightsQuery,
            injectionsQuery: injectionsQuery
        )
    }
}
