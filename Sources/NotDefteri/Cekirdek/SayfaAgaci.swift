import Foundation

/// Dosyadaki frontmatter bloğu `kaynak`ta ham durur; yalnızca bilinen alanlar güncellenir,
/// bilinmeyen satırlar (ör. Obsidian tags/aliases) sırası ve yazılışıyla korunur.
struct SayfaUstbilgisi: Equatable {
    var genislik = ""
    var yazi = ""
    var kaynak = ""
    var kaynakGenislik = ""
    var kaynakYazi = ""

    var markdown: String {
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
func sayfaUstbilgisiniAyir(_ metin: String) -> (bilgi: SayfaUstbilgisi, govde: String) {
    let ns = metin as NSString
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
func sayfaYolu(_ url: URL, kok: URL = notlarKlasoru()) -> [URL] {
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
    /// Klasörün .sira.json kaydında sabitlenmiş mi (siraUygula işaretler).
    var sabit = false

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
    // Tarih her karşılaştırmada değil, sayfa başına bir kez okunur (sıralama n·log n stat yapıyordu).
    let tarihler = Dictionary(sayfalar.map { ($0.icerikURL!, degistirilmeTarihi($0.icerikURL!)) }, uniquingKeysWith: { ilk, _ in ilk })
    sayfalar.sort { tarihler[$0.icerikURL!]! > tarihler[$1.icerikURL!]! }
    return siraUygula(kapsayicilar + sayfalar, siraOku(klasor))
}

/// Ağacın gizleyeceği ya da tek bir klasör adı olmayan adları reddeder.
func sayfaAdiGecerliMi(_ ad: String) -> Bool {
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
func benzersizSayfaURLSonucu(taban: String, klasor: URL) -> (url: URL, gecersizAd: Bool) {
    let gecersizAd = !sayfaAdiGecerliMi(taban)
    let ad = gecersizAd ? "Yeni Sayfa" : taban
    return (benzersizTasimaHedefi(ad: ad, klasor: klasor).appendingPathComponent(kIcerikDosyaAdi), gecersizAd)
}

/// İkinci parça taşınamadığında ilk parçanın geri alma sonucunu da taşır.
struct SayfaTasimaHatasi: Error {
    let neden: Error
    let geriAlmaHatasi: Error?
    let dosyaURL: URL
}

/// Sayfayı yeniden adlandırır. Yeni düzende yalnızca klasör taşınır (alt sayfalar
/// ve görseller içinde olduğu için tek hamlede taşınmış olur); eski düz notlarda
/// hem dosya hem varsa alt dal klasörü taşınır. Yeni içerik yolunu döner.
/// İkinci parçanın taşıma hatası, geri alma bilgisiyle fırlatılır.
@discardableResult
func sayfayiYenidenAdlandirmaSonucu(_ icerikURL: URL, yeniAd: String) throws -> URL? {
    guard sayfaAdiGecerliMi(yeniAd) else { return nil }
    let fm = FileManager.default
    let ust = ustKlasor(icerikURL)
    guard yeniAd != sayfaAdi(icerikURL) else { return icerikURL }

    let hedefKlasor = benzersizTasimaHedefi(ad: yeniAd, klasor: ust)

    if icerikURL.lastPathComponent == kIcerikDosyaAdi {
        guard (try? fm.moveItem(at: sayfaKlasoru(icerikURL), to: hedefKlasor)) != nil else { return nil }
        return hedefKlasor.appendingPathComponent(kIcerikDosyaAdi)
    }

    // Eski düzen: Ad.md (+ varsa Ad/ klasörü)
    return try eskiSayfayiTasi(icerikURL, hedef: hedefKlasor)
}

/// Eski düzenin iki parçasından ikincisi taşınamazsa ilkini geri alır.
private func eskiSayfayiTasi(_ icerikURL: URL, hedef: URL) throws -> URL? {
    let fm = FileManager.default
    let hedefDosya = hedef.deletingLastPathComponent().appendingPathComponent("\(hedef.lastPathComponent).md")
    guard (try? fm.moveItem(at: icerikURL, to: hedefDosya)) != nil else { return nil }
    do {
        let kaynakKlasor = sayfaKlasoru(icerikURL)
        if fm.fileExists(atPath: kaynakKlasor.path) {
            try fm.moveItem(at: kaynakKlasor, to: hedef)
        }
        return hedefDosya
    } catch {
        let neden = error
        var geriAlmaHatasi: Error?
        do {
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

// MARK: - Taşıma (kenar panelde sürükle-bırak)

/// Taşıma geçerli mi? Bir sayfa kendi altına, kendi içine ya da hâlihazırda
/// bulunduğu klasöre taşınamaz.
///
/// Kendi altına taşımaya izin verilseydi `moveItem` klasörü kendi torununa
/// taşıyıp dalı tamamen erişilemez hâle getirirdi.
func tasimaGecerliMi(kaynakKlasor: URL, hedefKlasor: URL, mevcutUst: URL) -> Bool {
    let kaynak = kaynakKlasor.standardizedFileURL.path
    let hedef = hedefKlasor.standardizedFileURL.path
    guard hedef != kaynak, !hedef.hasPrefix(kaynak + "/") else { return false }
    return hedef != mevcutUst.standardizedFileURL.path
}

/// Hedef klasörde `ad` ile çakışmayan bir yol üretir.
/// Hem "Ad/" klasörü hem eski düzenin "Ad.md" dosyası kontrol edilir.
private func benzersizTasimaHedefi(ad: String, klasor: URL) -> URL {
    let fm = FileManager.default
    func doluMu(_ aday: URL) -> Bool {
        fm.fileExists(atPath: aday.path) || fm.fileExists(atPath: aday.path + ".md")
    }
    var aday = klasor.appendingPathComponent(ad, isDirectory: true)
    var sayac = 2
    while doluMu(aday) {
        aday = klasor.appendingPathComponent("\(ad) (\(sayac))", isDirectory: true)
        sayac += 1
    }
    return aday
}

/// Sayfayı, alt sayfaları ve görselleriyle birlikte başka bir klasörün altına taşır.
/// Yeni içerik yolunu döner; geçersiz taşıma ya da ilk adım hatasında nil.
/// İkinci parçanın taşıma hatası, geri alma bilgisiyle fırlatılır.
@discardableResult
func sayfaTasimaSonucu(_ icerikURL: URL, hedefKlasor: URL) throws -> URL? {
    let fm = FileManager.default
    let kaynakKlasor = sayfaKlasoru(icerikURL)
    guard tasimaGecerliMi(kaynakKlasor: kaynakKlasor, hedefKlasor: hedefKlasor,
                          mevcutUst: ustKlasor(icerikURL)) else { return nil }
    guard (try? fm.createDirectory(at: hedefKlasor, withIntermediateDirectories: true)) != nil else { return nil }

    let hedef = benzersizTasimaHedefi(ad: sayfaAdi(icerikURL), klasor: hedefKlasor)

    // Yeni düzen: her şey klasörün içinde, tek hamle yeter.
    if icerikURL.lastPathComponent == kIcerikDosyaAdi {
        guard (try? fm.moveItem(at: kaynakKlasor, to: hedef)) != nil else { return nil }
        return hedef.appendingPathComponent(kIcerikDosyaAdi)
    }

    // Eski düzen: "Ad.md" ve varsa alt dallarını tutan "Ad/" klasörü birlikte gider.
    return try eskiSayfayiTasi(icerikURL, hedef: hedef)
}

/// Eski yapıdan kalan salt kapsayıcı klasörü taşır. Yeni klasör yolunu döner.
@discardableResult
func klasoruTasi(_ klasorURL: URL, hedefKlasor: URL) -> URL? {
    let fm = FileManager.default
    guard tasimaGecerliMi(kaynakKlasor: klasorURL, hedefKlasor: hedefKlasor,
                          mevcutUst: klasorURL.deletingLastPathComponent()) else { return nil }
    guard (try? fm.createDirectory(at: hedefKlasor, withIntermediateDirectories: true)) != nil else { return nil }

    let hedef = benzersizTasimaHedefi(ad: klasorURL.lastPathComponent, klasor: hedefKlasor)
    guard (try? fm.moveItem(at: klasorURL, to: hedef)) != nil else { return nil }
    return hedef
}

/// Bağlantı yolu köke görelidir; kapsayıcı klasörler de ad çakışmasını ayırır.
func sayfaBagYolu(_ url: URL) -> String {
    let yol = sayfaKlasoru(url).standardizedFileURL.path
    let kok = notlarKlasoru().standardizedFileURL.path + "/"
    return yol.hasPrefix(kok) ? String(yol.dropFirst(kok.count)) : sayfaAdi(url)
}
