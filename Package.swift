// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PasskeyPlugin",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "PasskeyPlugin",
            targets: ["PasskeyPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "PasskeyPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/PasskeyPlugin"),
        .testTarget(
            name: "PasskeyPluginTests",
            dependencies: ["PasskeyPlugin"],
            path: "ios/Tests/PasskeyPluginTests")
    ]
)