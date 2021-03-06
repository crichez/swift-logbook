// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Logbook",
    platforms: [
        .macOS(.v11),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v8),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Logbook",
            targets: ["Logbook"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections", branch: "feature/SortedCollections"),
        .package(url: "https://github.com/apple/swift-system", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Logbook",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SortedCollections", package: "swift-collections"),
                .product(name: "SystemPackage", package: "swift-system"),
            ]),
        .testTarget(
            name: "LogbookTests",
            dependencies: [
                "Logbook",
                .product(name: "SortedCollections", package: "swift-collections"),
            ]),
    ]
)
