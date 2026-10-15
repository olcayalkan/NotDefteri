// swift-tools-version:5.9
import PackageDescription

var targets: [Target] = [
    .target(name: "NotDefteriCekirdek", path: "Sources/NotDefteri/Cekirdek"),
    .testTarget(name: "NotDefteriCekirdekTests", dependencies: ["NotDefteriCekirdek"],
                path: "Tests/NotDefteriCekirdekTests")
]

#if os(macOS)
targets += [
    .target(name: "NotDefteriMac", dependencies: ["NotDefteriCekirdek"],
            path: "Sources/NotDefteri", exclude: ["Cekirdek"]),
    .executableTarget(name: "NotDefteri", dependencies: ["NotDefteriMac"],
                      path: "Sources/Calistirici"),
    .testTarget(name: "NotDefteriMacTests", dependencies: ["NotDefteriCekirdek", "NotDefteriMac"],
                path: "Tests/NotDefteriMacTests")
]
#endif

#if os(Linux)
targets += [
    .systemLibrary(name: "CGtk", pkgConfig: "gtk4", providers: [.apt(["libgtk-4-dev"])]),
    .target(name: "NotDefteriLinux", dependencies: ["NotDefteriCekirdek", "CGtk"]),
    .testTarget(name: "NotDefteriLinuxTests", dependencies: ["NotDefteriLinux", "CGtk"],
                path: "Tests/NotDefteriLinuxTests"),
    .executableTarget(name: "NotDefteri", dependencies: ["NotDefteriLinux"],
                      path: "Sources/Calistirici")
]
#endif

let package = Package(
    name: "NotDefteri",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "NotDefteri", targets: ["NotDefteri"])],
    targets: targets,
    swiftLanguageVersions: [.v5]
)
