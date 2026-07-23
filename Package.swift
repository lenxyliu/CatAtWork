// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CatAtWork",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CatAtWork", targets: ["CatAtWork"]),
        .library(name: "CatAtWorkCore", targets: ["CatAtWorkCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(name: "CatAtWorkCore"),
        .executableTarget(
            name: "CatAtWork",
            dependencies: [
                "CatAtWorkCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [
                .copy("Resources/DefaultPet.catpet"),
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/AppIcon.iconset"),
                .copy("Resources/README.txt"),
            ]
        ),
        .testTarget(name: "CatAtWorkCoreTests", dependencies: ["CatAtWorkCore"]),
    ]
)
