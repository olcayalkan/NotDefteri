import Foundation

/// Dosyadaki frontmatter bloğu `kaynak`ta ham durur; yalnızca bilinen alanlar güncellenir,
/// bilinmeyen satırlar (ör. Obsidian tags/aliases) sırası ve yazılışıyla korunur.
package struct SayfaUstbilgisi: Equatable {
    package var genislik = ""
    package var yazi = ""
    package var kaynak = ""
    var kaynakGenislik = ""
    var kaynakYazi = ""

    package init() {}

    package var markdown: String {
        if genislik == kaynakGenislik, yazi == kaynakYazi { return kaynak }
        let satirSonu = kaynak.contains("\r\n") ? "\r\n" : "\n"
        let yeni = ["genislik": genislik, "yazi": yazi]
        var yazildi = Set<String>()
        var satirlar: [String] = []
        let kaynakSatirlari = kaynak.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        if let kapanis = kaynakSatirlari.lastIndex(of: "---"), kapanis > 0 {
            for satir in kaynakSatirlari[1..<kapanis] {
                if let anahtar = ustbilgiAnahtari(satir), let deger = yeni[anahtar] {
                    if !deger.isEmpty { satirlar.append("\(anahtar): \(deger)"); yazildi.insert(anahtar) }
                } else {
                    satirlar.append(satir)
                }
            }
        }
        for anahtar in ["genislik", "yazi"] where !yazildi.contains(anahtar) && !(yeni[anahtar] ?? "").isEmpty {
            satirlar.append("\(anahtar): \(yeni[anahtar]!)")
        }
        guard satirlar.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return "" }
        return (["---"] + satirlar + ["---"]).joined(separator: satirSonu) + satirSonu
    }
}

/// Sütun 0'daki `anahtar:` satırının anahtarı; değilse nil. İki noktadan sonra boşluk ister.
private func ustbilgiAnahtari(_ satir: String) -> String? {
    guard let ikiNokta = satir.firstIndex(of: ":") else { return nil }
    let anahtar = String(satir[..<ikiNokta])
    guard let ilk = anahtar.first, ilk.isLetter || ilk.isNumber || ilk == "_",
          anahtar.allSatisfy({ $0.isLetter || $0.isNumber || "_.- ".contains($0) }) else { return nil }
    if let sonraki = satir[satir.index(after: ikiNokta)...].first, !sonraki.isWhitespace { return nil }
    return anahtar
}

/// Başta `---` ile açılıp en fazla 200 satır içinde `---` ile kapanan, YAML benzeri bloktur
/// (en az bir `anahtar:` satırı; devam/liste/yorum/boş satırlar serbest). Aksi hâlde frontmatter değildir.
package func sayfaUstbilgisiniAyir(_ metin: String) -> (bilgi: SayfaUstbilgisi, govde: String) {
    let ns = NSString(string: metin)
    var konum = 0
    var bilgi = SayfaUstbilgisi()
    var anahtarlar = Set<String>()
    for sira in 0..<200 {
        guard konum < ns.length else { break }
        let aralik = ns.lineRange(for: NSRange(location: konum, length: 0))
        let satir = ns.substring(with: aralik).trimmingCharacters(in: .newlines)
        konum = NSMaxRange(aralik)
        if sira == 0 {
            guard satir == "---" else { break }
        } else if satir == "---" {
            guard !anahtarlar.isEmpty else { break }
            bilgi.kaynak = ns.substring(to: konum)
            bilgi.kaynakGenislik = bilgi.genislik
            bilgi.kaynakYazi = bilgi.yazi
            return (bilgi, ns.substring(from: konum))
        } else if let anahtar = ustbilgiAnahtari(satir) {
            if ["genislik", "yazi"].contains(anahtar) {
                guard anahtarlar.insert(anahtar).inserted else { break }
                let deger = String(satir[satir.index(after: satir.firstIndex(of: ":")!)...]).trimmingCharacters(in: .whitespaces)
                switch anahtar {
                case "genislik": bilgi.genislik = deger
                default: bilgi.yazi = deger
                }
            } else {
                anahtarlar.insert(anahtar)
            }
        } else {
            let sade = satir.trimmingCharacters(in: .whitespaces)
            // Devam/liste/yorum/boş satır yalnızca bir anahtardan sonra geçerli.
            guard !anahtarlar.isEmpty, sade.isEmpty || satir.first!.isWhitespace || sade.hasPrefix("#") || sade == "-" || sade.hasPrefix("- ") else { break }
        }
    }
    return (SayfaUstbilgisi(), metin)
}

