// swift-tools-version: 5.9
// This Package.swift allows building the app with Swift Package Manager.
// For Xcode: Open this directory and create a new Xcode project, then add
// all files from InMarketingApp/ to the project.

import PackageDescription

let package = Package(
    name: "InMarketingApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "InMarketingApp",
            path: "InMarketingApp"
        ),
        .testTarget(
            name: "InMarketingAppTests",
            dependencies: ["InMarketingApp"],
            path: "Tests"
        ),
    ]
)
