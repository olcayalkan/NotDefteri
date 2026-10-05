import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

package struct SayfaDosyasi {
    package let url: URL
    package let goreliYol: String
    package let boyut: Int64
    package var klasor: String { NSString(string: goreliYol).deletingLastPathComponent }
    package var metinMi: Bool { SayfaDosyalari.metinUzantilari.contains(url.pathExtension.lowercased()) }
    package var kodMu: Bool { metinMi && url.pathExtension.lowercased() != "txt" }
}

package enum SayfaDosyasiOkuma {
    case metin(String)
    case buyuk
    case ikili
}

/// UI içermez. Çağıran toplama ve okumayı arka plan kuyruğunda yürütür.
package enum SayfaDosyalari {
    static let metinUzantilari: Set<String> = ["go", "swift", "py", "js", "ts", "json", "sh", "sql", "html", "css", "txt", "yaml", "yml", "toml", "mod", "sum"]
    static let boyutSiniri = 1_048_576

    private static func hata(_ mesaj: String) -> NSError {
        NSError(domain: "NotDefteri.SayfaDosyalari", code: 1, userInfo: [NSLocalizedDescriptionKey: mesaj])
    }

    /// Her bileşen kökten itibaren openat/O_NOFOLLOW ile açılır. Kontrol ile okuma
    /// arasında bir klasör sembolik bağa çevrilse de içerik dışarıdan okunamaz.
    private static func dosyayiAc(_ url: URL, kok: URL) throws -> Int32 {
        guard url.isFileURL, kok.isFileURL, !url.pathComponents.contains(".."),
              !kok.pathComponents.contains("..") else { throw hata("Geçersiz dosya yolu.") }
        let yol = url.standardizedFileURL.path
        let taban = kok.standardizedFileURL.path
        guard yol == taban || yol.hasPrefix(taban + "/") else {
            throw hata("Dosya notlar klasörünün dışında.")
        }
        let goreli = String(yol.dropFirst(taban.count)).split(separator: "/")
        guard goreli.allSatisfy({ !$0.hasPrefix(".") && $0 != "Görseller" && $0 != "node_modules" }) else {
            throw hata("Bu klasördeki dosyalar görüntülenemez.")
        }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { throw hata("Dosya yolu açılamadı.") }
        let parcalar = url.standardizedFileURL.pathComponents.dropFirst()
        for (sira, parca) in parcalar.enumerated() {
            let bayrak = O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC | (sira < parcalar.count - 1 ? O_DIRECTORY : 0)
            let yeni = parca.withCString { openat(fd, $0, bayrak) }
            close(fd)
            guard yeni >= 0 else { throw hata("Dosyaya erişilemiyor veya yol sembolik bağ içeriyor.") }
            fd = yeni
        }
        return fd
    }

    /// Finder işlemi dahil her erişim öncesi aynı sınır ve tür kontrolü kullanılır.
    package static func dogrula(_ url: URL, kok: URL) throws -> (tur: mode_t, boyut: Int64) {
        if url.standardizedFileURL == kok.standardizedFileURL {
            let fd = try dosyayiAc(url, kok: kok)
            defer { close(fd) }
            return try bilgiyiOku(fd)
        }
        // Son dosyayı açmadan stat al: okuma izni olmayan dosya da listelenir;
        // tıklamada oku() erişim hatasını gösterir. Son bağ asla takip edilmez.
        let fd = try dosyayiAc(url.deletingLastPathComponent(), kok: kok)
        defer { close(fd) }
        guard !url.lastPathComponent.hasPrefix("."), url.lastPathComponent != "Görseller",
              url.lastPathComponent != "node_modules" else { throw hata("Bu dosya görüntülenemez.") }
        var bilgi = stat()
        guard url.lastPathComponent.withCString({ fstatat(fd, $0, &bilgi, AT_SYMLINK_NOFOLLOW) }) == 0 else {
            throw hata("Dosya bilgisi okunamadı.")
        }
        return try bilgiyiAyir(bilgi)
    }

    private static func bilgiyiOku(_ fd: Int32) throws -> (tur: mode_t, boyut: Int64) {
        var bilgi = stat()
        guard fstat(fd, &bilgi) == 0 else { throw hata("Dosya bilgisi okunamadı.") }
        return try bilgiyiAyir(bilgi)
    }

    private static func bilgiyiAyir(_ bilgi: stat) throws -> (tur: mode_t, boyut: Int64) {
        let tur = bilgi.st_mode & mode_t(S_IFMT)
        guard tur == mode_t(S_IFREG) || tur == mode_t(S_IFDIR) else { throw hata("Bu dosya türü görüntülenemez.") }
        return (tur, Int64(bilgi.st_size))
    }

    package static func oku(_ url: URL, kok: URL) throws -> SayfaDosyasiOkuma {
        let fd = try dosyayiAc(url, kok: kok)
        let dosya = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? dosya.close() }
        let bilgi = try bilgiyiOku(fd)
        guard bilgi.tur == mode_t(S_IFREG) else { throw hata("Bu öğe bir metin dosyası değil.") }
        guard bilgi.boyut <= boyutSiniri else { return .buyuk }
        // Dosya kontrol sonrasında büyürse de belleğe en fazla sınır + 1 bayt alınır.
        var veri = Data()
        while veri.count <= boyutSiniri {
            guard let parca = try dosya.read(upToCount: min(65_536, boyutSiniri + 1 - veri.count)), !parca.isEmpty else { break }
            veri.append(parca)
        }
        guard veri.count <= boyutSiniri else { return .buyuk }
        guard !veri.contains(where: { $0 < 32 && ![9, 10, 12, 13].contains($0) || $0 == 127 }),
              let metin = String(data: veri, encoding: .utf8) else { return .ikili }
        return .metin(metin)
    }

    package static func topla(sayfaKlasoru: URL, kok: URL) -> [SayfaDosyasi] {
        let taban = sayfaKlasoru.standardizedFileURL
        guard (try? dogrula(taban, kok: kok).tur) == mode_t(S_IFDIR) else { return [] }
        let sonuc = klasoruTara(taban, taban: taban, kok: kok, seviye: 0)
        return sonuc.dosyalar.sorted {
            if $0.klasor != $1.klasor { return $0.klasor.localizedStandardCompare($1.klasor) == .orderedAscending }
            return $0.goreliYol.localizedStandardCompare($1.goreliYol) == .orderedAscending
        }
    }

    /// Markdown içeren alt dallar bir başka sayfaya aittir; o dalın ekleri alınmaz.
    private static func klasoruTara(_ klasor: URL, taban: URL, kok: URL, seviye: Int) -> (mdVar: Bool, dosyalar: [SayfaDosyasi]) {
        guard let ogeler = try? FileManager.default.contentsOfDirectory(at: klasor,
            includingPropertiesForKeys: [.isPackageKey], options: [.skipsHiddenFiles]) else { return (true, []) }
        if seviye > 0, ogeler.contains(where: { $0.pathExtension.lowercased() == "md" }) { return (true, []) }
        var dosyalar: [SayfaDosyasi] = []
        for url in ogeler.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            if seviye == 0, dosyalar.count == 200 { break }
            guard let bilgi = try? dogrula(url, kok: kok) else { continue }
            let paket = (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true || url.pathExtension.lowercased() == "app"
            if bilgi.tur == mode_t(S_IFDIR), !paket {
                guard seviye < 3 else { continue }
                let alt = klasoruTara(url, taban: taban, kok: kok, seviye: seviye + 1)
                if seviye > 0, alt.mdVar { return (true, []) }
                if !alt.mdVar { dosyalar.append(contentsOf: alt.dosyalar.prefix(max(0, 200 - dosyalar.count))) }
            } else if url.pathExtension.lowercased() != "md", dosyalar.count < 200 {
                let yol = String(url.standardizedFileURL.path.dropFirst(taban.path.count + 1))
                dosyalar.append(SayfaDosyasi(url: url, goreliYol: yol, boyut: bilgi.boyut))
            }
        }
        return (false, dosyalar)
    }
}
