// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SockApp",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SockApp",
            targets: ["SockApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "SockApp",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk")
            ])
    ]
)
