// swift-tools-version:5.9
import PackageDescription

var targets: [Target] = [
    .target(name: "NotDefteriCekirdek", path: "Sources/NotDefteriCekirdek"),
    .testTarget(name: "NotDefteriCekirdekTests", dependencies: ["NotDefteriCekirdek"],
                path: "Tests/NotDefteriCekirdekTests")
]

#if os(macOS)
targets += [
    .target(name: "NotDefteriMac", dependencies: ["NotDefteriCekirdek"],
            path: "Sources/NotDefteriMac"),
    .executableTarget(name: "NotDefteri", dependencies: ["NotDefteriMac"],
                      path: "Sources/Calistirici"),
    .testTarget(name: "NotDefteriMacTests", dependencies: ["NotDefteriCekirdek", "NotDefteriMac"],
                path: "Tests/NotDefteriMacTests")
]
#endif

// GTK hedefleri Linux'ta derlenir. NOTDEFTERI_GTK=1 ile macOS'ta da (Homebrew gtk4) derlenir:
// CodeQL Swift'i yalnızca macOS'ta çözümlediği için GTK kodu bu yolla taranır.
#if os(Linux)
let gtkHedefleri = true
#else
let gtkHedefleri = Context.environment["NOTDEFTERI_GTK"] == "1"
#endif

if gtkHedefleri {
    targets += [
        .systemLibrary(name: "CGtk", pkgConfig: "gtk4", providers: [.apt(["libgtk-4-dev"]), .brew(["gtk4"])]),
        .target(name: "NotDefteriLinux", dependencies: ["NotDefteriCekirdek", "CGtk"]),
        .testTarget(name: "NotDefteriLinuxTests", dependencies: ["NotDefteriLinux", "CGtk"],
                    path: "Tests/NotDefteriLinuxTests")
    ]
}

#if os(Linux)
targets += [
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