/// Yalnızca ata klasörlerini inceler; tüm ağacı taramaz. Eski düz notlar da açılır.
package func sayfaYolu(_ url: URL, kok: URL = notlarKlasoru()) -> [URL] {
    var sonuc = [url]
    var klasor = ustKlasor(url)
    let kokYolu = kok.standardizedFileURL.path
    while klasor.standardizedFileURL.path.hasPrefix(kokYolu + "/") {
        let index = klasor.appendingPathComponent(kIcerikDosyaAdi)
        let eski = klasor.appendingPathExtension("md")
        if FileManager.default.fileExists(atPath: index.path) { sonuc.insert(index, at: 0) }
        else if FileManager.default.fileExists(atPath: eski.path) { sonuc.insert(eski, at: 0) }
        klasor = klasor.deletingLastPathComponent()
    }
    return sonuc
}

// MARK: - Sayfa ağacı modeli (her sayfa kendi klasörü)

/// Bir sayfa klasörünün içindeki metin dosyasının adı.
package let kIcerikDosyaAdi = "index.md"

/// Sayfa klasörü düzeni:
///   SSRF/
///     index.md          → sayfanın metni
///     ekler/            → sayfanın görselleri
///     Örnekler/         → alt sayfa (aynı yapıda)
/// Eski düzenden kalan düz "Ad.md" notları da desteklenir; onların alt sayfaları
/// ve görselleri "Ad/" klasöründe durur.
func klasorSayfasiMi(_ klasor: URL) -> Bool {
    FileManager.default.fileExists(atPath: klasor.appendingPathComponent(kIcerikDosyaAdi).path)
}

/// Sayfanın kendi klasörü: yeni düzende index.md'yi içeren klasör, eski düz
/// notlarda notun adını taşıyan kardeş klasör. Görseller ve alt sayfalar buradadır.
package func sayfaKlasoru(_ icerikURL: URL) -> URL {
    icerikURL.lastPathComponent == kIcerikDosyaAdi
        ? icerikURL.deletingLastPathComponent()
        : icerikURL.deletingPathExtension()
}

/// Sayfanın görünen adı.
package func sayfaAdi(_ icerikURL: URL) -> String {
    sayfaKlasoru(icerikURL).lastPathComponent
}

/// Sayfanın bulunduğu üst klasör (kardeşlerinin de durduğu yer).
package func ustKlasor(_ icerikURL: URL) -> URL {
    sayfaKlasoru(icerikURL).deletingLastPathComponent()
}

/// Ağacın bir düğümü: bir sayfa ya da (eski yapıdan kalmış) salt kapsayıcı klasör.
package final class AgacDugumu {
    /// Düzenlenecek metin dosyası; kapsayıcı klasörlerde nil.
    package let icerikURL: URL?
    /// Alt sayfaların ve görsellerin durduğu klasör.
    package let klasorURL: URL
    package var cocuklar: [AgacDugumu]
    /// Klasörün .sira.json kaydında sabitlenmiş mi (siraUygula işaretler).
    package var sabit = false

    package init(icerikURL: URL?, klasorURL: URL, cocuklar: [AgacDugumu] = []) {
        self.icerikURL = icerikURL
        self.klasorURL = klasorURL
        self.cocuklar = cocuklar
    }

    package var sayfaMi: Bool { icerikURL != nil }
    package var ad: String { klasorURL.lastPathComponent }
    /// Alt sayfaların oluşturulacağı klasör.
    package var cocuklarKlasoru: URL { klasorURL }
}

package func degistirilmeTarihi(_ url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
}

/// Klasörü özyinelemeli tarayıp sayfa ağacını kurar.
package func agaciYukle(_ klasor: URL = notlarKlasoru()) -> [AgacDugumu] {
    klasoruTara(klasor).dugumler
}

