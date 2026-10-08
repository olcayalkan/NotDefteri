import Foundation

// MARK: - Markdown <-> Attributed String dönüşümü (kalın yazı + punto desteği)

package func boyutSinirla(_ boyut: CGFloat) -> CGFloat {
    min(max(boyut, kMinYaziBoyutu), kMaksYaziBoyutu)
}

/// Punto değerini dosyaya yazarken kısa gösterir (14.0 -> "14").
package func boyutMetni(_ boyut: CGFloat) -> String {
    // Görünüm ölçeğini geri alırken oluşan kayan nokta farkı "16"yı "16.0"a çevirmesin.
    abs(boyut - boyut.rounded()) < 0.0001 ? String(Int(boyut.rounded())) : String(format: "%.1f", Double(boyut))
}

/// Metinden biçimlendirme işaretlerini ("**", "<punto=..>") temizler.
package func isaretlemeleriTemizle(_ metin: String) -> String {
    metin
        .replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]*\\)(\\{[0-9]+x[0-9]+\\})?", with: "", options: .regularExpression)
        .replacingOccurrences(of: "(?m)^#{1,3} ", with: "", options: .regularExpression)
        .replacingOccurrences(of: #"(?m)^ *> \[![^\]\s]+ (?:gri|mavi|sarı|kırmızı|yeşil)\] ?"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: "(?m)^ *(?:- \\[[ xX]\\] |[-*] |[0-9]+\\. |> )", with: "", options: .regularExpression)
        .replacingOccurrences(of: "(?m)^ *(?:[•☐☑]\\t|[0-9]+\\.\\t)", with: "", options: .regularExpression)
        .replacingOccurrences(of: "</?punto[^>]*>", with: "", options: .regularExpression)
        .replacingOccurrences(of: "**", with: "")
        .replacingOccurrences(of: "\u{FFFC}", with: "")
        .replacingOccurrences(of: "\u{200B}", with: "")
}

private let kSatirIciBicimAnahtarlari = [kPuntoOlcegiAnahtari, kKalinAnahtari, kItalikAnahtari, kSatirIciKodAnahtari,
    kUstuCiziliAnahtari, kVurguAnahtari, kBaglantiAnahtari, kCiplakBagAnahtari, kSayfaBagiAnahtari, kBaslikSeviyesiAnahtari]

/// Aynı Markdown etiketine girecek iki parça mı? Değerleri metne çevirip karşılaştırmak
/// (String(describing:)) her parçada yansıma maliyeti çıkarıyordu.
private func ayniSatirIciBicim(_ a: [NSAttributedString.Key: Any], _ b: [NSAttributedString.Key: Any]) -> Bool {
    kSatirIciBicimAnahtarlari.allSatisfy { anahtar in
        switch (a[anahtar], b[anahtar]) {
        case (nil, nil): return true
        case let (x?, y?): return (x as? AnyHashable) == (y as? AnyHashable) && x as? AnyHashable != nil
        default: return false
        }
    }
}

