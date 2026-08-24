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
    boyut == boyut.rounded() ? String(Int(boyut)) : String(format: "%.1f", Double(boyut))
}

/// Metinden biçimlendirme işaretlerini ("**", "<punto=..>") temizler.
func isaretlemeleriTemizle(_ metin: String) -> String {
    metin
        .replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]*\\)(\\{[0-9]+x[0-9]+\\})?", with: "", options: .regularExpression)
        .replacingOccurrences(of: "(?m)^#{1,3} ", with: "", options: .regularExpression)
        .replacingOccurrences(of: "</?punto[^>]*>", with: "", options: .regularExpression)
        .replacingOccurrences(of: "**", with: "")
        .replacingOccurrences(of: "\u{FFFC}", with: "")
}

func markdownMetniUret(_ attr: NSAttributedString) -> String {
    var sonuc = ""
    let tamAralik = NSRange(location: 0, length: attr.length)
    guard tamAralik.length > 0 else { return "" }
    var satirBasi = true
    attr.enumerateAttributes(in: tamAralik, options: []) { oznitelikler, aralik, _ in
        // Görsel eki: ![](ekler/dosya.png){genişlikxyükseklik}
        if let ek = oznitelikler[.attachment] as? ResimEki, let url = ek.dosyaURL {
            let boyut = ek.gosterimBoyutu
            let yol = ek.bagYolu ?? "\(kGorsellerKlasorAdi)/\(url.lastPathComponent)"
            sonuc += "![](\(yol)){\(Int(boyut.width))x\(Int(boyut.height))}"
            satirBasi = false
            return
        }
        let font = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
        var parca = (attr.string as NSString).substring(with: aralik)

        // Başlık paragrafı: satır başına "#" işareti; punto/kalın işaretine gerek yok.
        if let seviye = oznitelikler[kBaslikSeviyesiAnahtari] as? Int, seviye >= 1, seviye <= 3 {
            sonuc += (satirBasi ? String(repeating: "#", count: seviye) + " " : "") + parca
            satirBasi = parca.hasSuffix("\n")
            return
        }
        satirBasi = parca.hasSuffix("\n")

        if kalinMi(font) { parca = "**\(parca)**" }
        // Taban puntodan farklı parçalar <punto=..> etiketiyle saklanır.
        if abs(font.pointSize - kTabanPunto) > 0.01 {
            parca = "<punto=\(boyutMetni(font.pointSize))>\(parca)</punto>"
        }
        sonuc += parca
    }
    return sonuc
}

/// Kaydedilmemiş yeni bir notun içeriğinden otomatik bir dosya adı üretir (ilk satırdan).
func otomatikBaslikUret(icerik: String) -> String {
    let ilkSatir = icerik.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
    var baslik = isaretlemeleriTemizle(ilkSatir)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
    if baslik.count > 40 {
        baslik = String(baslik.prefix(40))
    }
    if baslik.isEmpty {
        let bicim = DateFormatter()
        bicim.dateFormat = "dd.MM.yyyy HH.mm.ss"
        baslik = "Adsız Not \(bicim.string(from: Date()))"
    }
    return baslik
}

/// "![](ekler/x.png){320x240}" biçimindeki bağlantıyı okur; dosya diskte varsa
/// ek üretir, yoksa nil döner (metin olduğu gibi korunsun diye).
func resimBaginiCozumle(_ ns: NSString, _ baslangic: Int, taban: URL) -> (ResimEki, Int)? {
    let kalan = ns.substring(from: baslangic)
    let desen = "^!\\[[^\\]]*\\]\\(([^)]*)\\)(?:\\{([0-9]+)x([0-9]+)\\})?"
    guard let duzenli = try? NSRegularExpression(pattern: desen),
          let eslesme = duzenli.firstMatch(in: kalan, range: NSRange(location: 0, length: (kalan as NSString).length)),
          eslesme.range(at: 1).location != NSNotFound else { return nil }

    let kalanNS = kalan as NSString
    let yol = kalanNS.substring(with: eslesme.range(at: 1))
    // Önce sayfanın kendi klasörüne göre, olmazsa eski düzendeki kök klasöre göre çöz.
    let adaylar = [taban.appendingPathComponent(yol), notlarKlasoru().appendingPathComponent(yol)]
    guard let dosyaURL = adaylar.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
          let gorsel = NSImage(contentsOf: dosyaURL) else { return nil }

    var gosterimBoyutu: NSSize?
    if eslesme.range(at: 2).location != NSNotFound,
       let en = Double(kalanNS.substring(with: eslesme.range(at: 2))),
       let boy = Double(kalanNS.substring(with: eslesme.range(at: 3))) {
        gosterimBoyutu = NSSize(width: en, height: boy)
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

func markdowndenAttributedStringUret(_ metin: String, taban: URL = notlarKlasoru()) -> NSAttributedString {
    let sonuc = NSMutableAttributedString()
    let ns = metin as NSString
    var kalin = false
    var boyut = kTabanPunto
    var baslikSeviyesi = 0
    var tampon: [unichar] = []

    func tamponuBosalt() {
        guard !tampon.isEmpty else { return }
        let parca = String(utf16CodeUnits: tampon, count: tampon.count)
        var oznitelikler: [NSAttributedString.Key: Any] = [
            .font: baslikSeviyesi > 0 ? baslikFontu(baslikSeviyesi) : fontUret(boyut: boyut, kalin: kalin),
            .foregroundColor: kMetinRenk
        ]
        if baslikSeviyesi > 0 { oznitelikler[kBaslikSeviyesiAnahtari] = baslikSeviyesi }
        sonuc.append(NSAttributedString(string: parca, attributes: oznitelikler))
        tampon.removeAll(keepingCapacity: true)
    }

    var i = 0
    var satirBasi = true
    while i < ns.length {
        // Satır başındaki "# ", "## ", "### " başlık düzeyini belirler.
        if satirBasi, ns.character(at: i) == unichar(35) {  // "#"
            var isaretSayisi = 0
            while i + isaretSayisi < ns.length, ns.character(at: i + isaretSayisi) == unichar(35) { isaretSayisi += 1 }
            if isaretSayisi <= 3, i + isaretSayisi < ns.length, ns.character(at: i + isaretSayisi) == unichar(32) {
                tamponuBosalt()
                baslikSeviyesi = isaretSayisi
                i += isaretSayisi + 1
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
            i += 1
            continue
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
        if ns.character(at: i) == unichar(33), i + 1 < ns.length, ns.character(at: i + 1) == unichar(91) {  // "!["
            if let (ek, uzunluk) = resimBaginiCozumle(ns, i, taban: taban) {
                tamponuBosalt()
                sonuc.append(NSAttributedString(attachment: ek))
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
                if etiket == "/punto" {
                    tamponuBosalt()
                    boyut = kTabanPunto
                    i += etiketUzunlugu
                    continue
                }
                if etiket.hasPrefix("punto="), let deger = Double(etiket.dropFirst("punto=".count)),
                   kapanisVarMi(ns, sonrasinda: i + etiketUzunlugu, aranan: "</punto>") {
                    tamponuBosalt()
                    boyut = boyutSinirla(CGFloat(deger))
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