/// Bir klasörün tek listelemesinden çıkan her şey: düğümler, kendisi sayfaysa index.md'nin
/// değişme tarihi. Sayfa mı, tarih ne, sıra dosyası var mı soruları ayrı stat/okuma yapıyordu;
/// 1000 sayfada taramanın çoğu bunlardı (olmayan .sira.json için hata nesnesi bile üretiliyordu).
private func klasoruTara(_ klasor: URL) -> (dugumler: [AgacDugumu], icerikTarihi: Date?) {
    let fm = FileManager.default
    let anahtarlar: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey, .isHiddenKey]
    // Gizli dosyalar elle süzülür: .sira.json'un varlığı da bu listeden öğrenilir.
    guard let icerik = try? fm.contentsOfDirectory(at: klasor, includingPropertiesForKeys: anahtarlar,
                                                    options: []) else { return ([], nil) }
    var klasorler: [URL] = []
    var duzNotlar: [URL] = []
    var tarihler: [String: Date] = [:]   // dosya adı -> değişme tarihi (listelemede önceden alındı)
    var icerikTarihi: Date?
    var siraVar = false
    for url in icerik {
        let ad = url.lastPathComponent
        let degerler = try? url.resourceValues(forKeys: Set(anahtarlar))
        if ad == kSiraDosyaAdi { siraVar = true }
        if ad.hasPrefix(".") || degerler?.isHidden == true { continue }
        if degerler?.isDirectory ?? false {
            guard ad != "ekler", ad != kGorsellerKlasorAdi else { continue }
            klasorler.append(url)
        } else if ad == kIcerikDosyaAdi {
            icerikTarihi = degerler?.contentModificationDate ?? .distantPast
        } else if url.pathExtension.lowercased() == "md" {
            duzNotlar.append(url)
            tarihler[ad] = degerler?.contentModificationDate ?? .distantPast
            // Büyük/küçük harf duyarsız diskte "Index.md" de sayfa işaretidir (eski fileExists davranışı).
            if icerikTarihi == nil, ad.lowercased() == kIcerikDosyaAdi,
               fm.fileExists(atPath: klasor.appendingPathComponent(kIcerikDosyaAdi).path) {
                icerikTarihi = degistirilmeTarihi(klasor.appendingPathComponent(kIcerikDosyaAdi))
            }
        }
    }

    let duzNotAdlari = Set(duzNotlar.map { $0.deletingPathExtension().lastPathComponent })
    var sayfalar: [(dugum: AgacDugumu, tarih: Date)] = []
    var kapsayicilar: [AgacDugumu] = []

    for klasorURL in klasorler {
        // Eski düz notun alt dal klasörüyse o notun düğümünde işlenecek.
        guard !duzNotAdlari.contains(klasorURL.lastPathComponent) else { continue }
        let alt = klasoruTara(klasorURL)
        if let tarih = alt.icerikTarihi {
            sayfalar.append((AgacDugumu(icerikURL: klasorURL.appendingPathComponent(kIcerikDosyaAdi),
                                        klasorURL: klasorURL, cocuklar: alt.dugumler), tarih))
        } else {
            kapsayicilar.append(AgacDugumu(icerikURL: nil, klasorURL: klasorURL, cocuklar: alt.dugumler))
        }
    }

    // Eski düzenden kalan düz notlar.
    let klasorlerAdaGore = Dictionary(klasorler.map { ($0.lastPathComponent, $0) }, uniquingKeysWith: { ilk, _ in ilk })
    for notURL in duzNotlar {
        let ad = notURL.deletingPathExtension().lastPathComponent
        let altKlasor = klasorlerAdaGore[ad]
        sayfalar.append((AgacDugumu(icerikURL: notURL,
                                    klasorURL: altKlasor ?? sayfaKlasoru(notURL),
                                    cocuklar: altKlasor.map { klasoruTara($0).dugumler } ?? []),
                         tarihler[notURL.lastPathComponent] ?? .distantPast))
    }

    kapsayicilar.sort { $0.ad.localizedStandardCompare($1.ad) == .orderedAscending }
    // Kararlı sıralama: eşit tarihte listeleme sırası korunur (eski sıralamayla aynı).
    let siraliSayfalar = sayfalar.enumerated()
        .sorted { $0.element.tarih != $1.element.tarih ? $0.element.tarih > $1.element.tarih : $0.offset < $1.offset }
        .map(\.element.dugum)
    return (siraUygula(kapsayicilar + siraliSayfalar, siraVar ? siraOku(klasor) : nil), icerikTarihi)
}

