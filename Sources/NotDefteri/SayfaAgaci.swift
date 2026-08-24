import AppKit

// MARK: - Sayfa ağacı modeli (her sayfa kendi klasörü)

/// Bir sayfa klasörünün içindeki metin dosyasının adı.
let kIcerikDosyaAdi = "index.md"

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
func sayfaKlasoru(_ icerikURL: URL) -> URL {
    icerikURL.lastPathComponent == kIcerikDosyaAdi
        ? icerikURL.deletingLastPathComponent()
        : icerikURL.deletingPathExtension()
}

/// Sayfanın görünen adı.
func sayfaAdi(_ icerikURL: URL) -> String {
    sayfaKlasoru(icerikURL).lastPathComponent
}

/// Sayfanın bulunduğu üst klasör (kardeşlerinin de durduğu yer).
func ustKlasor(_ icerikURL: URL) -> URL {
    sayfaKlasoru(icerikURL).deletingLastPathComponent()
}

/// Ağacın bir düğümü: bir sayfa ya da (eski yapıdan kalmış) salt kapsayıcı klasör.
final class AgacDugumu {
    /// Düzenlenecek metin dosyası; kapsayıcı klasörlerde nil.
    let icerikURL: URL?
    /// Alt sayfaların ve görsellerin durduğu klasör.
    let klasorURL: URL
    var cocuklar: [AgacDugumu]

    init(icerikURL: URL?, klasorURL: URL, cocuklar: [AgacDugumu] = []) {
        self.icerikURL = icerikURL
        self.klasorURL = klasorURL
        self.cocuklar = cocuklar
    }

    var sayfaMi: Bool { icerikURL != nil }
    var ad: String { klasorURL.lastPathComponent }
    /// Alt sayfaların oluşturulacağı klasör.
    var cocuklarKlasoru: URL { klasorURL }
}

func degistirilmeTarihi(_ url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
}

/// Klasörü özyinelemeli tarayıp sayfa ağacını kurar.
func agaciYukle(_ klasor: URL = notlarKlasoru()) -> [AgacDugumu] {
    let fm = FileManager.default
    guard let icerik = try? fm.contentsOfDirectory(at: klasor,
                                                    includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                                                    options: [.skipsHiddenFiles]) else { return [] }
    var klasorler: [URL] = []
    var duzNotlar: [URL] = []
    for url in icerik {
        let dizinMi = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if dizinMi {
            guard url.lastPathComponent != "ekler", url.lastPathComponent != kGorsellerKlasorAdi else { continue }
            klasorler.append(url)
        } else if url.pathExtension.lowercased() == "md", url.lastPathComponent != kIcerikDosyaAdi {
            duzNotlar.append(url)
        }
    }

    let duzNotAdlari = Set(duzNotlar.map { $0.deletingPathExtension().lastPathComponent })
    var sayfalar: [AgacDugumu] = []
    var kapsayicilar: [AgacDugumu] = []

    for klasorURL in klasorler {
        // Eski düz notun alt dal klasörüyse o notun düğümünde işlenecek.
        guard !duzNotAdlari.contains(klasorURL.lastPathComponent) else { continue }
        let cocuklar = agaciYukle(klasorURL)
        if klasorSayfasiMi(klasorURL) {
            sayfalar.append(AgacDugumu(icerikURL: klasorURL.appendingPathComponent(kIcerikDosyaAdi),
                                        klasorURL: klasorURL, cocuklar: cocuklar))
        } else {
            kapsayicilar.append(AgacDugumu(icerikURL: nil, klasorURL: klasorURL, cocuklar: cocuklar))
        }
    }

    // Eski düzenden kalan düz notlar.
    let klasorlerAdaGore = Dictionary(klasorler.map { ($0.lastPathComponent, $0) }, uniquingKeysWith: { ilk, _ in ilk })
    for notURL in duzNotlar {
        let ad = notURL.deletingPathExtension().lastPathComponent
        let altKlasor = klasorlerAdaGore[ad]
        sayfalar.append(AgacDugumu(icerikURL: notURL,
                                    klasorURL: altKlasor ?? sayfaKlasoru(notURL),
                                    cocuklar: altKlasor.map { agaciYukle($0) } ?? []))
    }

    kapsayicilar.sort { $0.ad.localizedStandardCompare($1.ad) == .orderedAscending }
    sayfalar.sort { degistirilmeTarihi($0.icerikURL!) > degistirilmeTarihi($1.icerikURL!) }
    return kapsayicilar + sayfalar
}

