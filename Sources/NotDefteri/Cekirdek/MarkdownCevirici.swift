import AppKit

// MARK: - Markdown <-> Attributed String dönüşümü (kalın yazı + punto desteği)

/// Etiketsiz metnin temel fontu: her zaman sabit taban punto (kayma olmaması için).
func varsayilanFont() -> NSFont { fontUret(boyut: kTabanPunto, kalin: false) }
func kalinFont() -> NSFont { fontUret(boyut: kTabanPunto, kalin: true) }

/// Bir paragrafın başlık düzeyini (1-3) taşıyan öznitelik.
let kBaslikSeviyesiAnahtari = NSAttributedString.Key("baslikSeviyesi")

/// Başlık düzeylerinin punto çarpanları: /1 en büyük.
func baslikFontu(_ seviye: Int) -> NSFont {
    let carpan: CGFloat
    switch seviye {
    case 1: carpan = 1.75
    case 2: carpan = 1.40
    default: carpan = 1.15
    }
    return fontUret(boyut: (kTabanPunto * carpan).rounded(), kalin: true)
}

func fontUret(boyut: CGFloat, kalin: Bool) -> NSFont {
    let temel = NSFont.systemFont(ofSize: boyut)
    return kalin ? NSFontManager.shared.convert(temel, toHaveTrait: .boldFontMask) : temel
}

func kalinMi(_ font: NSFont) -> Bool {
    NSFontManager.shared.traits(of: font).contains(.boldFontMask)
}

func boyutSinirla(_ boyut: CGFloat) -> CGFloat {
    min(max(boyut, kMinYaziBoyutu), kMaksYaziBoyutu)
}

/// Punto değerini dosyaya yazarken kısa gösterir (14.0 -> "14").
func boyutMetni(_ boyut: CGFloat) -> String {
    // Görünüm ölçeğini geri alırken oluşan kayan nokta farkı "16"yı "16.0"a çevirmesin.
    abs(boyut - boyut.rounded()) < 0.0001 ? String(Int(boyut.rounded())) : String(format: "%.1f", Double(boyut))
}