/// Ağacın gizleyeceği ya da tek bir klasör adı olmayan adları reddeder.
package func sayfaAdiGecerliMi(_ ad: String) -> Bool {
    !ad.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !ad.hasPrefix(".")
        && !ad.contains("/") && !ad.contains(":") && !ad.contains("\0")
        && !ad.contains("[") && !ad.contains("]")
        && ad.caseInsensitiveCompare("ekler") != .orderedSame
        && ad.caseInsensitiveCompare(kGorsellerKlasorAdi) != .orderedSame
}

/// Verilen klasörün içinde, adı çakışmayan yeni bir sayfa klasörü yolu üretir.
/// Dönen değer sayfanın index.md yoludur; dosya/klasör henüz oluşturulmaz.
/// Geçersiz adlar "Yeni Sayfa" adına düşer; çağıran uyarı gereğini sonuçtan öğrenir.
package func benzersizSayfaURLSonucu(taban: String, klasor: URL) -> (url: URL, gecersizAd: Bool) {
    let gecersizAd = !sayfaAdiGecerliMi(taban)
    let ad = gecersizAd ? "Yeni Sayfa" : taban
    return (benzersizTasimaHedefi(ad: ad, klasor: klasor).appendingPathComponent(kIcerikDosyaAdi), gecersizAd)
}

/// İkinci parça taşınamadığında ilk parçanın geri alma sonucunu da taşır.
package struct SayfaTasimaHatasi: Error {
    package let neden: Error
    package let geriAlmaHatasi: Error?
    package let dosyaURL: URL
}

/// Sayfayı yeniden adlandırır. Yeni düzende yalnızca klasör taşınır (alt sayfalar
/// ve görseller içinde olduğu için tek hamlede taşınmış olur); eski düz notlarda
/// hem dosya hem varsa alt dal klasörü taşınır. Yeni içerik yolunu döner.
/// İkinci parçanın taşıma hatası, geri alma bilgisiyle fırlatılır.
@discardableResult
package func sayfayiYenidenAdlandirmaSonucu(_ icerikURL: URL, yeniAd: String, kok: URL = notlarKlasoru()) throws -> URL? {
    guard sayfaAdiGecerliMi(yeniAd) else { return nil }
    try notlarYolunuDogrula(icerikURL, kok: kok)
    try notlarYolunuDogrula(sayfaKlasoru(icerikURL), kok: kok)
    let fm = FileManager.default
    let ust = ustKlasor(icerikURL)
    guard yeniAd != sayfaAdi(icerikURL) else { return icerikURL }

    let hedefKlasor = benzersizTasimaHedefi(ad: yeniAd, klasor: ust)
    try notlarYolunuDogrula(hedefKlasor, kok: kok)

    if icerikURL.lastPathComponent == kIcerikDosyaAdi {
        try fm.moveItem(at: sayfaKlasoru(icerikURL), to: hedefKlasor)
        return hedefKlasor.appendingPathComponent(kIcerikDosyaAdi)
    }

    // Eski düzen: Ad.md (+ varsa Ad/ klasörü)
    return try eskiSayfayiTasi(icerikURL, hedef: hedefKlasor, kok: kok)
}

