// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PlatformDownloadsNativeTests",
  platforms: [.macOS(.v13)],
  products: [],
  targets: [
    .target(
      name: "PlatformDownloadsNative",
      path: "Classes",
      exclude: ["PlatformDownloadsPlugin.swift"],
      sources: [
        "DownloadIntegrity.swift",
        "DownloadResumeDataStore.swift",
        "PlatformDownloadModels.swift",
      ]
    ),
    .testTarget(
      name: "PlatformDownloadsNativeTests",
      dependencies: ["PlatformDownloadsNative"],
      path: "Tests"
    ),
  ]
)
