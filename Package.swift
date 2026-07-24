// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FitBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "FitBarKit",
            path: "Sources/FitBarKit",
            resources: [
                .copy("Resources/exercises.json"),
                .copy("Resources/names_ru.json"),
                .copy("Resources/fitbar-icon-app.png"),
                .copy("Resources/fitbar-icon-male.png"),
                .copy("Resources/fitbar-icon-female.png"),
                .copy("Resources/body-male-front.png"),
                .copy("Resources/body-male-back.png"),
                .copy("Resources/body-female-front.png"),
                .copy("Resources/body-female-back.png"),
            ]
        ),
        .executableTarget(
            name: "FitBar",
            dependencies: ["FitBarKit"],
            path: "Sources/FitBar"
        ),
        .executableTarget(
            name: "fitbar-tests",
            dependencies: ["FitBarKit"],
            path: "Tests/FitBarTests"
        ),
    ]
)
