// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftLLMOutputValidation",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [
        .library(name: "MomentLLMValidation", targets: ["MomentLLMValidation"]),
        .executable(name: "proposal-demo", targets: ["ProposalDemo"])
    ],
    targets: [
        .target(name: "MomentLLMValidation"),
        .executableTarget(name: "ProposalDemo", dependencies: ["MomentLLMValidation"]),
        .testTarget(name: "MomentLLMValidationTests", dependencies: ["MomentLLMValidation"])
    ]
)