/// Eski düzenin iki parçasından ikincisi taşınamazsa ilkini geri alır.
private func eskiSayfayiTasi(_ icerikURL: URL, hedef: URL, kok: URL) throws -> URL? {
    let fm = FileManager.default
    let hedefDosya = hedef.deletingLastPathComponent().appendingPathComponent("\(hedef.lastPathComponent).md")
    try notlarYolunuDogrula(icerikURL, kok: kok)
    try notlarYolunuDogrula(hedefDosya, kok: kok)
    try fm.moveItem(at: icerikURL, to: hedefDosya)
    do {
        let kaynakKlasor = sayfaKlasoru(icerikURL)
        try notlarYolunuDogrula(kaynakKlasor, kok: kok)
        try notlarYolunuDogrula(hedef, kok: kok)
        if dosyaYoluVarMi(kaynakKlasor) {
            try fm.moveItem(at: kaynakKlasor, to: hedef)
        }
        return hedefDosya
    } catch {
        let neden = error
        var geriAlmaHatasi: Error?
        do {
            try notlarYolunuDogrula(hedefDosya, kok: kok)
            try notlarYolunuDogrula(icerikURL, kok: kok)
            try fm.moveItem(at: hedefDosya, to: icerikURL)
        } catch {
            geriAlmaHatasi = error
        }
        throw SayfaTasimaHatasi(neden: neden, geriAlmaHatasi: geriAlmaHatasi, dosyaURL: hedefDosya)
    }
}

/// Eski düz notu ("Ad.md") yeni düzene taşır: "Ad/index.md".
/// Notun alt dallarını tutan "Ad/" klasörü zaten varsa dosya onun içine alınır.
@discardableResult
package func sayfayiKlasoreDonustur(_ icerikURL: URL) -> URL? {
    guard icerikURL.lastPathComponent != kIcerikDosyaAdi else { return icerikURL }
    let fm = FileManager.default
    let klasor = sayfaKlasoru(icerikURL)
    guard (try? notlarYolunuDogrula(icerikURL)) != nil,
          (try? notlarYolunuDogrula(klasor.appendingPathComponent(kIcerikDosyaAdi))) != nil else { return nil }
    if !fm.fileExists(atPath: klasor.path) {
        guard (try? fm.createDirectory(at: klasor, withIntermediateDirectories: true)) != nil else { return nil }
    }
    let hedef = klasor.appendingPathComponent(kIcerikDosyaAdi)
    guard !fm.fileExists(atPath: hedef.path),
          (try? fm.moveItem(at: icerikURL, to: hedef)) != nil else { return nil }
    return hedef
}

// MARK: - Taşıma (kenar panelde sürükle-bırak)

package enum TasimaDogrulamaHatasi: LocalizedError {
    case kendiAltina
    case ayniUst
    case yol(Error)

    package var errorDescription: String? {
        switch self {
        case .kendiAltina: return "Sayfa kendi içine veya altına taşınamaz."
        case .ayniUst: return "Sayfa zaten bu klasörde."
        case .yol(let hata): return hata.localizedDescription
        }
    }
}

/// UI ön doğrulamada hata türünü kullanır; gerçek taşıma aynı kontrolü yeniden yapar.
package func tasimayiDogrula(kaynakKlasor: URL, hedefKlasor: URL, mevcutUst: URL,
                            kok: URL = notlarKlasoru()) -> Result<Void, TasimaDogrulamaHatasi> {
    do {
        let kaynak = try notlarYolunuDogrula(kaynakKlasor, kok: kok).path
        let hedef = try notlarYolunuDogrula(hedefKlasor, kok: kok, kokDahil: true).path
        let ust = try notlarYolunuDogrula(mevcutUst, kok: kok, kokDahil: true).path
        guard hedef != kaynak, !hedef.hasPrefix(kaynak + "/") else { return .failure(.kendiAltina) }
        guard hedef != ust else { return .failure(.ayniUst) }
        return .success(())
    } catch { return .failure(.yol(error)) }
}

package func tasimaGecerliMi(kaynakKlasor: URL, hedefKlasor: URL, mevcutUst: URL,
                           kok: URL = notlarKlasoru()) -> Bool {
    if case .success = tasimayiDogrula(kaynakKlasor: kaynakKlasor, hedefKlasor: hedefKlasor,
                                     mevcutUst: mevcutUst, kok: kok) { return true }
    return false
}

/// Hedef klasörde `ad` ile çakışmayan bir yol üretir.
/// Hem "Ad/" klasörü hem eski düzenin "Ad.md" dosyası kontrol edilir.
private func benzersizTasimaHedefi(ad: String, klasor: URL) -> URL {
    var aday = klasor.appendingPathComponent(ad, isDirectory: true)
    var sayac = 2
    while sayfaHedefiDoluMu(aday) {
        aday = klasor.appendingPathComponent("\(ad) (\(sayac))", isDirectory: true)
        sayac += 1
    }
    return aday
}

