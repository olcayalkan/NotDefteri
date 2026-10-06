import Foundation

package enum DosyaYoluHatasi: LocalizedError {
    case gecersizYol
    case kokDisinda(URL)
    case sembolikBag(URL)

    package var errorDescription: String? {
        switch self {
        case .gecersizYol: return "Geçersiz dosya yolu."
        case .kokDisinda(let url): return "Yol notlar klasörünün dışında: \(url.path)"
        case .sembolikBag(let url): return "Sembolik bağ içeren yol kullanılamaz: \(url.path)"
        }
    }
}

/// Eksik hedefe izin verir; mevcut bileşenlerde kopuk bağ dahil hiçbir bağı takip etmez.
/// Kökün kendisi çözülür; alt yollar hem çözülmeden hem çözülerek kökle sınırlandırılır.
@discardableResult
package func notlarYolunuDogrula(_ url: URL, kok: URL = notlarKlasoru(), kokDahil: Bool = false) throws -> URL {
    guard url.isFileURL, kok.isFileURL else { throw DosyaYoluHatasi.gecersizYol }
    let taban = kok.standardizedFileURL
    let cozulmusKok = taban.resolvingSymlinksInPath().standardizedFileURL
    let yol = url.standardizedFileURL
    let ust = [taban, cozulmusKok].first { yol.path == $0.path || yol.path.hasPrefix($0.path + "/") }
    guard let ust, kokDahil || yol.path != ust.path else { throw DosyaYoluHatasi.kokDisinda(url) }
    // .. öncesinde kalan bileşenler de denetlenir; symlink/../ ile kontrol atlanamaz.
    let hamUst = [taban, cozulmusKok].first { url.path == $0.path || url.path.hasPrefix($0.path + "/") }
    guard let hamUst else { throw DosyaYoluHatasi.kokDisinda(url) }
    var parca = hamUst
    let parcalar = String(url.path.dropFirst(hamUst.path.count)).split(separator: "/")
    for ad in parcalar {
        if ad == "." { continue }
        if ad == ".." {
            guard parca != hamUst else { throw DosyaYoluHatasi.kokDisinda(url) }
            parca.deleteLastPathComponent()
            continue
        }
        parca.appendPathComponent(String(ad))
        do {
            let bilgi = try FileManager.default.attributesOfItem(atPath: parca.path)
            if bilgi[.type] as? FileAttributeType == .typeSymbolicLink { throw DosyaYoluHatasi.sembolikBag(parca) }
        } catch let hata as NSError where hata.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(hata.code) {
            // Henüz oluşturulmamış hedef; sonraki bileşenler yine denetlenir.
        }
    }
    let cozulmus = yol.resolvingSymlinksInPath().standardizedFileURL
    guard cozulmus.path.hasPrefix(cozulmusKok.path + "/") || kokDahil && cozulmus == cozulmusKok else {
        throw DosyaYoluHatasi.kokDisinda(url)
    }
    return cozulmus
}

/// fileExists kopuk bağlarda false verir; ad seçerken bağ da dolu hedef sayılır.
package func dosyaYoluVarMi(_ url: URL) -> Bool {
    (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
}

package func sayfaHedefiDoluMu(_ url: URL) -> Bool {
    dosyaYoluVarMi(url) || ["md", "MD", "Md", "mD"].contains { dosyaYoluVarMi(url.appendingPathExtension($0)) }
}

// MARK: - Kaydetme konumu (Belgeler/NotDefteri)

package func notlarKlasoru() -> URL {
    let fm = FileManager.default
    #if os(Linux)
    let belgeler = linuxBelgelerKlasoru()
    #else
    let belgeler = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    #endif
    let klasor = belgeler.appendingPathComponent("NotDefteri", isDirectory: true)
    if !fm.fileExists(atPath: klasor.path) {
        try? fm.createDirectory(at: klasor, withIntermediateDirectories: true)
    }
    return klasor
}

#if os(Linux)
private func linuxBelgelerKlasoru() -> URL {
    let ev = FileManager.default.homeDirectoryForCurrentUser
    let ortam = ProcessInfo.processInfo.environment
    if let deger = ortam["XDG_DOCUMENTS_DIR"], let yol = linuxBelgelerYolu(deger, ev: ev) { return yol }
    let config = ortam["XDG_CONFIG_HOME"].flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }
        ?? ev.appendingPathComponent(".config", isDirectory: true)
    if let icerik = try? String(contentsOf: config.appendingPathComponent("user-dirs.dirs"), encoding: .utf8) {
        for satir in icerik.split(whereSeparator: \.isNewline) {
            let parcalar = satir.split(separator: "=", maxSplits: 1)
            guard parcalar.count == 2, parcalar[0].trimmingCharacters(in: .whitespaces) == "XDG_DOCUMENTS_DIR" else { continue }
            if let yol = linuxBelgelerYolu(String(parcalar[1]), ev: ev) { return yol }
        }
    }
    return ev.appendingPathComponent("Documents", isDirectory: true)
}

