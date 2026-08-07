// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TuTuMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TuTuMac",
            path: "Sources/TuTuMac"
        )
    ]
)