/// Sayfayı, alt sayfaları ve görselleriyle birlikte başka bir klasörün altına taşır.
/// Yeni içerik yolunu döner; doğrulama ve dosya işlemi hataları UI katmanına fırlatılır.
/// İkinci parçanın taşıma hatası, geri alma bilgisiyle fırlatılır.
@discardableResult
package func sayfaTasimaSonucu(_ icerikURL: URL, hedefKlasor: URL, kok: URL = notlarKlasoru()) throws -> URL? {
    let fm = FileManager.default
    let kaynakKlasor = sayfaKlasoru(icerikURL)
    try tasimayiDogrula(kaynakKlasor: kaynakKlasor, hedefKlasor: hedefKlasor,
                       mevcutUst: ustKlasor(icerikURL), kok: kok).get()
    try notlarYolunuDogrula(icerikURL, kok: kok)
    try fm.createDirectory(at: hedefKlasor, withIntermediateDirectories: true)

    let hedef = benzersizTasimaHedefi(ad: sayfaAdi(icerikURL), klasor: hedefKlasor)
    try notlarYolunuDogrula(hedef, kok: kok)

    // Yeni düzen: her şey klasörün içinde, tek hamle yeter.
    if icerikURL.lastPathComponent == kIcerikDosyaAdi {
        try notlarYolunuDogrula(kaynakKlasor, kok: kok)
        try fm.moveItem(at: kaynakKlasor, to: hedef)
        return hedef.appendingPathComponent(kIcerikDosyaAdi)
    }

    // Eski düzen: "Ad.md" ve varsa alt dallarını tutan "Ad/" klasörü birlikte gider.
    return try eskiSayfayiTasi(icerikURL, hedef: hedef, kok: kok)
}

/// Eski yapıdan kalan salt kapsayıcı klasörü taşır. Yeni klasör yolunu döner.
@discardableResult
package func klasorTasimaSonucu(_ klasorURL: URL, hedefKlasor: URL, kok: URL = notlarKlasoru()) throws -> URL {
    try tasimayiDogrula(kaynakKlasor: klasorURL, hedefKlasor: hedefKlasor,
                       mevcutUst: klasorURL.deletingLastPathComponent(), kok: kok).get()
    return try klasorIslemi(klasorURL, ad: klasorURL.lastPathComponent, hedefKlasor: hedefKlasor, kok: kok)
}

package func klasoruYenidenAdlandir(_ klasorURL: URL, yeniAd: String, kok: URL = notlarKlasoru()) throws -> URL? {
    guard sayfaAdiGecerliMi(yeniAd) else { return nil }
    try notlarYolunuDogrula(klasorURL, kok: kok)
    guard yeniAd != klasorURL.lastPathComponent else { return klasorURL }
    return try klasorIslemi(klasorURL, ad: yeniAd, hedefKlasor: klasorURL.deletingLastPathComponent(), kok: kok)
}

private func klasorIslemi(_ kaynak: URL, ad: String, hedefKlasor: URL, kok: URL) throws -> URL {
    try notlarYolunuDogrula(kaynak, kok: kok)
    try notlarYolunuDogrula(hedefKlasor, kok: kok, kokDahil: true)
    try FileManager.default.createDirectory(at: hedefKlasor, withIntermediateDirectories: true)
    let hedef = benzersizTasimaHedefi(ad: ad, klasor: hedefKlasor)
    try notlarYolunuDogrula(hedef, kok: kok)
    try FileManager.default.moveItem(at: kaynak, to: hedef)
    return hedef
}

@discardableResult
package func klasoruTasi(_ klasorURL: URL, hedefKlasor: URL) -> URL? {
    try? klasorTasimaSonucu(klasorURL, hedefKlasor: hedefKlasor)
}

/// Bağlantı yolu köke görelidir; kapsayıcı klasörler de ad çakışmasını ayırır.
package func sayfaBagYolu(_ url: URL) -> String {
    let yol = sayfaKlasoru(url).standardizedFileURL.path
    let kok = notlarKlasoru().standardizedFileURL.path + "/"
    return yol.hasPrefix(kok) ? String(yol.dropFirst(kok.count)) : sayfaAdi(url)
}