/// Metinden biçimlendirme işaretlerini ("**", "<punto=..>") temizler.
func isaretlemeleriTemizle(_ metin: String) -> String {
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

private func satirMarkdownunuUret(_ attr: NSAttributedString) -> String {
    var sonuc = ""
    let tamAralik = NSRange(location: 0, length: attr.length)
    guard tamAralik.length > 0 else { return "" }
    let ns = attr.string as NSString
    var satirBasi = true
    var tampon = ""
    var tamponFontu: NSFont?
    var tamponBicimi = ""
    var tamponOznitelikleri: [NSAttributedString.Key: Any] = [:]
    var yazilanBagSonu = 0
    let riskli = satirKacisRiskleri(attr)

    // Blok rengi/girintisi aynı inline font kapsamını ayrı Markdown etiketlerine bölmesin.
    func tamponuYaz() {
        guard !tampon.isEmpty, let font = tamponFontu else { return }
        let duzKodVeyaURL = tamponOznitelikleri[kSayfaBagiAnahtari] != nil || tamponOznitelikleri[kSatirIciKodAnahtari] as? Bool == true || tamponOznitelikleri[kCiplakBagAnahtari] as? Bool == true
        // Bağlantı etiketinde köşeli parantez, okuyucunun etiket sonunu şaşırmaması için hep kaçar.
        let etiketMi = tamponOznitelikleri[.link] != nil && tamponOznitelikleri[kCiplakBagAnahtari] as? Bool != true
        var parca = duzKodVeyaURL ? tampon : markdownKarakterleriniKacir(tampon,
            riskli: etiketMi ? riskli.union(["[", "]"]) : riskli, satirBasinda: sonuc.isEmpty)
        let baslik = tamponOznitelikleri[kBaslikSeviyesiAnahtari] as? Int
        if tamponOznitelikleri[kSatirIciKodAnahtari] as? Bool == true {
            let ayirac = kodAyiraci(parca, enAz: 1)
            let bosluk = parca.hasPrefix("`") || parca.hasSuffix("`") ||
                (parca.hasPrefix(" ") && parca.hasSuffix(" ") && !parca.trimmingCharacters(in: .whitespaces).isEmpty) ? " " : ""
            parca = ayirac + bosluk + parca + bosluk + ayirac
        }
        if italikMi(font) { parca = "*\(parca)*" }
        if tamponOznitelikleri[kUstuCiziliAnahtari] as? Bool == true { parca = "~~\(parca)~~" }
        if tamponOznitelikleri[kVurguAnahtari] as? Bool == true { parca = "==\(parca)==" }
        if kalinMi(font), baslik == nil { parca = "**\(parca)**" }
        let kayitBoyutu = font.pointSize / ((tamponOznitelikleri[kSayfaYaziOlcegiAnahtari] as? CGFloat) ?? 1)
        if baslik == nil, abs(kayitBoyutu - kTabanPunto) > 0.01 {
            parca = "<punto=\(boyutMetni(kayitBoyutu))>\(parca)</punto>"
        }
        if let bag = tamponOznitelikleri[.link], tamponOznitelikleri[kCiplakBagAnahtari] as? Bool != true {
            parca = "[\(parca)](\(bag))"
        }
        sonuc += parca
        tampon = ""
        tamponFontu = nil
    }
    func onEkiYaz(_ onEk: String) {
        if tampon.isEmpty { sonuc += onEk } else { tampon += onEk }
    }
    attr.enumerateAttributes(in: tamAralik, options: []) { oznitelikler, aralik, _ in
        guard aralik.location >= yazilanBagSonu else { return }
        if satirBasi, let blok = oznitelikler[kMetinBloguAnahtari] as? MetinBlogu {
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
        // Görsel eki: ![](ekler/dosya.png){genişlikxyükseklik}
        if let ek = oznitelikler[.attachment] as? ResimEki, let url = ek.dosyaURL {
            tamponuYaz()
            if satirBasi, let seviye = oznitelikler[kBaslikSeviyesiAnahtari] as? Int {
                sonuc += String(repeating: "#", count: seviye) + " "
            }
            let boyut = resimBoyutuGecerliMi(ek.gosterimBoyutu) ? ek.gosterimBoyutu : NSSize(width: 200, height: 150)
            let yol = ek.bagYolu ?? "\(kGorsellerKlasorAdi)/\(url.lastPathComponent)"
            sonuc += "![](\(yol)){\(Int(boyut.width))x\(Int(boyut.height))}"
            satirBasi = false
            return
        }
        let font = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
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
        let bicim = "\(font.pointSize)|\(kalinMi(font))|\(italikMi(font))|" +
            [kSatirIciKodAnahtari, kUstuCiziliAnahtari, kVurguAnahtari, .link,
             kCiplakBagAnahtari, kSayfaBagiAnahtari, kBaslikSeviyesiAnahtari].map { String(describing: oznitelikler[$0]) }.joined(separator: "|")
        if tamponFontu != nil, tamponBicimi != bicim { tamponuYaz() }
        tamponFontu = font
        tamponBicimi = bicim
        tamponOznitelikleri = oznitelikler
        tampon += parca
        if satirSonu { tamponuYaz(); sonuc += "\n" }
        satirBasi = satirSonu
    }
    tamponuYaz()
    return sonuc
}

/// Kaydedilmemiş yeni bir notun içeriğinden otomatik bir dosya adı üretir (ilk satırdan).
func otomatikBaslikUret(icerik: String) -> String {
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

// Yol taraması macOS dosya yolu sınırını aşmaz; iç içe adaylar da sınırlı maliyetle işlenir.
private let kResimBagiDeseni = try! NSRegularExpression(
    pattern: #"!\[[^\]]*\]\(([^)]{0,\#(PATH_MAX)})\)(?:\{([0-9]+)x([0-9]+)\})?"#)

/// "![](ekler/x.png){320x240}" biçimindeki bağlantıyı okur; dosya diskte varsa
/// ek üretir, yoksa nil döner (metin olduğu gibi korunsun diye).
func resimBaginiCozumle(_ ns: NSString, _ baslangic: Int, taban: URL, metin: String? = nil) -> (ResimEki, Int)? {
    guard let eslesme = kResimBagiDeseni.firstMatch(in: metin ?? (ns as String), options: .anchored,
          range: NSRange(location: baslangic, length: ns.length - baslangic)),
          eslesme.range(at: 1).location != NSNotFound else { return nil }

    let yol = ns.substring(with: eslesme.range(at: 1))
    // Önce sayfanın kendi klasörüne göre, olmazsa eski düzendeki kök klasöre göre çöz.
    let adaylar = [taban.appendingPathComponent(yol), notlarKlasoru().appendingPathComponent(yol)]
    guard let dosyaURL = adaylar.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
          let gorsel = NSImage(contentsOf: dosyaURL) else { return nil }

    var gosterimBoyutu: NSSize?
    if eslesme.range(at: 2).location != NSNotFound,
       let en = Double(ns.substring(with: eslesme.range(at: 2))),
       let boy = Double(ns.substring(with: eslesme.range(at: 3))) {
        let boyut = NSSize(width: en, height: boy)
        if resimBoyutuGecerliMi(boyut) { gosterimBoyutu = boyut }
    }
    return (resimEkiUret(gorsel: gorsel, dosyaURL: dosyaURL, bagYolu: yol, gosterimBoyutu: gosterimBoyutu), eslesme.range.length)
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
    let sonuc = NSMutableAttributedString()
    let ns = metin as NSString
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
    let ciplakBaglar = Dictionary(uniqueKeysWithValues: kBagAlgilayici.matches(in: metin,
        range: NSRange(location: 0, length: ns.length)).map { ($0.range.location, $0) })

    func yazimOznitelikleri() -> [NSAttributedString.Key: Any] {
        var oznitelikler: [NSAttributedString.Key: Any] = [
            .font: baslikSeviyesi > 0 ? baslikFontu(baslikSeviyesi) : fontUret(boyut: boyut, kalin: kalin),
            .foregroundColor: kMetinRenk]
        if italik {
            oznitelikler[.font] = NSFontManager.shared.convert(oznitelikler[.font] as! NSFont, toHaveTrait: .italicFontMask)
        }
        if ustuCizili { oznitelikler[kUstuCiziliAnahtari] = true; oznitelikler[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if vurgu { oznitelikler[kVurguAnahtari] = true; oznitelikler[.backgroundColor] = NSColor.systemYellow.withAlphaComponent(0.3) }
        if baslikSeviyesi > 0 { oznitelikler[kBaslikSeviyesiAnahtari] = baslikSeviyesi }
        if let blok {
            oznitelikler.merge(blok.oznitelikler) { _, yeni in yeni }
            if blok.tur == .yapilacak, blok.tamamlandi {
                oznitelikler[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                oznitelikler[.foregroundColor] = kMetinRenk.withAlphaComponent(0.45)
            }
        }
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
                        .font: baslikFontu(baslikSeviyesi), .foregroundColor: kMetinRenk,
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
        if let bag = ciplakBaglar[i], let url = bag.url, disBaglantiGecerliMi(url) {
            // URL yolundaki yıldız/backtick, metin biçimi olarak yorumlanmamalı.
            var yazi = ns.substring(with: bag.range)
            for (etkin, isaret) in [(kalin, "**"), (italik, "*"), (ustuCizili, "~~"), (vurgu, "==")] {
                if etkin, yazi.hasSuffix(isaret) { yazi.removeLast(isaret.count) }
            }
            tamponuBosalt()
            var oznitelikler = yazimOznitelikleri()
            oznitelikler[.link] = URL(string: yazi) ?? url
            oznitelikler[kCiplakBagAnahtari] = true
            sonuc.append(NSAttributedString(string: yazi, attributes: oznitelikler))
            i += (yazi as NSString).length
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
                let eskiFont = oznitelikler[.font] as! NSFont
                oznitelikler[.font] = NSFontManager.shared.convert(
                    NSFont.monospacedSystemFont(ofSize: eskiFont.pointSize, weight: .regular),
                    toHaveTrait: NSFontManager.shared.traits(of: eskiFont).intersection([.boldFontMask, .italicFontMask]))
                if !vurgu { oznitelikler[.backgroundColor] = kMetinRenk.withAlphaComponent(0.08) }
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
                let font = ic[.font] as? NSFont ?? varsayilanFont()
                if let disFont = dis[.font] as? NSFont {
                    birlesik[.font] = NSFontManager.shared.convert(font,
                        toHaveTrait: NSFontManager.shared.traits(of: disFont).intersection([.boldFontMask, .italicFontMask]))
                    birlesik[.font] = NSFontManager.shared.convert(birlesik[.font] as! NSFont, toSize: disFont.pointSize)
                }
                birlesik.removeValue(forKey: kCiplakBagAnahtari)
                birlesik.removeValue(forKey: kSayfaBagiAnahtari)
                birlesik[.link] = url
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
                let gorsel = NSMutableAttributedString(attachment: ek)
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
                let etiketUzunlugu = (pencere as NSString).range(of: ">").location + 1
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

let kKacisliKoseParantezAnahtari = NSAttributedString.Key("kacisliKoseParantez")
let kSayfaBagiAnahtari = NSAttributedString.Key("sayfaBagi")
let kSatirIciKodAnahtari = NSAttributedString.Key("satirIciKod")
let kKodBloguAnahtari = NSAttributedString.Key("kodBlogu")
let kBosKodSatiriAnahtari = NSAttributedString.Key("bosKodSatiri")
let kUstuCiziliAnahtari = NSAttributedString.Key("ustuCizili")
let kVurguAnahtari = NSAttributedString.Key("vurgu")
let kCiplakBagAnahtari = NSAttributedString.Key("ciplakBag")
let kSayfaYaziOlcegiAnahtari = NSAttributedString.Key("sayfaYaziOlcegi")
private let kMarkdownKaynakAnahtari = NSAttributedString.Key("markdownKaynak")
private let kBagAlgilayici = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

func italikMi(_ font: NSFont) -> Bool {
    NSFontManager.shared.traits(of: font).contains(.italicFontMask)
}

/// Algılama yalnızca açılan/yapıştırılan aralıkta çalışır; yazımda belge taranmaz.
func ciplakBaglariIsaretle(_ metin: NSMutableAttributedString, aralik: NSRange) {
    kBagAlgilayici.enumerateMatches(in: metin.string, range: aralik) { eslesme, _, _ in
        guard let eslesme, let url = eslesme.url, disBaglantiGecerliMi(url),
              metin.attribute(.link, at: eslesme.range.location, effectiveRange: nil) == nil,
              metin.attribute(kSayfaBagiAnahtari, at: eslesme.range.location, effectiveRange: nil) == nil,
              metin.attribute(kSatirIciKodAnahtari, at: eslesme.range.location, effectiveRange: nil) == nil,
              metin.attribute(kKodBloguAnahtari, at: eslesme.range.location, effectiveRange: nil) == nil else { return }
        metin.addAttributes([.link: url, kCiplakBagAnahtari: true], range: eslesme.range)
    }
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
            let ns = parca.string as NSString
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

func sayfaMarkdownunuUret(_ metin: NSAttributedString, ustbilgi: SayfaUstbilgisi) -> String {
    let govde = markdownMetniUret(metin)
    let onek = ustbilgi.markdown
    let ayirac = !onek.isEmpty && !govde.isEmpty && !onek.hasSuffix("\n") && !onek.hasSuffix("\r") ? "\n" : ""
    return onek + ayirac + govde
}

func markdownMetniUret(_ metin: NSAttributedString) -> String {
    var sonuc = ""
    let ns = metin.string as NSString
    var konum = 0
    var oncekiBlok: MetinBlogu?
    while konum < metin.length {
        var aralik = NSRange()
        let kodBlogu = metin.attribute(kKodBloguAnahtari, at: konum, effectiveRange: nil) != nil
        let blok = kodBlogu ? nil : metin.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil) as? MetinBlogu
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
        let kaynak = parca.attribute(kMarkdownKaynakAnahtari, at: 0, effectiveRange: nil) as? [String: String]
        var ayniKaynak = kaynak != nil
        parca.enumerateAttribute(kMarkdownKaynakAnahtari, in: NSRange(location: 0, length: parca.length)) { deger, _, durdur in
            if (deger as? [String: String]) != kaynak { ayniKaynak = false; durdur.pointee = true }
        }
        // Karşılaştırma kayıt/kopyalamada yapılır; özgün paragrafın yazılışı korunur.
        if ayniKaynak, kaynak?["kanonik"] == kanonik { sonuc += kaynak?["metin"] ?? kanonik }
        else { sonuc += kanonik }
        oncekiBlok = blok
        konum = NSMaxRange(aralik)
    }
    return sonuc
}

func markdowndenAttributedStringUret(_ metin: String, taban: URL = notlarKlasoru()) -> NSAttributedString {
    let sonuc = NSMutableAttributedString()
    let ns = metin as NSString
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
            let kapanis = kodBloguKapanisi(metin, ayirac: ayirac, sonrasinda: govdeBasi)
            let govdeSonu = kapanis?.location ?? ns.length
            kaynakAraligi.length = (kapanis.map { NSMaxRange($0) } ?? ns.length) - konum
            let sinirlar = kodBloguSinirlari(acilis: yazi, kapanis: kapanis.map { ns.substring(with: $0) } ?? "")
            let oznitelikler: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: kTabanPunto, weight: .regular),
                .foregroundColor: kMetinRenk, .backgroundColor: kMetinRenk.withAlphaComponent(0.08),
                kKodBloguAnahtari: sinirlar]
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
                .font: varsayilanFont(), .foregroundColor: kMetinRenk, kBlokIsaretiAnahtari: true]))
        }
        let kaynak = ["metin": ns.substring(with: kaynakAraligi), "kanonik": kanonikMarkdownUret(parca)]
        parca.addAttribute(kMarkdownKaynakAnahtari, value: kaynak, range: NSRange(location: 0, length: parca.length))
        sonuc.append(parca)
        konum = NSMaxRange(kaynakAraligi)
    }
    return sonuc
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
let kKacisKarakterleri: Set<Character> = ["\\", "*", "`", "~", "=", "[", "]", ">", "#", ".", "-", "<", "!"]

/// Satırda eşleşebilecek işaretler: düz metindeki tek "*" / "==" ancak satırda ikinci
/// bir eş ya da o biçim varsa okuyucuda biçim açar; yalnızca o zaman kaçmalı.
private func satirKacisRiskleri(_ satir: NSAttributedString) -> Set<Character> {
    var baglam = satir.string
    var riskli = Set<Character>()
    satir.enumerateAttributes(in: NSRange(location: 0, length: satir.length)) { o, _, _ in
        let font = o[.font] as? NSFont ?? varsayilanFont()
        if italikMi(font) || (kalinMi(font) && o[kBaslikSeviyesiAnahtari] == nil) { riskli.insert("*") }
        if o[kUstuCiziliAnahtari] as? Bool == true { riskli.insert("~") }
        if o[kVurguAnahtari] as? Bool == true { riskli.insert("=") }
        if o[kSatirIciKodAnahtari] as? Bool == true { riskli.insert("`") }
        if let bag = o[.link], o[kCiplakBagAnahtari] as? Bool != true { riskli.insert("["); baglam += "\(bag)" }
    }
    func cift(_ h: Character) -> Int { zip(baglam, baglam.dropFirst()).filter { $0 == h && $1 == h }.count }
    if baglam.filter({ $0 == "*" }).count > 1 { riskli.insert("*") }
    if baglam.filter({ $0 == "`" }).count > 1 { riskli.insert("`") }
    if cift("~") > 1 { riskli.insert("~") }
    if cift("=") > 1 { riskli.insert("=") }
    if baglam.contains("[[") || baglam.contains("](") { riskli.insert("[") }
    if satir.length > 0, let blok = satir.attribute(kMetinBloguAnahtari, at: 0, effectiveRange: nil) as? MetinBlogu,
       blok.tur == .alinti || (blok.tur == .uyari && blok.devam) {
        let govde = (satir.string as NSString).substring(from: blokIsaretiUzunlugu(satir))
        if metinBlogunuCozumle("> " + govde.trimmingCharacters(in: .newlines))?.blok.tur == .uyari {
            riskli.insert("[")
        }
    }
    return riskli
}

/// Yalnızca değişen paragrafın kopyası verilir; görünüm işaretleri önceden çıkarılır.
func kelimeleriSay(_ metin: String) -> Int {
    var sayi = 0
    metin.enumerateSubstrings(in: metin.startIndex..<metin.endIndex, options: .byWords) { _, _, _, _ in sayi += 1 }
    return sayi
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