private func satirMarkdownunuUret(_ attr: NSAttributedString) -> String {
    var sonuc = ""
    let tamAralik = NSRange(location: 0, length: attr.length)
    guard tamAralik.length > 0 else { return "" }
    let ns = NSString(string: attr.string)
    var satirBasi = true
    var tampon = ""
    var tamponOznitelikleri: [NSAttributedString.Key: Any] = [:]
    var yazilanBagSonu = 0
    let riskli = satirKacisRiskleri(attr)
    // Parçalar arasında açık kalan vurgu işaretleri (dıştan içe). Her parça ayrı sarılınca bitişik
    // iki italik "*a**b*" olup kalın okunuyordu; yalnızca değişen işaretler kapanıp açılır.
    var acikIsaretler: [String] = []

    /// Kapanış işareti sondaki boşluktan önce yazılır; boşluktan sonra gelen işaret kapanış sayılmaz.
    func isaretleriKapat(_ kalan: Int = 0) {
        guard acikIsaretler.count > kalan else { return }
        var bosluk = ""
        while let son = sonuc.last, son == " " || son == "\t" { bosluk.insert(son, at: bosluk.startIndex); sonuc.removeLast() }
        for isaret in acikIsaretler[kalan...].reversed() { sonuc += isaret }
        acikIsaretler.removeSubrange(kalan...)
        sonuc += bosluk
    }

    // Blok rengi/girintisi aynı inline font kapsamını ayrı Markdown etiketlerine bölmesin.
    func tamponuYaz() {
        guard !tampon.isEmpty else { return }
        let duzKodVeyaURL = tamponOznitelikleri[kSayfaBagiAnahtari] != nil || tamponOznitelikleri[kSatirIciKodAnahtari] as? Bool == true || tamponOznitelikleri[kCiplakBagAnahtari] as? Bool == true
        // Bağlantı etiketinde köşeli parantez, okuyucunun etiket sonunu şaşırmaması için hep kaçar.
        let etiketMi = tamponOznitelikleri[kBaglantiAnahtari] != nil && tamponOznitelikleri[kCiplakBagAnahtari] as? Bool != true
        var parca = duzKodVeyaURL ? tampon : markdownKarakterleriniKacir(tampon,
            riskli: etiketMi ? riskli.union(["[", "]"]) : riskli, satirBasinda: sonuc.isEmpty)
        let baslik = tamponOznitelikleri[kBaslikSeviyesiAnahtari] as? Int
        if tamponOznitelikleri[kSatirIciKodAnahtari] as? Bool == true {
            let ayirac = kodAyiraci(parca, enAz: 1)
            let bosluk = parca.hasPrefix("`") || parca.hasSuffix("`") ||
                (parca.hasPrefix(" ") && parca.hasSuffix(" ") && !parca.trimmingCharacters(in: .whitespaces).isEmpty) ? " " : ""
            parca = ayirac + bosluk + parca + bosluk + ayirac
        }
        // Dıştan içe: kalın, vurgu, üstü çizili, italik (eski tek parça sarma sırasıyla aynı).
        var istenen: [String] = []
        if tamponOznitelikleri[kKalinAnahtari] as? Bool == true, baslik == nil { istenen.append("**") }
        if tamponOznitelikleri[kVurguAnahtari] as? Bool == true { istenen.append("==") }
        if tamponOznitelikleri[kUstuCiziliAnahtari] as? Bool == true { istenen.append("~~") }
        if tamponOznitelikleri[kItalikAnahtari] as? Bool == true { istenen.append("*") }
        let kayitBoyutu = kTabanPunto * CGFloat((tamponOznitelikleri[kPuntoOlcegiAnahtari] as? Double) ?? 1)
        let puntoVar = baslik == nil && abs(kayitBoyutu - kTabanPunto) > 0.01
        let bag = etiketMi ? tamponOznitelikleri[kBaglantiAnahtari] : nil
        tampon = ""
        // Punto etiketi ve bağlantı parçanın tamamını sarar; okuyucu bunları eskisi gibi kendi içinde bekler.
        if puntoVar || bag != nil {
            isaretleriKapat()
            for isaret in istenen.reversed() { parca = isaret + parca + isaret }
            if puntoVar { parca = "<punto=\(boyutMetni(kayitBoyutu))>\(parca)</punto>" }
            if let bag { parca = "[\(parca)](\(bag))" }
            sonuc += parca
            return
        }
        // Kod içindeki boşluk koda aittir; diğer parçalarda işaretler boşlukların dışında kalır.
        let kod = tamponOznitelikleri[kSatirIciKodAnahtari] as? Bool == true
        let bas = kod ? "" : String(parca.prefix { $0 == " " || $0 == "\t" })
        let govde = parca.dropFirst(bas.count)
        let son = kod ? "" : String(govde.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
        let oz = govde.dropLast(son.count)
        // Yalnız boşluktan oluşan parça görünmez; açık işaretler değişmez.
        guard !oz.isEmpty else { sonuc += parca; return }
        // Hâlâ istenen açık işaretler dışta kalır; yenileri içe açılır.
        let korunan = acikIsaretler.filter { istenen.contains($0) }
        istenen = korunan + istenen.filter { !korunan.contains($0) }
        var ortak = 0
        while ortak < min(acikIsaretler.count, istenen.count), acikIsaretler[ortak] == istenen[ortak] { ortak += 1 }
        isaretleriKapat(ortak)
        sonuc += bas
        for isaret in istenen[ortak...] { sonuc += isaret; acikIsaretler.append(isaret) }
        sonuc += oz + son
    }
    func onEkiYaz(_ onEk: String) {
        if tampon.isEmpty { sonuc += onEk } else { tampon += onEk }
    }
    attr.enumerateAttributes(in: tamAralik, options: []) { oznitelikler, aralik, _ in
        guard aralik.location >= yazilanBagSonu else { return }
        if satirBasi, let blok = MetinBlogu(oznitelik: oznitelikler[kMetinBloguAnahtari]) {
            onEkiYaz(blok.markdownOnEki)
            satirBasi = false
        }
        if oznitelikler[kBlokIsaretiAnahtari] as? Bool == true {
            if satirBasi, let seviye = oznitelikler[kBaslikSeviyesiAnahtari] as? Int {
                tamponuYaz()
                sonuc += String(repeating: "#", count: seviye) + " "
                satirBasi = false
            }
            return
        }
        // Görselin yolu ve isteğe bağlı boyutu platformdan bağımsızdır.
        if let gorsel = oznitelikler[kGorselAnahtari] as? [String: Any], let yol = gorsel["yol"] as? String {
            tamponuYaz()
            isaretleriKapat()
            if satirBasi, let seviye = oznitelikler[kBaslikSeviyesiAnahtari] as? Int {
                sonuc += String(repeating: "#", count: seviye) + " "
            }
            sonuc += "![](\(yol))"
            if let en = gorsel["genislik"] as? Double, let boy = gorsel["yukseklik"] as? Double,
               anlamsalGorselBoyutuGecerliMi(en: en, boy: boy) {
                sonuc += "{\(Int(en))x\(Int(boy))}"
            }
            satirBasi = false
            return
        }
        var yazilacakAralik = aralik
        if oznitelikler[kSayfaBagiAnahtari] != nil {
            // Fontun adı parçalaması, bağlantı hedefinin içine Markdown işaretleri sokmamalı.
            _ = attr.attribute(kSayfaBagiAnahtari, at: aralik.location,
                               longestEffectiveRange: &yazilacakAralik, in: tamAralik)
            yazilanBagSonu = NSMaxRange(yazilacakAralik)
        }
        var parca = ns.substring(with: yazilacakAralik)
        if let seviye = oznitelikler[kBaslikSeviyesiAnahtari] as? Int, satirBasi {
            tamponuYaz()
            sonuc += String(repeating: "#", count: seviye) + " "
        }
        // Satır sonu biçim etiketinin dışında kalır; blok sınırları karışmaz.
        let satirSonu = parca.hasSuffix("\n")
        if satirSonu { parca.removeLast() }
        if !tampon.isEmpty, !ayniSatirIciBicim(tamponOznitelikleri, oznitelikler) { tamponuYaz() }
        tamponOznitelikleri = oznitelikler
        tampon += parca
        if satirSonu { tamponuYaz(); isaretleriKapat(); sonuc += "\n" }
        satirBasi = satirSonu
    }
    tamponuYaz()
    isaretleriKapat()
    return sonuc
}

/// Kaydedilmemiş yeni bir notun içeriğinden otomatik bir dosya adı üretir (ilk satırdan).
package func otomatikBaslikUret(icerik: String) -> String {
    let ilkSatir = icerik.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
    var baslik = guvenliDosyaAdi(isaretlemeleriTemizle(ilkSatir)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\0", with: "-"), varsayilan: "")
    if baslik.isEmpty {
        let bicim = DateFormatter()
        bicim.dateFormat = "dd.MM.yyyy HH.mm.ss"
        baslik = "Adsız Not \(bicim.string(from: Date()))"
    }
    // Temizlenmiş ad ayrılmışsa otomatik kayıt uyarı açmadan devam etsin.
    if !sayfaAdiGecerliMi(baslik) { baslik += " 2" }
    return baslik
}

/// Otomatik adlı sayfanın yeniden adlandırılması gerekiyor mu? Aynı adlı kardeş varken taşıma
/// "Ad (2)" üretir; bu, istenen adın eşi sayılır. Sayılmasaydı her kayıtta (3), (4)… diye artıyordu.
package func otomatikAdDegismeli(mevcut: String, istenen: String) -> Bool {
    guard mevcut != istenen else { return false }
    guard mevcut.hasPrefix(istenen + " ("), mevcut.hasSuffix(")"),
          let sayac = Int(mevcut.dropFirst(istenen.count + 2).dropLast()) else { return true }
    return sayac < 2
}

// Yol taraması önceki 1024 karakter sınırını korur; iç içe adaylar da sınırlı maliyetle işlenir.
private let kResimBagiDeseni = try! NSRegularExpression(
    pattern: #"!\[[^\]]*\]\(([^)]{0,1024})\)(?:\{([0-9]+)x([0-9]+)\})?"#)

/// Dosya varsa anlamsal görsel üretir; yoksa kaynak metin olduğu gibi kalır.
/// Boyutsuz görselin doğal ölçüsünü ve dosyanın çözülebilirliğini platform belirler.
package func resimBaginiCozumle(_ ns: NSString, _ baslangic: Int, taban: URL, metin: String? = nil) -> ([String: Any], Int)? {
    guard baslangic >= 0, baslangic <= ns.length,
          let eslesme = kResimBagiDeseni.firstMatch(in: metin ?? String(ns), options: .anchored,
          range: NSRange(location: baslangic, length: ns.length - baslangic)),
          eslesme.range(at: 1).location != NSNotFound else { return nil }
    let yol = ns.substring(with: eslesme.range(at: 1))
    let adaylar = [taban.appendingPathComponent(yol), notlarKlasoru().appendingPathComponent(yol)]
    guard let dosyaURL = adaylar.first(where: {
        var klasor: ObjCBool = false
        return FileManager.default.fileExists(atPath: $0.path, isDirectory: &klasor) && !klasor.boolValue
    }) else { return nil }
    var gorsel: [String: Any] = ["yol": yol, "dosyaURL": dosyaURL]
    if eslesme.range(at: 2).location != NSNotFound,
       let en = Double(ns.substring(with: eslesme.range(at: 2))),
       let boy = Double(ns.substring(with: eslesme.range(at: 3))),
       anlamsalGorselBoyutuGecerliMi(en: en, boy: boy) {
        gorsel["genislik"] = en
        gorsel["yukseklik"] = boy
    }
    return (gorsel, eslesme.range.length)
}

/// `baslangic` konumundan sonra `aranan` dizesi geçiyor mu?
/// Eşleşmemiş işaretlemenin biçim başlatmasını engellemek için kullanılır:
/// kapanışı olmayan bir "**" ya da "<punto=..>" düz metin sayılmalı, yoksa
/// geri yazarken sona uydurma bir kapanış etiketi ekleniyordu
/// (ör. "2 ** 3 = 8" -> "2 ** 3 = 8\n**").
private func kapanisVarMi(_ ns: NSString, sonrasinda baslangic: Int, aranan: String) -> Bool {
    guard baslangic <= ns.length else { return false }
    let kalanAralik = NSRange(location: baslangic, length: ns.length - baslangic)
    return ns.range(of: aranan, options: [], range: kalanAralik).location != NSNotFound
}

private func satiriAttributedStringeCevir(_ metin: String, taban: URL, devamBlogu: MetinBlogu? = nil) -> NSAttributedString {
    let sonuc = NSMutableAttributedString(string: "")
    let ns = NSString(string: metin)
    var kalin = false
    var italik = false
    var ustuCizili = false
    var vurgu = false
    var boyut = kTabanPunto
    var puntoAcik = false
    var baslikSeviyesi = 0
    var blok: MetinBlogu?
    var tampon: [unichar] = []
    let sayfaBaglari = Dictionary(uniqueKeysWithValues: sayfaBaglariniBul(metin).map { ($0.aralik.location, $0) })
    let ciplakBaglar = Dictionary(uniqueKeysWithValues: ciplakBaglariBul(metin,
        aralik: NSRange(location: 0, length: ns.length)).map { ($0.aralik.location, $0) })

    func yazimOznitelikleri() -> [NSAttributedString.Key: Any] {
        var oznitelikler: [NSAttributedString.Key: Any] = [:]
        if kalin { oznitelikler[kKalinAnahtari] = true }
        if italik { oznitelikler[kItalikAnahtari] = true }
        if boyut != kTabanPunto { oznitelikler[kPuntoOlcegiAnahtari] = Double(boyut / kTabanPunto) }
        if ustuCizili { oznitelikler[kUstuCiziliAnahtari] = true }
        if vurgu { oznitelikler[kVurguAnahtari] = true }
        if baslikSeviyesi > 0 { oznitelikler[kBaslikSeviyesiAnahtari] = baslikSeviyesi }
        if let blok { oznitelikler.merge(blok.oznitelikler) { _, yeni in yeni } }
        return oznitelikler
    }
    func tamponuBosalt() {
        guard !tampon.isEmpty else { return }
        sonuc.append(NSAttributedString(string: String(utf16CodeUnits: tampon, count: tampon.count), attributes: yazimOznitelikleri()))
        tampon.removeAll(keepingCapacity: true)
    }

    var i = 0
    var satirBasi = true
    var sonGorselAltKapanisi = -1
    while i < ns.length {
        if satirBasi {
            var satirSonu = 0
            ns.getLineStart(nil, end: nil, contentsEnd: &satirSonu, for: NSRange(location: i, length: 0))
            let satir = ns.substring(with: NSRange(location: i, length: satirSonu - i))
            if let cozum = metinBlogunuCozumle(satir) {
                tamponuBosalt()
                blok = devamBlogu ?? cozum.blok
                sonuc.append(blokIsaretiniUret(blok!))
                i += cozum.uzunluk
                satirBasi = false
                continue
            }
        }
        // Satır başındaki "# ", "## ", "### " başlık düzeyini belirler.
        if satirBasi, ns.character(at: i) == unichar(35) {  // "#"
            var isaretSayisi = 0
            while i + isaretSayisi < ns.length, ns.character(at: i + isaretSayisi) == unichar(35) { isaretSayisi += 1 }
            if isaretSayisi <= 3, i + isaretSayisi < ns.length, ns.character(at: i + isaretSayisi) == unichar(32) {
                tamponuBosalt()
                baslikSeviyesi = isaretSayisi
                i += isaretSayisi + 1
                // Boş başlık da dosyada saklanabilsin; işaret ekranda görünmez.
                if i == ns.length || ns.character(at: i) == 10 || ns.character(at: i) == 13 {
                    sonuc.append(NSAttributedString(string: "\u{200B}", attributes: [
                        kBaslikSeviyesiAnahtari: baslikSeviyesi, kBlokIsaretiAnahtari: true]))
                }
                satirBasi = false
                continue
            }
        }
        satirBasi = ns.character(at: i) == unichar(10)  // "\n"
        if satirBasi {
            // Satır sonu başlığı da bitirir.
            tampon.append(ns.character(at: i))
            tamponuBosalt()
            baslikSeviyesi = 0
            blok = nil
            i += 1
            continue
        }
        if let bag = ciplakBaglar[i], disBaglantiGecerliMi(bag.url) {
            // URL yolundaki yıldız/backtick, metin biçimi olarak yorumlanmamalı.
            var yazi = ns.substring(with: bag.aralik)
            // macOS bağ algılayıcısı punto kapanışını URL'nin parçası sayabilir.
            if puntoAcik, let kapanis = yazi.range(of: "</punto>") {
                yazi = String(yazi[..<kapanis.lowerBound])
            }
            for (etkin, isaret) in [(kalin, "**"), (italik, "*"), (ustuCizili, "~~"), (vurgu, "==")] {
                if etkin, yazi.hasSuffix(isaret) { yazi.removeLast(isaret.count) }
            }
            tamponuBosalt()
            var oznitelikler = yazimOznitelikleri()
            #if os(macOS)
            let url = bag.url
            oznitelikler[kBaglantiAnahtari] = URL(string: yazi) ?? url
            #else
            oznitelikler[kBaglantiAnahtari] = ciplakBagURLsi(yazi) ?? bag.url
            #endif
            oznitelikler[kCiplakBagAnahtari] = true
            sonuc.append(NSAttributedString(string: yazi, attributes: oznitelikler))
            i += NSString(string: yazi).length
            continue
        }
        if ns.character(at: i) == 92, i + 1 < ns.length,
           kKacisKarakterleri.contains(Character(UnicodeScalar(ns.character(at: i + 1)) ?? " ")) {
            if ns.character(at: i + 1) == 91 {
                // Ekranda kaçış kaldırılır; sonraki paragraf düzenlemesi literal bağı etkinleştirmemeli.
                tamponuBosalt()
                var oznitelikler = yazimOznitelikleri()
                oznitelikler[kKacisliKoseParantezAnahtari] = true
                sonuc.append(NSAttributedString(string: "[", attributes: oznitelikler))
            } else { tampon.append(ns.character(at: i + 1)) }
            i += 2; continue
        }
        if ns.character(at: i) == 96 {
            var uzunluk = 1
            while i + uzunluk < ns.length, ns.character(at: i + uzunluk) == 96 { uzunluk += 1 }
            let ayirac = String(repeating: "`", count: uzunluk)
            let son = ns.range(of: ayirac, range: NSRange(location: i + uzunluk, length: ns.length - i - uzunluk))
            if son.location != NSNotFound, son.location > i + uzunluk {
                tamponuBosalt()
                var kod = ns.substring(with: NSRange(location: i + uzunluk, length: son.location - i - uzunluk))
                if kod.hasPrefix(" "), kod.hasSuffix(" "), !kod.trimmingCharacters(in: .whitespaces).isEmpty {
                    kod.removeFirst(); kod.removeLast()
                }
                var oznitelikler = yazimOznitelikleri()
                oznitelikler[kSatirIciKodAnahtari] = true
                sonuc.append(NSAttributedString(string: kod, attributes: oznitelikler))
                i = son.location + uzunluk
                continue
            }
        }
        if let bag = sayfaBaglari[i] {
            tamponuBosalt()
            var oznitelikler = yazimOznitelikleri()
            oznitelikler[kSayfaBagiAnahtari] = bag.hedef
            sonuc.append(NSAttributedString(string: ns.substring(with: bag.aralik), attributes: oznitelikler))
            i = NSMaxRange(bag.aralik)
            continue
        }
        if ns.character(at: i) == 91, i == 0 || ns.character(at: i - 1) != 33,
           let (etiketMetni, url, uzunluk) = metinBaginiCozumle(ns, baslangic: i) {
            tamponuBosalt()
            let etiket = NSMutableAttributedString(attributedString: satiriAttributedStringeCevir(etiketMetni, taban: taban))
            let aralik = NSRange(location: 0, length: etiket.length)
            let dis = yazimOznitelikleri()
            etiket.enumerateAttributes(in: aralik) { ic, alt, _ in
                var birlesik = dis.merging(ic) { _, yeni in yeni }
                for anahtar in [kKalinAnahtari, kItalikAnahtari] where dis[anahtar] as? Bool == true {
                    birlesik[anahtar] = true
                }
                // Dış punto etiketi bağlantı etiketinin tamamını kapsar.
                if puntoAcik { birlesik[kPuntoOlcegiAnahtari] = dis[kPuntoOlcegiAnahtari] }
                birlesik.removeValue(forKey: kCiplakBagAnahtari)
                birlesik.removeValue(forKey: kSayfaBagiAnahtari)
                birlesik[kBaglantiAnahtari] = url
                etiket.setAttributes(birlesik, range: alt)
            }
            if baslikSeviyesi > 0 { etiket.addAttribute(kBaslikSeviyesiAnahtari, value: baslikSeviyesi, range: aralik) }
            if let blok { etiket.addAttributes(blok.oznitelikler, range: aralik) }
            sonuc.append(etiket)
            i += uzunluk
            continue
        }
        let ikili = i + 2 <= ns.length ? ns.substring(with: NSRange(location: i, length: 2)) : ""
        if ikili == "~~", ustuCizili || kapanisVarMi(ns, sonrasinda: i + 2, aranan: "~~") {
            tamponuBosalt(); ustuCizili.toggle(); i += 2; continue
        }
        if ikili == "==", vurgu || kapanisVarMi(ns, sonrasinda: i + 2, aranan: "==") {
            tamponuBosalt(); vurgu.toggle(); i += 2; continue
        }
        if ns.character(at: i) == 42, ikili != "**",
           italik || kapanisVarMi(ns, sonrasinda: i + 1, aranan: "*") {
            tamponuBosalt(); italik.toggle(); i += 1; continue
        }
        // Kalın işareti. Açılış yalnızca ileride bir kapanış varsa kabul edilir;
        // eşleşmemiş "**" düz metin olarak kalır.
        if i + 2 <= ns.length, ns.substring(with: NSRange(location: i, length: 2)) == "**",
           kalin || kapanisVarMi(ns, sonrasinda: i + 2, aranan: "**") {
            tamponuBosalt()
            kalin.toggle()
            i += 2
            continue
        }
        // Görsel: ![](ekler/dosya.png){320x240}
        if ns.character(at: i) == unichar(33), i + 1 < ns.length, ns.character(at: i + 1) == unichar(91),
           i > sonGorselAltKapanisi {  // "!["
            // Aynı ilk "]" işaretine ulaşan adayların yolu aynıdır. İlk aday
            // çözülemediyse içindeki "![" işaretlerinde aynı bağı tekrar deneme.
            let kapanis = ns.range(of: "]", options: [], range: NSRange(location: i + 2, length: ns.length - i - 2)).location
            sonGorselAltKapanisi = kapanis == NSNotFound ? ns.length : kapanis
            if kapanis != NSNotFound, let (ek, uzunluk) = resimBaginiCozumle(ns, i, taban: taban, metin: metin) {
                tamponuBosalt()
                let gorsel = NSMutableAttributedString(string: "\u{FFFC}", attributes: [kGorselAnahtari: ek])
                if let blok { gorsel.addAttributes(blok.oznitelikler, range: NSRange(location: 0, length: gorsel.length)) }
                if baslikSeviyesi > 0 { gorsel.addAttribute(kBaslikSeviyesiAnahtari, value: baslikSeviyesi, range: NSRange(location: 0, length: gorsel.length)) }
                sonuc.append(gorsel)
                i += uzunluk
                continue
            }
        }
        // Punto etiketi: <punto=16> ... </punto>
        if ns.character(at: i) == unichar(60) {  // "<"
            let pencere = ns.substring(with: NSRange(location: i, length: min(24, ns.length - i)))
            if let kapanisIndex = pencere.firstIndex(of: ">") {
                let etiket = String(pencere[pencere.index(after: pencere.startIndex)..<kapanisIndex])
                let etiketUzunlugu = NSString(string: pencere).range(of: ">").location + 1
                if etiket == "/punto", puntoAcik {
                    tamponuBosalt()
                    boyut = kTabanPunto
                    puntoAcik = false
                    i += etiketUzunlugu
                    continue
                }
                if etiket.hasPrefix("punto="), let deger = Double(etiket.dropFirst("punto=".count)),
                   kapanisVarMi(ns, sonrasinda: i + etiketUzunlugu, aranan: "</punto>") {
                    tamponuBosalt()
                    boyut = boyutSinirla(CGFloat(deger))
                    puntoAcik = true
                    i += etiketUzunlugu
                    continue
                }
            }
        }
        tampon.append(ns.character(at: i))
        i += 1
    }
    tamponuBosalt()
    return sonuc
}

/// Algılayıcının bulabileceği her bağ "@", harf/rakamdan önce "." ya da "/"/harften önce ":"
/// içerir. Çoğu satırda bunlar yok; algılayıcı (macOS'ta dil tanıma dahil) satır başına
/// pahalı olduğu için önce bu ucuz tarama yapılır.
private func bagIcerebilir(_ ns: NSString, _ aralik: NSRange) -> Bool {
    let son = NSMaxRange(aralik)
    var i = aralik.location
    while i < son {
        let k = ns.character(at: i)
        if k == 64 { return true }                                    // @
        if (k == 46 || k == 58), i + 1 < son {                        // . :
            let sonraki = ns.character(at: i + 1)
            if UTF16.isLeadSurrogate(sonraki) { return true }
            if let skaler = Unicode.Scalar(sonraki) {
                if k == 46, CharacterSet.alphanumerics.contains(skaler) { return true }
                if k == 58, sonraki == 47 || CharacterSet.letters.contains(skaler) { return true }
            }
        }
        i += 1
    }
    return false
}

#if os(macOS)
private let kBagAlgilayici = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

private func ciplakBaglariBul(_ metin: String, aralik: NSRange) -> [(aralik: NSRange, url: URL)] {
    guard bagIcerebilir(NSString(string: metin), aralik) else { return [] }
    return kBagAlgilayici.matches(in: metin, range: aralik).compactMap {
        guard let url = $0.url else { return nil }
        return ($0.range, url)
    }
}
#else
// Şemasız alan adları (www. dahil) yalnızca listedeki TLD'lerle tanınır;
// dosya uzantıları alan adı sayılmaz. E-posta alan adı veya IPv4 taşıyabilir.
// Şemalı URL, e-posta ve çıplak alan adları. Noktalama URL'nin dışındadır;
// yol içindeki dengeli parantezler ve Markdown karakterleri korunur.
private let kBagAlgilayici = try! NSRegularExpression(pattern: ##"""
(?ix)(?<![\p{L}\p{N}_@/:.\-])(?:
    https?://[^\s<>"“”]+ |
    mailto:[^\s<>"“”]+ |
    [\p{L}\p{N}.!\#$%&'*+/=?^_`{|}~\-]+@
        (?:(?:[\p{L}\p{N}](?:[\p{L}\p{N}\-]*[\p{L}\p{N}])?\.)+[\p{L}]{2,63} |
            (?:(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}
            (?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])) |
    (?:[\p{L}\p{N}](?:[\p{L}\p{N}\-]*[\p{L}\p{N}])?\.)+
        (?:com\.tr|org\.tr|edu\.tr|gov\.tr|com|net|org|io|dev|app|edu|gov|co|me|info|tr)
        (?::[0-9]{1,5})?(?:[/?\#][^\s<>"“”]*)?
)(?![\p{L}\p{N}_\-]|\.[\p{L}\p{N}_\-])
"""##)

private func ciplakBagURLsi(_ yazi: String) -> URL? {
    let kucuk = yazi.lowercased()
    let semali = kucuk.hasPrefix("http://") || kucuk.hasPrefix("https://") || kucuk.hasPrefix("mailto:")
    let adres = semali ? yazi : (yazi.contains("@") ? "mailto:" : "http://") + yazi
    guard let url = URL(string: adres), disBaglantiGecerliMi(url) else { return nil }
    return url
}

private func ciplakBaglariBul(_ metin: String, aralik: NSRange) -> [(aralik: NSRange, url: URL)] {
    let ns = NSString(string: metin)
    guard bagIcerebilir(ns, aralik) else { return [] }
    return kBagAlgilayici.matches(in: metin, range: aralik).compactMap { eslesme in
        var yazi = ns.substring(with: eslesme.range)
        while let son = yazi.last {
            if ".,;:!?…'’".contains(son) { yazi.removeLast(); continue }
            let acilis: Character? = son == ")" ? "(" : son == "]" ? "[" : son == "}" ? "{" : nil
            if let acilis, yazi.filter({ $0 == son }).count > yazi.filter({ $0 == acilis }).count {
                yazi.removeLast(); continue
            }
            break
        }
        guard !yazi.isEmpty, let url = ciplakBagURLsi(yazi) else { return nil }
        return (NSRange(location: eslesme.range.location, length: NSString(string: yazi).length), url)
    }
}

#endif

/// Algılama yalnızca açılan/yapıştırılan aralıkta çalışır; yazımda belge taranmaz.
package func ciplakBaglariIsaretle(_ metin: NSMutableAttributedString, aralik: NSRange) {
    guard bagIcerebilir(metin.mutableString, aralik) else { return }
    #if os(macOS)
    kBagAlgilayici.enumerateMatches(in: metin.string, range: aralik) { eslesme, _, _ in
        guard let eslesme, let url = eslesme.url, disBaglantiGecerliMi(url),
              metin.attribute(kBaglantiAnahtari, at: eslesme.range.location, effectiveRange: nil) == nil,
              metin.attribute(kSayfaBagiAnahtari, at: eslesme.range.location, effectiveRange: nil) == nil,
              metin.attribute(kSatirIciKodAnahtari, at: eslesme.range.location, effectiveRange: nil) == nil,
              metin.attribute(kKodBloguAnahtari, at: eslesme.range.location, effectiveRange: nil) == nil else { return }
        metin.addAttributes([kBaglantiAnahtari: url, kCiplakBagAnahtari: true], range: eslesme.range)
    }
    #else
    for bag in ciplakBaglariBul(metin.string, aralik: aralik) {
        let konum = bag.aralik.location
        guard disBaglantiGecerliMi(bag.url),
              metin.attribute(kBaglantiAnahtari, at: konum, effectiveRange: nil) == nil,
              metin.attribute(kSayfaBagiAnahtari, at: konum, effectiveRange: nil) == nil,
              metin.attribute(kSatirIciKodAnahtari, at: konum, effectiveRange: nil) == nil,
              metin.attribute(kKodBloguAnahtari, at: konum, effectiveRange: nil) == nil else { continue }
        metin.addAttributes([kBaglantiAnahtari: bag.url, kCiplakBagAnahtari: true], range: bag.aralik)
    }
    #endif
}

private func kanonikMarkdownUret(_ metin: NSAttributedString) -> String {
    var sonuc = ""
    metin.enumerateAttribute(kKodBloguAnahtari, in: NSRange(location: 0, length: metin.length)) { deger, aralik, _ in
        let parca = metin.attributedSubstring(from: aralik)
        if let sinirlar = deger as? [String: String] {
            var govde = kodBloguGovdesi(parca)
            let kapanis = sinirlar["kapanis"] ?? "```\n"
            if !govde.isEmpty, !govde.hasSuffix("\n"), !kapanis.isEmpty { govde += "\n" }
            var acilis = sinirlar["acilis"] ?? "```\n"
            var son = kapanis
            if !govde.isEmpty, !acilis.hasSuffix("\n") { acilis += "\n" }
            if !son.isEmpty {
                let eski = String(acilis.prefix { $0 == "`" })
                let ayirac = kodAyiraci(govde, enAz: max(3, eski.count))
                acilis = ayirac + acilis.dropFirst(eski.count)
                son = ayirac + son.dropFirst(son.prefix { $0 == "`" }.count)
            }
            sonuc += acilis + govde + son
        } else {
            let ns = NSString(string: parca.string)
            var konum = 0
            while konum < ns.length {
                let satir = ns.lineRange(for: NSRange(location: konum, length: 0))
                sonuc += satirMarkdownunuUret(parca.attributedSubstring(from: satir))
                konum = NSMaxRange(satir)
            }
        }
    }
    return sonuc
}

package func sayfaMarkdownunuUret(_ metin: NSAttributedString, ustbilgi: SayfaUstbilgisi) -> String {
    let govde = markdownMetniUret(metin)
    let onek = ustbilgi.markdown
    let ayirac = !onek.isEmpty && !govde.isEmpty && !onek.hasSuffix("\n") && !onek.hasSuffix("\r") ? "\n" : ""
    return onek + ayirac + govde
}

package func markdownMetniUret(_ metin: NSAttributedString) -> String {
    var sonuc = ""
    let ns = NSString(string: metin.string)
    var konum = 0
    var oncekiBlok: MetinBlogu?
    while konum < metin.length {
        var aralik = NSRange()
        let kodBlogu = metin.attribute(kKodBloguAnahtari, at: konum, effectiveRange: nil) != nil
        let blok = kodBlogu ? nil : MetinBlogu(oznitelik: metin.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil))
        // Bitişik alıntı ve uyarı, okuyucuda tek uyarı kutusuna dönüşmesin.
        if (oncekiBlok?.tur == .uyari && blok?.tur == .alinti) ||
           (oncekiBlok?.tur == .alinti && blok?.tur == .uyari) {
            sonuc += sonuc.hasSuffix("\r\n") ? "\r\n" : sonuc.hasSuffix("\r") ? "\r" : "\n"
        }
        if kodBlogu {
            _ = metin.attribute(kKodBloguAnahtari, at: konum, longestEffectiveRange: &aralik,
                                in: NSRange(location: 0, length: metin.length))
        } else {
            let satir = ns.lineRange(for: NSRange(location: konum, length: 0))
            aralik = NSRange(location: konum, length: NSMaxRange(satir) - konum)
        }
        let parca = metin.attributedSubstring(from: aralik)
        let kanonik = kanonikMarkdownUret(parca)
        let kaynak = MarkdownKaynagi(oznitelik: parca.attribute(kMarkdownKaynakAnahtari, at: 0, effectiveRange: nil))
        var ayniKaynak = kaynak != nil
        parca.enumerateAttribute(kMarkdownKaynakAnahtari, in: NSRange(location: 0, length: parca.length)) { deger, _, durdur in
            if MarkdownKaynagi(oznitelik: deger) != kaynak { ayniKaynak = false; durdur.pointee = true }
        }
        // Karşılaştırma kayıt/kopyalamada yapılır; özgün paragrafın yazılışı korunur.
        if ayniKaynak, let kaynak, kaynak.kanonik == kanonik { sonuc += kaynak.metin }
        else { sonuc += kanonik }
        oncekiBlok = blok
        konum = NSMaxRange(aralik)
    }
    return sonuc
}

package func markdowndenAttributedStringUret(_ metin: String, taban: URL = notlarKlasoru()) -> NSAttributedString {
    var parcalar: [NSAttributedString] = []
    let ns = NSString(string: metin)
    var konum = 0
    var uyari: MetinBlogu?
    while konum < ns.length {
        let satir = ns.lineRange(for: NSRange(location: konum, length: 0))
        let yazi = ns.substring(with: satir)
        let cozum = metinBlogunuCozumle(yazi.trimmingCharacters(in: .newlines))
        if cozum?.blok.tur == .uyari {
            uyari = cozum?.blok
        } else if cozum?.blok.tur == .alinti, var devam = uyari,
                  devam.seviye == cozum?.blok.seviye {
            devam.devam = true
            devam.kaynakOnEk = cozum?.blok.kaynakOnEk
            uyari = devam
        } else { uyari = nil }
        var kaynakAraligi = satir
        let parca: NSMutableAttributedString
        if let ayirac = kodBloguAyiraci(yazi) {
            let govdeBasi = NSMaxRange(satir)
            let kapanis = kodBloguKapanisi(ns, ayirac: ayirac, sonrasinda: govdeBasi)
            let govdeSonu = kapanis?.location ?? ns.length
            kaynakAraligi.length = (kapanis.map { NSMaxRange($0) } ?? ns.length) - konum
            let sinirlar = kodBloguSinirlari(acilis: yazi, kapanis: kapanis.map { ns.substring(with: $0) } ?? "")
            let oznitelikler: [NSAttributedString.Key: Any] = [
                kKodBloguAnahtari: sinirlar, kKodBloguDiliAnahtari: kodBloguDilEtiketi(sinirlar),
                kBlokKimligiAnahtari: sinirlar["kimlik"]!]
            parca = NSMutableAttributedString(string: "\u{200B}", attributes: oznitelikler)
            parca.addAttribute(kBlokIsaretiAnahtari, value: true, range: NSRange(location: 0, length: 1))
            parca.append(NSAttributedString(string: ns.substring(with: NSRange(location: govdeBasi, length: govdeSonu - govdeBasi)), attributes: oznitelikler))
            if govdeBasi == govdeSonu {
                // Boş kodun sonraki paragrafla birleşmesini önler; dosyaya yazılmaz.
                var bosSatir = oznitelikler
                bosSatir[kBosKodSatiriAnahtari] = true
                parca.append(NSAttributedString(string: "\n", attributes: bosSatir))
            }
        } else {
            parca = NSMutableAttributedString(attributedString: satiriAttributedStringeCevir(yazi, taban: taban, devamBlogu: uyari))
            ciplakBaglariIsaretle(parca, aralik: NSRange(location: 0, length: parca.length))
        }
        if parca.length == 0 {
            // Yalnızca biçim işaretinden oluşan son satır da kaynak yazılışını taşımalı.
            parca.append(NSAttributedString(string: "\u{200B}", attributes: [
                kBlokIsaretiAnahtari: true]))
        }
        let kaynak = MarkdownKaynagi(metin: ns.substring(with: kaynakAraligi), kanonik: kanonikMarkdownUret(parca))
        parca.addAttribute(kMarkdownKaynakAnahtari, value: kaynak.oznitelikDegeri, range: NSRange(location: 0, length: parca.length))
        parcalar.append(parca)
        konum = NSMaxRange(kaynakAraligi)
    }
    return parcalariBirlestir(parcalar)
}

/// Linux'ta (corelibs) her append tüm metnin UTF-16 uzunluğunu baştan sayıyordu; büyük not
/// karesel açılıyordu. Orada metin tek seferde kurulur, öznitelikler sonra yazılır. AppKit'in
/// append'i zaten doğrusal ve bu yoldan biraz hızlı.
private func parcalariBirlestir(_ parcalar: [NSAttributedString]) -> NSAttributedString {
    #if os(macOS)
    let sonuc = NSMutableAttributedString()
    for parca in parcalar { sonuc.append(parca) }
    return sonuc
    #else
    let sonuc = NSMutableAttributedString(string: parcalar.map(\.string).joined())
    sonuc.beginEditing()
    var konum = 0
    for parca in parcalar {
        parca.enumerateAttributes(in: NSRange(location: 0, length: parca.length)) { oznitelikler, aralik, _ in
            guard !oznitelikler.isEmpty else { return }
            sonuc.setAttributes(oznitelikler, range: NSRange(location: konum + aralik.location, length: aralik.length))
        }
        konum += parca.length
    }
    sonuc.endEditing()
    return sonuc
    #endif
}

/// İçerikte backtick varsa daha uzun ayıraç seçilir; yeniden açışta kod bölünmesin.
private func kodAyiraci(_ metin: String, enAz: Int) -> String {
    var enUzun = 0
    var adet = 0
    for karakter in metin {
        adet = karakter == "`" ? adet + 1 : 0
        enUzun = max(enUzun, adet)
    }
    return String(repeating: "`", count: max(enAz, enUzun + 1))
}

/// Okuyucunun çözdüğü tek kaçış kümesi; yazıcı da yalnızca bunlardan önce "\\" üretir.
/// Diğer "\\" dizileri ("\\(", "C:\\Users") olduğu gibi metindir.
package let kKacisKarakterleri: Set<Character> = ["\\", "*", "`", "~", "=", "[", "]", ">", "#", ".", "-", "<", "!"]

/// Satırda eşleşebilecek işaretler: düz metindeki tek "*" / "==" ancak satırda ikinci
/// bir eş ya da o biçim varsa okuyucuda biçim açar; yalnızca o zaman kaçmalı.
private func satirKacisRiskleri(_ satir: NSAttributedString) -> Set<Character> {
    var baglam = satir.string
    var riskli = Set<Character>()
    satir.enumerateAttributes(in: NSRange(location: 0, length: satir.length)) { o, _, _ in
        if o[kItalikAnahtari] as? Bool == true || (o[kKalinAnahtari] as? Bool == true && o[kBaslikSeviyesiAnahtari] == nil) { riskli.insert("*") }
        if o[kUstuCiziliAnahtari] as? Bool == true { riskli.insert("~") }
        if o[kVurguAnahtari] as? Bool == true { riskli.insert("=") }
        if o[kSatirIciKodAnahtari] as? Bool == true { riskli.insert("`") }
        if let bag = o[kBaglantiAnahtari], o[kCiplakBagAnahtari] as? Bool != true { riskli.insert("["); baglam += "\(bag)" }
    }
    // İşaretlerin hepsi ASCII: tek geçişte UTF-8 baytları sayılır. NSString'den gelen metinde
    // Character yinelemesi her karakterde köprüden geçiyor, kaydın en pahalı adımıydı.
    var yildiz = 0, tirnak = 0, tilda = 0, esittir = 0, bagIsareti = false
    var onceki: UInt8 = 0
    for bayt in baglam.utf8 {
        switch bayt {
        case UInt8(ascii: "*"): yildiz += 1
        case UInt8(ascii: "`"): tirnak += 1
        case UInt8(ascii: "~") where onceki == bayt: tilda += 1
        case UInt8(ascii: "=") where onceki == bayt: esittir += 1
        case UInt8(ascii: "[") where onceki == bayt: bagIsareti = true
        case UInt8(ascii: "(") where onceki == UInt8(ascii: "]"): bagIsareti = true
        default: break
        }
        onceki = bayt
    }
    if yildiz > 1 { riskli.insert("*") }
    if tirnak > 1 { riskli.insert("`") }
    if tilda > 1 { riskli.insert("~") }
    if esittir > 1 { riskli.insert("=") }
    if bagIsareti { riskli.insert("[") }
    if satir.length > 0, let blok = MetinBlogu(oznitelik: satir.attribute(kMetinBloguAnahtari, at: 0, effectiveRange: nil)),
       blok.tur == .alinti || (blok.tur == .uyari && blok.devam) {
        let govde = NSString(string: satir.string).substring(from: blokIsaretiUzunlugu(satir))
        if metinBlogunuCozumle("> " + govde.trimmingCharacters(in: .newlines))?.blok.tur == .uyari {
            riskli.insert("[")
        }
    }
    return riskli
}

#if !os(macOS)
// ICU'nun Unicode kelime sınırları boşluk/noktalama ile ayrılır; kesme işareti,
// birleştirici işaretler ve sayılar sözcüğün parçası olarak kalır.
private let kKelimeSinirlari = try! NSRegularExpression(pattern: #"\b[\s\S]+?\b"#, options: .useUnicodeWordBoundaries)
#endif

/// Yalnızca değişen paragrafın kopyası verilir; görünüm işaretleri önceden çıkarılır.
package func kelimeleriSay(_ metin: String) -> Int {
    #if os(macOS)
    var sayi = 0
    metin.enumerateSubstrings(in: metin.startIndex..<metin.endIndex, options: .byWords) { _, _, _, _ in sayi += 1 }
    return sayi
    #else
    let ns = NSString(string: metin)
    // Harf/sayı içermeyen işaretler, varyasyon seçicileri ve ZWJ kelime değildir.
    return kKelimeSinirlari.matches(in: metin, range: NSRange(location: 0, length: ns.length)).reduce(0) {
        $0 + (ns.substring(with: $1.range).range(of: #"[\p{L}\p{N}]"#, options: .regularExpression) == nil ? 0 : 1)
    }
    #endif
}

private func markdownKarakterleriniKacir(_ metin: String, riskli: Set<Character>, satirBasinda: Bool) -> String {
    let harfler = Array(metin)
    var blokIsareti = -1
    // Satır başındaki düz metin blok/başlık öneki gibi okunmasın: yalnızca ilk işaret kaçar.
    if satirBasinda, metin.range(of: #"^ *(- |\* |> |---|\[ ?\] |#{1,3} |[0-9]+\. )"#, options: .regularExpression) != nil,
       let ilk = harfler.firstIndex(where: { $0 != " " }) {
        blokIsareti = harfler[ilk].isNumber ? harfler.firstIndex(of: ".") ?? -1 : ilk
    }
    var sonuc = ""
    for (i, h) in harfler.enumerated() {
        let kalan = harfler[(i + 1)...]
        // Parça sonundaki "\\" ardından gelecek işareti bilemez; kaçması güvenlidir.
        let kacsin = i == blokIsareti || riskli.contains(h) ||
            (h == "\\" && (kalan.first.map(kKacisKarakterleri.contains) ?? true)) ||
            (h == "<" && (kalan.starts(with: "punto=") || kalan.starts(with: "/punto>")))
        if kacsin { sonuc.append("\\") }
        sonuc.append(h)
    }
    return sonuc
}

/// Köşeli/parantezli etiket ve URL'lerde kapanışı dengeleyerek bulur.
private func metinBaginiCozumle(_ ns: NSString, baslangic: Int) -> (String, URL, Int)? {
    func kapanis(_ bas: Int, ac: unichar, kapa: unichar) -> Int? {
        var derinlik = 1
        var konum = bas
        while konum < ns.length {
            let karakter = ns.character(at: konum)
            if karakter == 10 || karakter == 13 { return nil }
            if karakter == 92 { konum += 2; continue }
            if karakter == ac { derinlik += 1 }
            if karakter == kapa { derinlik -= 1; if derinlik == 0 { return konum } }
            konum += 1
        }
        return nil
    }
    guard let etiketSonu = kapanis(baslangic + 1, ac: 91, kapa: 93),
          etiketSonu + 1 < ns.length, ns.character(at: etiketSonu + 1) == 40,
          let urlSonu = kapanis(etiketSonu + 2, ac: 40, kapa: 41),
          let url = URL(string: ns.substring(with: NSRange(location: etiketSonu + 2, length: urlSonu - etiketSonu - 2))) else { return nil }
    return (ns.substring(with: NSRange(location: baslangic + 1, length: etiketSonu - baslangic - 1)), url, urlSonu - baslangic + 1)
}
