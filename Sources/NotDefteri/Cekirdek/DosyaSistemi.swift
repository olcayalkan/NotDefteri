import AppKit

// MARK: - Kaydetme konumu (Belgeler/NotDefteri)

func notlarKlasoru() -> URL {
    let fm = FileManager.default
    let belgeler = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    let klasor = belgeler.appendingPathComponent("NotDefteri", isDirectory: true)
    if !fm.fileExists(atPath: klasor.path) {
        try? fm.createDirectory(at: klasor, withIntermediateDirectories: true)
    }
    return klasor
}

let kGorsellerKlasorAdi = "Görseller"

/// Bir sayfanın görsellerinin tutulduğu klasör: <sayfa klasörü>/Görseller.
func gorsellerKlasoru(_ sayfaninKlasoru: URL = notlarKlasoru()) -> URL {
    let klasor = sayfaninKlasoru.appendingPathComponent(kGorsellerKlasorAdi, isDirectory: true)
    if !FileManager.default.fileExists(atPath: klasor.path) {
        try? FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
    }
    return klasor
}

// MARK: - Girişte otomatik başlatma (LaunchAgent)

func launchAgentYolu() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.notdefteri.baslangic.plist")
}

func giristeAcikMi() -> Bool {
    FileManager.default.fileExists(atPath: launchAgentYolu().path)
}

func giristeAcmayiAyarla(_ acik: Bool) {
    let yol = launchAgentYolu()
    if acik {
        let calistirilabilirYol = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let icerik: [String: Any] = [
            "Label": "com.notdefteri.baslangic",
            "ProgramArguments": [calistirilabilirYol],
            "RunAtLoad": true
        ]
        try? FileManager.default.createDirectory(at: yol.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let veri = try? PropertyListSerialization.data(fromPropertyList: icerik, format: .xml, options: 0) {
            try? veri.write(to: yol)
        }
        let islem = Process()
        islem.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        islem.arguments = ["load", "-w", yol.path]
        try? islem.run()
    } else {
        let islem = Process()
        islem.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        islem.arguments = ["unload", "-w", yol.path]
        try? islem.run()
        islem.waitUntilExit()
        try? FileManager.default.removeItem(at: yol)
    }
}
