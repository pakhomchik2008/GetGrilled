// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Languages",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "RunestoneJavaScriptLanguage", targets: ["RunestoneJavaScriptLanguage"]),
        .library(name: "RunestonePythonLanguage", targets: ["RunestonePythonLanguage"])
    ],
    dependencies: [
        .package(url: "https://github.com/simonbs/Runestone", from: "0.4.0")
    ],
    targets: [
        .target(name: "TreeSitterJavaScript", cSettings: [.headerSearchPath("src"), .unsafeFlags(["-w"])]),
        .target(
            name: "RunestoneJavaScriptLanguage",
            dependencies: ["TreeSitterJavaScript", .product(name: "Runestone", package: "Runestone")],
            resources: [.copy("highlights.scm"), .copy("injections.scm")]
        ),
        .target(name: "TreeSitterPython", cSettings: [.unsafeFlags(["-w"])]),
        .target(
            name: "RunestonePythonLanguage",
            dependencies: ["TreeSitterPython", .product(name: "Runestone", package: "Runestone")],
            resources: [.copy("highlights.scm")]
        )
    ]
)
