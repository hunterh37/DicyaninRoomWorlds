// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DicyaninRoomWorlds",
    platforms: [
        .visionOS(.v2),
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "DicyaninRoomWorlds", targets: ["DicyaninRoomWorlds"])
    ],
    targets: [
        .target(name: "DicyaninRoomWorlds"),
        .testTarget(name: "DicyaninRoomWorldsTests", dependencies: ["DicyaninRoomWorlds"])
    ]
)
