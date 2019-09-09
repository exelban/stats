// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Charts",
    products: [
        .library(name: "Charts", type: .dynamic, targets: ["Charts"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Charts", dependencies: [])
    ],
    swiftLanguageVersions: [5]
)
