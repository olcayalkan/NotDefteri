import Foundation

/// Sayfa sürümleri: sayfa klasöründeki gizli `.gecmis/<yyyy-MM-dd_HH-mm-ss>.md` dosyaları.
/// Klasör sayfayla birlikte taşındığı/silindiği için ek bakım gerekmez; `.gecmis`
/// gizli olduğundan ağaç taraması (skipsHiddenFiles) onu görmez.
package struct SayfaSurumu {
    package let url: URL
    package let tarih: Date
}

package enum SayfaGecmisi {
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

    package static func klasor(_ icerikURL: URL) -> URL {
        sayfaKlasoru(icerikURL).appendingPathComponent(klasorAdi, isDirectory: true)
    }

    /// Başarı: yeni sürüm URL'si; nil: aynı içerik veya olağan kayıt eşiği nedeniyle mevcut sürüm korundu.
    /// Zorla kayıtta nil yalnızca aynı içeriğin zaten saklandığını belirtir. Sonuç UI kuyruğuna teslim edilir.
    package static func kaydet(metin: String, icerikURL: URL, zorla: Bool = false,
                               kok: URL = notlarKlasoru(),
                               tamamlandi: ((Result<URL?, Error>) -> Void)? = nil) {
        kuyruk.async {
            let sonuc = Result { try surumuKaydet(metin: metin, icerikURL: icerikURL, zorla: zorla, kok: kok) }
            if let tamamlandi { Platform.anaIsParcaciginda { tamamlandi(sonuc) } }
        }
    }

    private static func surumuKaydet(metin: String, icerikURL: URL, zorla: Bool, kok: URL) throws -> URL? {
        let fm = FileManager.default
        try notlarYolunuDogrula(icerikURL, kok: kok)
        guard fm.fileExists(atPath: icerikURL.path) else { throw CocoaError(.fileReadNoSuchFile) }
        let dizin = klasor(icerikURL)
        try notlarYolunuDogrula(dizin, kok: kok)
        let b = bicim()
        let mevcut = try surumleriOku(dizin, bicim: b)
        // Son sürüm okunamıyorsa karşılaştırma atlanır; aksi hâlde geçmiş sonsuza dek donar.
        if let son = mevcut.first, let eski = try? surumMetniniOku(son, kok: kok) {
            if eski == metin { return nil }
            if !zorla, Date().timeIntervalSince(son.tarih) < enAzAralik,
               degisimOrani(eski, metin) <= esikOran { return nil }
        }
        // Kuyruk beklerken silinen/taşınan sayfanın eski klasörünü yeniden yaratma.
        try notlarYolunuDogrula(icerikURL, kok: kok)
        guard fm.fileExists(atPath: icerikURL.path) else { throw CocoaError(.fileReadNoSuchFile) }
        let sayfaDizini = sayfaKlasoru(icerikURL)
        if !dosyaYoluVarMi(sayfaDizini) { try fm.createDirectory(at: sayfaDizini, withIntermediateDirectories: false) }
        if !dosyaYoluVarMi(dizin) { try fm.createDirectory(at: dizin, withIntermediateDirectories: false) }
        var an = Date()
        if let son = mevcut.first, an <= son.tarih { an = son.tarih.addingTimeInterval(1) }
        var hedef = dizin.appendingPathComponent(b.string(from: an) + ".md")
        while dosyaYoluVarMi(hedef) {
            an.addTimeInterval(1)
            hedef = dizin.appendingPathComponent(b.string(from: an) + ".md")
        }
        try notlarYolunuDogrula(hedef, kok: kok)
        try metin.write(to: hedef, atomically: true, encoding: .utf8)
        eskileriniSil(dizin, bicim: b, kok: kok)
        return hedef
    }

    package static func surumMetniniOku(_ surum: SayfaSurumu, kok: URL = notlarKlasoru()) throws -> String {
        try notlarYolunuDogrula(surum.url, kok: kok)
        return try String(contentsOf: surum.url, encoding: .utf8)
    }

    /// Yeniden eskiye sıralı sürümler; ana thread'i bloklamamak için kuyrukta okunur.
    package static func listele(_ icerikURL: URL, tamamlandi: @escaping ([SayfaSurumu]) -> Void) {
        kuyruk.async {
            let sonuc = (try? notlarYolunuDogrula(klasor(icerikURL))) != nil
                ? (try? surumleriOku(klasor(icerikURL), bicim: bicim())) ?? [] : []
            Platform.anaIsParcaciginda { tamamlandi(sonuc) }
        }
    }

    private static func surumleriOku(_ dizin: URL, bicim b: DateFormatter) throws -> [SayfaSurumu] {
        guard dosyaYoluVarMi(dizin) else { return [] }
        let adlar = try FileManager.default.contentsOfDirectory(atPath: dizin.path)
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
    private static func eskileriniSil(_ dizin: URL, bicim b: DateFormatter, kok: URL) {
        guard let surumler = try? surumleriOku(dizin, bicim: b) else { return }
        guard surumler.count > enFazlaSurum else { return }
        let onek = dizin.standardizedFileURL.path + "/"
        for s in surumler.dropFirst(enFazlaSurum) {
            let hedef = s.url.standardizedFileURL
            guard hedef.path.hasPrefix(onek), hedef.deletingLastPathComponent().lastPathComponent == klasorAdi,
                  (try? hedef.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true else { continue }
            guard (try? notlarYolunuDogrula(hedef, kok: kok)) != nil else { continue }
            try? FileManager.default.removeItem(at: hedef)
        }
    }
}