/// Verilen klasörün içinde, adı çakışmayan yeni bir sayfa klasörü yolu üretir.
/// Dönen değer sayfanın index.md yoludur; dosya/klasör henüz oluşturulmaz.
func benzersizSayfaURL(taban: String, klasor: URL) -> URL {
    let fm = FileManager.default
    var aday = klasor.appendingPathComponent(taban, isDirectory: true)
    var sayac = 2
    while fm.fileExists(atPath: aday.path) {
        aday = klasor.appendingPathComponent("\(taban) (\(sayac))", isDirectory: true)
        sayac += 1
    }
    return aday.appendingPathComponent(kIcerikDosyaAdi)
}

/// Sayfayı yeniden adlandırır. Yeni düzende yalnızca klasör taşınır (alt sayfalar
/// ve görseller içinde olduğu için tek hamlede taşınmış olur); eski düz notlarda
/// hem dosya hem varsa alt dal klasörü taşınır. Yeni içerik yolunu döner.
@discardableResult
func sayfayiYenidenAdlandir(_ icerikURL: URL, yeniAd: String) -> URL? {
    let fm = FileManager.default
    let ust = ustKlasor(icerikURL)
    guard yeniAd != sayfaAdi(icerikURL) else { return icerikURL }

    var hedefKlasor = ust.appendingPathComponent(yeniAd, isDirectory: true)
    var sayac = 2
    while fm.fileExists(atPath: hedefKlasor.path) {
        hedefKlasor = ust.appendingPathComponent("\(yeniAd) (\(sayac))", isDirectory: true)
        sayac += 1
    }

    if icerikURL.lastPathComponent == kIcerikDosyaAdi {
        guard (try? fm.moveItem(at: sayfaKlasoru(icerikURL), to: hedefKlasor)) != nil else { return nil }
        return hedefKlasor.appendingPathComponent(kIcerikDosyaAdi)
    }

    // Eski düzen: Ad.md (+ varsa Ad/ klasörü)
    let hedefDosya = ust.appendingPathComponent("\(hedefKlasor.lastPathComponent).md")
    guard !fm.fileExists(atPath: hedefDosya.path),
          (try? fm.moveItem(at: icerikURL, to: hedefDosya)) != nil else { return nil }
    let eskiAltKlasor = sayfaKlasoru(icerikURL)
    if fm.fileExists(atPath: eskiAltKlasor.path) {
        try? fm.moveItem(at: eskiAltKlasor, to: hedefKlasor)
    }
    return hedefDosya
}

/// Eski düz notu ("Ad.md") yeni düzene taşır: "Ad/index.md".
/// Notun alt dallarını tutan "Ad/" klasörü zaten varsa dosya onun içine alınır.
@discardableResult
func sayfayiKlasoreDonustur(_ icerikURL: URL) -> URL? {
    guard icerikURL.lastPathComponent != kIcerikDosyaAdi else { return icerikURL }
    let fm = FileManager.default
    let klasor = sayfaKlasoru(icerikURL)
    if !fm.fileExists(atPath: klasor.path) {
        guard (try? fm.createDirectory(at: klasor, withIntermediateDirectories: true)) != nil else { return nil }
    }
    let hedef = klasor.appendingPathComponent(kIcerikDosyaAdi)
    guard !fm.fileExists(atPath: hedef.path),
          (try? fm.moveItem(at: icerikURL, to: hedef)) != nil else { return nil }
    return hedef
}
