import Foundation

/// Sayfa sürümleri: sayfa klasöründeki gizli `.gecmis/<yyyy-MM-dd_HH-mm-ss>.md` dosyaları.
/// Klasör sayfayla birlikte taşındığı/silindiği için ek bakım gerekmez; `.gecmis`
/// gizli olduğundan ağaç taraması (skipsHiddenFiles) onu görmez.
struct SayfaSurumu {
    let url: URL
    let tarih: Date
}

enum SayfaGecmisi {
    static let klasorAdi = ".gecmis"
    static let enAzAralik: TimeInterval = 600
    static let enFazlaSurum = 50
    private static let esikOran = 0.2
    /// Seri kuyruk: yazımlar sırayla işlenir ve ana thread'i bekletmez.
    private static let kuyruk = DispatchQueue(label: "notdefteri.sayfagecmisi", qos: .utility)

    private static func bicim() -> DateFormatter {
        let b = DateFormatter()
        b.locale = Locale(identifier: "en_US_POSIX")
        b.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return b
    }

    static func klasor(_ icerikURL: URL) -> URL {
        sayfaKlasoru(icerikURL).appendingPathComponent(klasorAdi, isDirectory: true)
    }

    /// Başarılı kayıttan sonra çağrılır; hata sessizce yutulur (kayıt zaten başarılı).
    /// `zorla`: zaman/değişim şartlarına bakmadan (aynı içerik değilse) sürüm saklar.
    static func kaydet(metin: String, icerikURL: URL, zorla: Bool = false) {
        kuyruk.async {
            let fm = FileManager.default
            let dizin = klasor(icerikURL)
            if (try? dizin.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true { return }
            let b = bicim()
            let mevcut = surumleriOku(dizin, bicim: b)
            if let son = mevcut.first, let eski = try? String(contentsOf: son.url, encoding: .utf8) {
                if eski == metin { return }
                if !zorla, Date().timeIntervalSince(son.tarih) < enAzAralik,
                   degisimOrani(eski, metin) <= esikOran { return }
            }
            // Sayfa kuyruk beklerken taşınmış/silinmiş olabilir; eski klasörü hayalet olarak yeniden yaratma.
            guard fm.fileExists(atPath: icerikURL.path) else { return }
            let sayfaDizini = sayfaKlasoru(icerikURL)
            // Eski düz notta "Ad/" henüz yoksa (not dosyası var) tek başına oluşturulur; ara klasör asla.
            if !fm.fileExists(atPath: sayfaDizini.path), (try? fm.createDirectory(at: sayfaDizini, withIntermediateDirectories: false)) == nil { return }
            if !fm.fileExists(atPath: dizin.path), (try? fm.createDirectory(at: dizin, withIntermediateDirectories: false)) == nil { return }
            var an = Date()
            if let son = mevcut.first, an <= son.tarih { an = son.tarih.addingTimeInterval(1) }
            var hedef = dizin.appendingPathComponent(b.string(from: an) + ".md")
            while fm.fileExists(atPath: hedef.path) {
                an.addTimeInterval(1)
                hedef = dizin.appendingPathComponent(b.string(from: an) + ".md")
            }
            guard (try? metin.write(to: hedef, atomically: true, encoding: .utf8)) != nil else { return }
            eskileriniSil(dizin, bicim: b)
        }
    }

    /// Yeniden eskiye sıralı sürümler; ana thread'i bloklamamak için kuyrukta okunur.
    static func listele(_ icerikURL: URL, tamamlandi: @escaping ([SayfaSurumu]) -> Void) {
        kuyruk.async {
            let sonuc = surumleriOku(klasor(icerikURL), bicim: bicim())
            DispatchQueue.main.async { tamamlandi(sonuc) }
        }
    }

    private static func surumleriOku(_ dizin: URL, bicim b: DateFormatter) -> [SayfaSurumu] {
        guard let adlar = try? FileManager.default.contentsOfDirectory(atPath: dizin.path) else { return [] }
        return adlar.compactMap { ad -> SayfaSurumu? in
            guard ad.hasSuffix(".md"), let tarih = b.date(from: String(ad.dropLast(3))) else { return nil }
            return SayfaSurumu(url: dizin.appendingPathComponent(ad), tarih: tarih)
        }.sorted { $0.tarih > $1.tarih }
    }

    /// Ortak ön ek ve son ek dışında kalan kısmın uzunluğa oranı; tek geçişte, O(n).
    private static func degisimOrani(_ a: String, _ b: String) -> Double {
        let x = Array(a.utf16), y = Array(b.utf16)
        let enAz = min(x.count, y.count)
        var on = 0
        while on < enAz, x[on] == y[on] { on += 1 }
        var son = 0
        while son < enAz - on, x[x.count - 1 - son] == y[y.count - 1 - son] { son += 1 }
        let uzun = max(x.count, y.count)
        return uzun == 0 ? 0 : Double(uzun - on - son) / Double(uzun)
    }

    /// Yalnızca `.gecmis` altındaki, gerçek (sembolik olmayan) sürüm dosyalarını siler.
    private static func eskileriniSil(_ dizin: URL, bicim b: DateFormatter) {
        let surumler = surumleriOku(dizin, bicim: b)
        guard surumler.count > enFazlaSurum else { return }
        let onek = dizin.standardizedFileURL.path + "/"
        for s in surumler.dropFirst(enFazlaSurum) {
            let hedef = s.url.standardizedFileURL
            guard hedef.path.hasPrefix(onek), hedef.deletingLastPathComponent().lastPathComponent == klasorAdi,
                  (try? hedef.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true else { continue }
            try? FileManager.default.removeItem(at: hedef)
        }
    }
}