/// XDG yolunu kabuk çalıştırmadan okur; yalnızca mutlak yol veya $HOME kabul edilir.
private func linuxBelgelerYolu(_ deger: String, ev: URL) -> URL? {
    var yol = deger.trimmingCharacters(in: .whitespaces)
    if yol.hasPrefix("\""), yol.hasSuffix("\""), yol.count >= 2 { yol = String(yol.dropFirst().dropLast()) }
    if yol == "$HOME" || yol.hasPrefix("$HOME/") { yol = ev.path + yol.dropFirst(5) }
    yol = yol.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
    guard yol.hasPrefix("/") else { return nil }
    return URL(fileURLWithPath: yol, isDirectory: true)
}
#endif

package let kGorsellerKlasorAdi = "Görseller"

/// Bir sayfanın görsellerinin tutulduğu klasör: <sayfa klasörü>/Görseller.
package func gorsellerKlasoru(_ sayfaninKlasoru: URL = notlarKlasoru()) -> URL {
    let klasor = sayfaninKlasoru.appendingPathComponent(kGorsellerKlasorAdi, isDirectory: true)
    if !FileManager.default.fileExists(atPath: klasor.path) {
        try? FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
    }
    return klasor
}

// MARK: - Girişte otomatik başlatma (LaunchAgent)

#if os(macOS)
func launchAgentYolu() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.notdefteri.baslangic.plist")
}

package func giristeAcikMi() -> Bool {
    FileManager.default.fileExists(atPath: launchAgentYolu().path)
}

package func giristeAcmayiAyarla(_ acik: Bool) {
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
#elseif os(Linux)
// GTK arayüzü de aynı girişte başlatma işlevlerini kullanır.
private func autostartYolu() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/autostart/notdefteri.desktop")
}

package func giristeAcikMi() -> Bool {
    FileManager.default.fileExists(atPath: autostartYolu().path)
}

package func giristeAcmayiAyarla(_ acik: Bool) {
    let yol = autostartYolu()
    do {
        if acik {
            let komut = try linuxBaslatmaKomutu()
            let icerik = "[Desktop Entry]\nType=Application\nName=NotDefteri\nExec=\(komut)\nTerminal=false\n"
            try FileManager.default.createDirectory(at: yol.deletingLastPathComponent(), withIntermediateDirectories: true)
            try icerik.write(to: yol, atomically: true, encoding: .utf8)
        } else if FileManager.default.fileExists(atPath: yol.path) {
            try FileManager.default.removeItem(at: yol)
        }
    } catch {
        FileHandle.standardError.write(Data("Girişte başlatma ayarlanamadı: \(error.localizedDescription)\n".utf8))
    }
}

/// Desktop Entry Exec değeri: önce komut alıntılama, ardından değer kaçışları.
private func linuxBaslatmaKomutu() throws -> String {
    var yol = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0]).path
    guard !yol.contains("=") else {
        throw NSError(domain: "NotDefteri.Autostart", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Başlatma yolu '=' içeremez."])
    }
    for karakter in ["\\", "\"", "`", "$"] {
        yol = yol.replacingOccurrences(of: karakter, with: "\\" + karakter)
    }
    yol = yol.replacingOccurrences(of: "%", with: "%%").replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\t", with: "\\t")
    return "\"\(yol)\""
}
#endif
