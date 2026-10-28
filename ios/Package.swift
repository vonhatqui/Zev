// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Zev",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Zev",
            targets: ["Zev"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Zev",
            dependencies: [],
            path: "Zev"
        ),
    ]
)
