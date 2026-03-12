// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClassFoxNative",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .executable(
            name: "ClassFoxNative",
            targets: ["ClassFoxNative"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "ClassFoxNative",
            path: "Sources/ClassFoxNative"
        ),
    ]
)
