import AppKit

// MARK: - Tema

struct Tema {
    let ad: String
    let arkaplan: NSColor
    let baslikCubugu: NSColor
    let kenarPanel: NSColor
}

let temaListesi: [Tema] = [
    Tema(ad: "Sepya",
         arkaplan: NSColor(calibratedRed: 0.84, green: 0.81, blue: 0.73, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.78, green: 0.74, blue: 0.65, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.80, green: 0.77, blue: 0.69, alpha: 1.0)),
    Tema(ad: "Yeşilimsi Kağıt",
         arkaplan: NSColor(calibratedRed: 0.79, green: 0.83, blue: 0.76, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.72, green: 0.77, blue: 0.70, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.75, green: 0.80, blue: 0.73, alpha: 1.0)),
    Tema(ad: "Gri Kağıt",
         arkaplan: NSColor(calibratedRed: 0.80, green: 0.80, blue: 0.80, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.73, green: 0.73, blue: 0.73, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.76, green: 0.76, blue: 0.76, alpha: 1.0)),
    Tema(ad: "Krem",
         arkaplan: NSColor(calibratedRed: 0.86, green: 0.83, blue: 0.76, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.80, green: 0.76, blue: 0.67, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.82, green: 0.79, blue: 0.71, alpha: 1.0)),
]

var gTemaIndex: Int = {
    let kayitli = UserDefaults.standard.integer(forKey: "temaIndex")
    return temaListesi.indices.contains(kayitli) ? kayitli : 0
}()

var aktifTema: Tema { temaListesi[gTemaIndex] }

extension NSColor {
    /// Rengi belirtilen miktar kadar koyulaştırır (0-1 arası).
    func koyulastir(_ miktar: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.genericRGB) else { return self }
        return NSColor(calibratedRed: max(rgb.redComponent - miktar, 0),
                        green: max(rgb.greenComponent - miktar, 0),
                        blue: max(rgb.blueComponent - miktar, 0),
                        alpha: rgb.alphaComponent)
    }
}

/// Kenar paneldeki, üzerinde çalışılan (seçili) notun dış kaplama rengi: panel renginin koyusu.
func secimVurguRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.14) }
/// Arama kutusunun, panelden ayrışması için biraz koyulaştırılmış rengi.
func aramaKutuRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.07) }
/// Arama kutusuna odaklanıldığında kullanılan, biraz daha koyu vurgu rengi.
func aramaOdakRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.16) }

/// Bir SF Symbol'ü verilen renkle (varsayılan tonlama/gölge olmadan) yeniden boyar.
func renklendirilmisSembol(_ ad: String, renk: NSColor, boyut: CGFloat = 12) -> NSImage? {
    guard let taban = NSImage(systemSymbolName: ad, accessibilityDescription: nil) else { return nil }
    let yapilandirma = NSImage.SymbolConfiguration(pointSize: boyut, weight: .regular)
    guard let yapilandirilmis = taban.withSymbolConfiguration(yapilandirma) else { return nil }
    let sonuc = NSImage(size: yapilandirilmis.size)
    sonuc.lockFocus()
    yapilandirilmis.draw(at: .zero, from: NSRect(origin: .zero, size: yapilandirilmis.size), operation: .sourceOver, fraction: 1.0)
    renk.set()
    NSRect(origin: .zero, size: yapilandirilmis.size).fill(using: .sourceAtop)
    sonuc.unlockFocus()
    sonuc.isTemplate = false
    return sonuc
}

/// Türkçe karakter/büyük-küçük harf duyarsız arama için metni sadeleştirir
/// (ör. "İ"/"I"/"ı" ve "ö"/"ü"/"ş"/"ç"/"ğ" gibi harfler doğru şekilde eşleşir).
func aramaIcinSadelestir(_ metin: String) -> String {
    metin.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
}

let kMetinRenk = NSColor.black
var gKenarPanelGenislik: CGFloat = {
    let kayitli = UserDefaults.standard.double(forKey: "kenarPanelGenislik")
    return kayitli > 0 ? CGFloat(kayitli) : 190
}()
let kKenarPanelMinGenislik: CGFloat = 140
let kKenarPanelMaksGenislik: CGFloat = 360
let kBaslikYuksekligi: CGFloat = 34
let kOtomatikKayitAraligi: TimeInterval = 5
let kMinYaziBoyutu: CGFloat = 10
let kMaksYaziBoyutu: CGFloat = 28

/// Sabit taban punto. Etiketsiz metnin ve başlıkların ölçüsü buna göre belirlenir;
/// hiçbir zaman değişmez, böylece kaydedilen puntolar yeniden açışta/derlemede kaymaz.
let kTabanPunto: CGFloat = 14

/// İmlecin o anki yazım puntosu (yalnızca yeni yazılacak metin için varsayılan).
/// Kalıcı DEĞİLDİR ve var olan metnin yorumunu etkilemez; her açılışta tabana döner.
var gYaziBoyutu: CGFloat = kTabanPunto

// MARK: - Kaydetme konumu (Belgeler/NotDefteri)

func notlarKlasoru() -> URL {
    let fm = FileManager.default
    let belgeler = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    let klasor = belgeler.appendingPathComponent("NotDefteri", isDirectory: true)
    if !fm.fileExists(atPath: klasor.path) {
        try? fm.createDirectory(at: klasor, withIntermediateDirectories: true)
    }
    return klasor
}

let kGorsellerKlasorAdi = "Görseller"

/// Bir sayfanın görsellerinin tutulduğu klasör: <sayfa klasörü>/Görseller.
func gorsellerKlasoru(_ sayfaninKlasoru: URL = notlarKlasoru()) -> URL {
    let klasor = sayfaninKlasoru.appendingPathComponent(kGorsellerKlasorAdi, isDirectory: true)
    if !FileManager.default.fileExists(atPath: klasor.path) {
        try? FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
    }
    return klasor
}

// MARK: - Girişte otomatik başlatma (LaunchAgent)

func launchAgentYolu() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.notdefteri.baslangic.plist")
}

func giristeAcikMi() -> Bool {
    FileManager.default.fileExists(atPath: launchAgentYolu().path)
}

func giristeAcmayiAyarla(_ acik: Bool) {
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
        // Kalın işareti
        if i + 2 <= ns.length, ns.substring(with: NSRange(location: i, length: 2)) == "**" {
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
                if etiket.hasPrefix("punto="), let deger = Double(etiket.dropFirst("punto=".count)) {
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

// MARK: - Görsel eki (köşesinden çekilerek boyutlandırılabilir)

let kEnKucukResimEni: CGFloat = 48

/// Metnin içine gömülen görsel. Dosya yolunu ve gösterim boyutunu taşır.
final class ResimEki: NSTextAttachment {
    var dosyaURL: URL?
    /// Notta yazılı olan bağ yolu ("Görseller/Başlık1.png"). Eski notların
    /// "ekler/..." bağlarını olduğu gibi korumak için saklanır.
    var bagYolu: String?

    var gosterimBoyutu: NSSize {
        get { (attachmentCell as? ResimEkiHucresi)?.gosterimBoyutu ?? .zero }
        set { (attachmentCell as? ResimEkiHucresi)?.gosterimBoyutu = newValue }
    }
}

/// Görseli çizen ve sağ alt köşesindeki tutamaçtan boyutlandırmayı yöneten hücre.
final class ResimEkiHucresi: NSTextAttachmentCell {

    var gosterimBoyutu: NSSize = NSSize(width: 200, height: 150)
    /// Görselin kendi en/boy oranı; boyutlandırırken korunur.
    var enBoyOrani: CGFloat = 4.0 / 3.0
    private let tutamacBoyutu: CGFloat = 14

    override func cellSize() -> NSSize { gosterimBoyutu }

    /// Görsel, satırda kalan yere sığmıyorsa oranı korunarak sığdırılır.
    /// Saklanan boyut değişmez; pencere genişleyince görsel eski boyutuna döner.
    override func cellFrame(for textContainer: NSTextContainer, proposedLineFragment lineFrag: NSRect,
                            glyphPosition position: NSPoint, characterIndex charIndex: Int) -> NSRect {
        var boyut = gosterimBoyutu
        let sigacakEn = max(kEnKucukResimEni, lineFrag.width - position.x)
        if boyut.width > sigacakEn {
            boyut = NSSize(width: sigacakEn.rounded(), height: (sigacakEn / enBoyOrani).rounded())
        }
        return NSRect(x: 0, y: cellBaselineOffset().y, width: boyut.width, height: boyut.height)
    }

    /// Görseli satırın taban çizgisine oturtur.
    override func cellBaselineOffset() -> NSPoint { NSPoint(x: 0, y: -3) }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        image?.draw(in: cellFrame, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        tutamaciCiz(cellFrame)
    }

    private func tutamaciCiz(_ cellFrame: NSRect) {
        let kare = tutamacKaresi(cellFrame).insetBy(dx: 3, dy: 3)
        NSColor.white.withAlphaComponent(0.9).setFill()
        let yol = NSBezierPath(roundedRect: kare, xRadius: 2, yRadius: 2)
        yol.fill()
        NSColor.black.withAlphaComponent(0.55).setStroke()
        yol.lineWidth = 1
        yol.stroke()
    }

    /// Tutamaç, görselin sağ alt köşesinde (metin görünümü ters çevrilmiş koordinatta).
    private func tutamacKaresi(_ cellFrame: NSRect) -> NSRect {
        NSRect(x: cellFrame.maxX - tutamacBoyutu, y: cellFrame.maxY - tutamacBoyutu,
               width: tutamacBoyutu, height: tutamacBoyutu)
    }

    override func wantsToTrackMouse() -> Bool { true }

    override func trackMouse(with theEvent: NSEvent, in cellFrame: NSRect, of controlView: NSView?, untilMouseUp flag: Bool) -> Bool {
        guard let metinGorunumu = controlView as? NSTextView, let pencere = metinGorunumu.window else { return false }
        let baslangicNoktasi = metinGorunumu.convert(theEvent.locationInWindow, from: nil)
        // Tutamacın dışına basıldıysa olağan davranış (seçme/sürükleme) sürsün.
        guard tutamacKaresi(cellFrame).contains(baslangicNoktasi) else { return false }

        let baslangicBoyutu = gosterimBoyutu
        let enFazlaEn = maksimumEn(metinGorunumu)

        while let olay = pencere.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if olay.type == .leftMouseUp { break }
            let nokta = metinGorunumu.convert(olay.locationInWindow, from: nil)
            // Çapraz çekme: yatay ve dikey hareketin ortalaması, oran korunarak.
            let yatayFark = nokta.x - baslangicNoktasi.x
            let dikeyFark = (nokta.y - baslangicNoktasi.y) * enBoyOrani
            let yeniEn = min(max(baslangicBoyutu.width + (yatayFark + dikeyFark) / 2, kEnKucukResimEni), enFazlaEn)
            gosterimBoyutu = NSSize(width: yeniEn.rounded(), height: (yeniEn / enBoyOrani).rounded())
            yerlesimiTazele(metinGorunumu)
        }
        yerlesimiTazele(metinGorunumu)
        // Boyut değişikliği not içeriğinin bir parçası; kaydı tetikle.
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: metinGorunumu)
        return true
    }

    /// Görselin sığabileceği en fazla genişlik (metin alanı eksi kenar boşlukları).
    private func maksimumEn(_ metinGorunumu: NSTextView) -> CGFloat {
        let kapsayiciEni = metinGorunumu.textContainer?.size.width ?? metinGorunumu.bounds.width
        return max(kEnKucukResimEni, kapsayiciEni - metinGorunumu.textContainerInset.width * 2 - 8)
    }

    /// Hücre boyutu değişince satır yerleşimi yeniden hesaplanmalı.
    private func yerlesimiTazele(_ metinGorunumu: NSTextView) {
        guard let metinDeposu = metinGorunumu.textStorage,
              let ekIndeksi = ekinIndeksi(metinDeposu) else { return }
        metinDeposu.edited(.editedAttributes, range: NSRange(location: ekIndeksi, length: 1), changeInLength: 0)
        metinGorunumu.needsDisplay = true
    }

    private func ekinIndeksi(_ metinDeposu: NSTextStorage) -> Int? {
        var bulunan: Int?
        metinDeposu.enumerateAttribute(.attachment, in: NSRange(location: 0, length: metinDeposu.length), options: []) { deger, aralik, durdur in
            if let ek = deger as? NSTextAttachment, ek.attachmentCell === self {
                bulunan = aralik.location
                durdur.pointee = true
            }
        }
        return bulunan
    }
}

/// Görsel verisinden, verilen gösterim boyutuyla bir ek üretir.
func resimEkiUret(gorsel: NSImage, dosyaURL: URL, bagYolu: String? = nil, gosterimBoyutu: NSSize? = nil) -> ResimEki {
    let ek = ResimEki()
    let hucre = ResimEkiHucresi()
    hucre.image = gorsel

    let gercekBoyut = gorsel.size
    let oran = gercekBoyut.height > 0 ? gercekBoyut.width / gercekBoyut.height : 1
    hucre.enBoyOrani = oran > 0 ? oran : 1

    if let istenen = gosterimBoyutu, istenen.width >= kEnKucukResimEni {
        hucre.gosterimBoyutu = istenen
    } else {
        // Yeni eklenen görsel çok büyükse makul bir başlangıç genişliğine indirilir.
        let baslangicEni = min(gercekBoyut.width, 360)
        hucre.gosterimBoyutu = NSSize(width: baslangicEni.rounded(), height: (baslangicEni / hucre.enBoyOrani).rounded())
    }

    ek.attachmentCell = hucre
    ek.dosyaURL = dosyaURL
    ek.bagYolu = bagYolu ?? "\(kGorsellerKlasorAdi)/\(dosyaURL.lastPathComponent)"
    return ek
}

// MARK: - Görsel yapıştırma/sürükleme kabul eden metin görünümü

final class NotMetinGorunumu: NSTextView {

    /// Panodan gelen görseli diske yazıp ek üretmesi için pencereye sorar.
    /// İkinci parametre, görselin eklendiği bölümün başlığı (varsa).
    var gorselEklenecek: ((NSImage, String?) -> ResimEki?)?

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if let gorsel = panodanGorsel(pboard), let ek = gorselEklenecek?(gorsel, bulunanBolumBasligi()) {
            ekiEkle(ek)
            return true
        }
        return super.readSelection(from: pboard, type: type)
    }

    /// İmlecin bulunduğu yerden yukarı doğru en yakın başlık satırının metni.
    /// Görsel dosyasını o bölümün adıyla kaydetmek için kullanılır.
    private func bulunanBolumBasligi() -> String? {
        guard let metinDeposu = textStorage, metinDeposu.length > 0 else { return nil }
        let ns = metinDeposu.string as NSString
        var aralik = ns.paragraphRange(for: NSRange(location: min(selectedRange().location, ns.length - 1), length: 0))
        while true {
            if aralik.length > 0,
               metinDeposu.attribute(kBaslikSeviyesiAnahtari, at: aralik.location, effectiveRange: nil) != nil {
                let baslik = ns.substring(with: aralik).trimmingCharacters(in: .whitespacesAndNewlines)
                if !baslik.isEmpty { return baslik }
            }
            guard aralik.location > 0 else { return nil }
            aralik = ns.paragraphRange(for: NSRange(location: aralik.location - 1, length: 0))
        }
    }

    private func panodanGorsel(_ pano: NSPasteboard) -> NSImage? {
        // Ekran görüntüleri ve kopyalanan görseller doğrudan pano verisi olarak gelir.
        if let gorsel = NSImage(pasteboard: pano), gorsel.size.width > 0 { return gorsel }
        // Finder'dan sürüklenen dosyalar.
        if let urller = pano.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let ilk = urller.first,
           ["png", "jpg", "jpeg", "gif", "heic", "tiff"].contains(ilk.pathExtension.lowercased()) {
            return NSImage(contentsOf: ilk)
        }
        return nil
    }

    private func ekiEkle(_ ek: ResimEki) {
        let aralik = selectedRange()
        let ns = (textStorage?.string ?? "") as NSString

        // Görsel kendi satırında (blok) dursun: aynı satırı yazıyla paylaşınca
        // satır yüksekliği görsel kadar olur ve yanında kocaman boşluk oluşur.
        let satirBasindaMi = aralik.location == 0 || ns.character(at: aralik.location - 1) == 10  // "\n"
        let satirSonundaMi = NSMaxRange(aralik) >= ns.length || ns.character(at: NSMaxRange(aralik)) == 10

        // Görsel ve çevresindeki satır sonları normal metin biçiminde olsun (başlık değil).
        let duzOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]

        let eklenecek = NSMutableAttributedString()
        if !satirBasindaMi { eklenecek.append(NSAttributedString(string: "\n", attributes: duzOznitelik)) }
        let gorselAralikBasi = eklenecek.length
        eklenecek.append(NSAttributedString(attachment: ek))
        eklenecek.addAttribute(.foregroundColor, value: kMetinRenk, range: NSRange(location: gorselAralikBasi, length: 1))
        if !satirSonundaMi { eklenecek.append(NSAttributedString(string: "\n", attributes: duzOznitelik)) }

        guard shouldChangeText(in: aralik, replacementString: eklenecek.string) else { return }
        textStorage?.replaceCharacters(in: aralik, with: eklenecek)
        didChangeText()
        // İmleci görselden hemen sonraya al ve yazımın normal biçimde sürmesini sağla.
        setSelectedRange(NSRange(location: aralik.location + gorselAralikBasi + 1, length: 0))
        typingAttributes = duzOznitelik
    }
}

// MARK: - Özel başlık çubuğu (Yeni Not / Sabitle / Arkaya At / Kapat)

final class BaslikCubugu: NSView {

    weak var pencere: NSWindow?
    private(set) var sabitlemeAcik = false

    var yeniNotTiklandi: (() -> Void)?
    var kapatTiklandi: (() -> Void)?
    var kenarPaneliDegistirTiklandi: (() -> Void)?
    var geriAlTiklandi: (() -> Void)?
    var ileriAlTiklandi: (() -> Void)?

    let notAdiEtiketi = NSTextField(labelWithString: "Yeni Not")

    private lazy var kenarPaneliButon = ozelButonOlustur(sembol: "sidebar.left", aciklama: "Kenar Paneli Göster/Gizle")
    private lazy var yeniNotButon = ozelButonOlustur(sembol: "square.and.pencil", aciklama: "Yeni Not")
    private lazy var geriAlButon = ozelButonOlustur(sembol: "arrow.uturn.backward", aciklama: "Geri Al (⌘Z)")
    private lazy var ileriAlButon = ozelButonOlustur(sembol: "arrow.uturn.forward", aciklama: "Yinele (⌘Y)")
    private lazy var sabitleButon = ozelButonOlustur(sembol: "pin", aciklama: "Sabitle (her zaman üstte)")
    private lazy var arkayaAtButon = ozelButonOlustur(sembol: "minus", aciklama: "Arka plana at")
    private lazy var kapatButon = ozelButonOlustur(sembol: "xmark", aciklama: "Kapat")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = aktifTema.baslikCubugu.cgColor

        kenarPaneliButon.target = self
        kenarPaneliButon.action = #selector(kenarPaneliButonaTiklandi)

        yeniNotButon.target = self
        yeniNotButon.action = #selector(yeniNotButonaTiklandi)

        geriAlButon.target = self
        geriAlButon.action = #selector(geriAlButonaTiklandi)

        ileriAlButon.target = self
        ileriAlButon.action = #selector(ileriAlButonaTiklandi)

        sabitleButon.target = self
        sabitleButon.action = #selector(sabitleButonaTiklandi)

        arkayaAtButon.target = self
        arkayaAtButon.action = #selector(arkayaAtButonaTiklandi)

        kapatButon.target = self
        kapatButon.action = #selector(kapatButonaTiklandi)

        notAdiEtiketi.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        notAdiEtiketi.textColor = .darkGray
        notAdiEtiketi.lineBreakMode = .byTruncatingTail

        for altGorunum in [kenarPaneliButon, yeniNotButon, geriAlButon, ileriAlButon, notAdiEtiketi, sabitleButon, arkayaAtButon, kapatButon] {
            addSubview(altGorunum)
        }
        sabitlemeGorunumunuGuncelle()
        gecmisDurumunuGoster(geriAlinabilir: false, ileriAlinabilir: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func ozelButonOlustur(sembol: String, aciklama: String) -> NSButton {
        let buton = NSButton(image: NSImage(systemSymbolName: sembol, accessibilityDescription: aciklama) ?? NSImage(), target: nil, action: nil)
        buton.bezelStyle = .circular
        buton.isBordered = false
        buton.imageScaling = .scaleProportionallyDown
        buton.toolTip = aciklama
        buton.contentTintColor = .darkGray
        buton.refusesFirstResponder = true  // Odak yazı alanından kaçmasın.
        return buton
    }

    func temayiUygula() {
        layer?.backgroundColor = aktifTema.baslikCubugu.cgColor
    }

    override func layout() {
        super.layout()
        let boyut: CGFloat = 22
        let bosluk: CGFloat = 8
        let y = (bounds.height - boyut) / 2

        var x = bounds.width - boyut - 10
        kapatButon.frame = NSRect(x: x, y: y, width: boyut, height: boyut)
        x -= (boyut + bosluk)
        arkayaAtButon.frame = NSRect(x: x, y: y, width: boyut, height: boyut)
        x -= (boyut + bosluk)
        sabitleButon.frame = NSRect(x: x, y: y, width: boyut, height: boyut)

        let solX: CGFloat = 10
        for (sira, buton) in [kenarPaneliButon, yeniNotButon, geriAlButon, ileriAlButon].enumerated() {
            buton.frame = NSRect(x: solX + (boyut + bosluk) * CGFloat(sira), y: y, width: boyut, height: boyut)
        }

        let etiketX = solX + (boyut + bosluk) * 4
        let etiketGenislik = max(0, sabitleButon.frame.minX - 8 - etiketX)
        notAdiEtiketi.frame = NSRect(x: etiketX, y: (bounds.height - 16) / 2, width: etiketGenislik, height: 16)
    }

    @objc private func kenarPaneliButonaTiklandi() { kenarPaneliDegistirTiklandi?() }

    @objc private func yeniNotButonaTiklandi() { yeniNotTiklandi?() }

    @objc private func geriAlButonaTiklandi() { geriAlTiklandi?() }

    @objc private func ileriAlButonaTiklandi() { ileriAlTiklandi?() }

    /// Geri/ileri alınacak işlem yoksa düğmeyi soluklaştırıp devre dışı bırakır.
    func gecmisDurumunuGoster(geriAlinabilir: Bool, ileriAlinabilir: Bool) {
        geriAlButon.isEnabled = geriAlinabilir
        geriAlButon.alphaValue = geriAlinabilir ? 1.0 : 0.3
        ileriAlButon.isEnabled = ileriAlinabilir
        ileriAlButon.alphaValue = ileriAlinabilir ? 1.0 : 0.3
    }

    @objc private func sabitleButonaTiklandi() {
        sabitlemeAcik.toggle()
        pencere?.level = sabitlemeAcik ? .floating : .normal
        sabitlemeGorunumunuGuncelle()
    }

    private func sabitlemeGorunumunuGuncelle() {
        sabitleButon.contentTintColor = sabitlemeAcik ? .systemOrange : .darkGray
    }

    @objc private func arkayaAtButonaTiklandi() {
        pencere?.miniaturize(nil)
    }

    @objc private func kapatButonaTiklandi() {
        kapatTiklandi?()
    }

    override func mouseDown(with event: NSEvent) {
        pencere?.performDrag(with: event)
    }
}

// MARK: - Not satırı (seçili notun dış kaplamasını animasyonlu şekilde vurgular)

final class NotSatirGorunumu: NSTableRowView {

    private let vurguGorunumu = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        vurguGorunumu.wantsLayer = true
        vurguGorunumu.layer?.cornerRadius = 6
        vurguGorunumu.layer?.backgroundColor = secimVurguRengi().cgColor
        vurguGorunumu.alphaValue = 0
        addSubview(vurguGorunumu, positioned: .below, relativeTo: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        vurguGorunumu.frame = bounds.insetBy(dx: 4, dy: 1)
    }

    override var isSelected: Bool {
        get { super.isSelected }
        set {
            let degisti = super.isSelected != newValue
            super.isSelected = newValue
            guard degisti else { return }
            NSAnimationContext.runAnimationGroup { baglam in
                baglam.duration = 0.16
                baglam.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                vurguGorunumu.animator().alphaValue = newValue ? 1 : 0
            }
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        // Varsayılan mavi seçim çizimi yerine kendi vurgu view'ımızı kullanıyoruz.
    }

    func temayiUygula() {
        vurguGorunumu.layer?.backgroundColor = secimVurguRengi().cgColor
    }
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

// MARK: - Kenar panel (arama + not ağacı + punto kısayolu)

final class KenarPaneli: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate, NSMenuDelegate {

    /// Ağacın görüntülenen (arama filtresinden geçmiş) hâli.
    private var kokDugumler: [AgacDugumu] = []
    /// Ağacın filtrelenmemiş hâli.
    private var tumKokDugumler: [AgacDugumu] = []
    private var icerikOnbellek: [URL: String] = [:]
    private var acikNotURL: URL?

    /// Görüntülenen sıradaki notlar (klasörler hariç).
    private(set) var notListesi: [URL] = []
    private var tumNotlar: [URL] = []
    /// Cmd+[ / Cmd+] ile gezinme gibi, arama filtresinden etkilenmemesi gereken durumlar için tüm notlar.
    var tumNotUrlListesi: [URL] { tumNotlar }

    var notSecildi: ((URL) -> Void)?
    var notSilindi: ((URL) -> Void)?
    var notYenidenAdlandirildi: ((URL, URL) -> Void)?
    /// Kenar paneldeki punto kısayolu (A- / A+) tıklandığında tetiklenir.
    var puntoDegistirIstendi: ((CGFloat) -> Void)?
    /// Verilen klasörün içine yeni bir sayfa oluşturulması istendiğinde tetiklenir.
    var yeniSayfaIstendi: ((URL) -> Void)?
    /// Başlık düğmelerine (B1/B2/B3/Aa) basıldığında tetiklenir; 0 = normal metin.
    var baslikSeviyesiIstendi: ((Int) -> Void)?

    let tablo = NSOutlineView()
    private let kaydirmaGorunumu = NSScrollView()
    private let aramaKutusu = NSView()
    private let aramaIkonu = NSImageView()
    private let aramaAlani = NSTextField()
    private let aramaTemizleButonu = NSButton()
    private let baslikCubugu = NSView()
    private var baslikButonlari: [NSButton] = []
    private let puntoCubugu = NSView()
    private let puntoAzaltButonu = NSButton()
    private let puntoArttirButonu = NSButton()
    private let puntoEtiketi = NSTextField(labelWithString: "")
    private var programatikSecimYapiliyor = false
    /// Adı yerinde düzenlenen düğüm (çift tıklama ile açılır).
    private var duzenlenenDugum: AgacDugumu?
    private var adDuzenlemesiIptal = false
    /// Açık bırakılan klasörler oturumlar arasında hatırlanır.
    private var acikKlasorYollari: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "acikKlasorler") ?? [])

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = aktifTema.kenarPanel.cgColor

        aramaKutusu.wantsLayer = true
        aramaKutusu.layer?.cornerRadius = 7
        aramaKutusu.layer?.backgroundColor = aramaKutuRengi().cgColor
        addSubview(aramaKutusu)

        aramaIkonu.image = renklendirilmisSembol("magnifyingglass", renk: NSColor.black.withAlphaComponent(0.65), boyut: 12)
        aramaIkonu.imageScaling = .scaleProportionallyDown
        aramaKutusu.addSubview(aramaIkonu)

        aramaAlani.delegate = self
        aramaAlani.font = NSFont.systemFont(ofSize: 12)
        aramaAlani.isBezeled = false
        aramaAlani.isBordered = false
        aramaAlani.drawsBackground = false
        aramaAlani.focusRingType = .none
        aramaAlani.textColor = .black
        aramaAlani.usesSingleLineMode = true
        aramaAlani.lineBreakMode = .byTruncatingTail
        aramaAlani.placeholderAttributedString = NSAttributedString(
            string: "Notlarda ara...",
            attributes: [.foregroundColor: NSColor.black.withAlphaComponent(0.45), .font: NSFont.systemFont(ofSize: 12)]
        )
        aramaKutusu.addSubview(aramaAlani)

        aramaTemizleButonu.image = renklendirilmisSembol("xmark.circle.fill", renk: NSColor.black.withAlphaComponent(0.55), boyut: 13)
        aramaTemizleButonu.isBordered = false
        aramaTemizleButonu.imageScaling = .scaleProportionallyDown
        aramaTemizleButonu.target = self
        aramaTemizleButonu.action = #selector(aramaTemizleTiklandi)
        aramaTemizleButonu.isHidden = true
        aramaKutusu.addSubview(aramaTemizleButonu)

        let sutun = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NotSutunu"))
        sutun.width = max(gKenarPanelGenislik - 8, 60)
        tablo.addTableColumn(sutun)
        tablo.outlineTableColumn = sutun
        tablo.headerView = nil
        tablo.backgroundColor = .clear
        tablo.rowHeight = 26
        tablo.dataSource = self
        tablo.delegate = self
        tablo.selectionHighlightStyle = .regular
        tablo.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tablo.intercellSpacing = NSSize(width: 0, height: 2)
        tablo.indentationPerLevel = 13
        tablo.indentationMarkerFollowsCell = true
        tablo.autoresizesOutlineColumn = false
        tablo.target = self
        tablo.doubleAction = #selector(cifteTiklandi)

        let sagTikMenusu = NSMenu()
        let altSayfaOgesi = NSMenuItem(title: "Alt Sayfa Ekle", action: #selector(altSayfaEkleTiklandi), keyEquivalent: "")
        altSayfaOgesi.target = self
        sagTikMenusu.addItem(altSayfaOgesi)
        let kardesSayfaOgesi = NSMenuItem(title: "Yanına Sayfa Ekle", action: #selector(kardesSayfaEkleTiklandi), keyEquivalent: "")
        kardesSayfaOgesi.target = self
        sagTikMenusu.addItem(kardesSayfaOgesi)
        sagTikMenusu.addItem(NSMenuItem.separator())
        let yenidenAdlandirOgesi = NSMenuItem(title: "Yeniden Adlandır", action: #selector(yenidenAdlandirTiklandi), keyEquivalent: "")
        yenidenAdlandirOgesi.target = self
        sagTikMenusu.addItem(yenidenAdlandirOgesi)
        let silOgesi = NSMenuItem(title: "Sil", action: #selector(silTiklandi), keyEquivalent: "")
        silOgesi.target = self
        sagTikMenusu.addItem(silOgesi)
        let donusturOgesi = NSMenuItem(title: "Sayfa Klasörüne Dönüştür", action: #selector(klasoreDonusturTiklandi), keyEquivalent: "")
        donusturOgesi.target = self
        sagTikMenusu.addItem(NSMenuItem.separator())
        sagTikMenusu.addItem(donusturOgesi)
        sagTikMenusu.delegate = self
        tablo.menu = sagTikMenusu

        kaydirmaGorunumu.documentView = tablo
        kaydirmaGorunumu.hasVerticalScroller = true
        kaydirmaGorunumu.drawsBackground = false
        kaydirmaGorunumu.borderType = .noBorder
        addSubview(kaydirmaGorunumu)

        baslikCubuguKur()
        puntoCubuguKur()
    }

    /// Punto çubuğunun üstündeki başlık düzeyi kısayolları: B1 / B2 / B3 / Aa
    private func baslikCubuguKur() {
        baslikCubugu.wantsLayer = true
        baslikCubugu.layer?.cornerRadius = 7
        baslikCubugu.layer?.backgroundColor = aramaKutuRengi().cgColor
        addSubview(baslikCubugu)

        let tanimlar: [(String, Int, String)] = [
            ("B1", 1, "En büyük başlık (satır başında /1 + boşluk)"),
            ("B2", 2, "Alt başlık (/2 + boşluk)"),
            ("B3", 3, "Küçük başlık (/3 + boşluk)"),
            ("Aa", 0, "Normal metin (/0 + boşluk)")
        ]
        for (yazi, seviye, ipucu) in tanimlar {
            let buton = NSButton()
            buton.title = yazi
            buton.isBordered = false
            buton.bezelStyle = .inline
            buton.refusesFirstResponder = true
            buton.toolTip = ipucu
            buton.tag = seviye
            buton.attributedTitle = NSAttributedString(
                string: yazi,
                attributes: [.foregroundColor: NSColor.black.withAlphaComponent(0.7),
                             .font: NSFont.systemFont(ofSize: 11.5, weight: seviye == 0 ? .regular : .semibold)]
            )
            buton.target = self
            buton.action = #selector(baslikButonunaTiklandi(_:))
            baslikCubugu.addSubview(buton)
            baslikButonlari.append(buton)
        }
    }

    @objc private func baslikButonunaTiklandi(_ gonderen: NSButton) {
        baslikSeviyesiIstendi?(gonderen.tag)
    }

    /// Panelin altındaki punto kısayolu: A-  /  14 pt  /  A+
    private func puntoCubuguKur() {
        puntoCubugu.wantsLayer = true
        puntoCubugu.layer?.cornerRadius = 7
        puntoCubugu.layer?.backgroundColor = aramaKutuRengi().cgColor
        addSubview(puntoCubugu)

        puntoAzaltButonu.title = "A−"
        puntoAzaltButonu.toolTip = "Seçili yazının puntosunu küçült (⌘−)"
        puntoArttirButonu.title = "A+"
        puntoArttirButonu.toolTip = "Seçili yazının puntosunu büyüt (⌘*)"

        for (buton, puntoBoyutu) in [(puntoAzaltButonu, CGFloat(11)), (puntoArttirButonu, CGFloat(13))] {
            buton.isBordered = false
            buton.bezelStyle = .inline
            buton.refusesFirstResponder = true   // Odak, yazı alanından kaçmasın.
            buton.font = NSFont.systemFont(ofSize: puntoBoyutu, weight: .semibold)
            buton.contentTintColor = .darkGray
            buton.attributedTitle = NSAttributedString(
                string: buton.title,
                attributes: [.foregroundColor: NSColor.black.withAlphaComponent(0.7),
                             .font: NSFont.systemFont(ofSize: puntoBoyutu, weight: .semibold)]
            )
            buton.target = self
            puntoCubugu.addSubview(buton)
        }
        puntoAzaltButonu.action = #selector(puntoAzaltTiklandi)
        puntoArttirButonu.action = #selector(puntoArttirTiklandi)

        puntoEtiketi.font = NSFont.systemFont(ofSize: 11.5)
        puntoEtiketi.textColor = NSColor.black.withAlphaComponent(0.6)
        puntoEtiketi.alignment = .center
        puntoCubugu.addSubview(puntoEtiketi)

        puntoyuGoster(gYaziBoyutu)
    }

    /// Punto göstergesini günceller (imlecin bulunduğu ya da seçili metnin puntosu).
    func puntoyuGoster(_ boyut: CGFloat) {
        puntoEtiketi.stringValue = "\(boyutMetni(boyut)) pt"
    }

    @objc private func puntoAzaltTiklandi() { puntoDegistirIstendi?(-1) }
    @objc private func puntoArttirTiklandi() { puntoDegistirIstendi?(1) }

    required init?(coder: NSCoder) { fatalError() }

    func temayiUygula() {
        layer?.backgroundColor = aktifTema.kenarPanel.cgColor
        aramaKutusu.layer?.backgroundColor = aramaKutuRengi().cgColor
        baslikCubugu.layer?.backgroundColor = aramaKutuRengi().cgColor
        puntoCubugu.layer?.backgroundColor = aramaKutuRengi().cgColor
        for satirIndex in 0..<tablo.numberOfRows {
            (tablo.rowView(atRow: satirIndex, makeIfNecessary: false) as? NotSatirGorunumu)?.temayiUygula()
        }
    }

    override func layout() {
        super.layout()
        let aramaAlaniYuksekligi: CGFloat = 24
        let ustBosluk: CGFloat = 8
        aramaKutusu.frame = NSRect(x: 8, y: bounds.height - aramaAlaniYuksekligi - ustBosluk, width: bounds.width - 16, height: aramaAlaniYuksekligi)

        let ikonBoyutu: CGFloat = 13
        aramaIkonu.frame = NSRect(x: 6, y: (aramaAlaniYuksekligi - ikonBoyutu) / 2, width: ikonBoyutu, height: ikonBoyutu)

        let temizleBoyutu: CGFloat = 14
        aramaTemizleButonu.frame = NSRect(x: aramaKutusu.bounds.width - temizleBoyutu - 6, y: (aramaAlaniYuksekligi - temizleBoyutu) / 2, width: temizleBoyutu, height: temizleBoyutu)

        let alaniX = aramaIkonu.frame.maxX + 5
        let alaniGenislik = max(0, aramaTemizleButonu.frame.minX - 4 - alaniX)
        aramaAlani.frame = NSRect(x: alaniX, y: 3, width: alaniGenislik, height: aramaAlaniYuksekligi - 6)

        let puntoCubuguYuksekligi: CGFloat = 26
        let altBosluk: CGFloat = 8
        puntoCubugu.frame = NSRect(x: 8, y: altBosluk, width: max(0, bounds.width - 16), height: puntoCubuguYuksekligi)

        let butonGenisligi: CGFloat = 30
        puntoAzaltButonu.frame = NSRect(x: 0, y: 0, width: butonGenisligi, height: puntoCubuguYuksekligi)
        puntoArttirButonu.frame = NSRect(x: puntoCubugu.bounds.width - butonGenisligi, y: 0, width: butonGenisligi, height: puntoCubuguYuksekligi)
        puntoEtiketi.frame = NSRect(x: butonGenisligi, y: (puntoCubuguYuksekligi - 14) / 2,
                                     width: max(0, puntoCubugu.bounds.width - butonGenisligi * 2), height: 14)

        let baslikCubuguYuksekligi: CGFloat = 24
        baslikCubugu.frame = NSRect(x: 8, y: puntoCubugu.frame.maxY + 6,
                                     width: max(0, bounds.width - 16), height: baslikCubuguYuksekligi)
        let dilimGenisligi = baslikCubugu.bounds.width / CGFloat(max(1, baslikButonlari.count))
        for (sira, buton) in baslikButonlari.enumerated() {
            buton.frame = NSRect(x: dilimGenisligi * CGFloat(sira), y: 0, width: dilimGenisligi, height: baslikCubuguYuksekligi)
        }

        let listeUstu = bounds.height - aramaAlaniYuksekligi - ustBosluk * 2
        let listeAlti = baslikCubugu.frame.maxY + altBosluk
        kaydirmaGorunumu.frame = NSRect(x: 0, y: listeAlti, width: bounds.width, height: max(0, listeUstu - listeAlti))
    }

    /// Arama kutusuna odaklanma/odak kaybı durumunda rengi yumuşak geçişle koyulaştırır.
    private func aramaOdakDegisti(odakta: Bool) {
        let eskiRenk = aramaKutusu.layer?.backgroundColor
        let hedefRenk = odakta ? aramaOdakRengi() : aramaKutuRengi()
        let animasyon = CABasicAnimation(keyPath: "backgroundColor")
        animasyon.fromValue = eskiRenk
        animasyon.toValue = hedefRenk.cgColor
        animasyon.duration = 0.18
        animasyon.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        aramaKutusu.layer?.add(animasyon, forKey: "arkaplanRengi")
        aramaKutusu.layer?.backgroundColor = hedefRenk.cgColor
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        if (obj.object as AnyObject?) === aramaAlani { aramaOdakDegisti(odakta: true) }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if (obj.object as AnyObject?) === aramaAlani {
            aramaOdakDegisti(odakta: false)
            return
        }
        guard let alan = obj.object as? NSTextField else { return }
        adDuzenlemesiniBitir(alan)
    }

    /// Esc: değişiklikten vazgeç.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control !== aramaAlani, commandSelector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        adDuzenlemesiIptal = true
        window?.makeFirstResponder(tablo)
        return true
    }

    // MARK: Ağacı yükleme / filtreleme

    func yenile(secili: URL?) {
        if let secili { acikNotURL = secili }
        tumKokDugumler = agaciYukle()
        tumNotlar = notlariDuzlestir(tumKokDugumler)
        icerikOnbellek = Dictionary(uniqueKeysWithValues: tumNotlar.compactMap { url in
            (try? String(contentsOf: url, encoding: .utf8)).map { (url, isaretlemeleriTemizle($0)) }
        })
        filtreUygula()
    }

    /// Ağacı, görüntülenme sırasına göre düz bir not listesine çevirir.
    private func notlariDuzlestir(_ dugumler: [AgacDugumu]) -> [URL] {
        var sonuc: [URL] = []
        for dugum in dugumler {
            if let icerik = dugum.icerikURL { sonuc.append(icerik) }
            sonuc += notlariDuzlestir(dugum.cocuklar)
        }
        return sonuc
    }

    /// Arama sorgusuna uyan notları ve onları içeren klasörleri bırakır.
    private func suzulmusAgac(_ dugumler: [AgacDugumu], sorgu: String) -> [AgacDugumu] {
        var sonuc: [AgacDugumu] = []
        for dugum in dugumler {
            let kendisiEsliyor = aramaIcinSadelestir(dugum.ad).contains(sorgu)
                || (dugum.icerikURL.map { notEsliyor($0, sorgu: sorgu) } ?? false)
            if kendisiEsliyor {
                // Eşleşen sayfa tüm alt dallarıyla birlikte görünsün.
                sonuc.append(dugum)
                continue
            }
            let kalanCocuklar = suzulmusAgac(dugum.cocuklar, sorgu: sorgu)
            if !kalanCocuklar.isEmpty {
                sonuc.append(AgacDugumu(icerikURL: dugum.icerikURL, klasorURL: dugum.klasorURL, cocuklar: kalanCocuklar))
            }
        }
        return sonuc
    }

    private func notEsliyor(_ url: URL, sorgu: String) -> Bool {
        if let icerik = icerikOnbellek[url] { return aramaIcinSadelestir(icerik).contains(sorgu) }
        return false
    }

    private func filtreUygula() {
        let sorgu = aramaIcinSadelestir(aramaAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        kokDugumler = sorgu.isEmpty ? tumKokDugumler : suzulmusAgac(tumKokDugumler, sorgu: sorgu)
        notListesi = notlariDuzlestir(kokDugumler)
        tablo.reloadData()

        programatikSecimYapiliyor = true
        if sorgu.isEmpty {
            acikKlasorleriGeriYukle(kokDugumler)
        } else {
            // Arama sırasında eşleşmeler görünsün diye tüm klasörler açılır.
            tablo.expandItem(nil, expandChildren: true)
        }

        // Filtre değiştiğinde, üzerinde çalışılan not ağaçta hâlâ varsa doğru satırı
        // yeniden seç; yoksa eski (artık alakasız) bir satır seçili görünmesin.
        if let acikNotURL, let dugum = dugumBul(acikNotURL, kokDugumler) {
            atalariAc(acikNotURL)
            let satir = tablo.row(forItem: dugum)
            if satir >= 0 {
                tablo.selectRowIndexes(IndexSet(integer: satir), byExtendingSelection: false)
            }
        } else {
            tablo.deselectAll(nil)
        }
        programatikSecimYapiliyor = false
    }

    private func dugumBul(_ url: URL, _ dugumler: [AgacDugumu]) -> AgacDugumu? {
        for dugum in dugumler {
            if dugum.icerikURL == url { return dugum }
            if let bulunan = dugumBul(url, dugum.cocuklar) { return bulunan }
        }
        return nil
    }

    /// Verilen notun bulunduğu klasörleri kökten aşağıya doğru açar.
    private func atalariAc(_ url: URL) {
        var atalar: [URL] = []
        var klasor = url.deletingLastPathComponent()
        let kok = notlarKlasoru()
        while klasor.path.hasPrefix(kok.path), klasor != kok {
            atalar.insert(klasor, at: 0)
            klasor = klasor.deletingLastPathComponent()
        }
        // Ata klasörlerin karşılığı olan sayfaları kökten aşağıya doğru aç.
        for ata in atalar {
            if let dugum = klasoreGoreDugumBul(ata, kokDugumler) { tablo.expandItem(dugum) }
        }
    }

    /// Alt sayfalarını verilen klasörde tutan düğümü bulur.
    private func klasoreGoreDugumBul(_ klasor: URL, _ dugumler: [AgacDugumu]) -> AgacDugumu? {
        for dugum in dugumler {
            if dugum.cocuklarKlasoru == klasor { return dugum }
            if let bulunan = klasoreGoreDugumBul(klasor, dugum.cocuklar) { return bulunan }
        }
        return nil
    }

    private func acikKlasorleriGeriYukle(_ dugumler: [AgacDugumu]) {
        for dugum in dugumler where !dugum.cocuklar.isEmpty {
            if acikKlasorYollari.contains(dugum.cocuklarKlasoru.path) {
                tablo.expandItem(dugum)
                acikKlasorleriGeriYukle(dugum.cocuklar)
            }
        }
    }

    private func acikKlasorleriKaydet() {
        UserDefaults.standard.set(Array(acikKlasorYollari), forKey: "acikKlasorler")
    }

    func controlTextDidChange(_ obj: Notification) {
        aramaTemizleButonu.isHidden = aramaAlani.stringValue.isEmpty
        filtreUygula()
    }

    @objc private func aramaTemizleTiklandi() {
        aramaAlani.stringValue = ""
        aramaTemizleButonu.isHidden = true
        filtreUygula()
        window?.makeFirstResponder(aramaAlani)
    }

    // MARK: Ağaç veri kaynağı

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        cocuklar(item).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        cocuklar(item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // Sadece alt sayfası olan düğümde açma oku çıkar.
        !((item as? AgacDugumu)?.cocuklar.isEmpty ?? true)
    }

    private func cocuklar(_ item: Any?) -> [AgacDugumu] {
        guard let dugum = item as? AgacDugumu else { return kokDugumler }
        return dugum.cocuklar
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let kimlik = NSUserInterfaceItemIdentifier("NotSatiri")
        if let yenidenKullan = outlineView.makeView(withIdentifier: kimlik, owner: self) as? NotSatirGorunumu {
            return yenidenKullan
        }
        let satir = NotSatirGorunumu()
        satir.identifier = kimlik
        return satir
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let dugum = item as? AgacDugumu else { return nil }
        let kimlik = NSUserInterfaceItemIdentifier("NotHucresi")
        let hucre: NSTableCellView
        if let yenidenKullan = outlineView.makeView(withIdentifier: kimlik, owner: self) as? NSTableCellView {
            hucre = yenidenKullan
        } else {
            hucre = NSTableCellView()
            hucre.identifier = kimlik

            let ikon = NSImageView()
            ikon.imageScaling = .scaleProportionallyDown
            ikon.translatesAutoresizingMaskIntoConstraints = false
            hucre.addSubview(ikon)
            hucre.imageView = ikon

            let etiket = NSTextField(labelWithString: "")
            etiket.font = NSFont.systemFont(ofSize: 12.5)
            etiket.textColor = .darkGray
            etiket.lineBreakMode = .byTruncatingTail
            etiket.translatesAutoresizingMaskIntoConstraints = false
            hucre.addSubview(etiket)
            hucre.textField = etiket

            NSLayoutConstraint.activate([
                ikon.leadingAnchor.constraint(equalTo: hucre.leadingAnchor, constant: 2),
                ikon.centerYAnchor.constraint(equalTo: hucre.centerYAnchor),
                ikon.widthAnchor.constraint(equalToConstant: 14),
                ikon.heightAnchor.constraint(equalToConstant: 14),
                etiket.leadingAnchor.constraint(equalTo: ikon.trailingAnchor, constant: 5),
                etiket.trailingAnchor.constraint(equalTo: hucre.trailingAnchor, constant: -6),
                etiket.centerYAnchor.constraint(equalTo: hucre.centerYAnchor)
            ])
        }
        // Alt sayfası olan sayfa dolu, olmayan boş belge simgesiyle gösterilir.
        let sembol: String
        if !dugum.sayfaMi {
            sembol = "folder"
        } else {
            sembol = dugum.cocuklar.isEmpty ? "doc.text" : "doc.on.doc"
        }
        hucre.imageView?.image = renklendirilmisSembol(sembol,
                                                        renk: NSColor.black.withAlphaComponent(dugum.sayfaMi ? 0.45 : 0.6),
                                                        boyut: 12)
        hucre.textField?.stringValue = dugum.ad
        hucre.textField?.font = NSFont.systemFont(ofSize: 12.5, weight: dugum.sayfaMi ? .regular : .medium)
        return hucre
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !programatikSecimYapiliyor else { return }
        guard let dugum = tablo.item(atRow: tablo.selectedRow) as? AgacDugumu,
              let icerik = dugum.icerikURL else { return }
        acikNotURL = icerik
        notSecildi?(icerik)
    }

    /// Çift tıklamak adı satırın üzerinde düzenlemeye açar (Finder gibi).
    @objc private func cifteTiklandi() {
        let satir = tablo.clickedRow
        guard satir >= 0, let dugum = tablo.item(atRow: satir) as? AgacDugumu else { return }
        adiYerindeDuzenle(dugum: dugum, satir: satir)
    }

    private func adiYerindeDuzenle(dugum: AgacDugumu, satir: Int) {
        guard let hucre = tablo.view(atColumn: 0, row: satir, makeIfNecessary: true) as? NSTableCellView,
              let alan = hucre.textField else { return }
        duzenlenenDugum = dugum
        adDuzenlemesiIptal = false
        alan.isEditable = true
        alan.isSelectable = true
        alan.isBordered = true
        alan.drawsBackground = true
        alan.backgroundColor = .textBackgroundColor
        alan.textColor = .textColor
        alan.focusRingType = .default
        alan.delegate = self
        alan.stringValue = dugum.ad
        window?.makeFirstResponder(alan)
        alan.currentEditor()?.selectAll(nil)
    }

    private func adDuzenlemesiniBitir(_ alan: NSTextField) {
        alan.isEditable = false
        alan.isSelectable = false
        alan.isBordered = false
        alan.drawsBackground = false
        alan.textColor = .darkGray
        guard let dugum = duzenlenenDugum else { return }
        duzenlenenDugum = nil

        let yeniAd = alan.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        guard !adDuzenlemesiIptal, !yeniAd.isEmpty, yeniAd != dugum.ad else {
            alan.stringValue = dugum.ad   // Vazgeçildi: eski adı geri yaz.
            return
        }
        adiDegistir(dugum, yeniAd: yeniAd)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let dugum = notification.userInfo?["NSObject"] as? AgacDugumu else { return }
        acikKlasorYollari.insert(dugum.cocuklarKlasoru.path)
        acikKlasorleriKaydet()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let dugum = notification.userInfo?["NSObject"] as? AgacDugumu else { return }
        acikKlasorYollari.remove(dugum.cocuklarKlasoru.path)
        acikKlasorleriKaydet()
    }

    // MARK: Klasör / not işlemleri

    /// Başlık çubuğundaki "yeni not" için hedef: seçili sayfanın kardeşi olacak
    /// şekilde onun bulunduğu klasör; seçim yoksa kök.
    func hedefKlasor() -> URL {
        guard let dugum = tablo.item(atRow: tablo.selectedRow) as? AgacDugumu else { return notlarKlasoru() }
        return dugum.sayfaMi ? dugum.klasorURL.deletingLastPathComponent() : dugum.klasorURL
    }

    /// Sağ tıklanan satırın düğümü (boşluğa tıklandıysa nil).
    private func tiklananDugum() -> AgacDugumu? {
        tablo.item(atRow: tablo.clickedRow) as? AgacDugumu
    }

    @objc private func altSayfaEkleTiklandi() {
        guard let dugum = tiklananDugum() else {
            yeniSayfaIstendi?(notlarKlasoru())
            return
        }
        let hedefKlasor = dugum.cocuklarKlasoru
        // Bu dal artık açık kalsın ki yeni sayfa görünsün.
        acikKlasorYollari.insert(hedefKlasor.path)
        acikKlasorleriKaydet()
        yeniSayfaIstendi?(hedefKlasor)
    }

    /// Sağ tıklanan sayfanın yanına (aynı seviyeye) yeni bir sayfa açar.
    @objc private func kardesSayfaEkleTiklandi() {
        guard let dugum = tiklananDugum() else {
            yeniSayfaIstendi?(notlarKlasoru())
            return
        }
        yeniSayfaIstendi?(dugum.sayfaMi ? dugum.klasorURL.deletingLastPathComponent() : dugum.klasorURL)
    }

    @objc private func yenidenAdlandirTiklandi() {
        guard let dugum = tiklananDugum() else { return }
        // Sağ tık menüsü de satır üzerinde düzenlemeyi açar; ayrı bir pencere gerekmez.
        let satir = tablo.row(forItem: dugum)
        guard satir >= 0 else { return }
        adiYerindeDuzenle(dugum: dugum, satir: satir)
    }

    private func adiDegistir(_ dugum: AgacDugumu, yeniAd: String) {
        let eskiCocukKlasoru = dugum.klasorURL
        let yeniCocukKlasoru: URL

        if let icerik = dugum.icerikURL {
            guard let yeni = sayfayiYenidenAdlandir(icerik, yeniAd: yeniAd), yeni != icerik else { return }
            yeniCocukKlasoru = sayfaKlasoru(yeni)
            if acikNotURL == icerik {
                acikNotURL = yeni
                notYenidenAdlandirildi?(icerik, yeni)
            }
        } else {
            // Salt kapsayıcı klasör (eski yapıdan).
            let ust = dugum.klasorURL.deletingLastPathComponent()
            var aday = ust.appendingPathComponent(yeniAd, isDirectory: true)
            guard aday != dugum.klasorURL else { return }
            var sayac = 2
            while FileManager.default.fileExists(atPath: aday.path) {
                aday = ust.appendingPathComponent("\(yeniAd) (\(sayac))", isDirectory: true)
                sayac += 1
            }
            guard (try? FileManager.default.moveItem(at: dugum.klasorURL, to: aday)) != nil else { return }
            yeniCocukKlasoru = aday
        }
        // Açık sayfa taşınan dalın altındaysa yeni yolunu bildir.
        if let acik = acikNotURL, acik.path.hasPrefix(eskiCocukKlasoru.path + "/") {
            let yeniURL = URL(fileURLWithPath: yeniCocukKlasoru.path + acik.path.dropFirst(eskiCocukKlasoru.path.count))
            acikNotURL = yeniURL
            notYenidenAdlandirildi?(acik, yeniURL)
        }
        if acikKlasorYollari.remove(eskiCocukKlasoru.path) != nil {
            acikKlasorYollari.insert(yeniCocukKlasoru.path)
            acikKlasorleriKaydet()
        }
        yenile(secili: acikNotURL)
    }

    /// Dönüştürme seçeneği yalnızca eski düzendeki düz notlarda görünür.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let eskiDuzenMi = tiklananDugum()?.icerikURL.map { $0.lastPathComponent != kIcerikDosyaAdi } ?? false
        for oge in menu.items where oge.action == #selector(klasoreDonusturTiklandi) {
            oge.isHidden = !eskiDuzenMi
        }
        // Ayırıcı da onunla birlikte gizlensin.
        if let index = menu.items.firstIndex(where: { $0.action == #selector(klasoreDonusturTiklandi) }), index > 0 {
            menu.items[index - 1].isHidden = !eskiDuzenMi
        }
    }

    /// "Ad.md" düzenindeki notu "Ad/index.md" düzenine taşır.
    @objc private func klasoreDonusturTiklandi() {
        guard let dugum = tiklananDugum(), let icerik = dugum.icerikURL,
              let yeni = sayfayiKlasoreDonustur(icerik) else { return }
        if acikNotURL == icerik {
            acikNotURL = yeni
            notYenidenAdlandirildi?(icerik, yeni)
        }
        yenile(secili: acikNotURL)
    }

    @objc private func silTiklandi() {
        guard let dugum = tiklananDugum() else { return }
        let altKlasor = dugum.klasorURL
        let altDallariVar = !dugum.cocuklar.isEmpty

        let uyari = NSAlert()
        uyari.messageText = "\"\(dugum.ad)\" silinsin mi?"
        uyari.informativeText = altDallariVar
            ? "Sayfa ve altındaki tüm sayfalar Çöp Kutusu'na taşınacak."
            : "Bu sayfa Çöp Kutusu'na taşınacak."
        uyari.addButton(withTitle: "Sil")
        uyari.addButton(withTitle: "Vazgeç")
        if let silButonu = uyari.buttons.first {
            silButonu.hasDestructiveAction = true
        }
        guard uyari.runModal() == .alertFirstButtonReturn else { return }

        // Yeni düzende sayfanın her şeyi klasörünün içinde; tek hamlede gider.
        if FileManager.default.fileExists(atPath: altKlasor.path) {
            try? FileManager.default.trashItem(at: altKlasor, resultingItemURL: nil)
        }
        if let icerik = dugum.icerikURL, icerik.lastPathComponent != kIcerikDosyaAdi {
            try? FileManager.default.trashItem(at: icerik, resultingItemURL: nil)
        }

        // Açık sayfa silindiyse (ya da silinen dalın altındaysa) editörü boşalt.
        if let acik = acikNotURL, acik == dugum.icerikURL || acik.path.hasPrefix(altKlasor.path + "/") {
            acikNotURL = nil
            notSilindi?(acik)
        }
        yenile(secili: nil)
    }
}

// MARK: - Kenar panelin genişliğini fare ile ayarlamak için sürükle tutamacı

final class KenarPaneliSurukleTutamaci: NSView {

    var surukleniyor: ((NSEvent) -> Void)?
    private var izlemeAlani: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let izlemeAlani { removeTrackingArea(izlemeAlani) }
        let yeni = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate], owner: self, userInfo: nil)
        addTrackingArea(yeni)
        izlemeAlani = yeni
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDragged(with event: NSEvent) {
        surukleniyor?(event)
    }
}

// MARK: - Ana pencere

final class NotPenceresi: NSWindow, NSTextViewDelegate {

    private let metinGorunumu = NotMetinGorunumu()
    private let baslikCubugu = BaslikCubugu()
    private let kenarPaneli = KenarPaneli(frame: .zero)
    private let icerikGorunum = NSView()
    private let kaydirmaGorunumu = NSScrollView()
    private let surukleTutamaci = KenarPaneliSurukleTutamaci()

    private var mevcutDosyaURL: URL? {
        didSet { UserDefaults.standard.set(mevcutDosyaURL?.path, forKey: "sonNotYolu") }
    }
    private var duzenlendiMi = false
    private var kenarPanelGizli = UserDefaults.standard.bool(forKey: "kenarPanelGizli")
    /// Otomatik kayıt: yalnızca bekleyen bir değişiklik varken kurulur, tetiklenince kendini bırakır.
    private var otomatikKayitZamanlayici: Timer?
    /// Diske en son yazılan metin; aynı içeriği tekrar yazmamak için karşılaştırılır.
    private var sonYazilanIcerik: String?
    /// Dosya adı kullanıcı tarafından değil, ilk satırdan otomatik üretildiyse doğrudur.
    private var otomatikAdlandirildiMi = false

    convenience init() {
        let boyut = NSRect(x: 0, y: 0, width: 680, height: 520)
        self.init(contentRect: boyut,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)

        title = "Not Defteri"
        isReleasedWhenClosed = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        backgroundColor = aktifTema.arkaplan
        minSize = NSSize(width: 460, height: 320)
        // Yerel tam ekran (yeşil buton gizli olsa da toggleFullScreen çalışsın).
        collectionBehavior.insert(.fullScreenPrimary)

        icerikGorunum.frame = boyut
        icerikGorunum.wantsLayer = true
        icerikGorunum.layer?.backgroundColor = aktifTema.arkaplan.cgColor

        baslikCubugu.frame = NSRect(x: 0, y: boyut.height - kBaslikYuksekligi, width: boyut.width, height: kBaslikYuksekligi)
        baslikCubugu.autoresizingMask = [.width, .minYMargin]
        baslikCubugu.pencere = self
        baslikCubugu.yeniNotTiklandi = { [weak self] in self?.yeniNotOlustur() }
        baslikCubugu.kapatTiklandi = { [weak self] in self?.close() }
        baslikCubugu.kenarPaneliDegistirTiklandi = { [weak self] in self?.kenarPaneliniAcKapa() }
        baslikCubugu.geriAlTiklandi = { [weak self] in self?.geriAl() }
        baslikCubugu.ileriAlTiklandi = { [weak self] in self?.ileriAl() }

        let kenarPanelBaslangicGenislik: CGFloat = kenarPanelGizli ? 0 : gKenarPanelGenislik
        kenarPaneli.frame = NSRect(x: 0, y: 0, width: kenarPanelBaslangicGenislik, height: boyut.height - kBaslikYuksekligi)
        kenarPaneli.autoresizingMask = [.maxXMargin, .height]
        kenarPaneli.isHidden = kenarPanelGizli
        kenarPaneli.notSecildi = { [weak self] url in self?.notuAc(url) }
        kenarPaneli.notSilindi = { [weak self] url in self?.notSilindiIsleyici(url) }
        kenarPaneli.notYenidenAdlandirildi = { [weak self] eski, yeni in self?.notYenidenAdlandirildiIsleyici(eski: eski, yeni: yeni) }
        kenarPaneli.yeniSayfaIstendi = { [weak self] klasor in self?.yeniSayfaOlustur(klasor: klasor) }
        kenarPaneli.baslikSeviyesiIstendi = { [weak self] seviye in self?.baslikSeviyesiUygula(seviye) }
        kenarPaneli.puntoDegistirIstendi = { [weak self] fark in
            guard let self else { return }
            self.yaziBoyutunuDegistir(fark: fark)
            self.makeFirstResponder(self.metinGorunumu)
        }


        surukleTutamaci.frame = NSRect(x: kenarPanelBaslangicGenislik - 3, y: 0, width: 6, height: boyut.height - kBaslikYuksekligi)
        surukleTutamaci.autoresizingMask = [.height]
        surukleTutamaci.isHidden = kenarPanelGizli
        surukleTutamaci.surukleniyor = { [weak self] event in self?.kenarPaneliSurukleniyor(event) }

        kaydirmaGorunumu.frame = NSRect(x: kenarPanelBaslangicGenislik, y: 0, width: boyut.width - kenarPanelBaslangicGenislik, height: boyut.height - kBaslikYuksekligi)
        kaydirmaGorunumu.autoresizingMask = [.width, .height]
        kaydirmaGorunumu.hasVerticalScroller = true
        kaydirmaGorunumu.hasHorizontalScroller = false
        kaydirmaGorunumu.drawsBackground = false
        kaydirmaGorunumu.borderType = .noBorder

        metinGorunumu.frame = NSRect(origin: .zero, size: kaydirmaGorunumu.contentSize)
        // Genişlik kaydırma görünümünü takip eder; yükseklik içerik kadar uzar.
        metinGorunumu.autoresizingMask = [.width]
        metinGorunumu.minSize = NSSize(width: 0, height: kaydirmaGorunumu.contentSize.height)
        metinGorunumu.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        metinGorunumu.isRichText = true
        metinGorunumu.font = varsayilanFont()
        metinGorunumu.textColor = kMetinRenk
        metinGorunumu.backgroundColor = aktifTema.arkaplan
        metinGorunumu.insertionPointColor = kMetinRenk
        metinGorunumu.textContainerInset = NSSize(width: 14, height: 12)
        metinGorunumu.isEditable = true
        metinGorunumu.isVerticallyResizable = true
        metinGorunumu.isHorizontallyResizable = false
        // Satırlar pencere genişliğine göre kırılsın, yana taşmasın.
        metinGorunumu.textContainer?.widthTracksTextView = true
        metinGorunumu.textContainer?.heightTracksTextView = false
        metinGorunumu.textContainer?.size = NSSize(width: kaydirmaGorunumu.contentSize.width,
                                                    height: CGFloat.greatestFiniteMagnitude)
        metinGorunumu.isAutomaticQuoteSubstitutionEnabled = false
        metinGorunumu.isAutomaticDashSubstitutionEnabled = false
        metinGorunumu.isAutomaticTextReplacementEnabled = false
        metinGorunumu.allowsUndo = true
        metinGorunumu.importsGraphics = true   // Görsel yapıştırma/sürükleme kabul edilsin.
        metinGorunumu.gorselEklenecek = { [weak self] gorsel, bolumBasligi in
            self?.gorseliDiskeYaz(gorsel, bolumBasligi: bolumBasligi)
        }
        metinGorunumu.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.delegate = self

        kaydirmaGorunumu.documentView = metinGorunumu

        icerikGorunum.addSubview(kaydirmaGorunumu)
        icerikGorunum.addSubview(kenarPaneli)
        icerikGorunum.addSubview(surukleTutamaci)
        icerikGorunum.addSubview(baslikCubugu)
        contentView = icerikGorunum

        kenarPaneli.yenile(secili: nil)
        onceki_notu_ac_gerekirse()
        center()
    }

    private func onceki_notu_ac_gerekirse() {
        if let yol = UserDefaults.standard.string(forKey: "sonNotYolu") {
            let url = URL(fileURLWithPath: yol)
            if FileManager.default.fileExists(atPath: url.path) {
                notuAc(url)
                return
            }
        }
        if let ilkNot = kenarPaneli.notListesi.first {
            notuAc(ilkNot)
        }
    }

    // MARK: Not açma / oluşturma

    private func notuAc(_ url: URL) {
        if mevcutDosyaURL != url {
            mevcutNotuKaybolmayacakSekildeKaydet()
        }
        guard let icerik = try? String(contentsOf: url, encoding: .utf8) else { return }
        metinGorunumu.textStorage?.setAttributedString(markdowndenAttributedStringUret(icerik, taban: sayfaKlasoru(url)))
        mevcutDosyaURL = url
        sonYazilanIcerik = icerik
        otomatikAdlandirildiMi = false
        duzenlendiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        kenarPaneli.yenile(secili: url)
        puntoGostergesiniGuncelle()
    }

    private func yeniNotOlustur() {
        mevcutNotuKaybolmayacakSekildeKaydet()
        let bosOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: bosOznitelik))
        mevcutDosyaURL = nil
        sonYazilanIcerik = nil
        otomatikAdlandirildiMi = false
        duzenlendiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        kenarPaneli.tablo.deselectAll(nil)
        makeFirstResponder(metinGorunumu)
    }

    /// Kenar panelden istenen yeni sayfayı oluşturup açar. Adı "Yeni Sayfa"dır;
    /// ilk satırı yazdıkça dosya adı ona göre değişir.
    private func yeniSayfaOlustur(klasor: URL) {
        mevcutNotuKaybolmayacakSekildeKaydet()
        let url = benzersizSayfaURL(taban: "Yeni Sayfa", klasor: klasor)
        // Sayfa = kendi klasörü + içindeki index.md
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? "".write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        notuAc(url)
        otomatikAdlandirildiMi = true
        makeFirstResponder(metinGorunumu)
    }

    private func notSilindiIsleyici(_ url: URL) {
        guard mevcutDosyaURL == url else { return }
        let bosOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: bosOznitelik))
        mevcutDosyaURL = nil
        sonYazilanIcerik = nil
        otomatikAdlandirildiMi = false
        duzenlendiMi = false
        otomatikKayitBekleyeniIptalEt()
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
    }

    private func notYenidenAdlandirildiIsleyici(eski: URL, yeni: URL) {
        guard mevcutDosyaURL == eski else { return }
        mevcutDosyaURL = yeni
        otomatikAdlandirildiMi = false  // Adı artık kullanıcı belirledi.
        baslikEtiketiniGuncelle()
    }

    /// Not değiştirilmeden önce, yazılmış ama kaydedilmemiş içeriği otomatik olarak kaydeder.
    /// Mevcut bir dosya açıksa üzerine yazar; yeni/boş bir nottaysa içerikten otomatik bir isim üretip yeni dosya oluşturur.
    private func mevcutNotuKaybolmayacakSekildeKaydet() {
        guard duzenlendiMi else { return }
        let icerik = metinGorunumu.string
        guard !icerik.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        } else {
            let hedefURL = benzersizDosyaURL(taban: otomatikBaslikUret(icerik: icerik))
            kaydetURLe(hedefURL)
        }
    }

    private func baslikEtiketiniGuncelle() {
        let ad = mevcutDosyaURL.map { sayfaAdi($0) } ?? "Yeni Sayfa"
        baslikCubugu.notAdiEtiketi.stringValue = ad
        title = ad
    }

    // MARK: Kaydetme (Cmd+S)

    @objc func kaydetKomutu(_ sender: Any?) { kaydet() }

    private func kaydet() {
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        } else {
            isimSorVeKaydet()
        }
    }

    private func kaydetURLe(_ url: URL, hazirMetin: String? = nil, panelYenile: Bool = true) {
        let metin = hazirMetin ?? markdownMetniUret(metinGorunumu.attributedString())
        // Aynı dosyaya aynı içeriği tekrar yazma (dosya diskte duruyorsa).
        guard metin != sonYazilanIcerik
                || url != mevcutDosyaURL
                || !FileManager.default.fileExists(atPath: url.path) else {
            duzenlendiMi = false
            return
        }
        // Sayfa klasörü henüz yoksa (yeni sayfa) oluşturulur.
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? metin.write(to: url, atomically: true, encoding: .utf8)
        sonYazilanIcerik = metin
        mevcutDosyaURL = url
        duzenlendiMi = false
        otomatikKayitBekleyeniIptalEt()
        baslikEtiketiniGuncelle()
        if panelYenile { kenarPaneli.yenile(secili: url) }
    }

    func textDidChange(_ notification: Notification) {
        icerikDegisti()
        gecmisDugmeleriniGuncelle()
    }

    // MARK: Eğik çizgi komutları (/1 /2 /3 /page) ve başlıklar

    /// Satır başında yazılıp boşluk veya Enter ile tamamlanan komutlar.
    private func egikCizgiKomutu(_ metin: String) -> String? {
        let komut = metin.trimmingCharacters(in: .whitespaces).lowercased()
        return ["/1", "/2", "/3", "/0", "/page", "/sayfa"].contains(komut) ? komut : nil
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let replacementString, replacementString == " " || replacementString == "\n" else { return true }
        let ns = textView.string as NSString

        // İmlecin bulunduğu satırın başından imlece kadarki metin komut mu?
        let satirAralik = ns.paragraphRange(for: NSRange(location: affectedCharRange.location, length: 0))
        let komutAralik = NSRange(location: satirAralik.location,
                                   length: max(0, affectedCharRange.location - satirAralik.location))
        if komutAralik.length > 0, let komut = egikCizgiKomutu(ns.substring(with: komutAralik)) {
            // Düzenlemeyi bu geri çağrının içinde yapmamak için bir sonraki döngüye bırak.
            DispatchQueue.main.async { [weak self] in self?.komutuCalistir(komut, aralik: komutAralik) }
            return false
        }

        // Başlık satırının sonunda Enter'a basılınca yeni satır normal biçimde başlasın.
        if replacementString == "\n", metinGorunumu.typingAttributes[kBaslikSeviyesiAnahtari] != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var oznitelikler = self.metinGorunumu.typingAttributes
                oznitelikler.removeValue(forKey: kBaslikSeviyesiAnahtari)
                oznitelikler[.font] = varsayilanFont()
                self.metinGorunumu.typingAttributes = oznitelikler
            }
        }
        return true
    }

    private func komutuCalistir(_ komut: String, aralik: NSRange) {
        guard let metinDeposu = metinGorunumu.textStorage,
              NSMaxRange(aralik) <= metinDeposu.length else { return }

        // Önce komut metnini sil.
        if metinGorunumu.shouldChangeText(in: aralik, replacementString: "") {
            metinDeposu.replaceCharacters(in: aralik, with: "")
            metinGorunumu.didChangeText()
        }
        metinGorunumu.setSelectedRange(NSRange(location: aralik.location, length: 0))

        switch komut {
        case "/1": baslikSeviyesiUygula(1)
        case "/2": baslikSeviyesiUygula(2)
        case "/3": baslikSeviyesiUygula(3)
        case "/0": baslikSeviyesiUygula(0)
        case "/page", "/sayfa": altSayfaKomutu()
        default: break
        }
    }

    /// İmlecin bulunduğu paragrafı başlığa çevirir; seviye 0 normal metne döndürür.
    func baslikSeviyesiUygula(_ seviye: Int) {
        guard let metinDeposu = metinGorunumu.textStorage else { return }
        let ns = metinDeposu.string as NSString
        let paragrafAralik = ns.paragraphRange(for: metinGorunumu.selectedRange())

        if paragrafAralik.length > 0, metinGorunumu.shouldChangeText(in: paragrafAralik, replacementString: nil) {
            metinDeposu.beginEditing()
            if seviye > 0 {
                metinDeposu.addAttributes([.font: baslikFontu(seviye), kBaslikSeviyesiAnahtari: seviye], range: paragrafAralik)
            } else {
                metinDeposu.removeAttribute(kBaslikSeviyesiAnahtari, range: paragrafAralik)
                metinDeposu.addAttribute(.font, value: varsayilanFont(), range: paragrafAralik)
            }
            metinDeposu.endEditing()
            metinGorunumu.didChangeText()
        }

        // Boş satırda komut verildiyse yazılacak metin başlık biçiminde başlasın.
        var oznitelikler = metinGorunumu.typingAttributes
        oznitelikler[.font] = seviye > 0 ? baslikFontu(seviye) : varsayilanFont()
        if seviye > 0 {
            oznitelikler[kBaslikSeviyesiAnahtari] = seviye
        } else {
            oznitelikler.removeValue(forKey: kBaslikSeviyesiAnahtari)
        }
        metinGorunumu.typingAttributes = oznitelikler
        icerikDegisti()
        puntoGostergesiniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    /// "/page": açık sayfanın altına yeni bir sayfa oluşturup açar.
    private func altSayfaKomutu() {
        // Sayfanın altına dal açabilmek için önce kendisinin diskte olması gerekir.
        if mevcutDosyaURL == nil {
            duzenlendiMi = true
            otomatikKaydet()
        }
        guard let ustSayfa = mevcutDosyaURL else {
            // Henüz hiç içeriği olmayan, kaydedilmemiş bir sayfadayız: yeni sayfayı
            // kardeş olarak oluştur, komut sessizce kaybolmasın.
            yeniSayfaOlustur(klasor: kenarPaneli.hedefKlasor())
            return
        }
        yeniSayfaOlustur(klasor: sayfaKlasoru(ustSayfa))
    }

    // MARK: Geri al / Yinele

    @objc func geriAlKomutu(_ sender: Any?) { geriAl() }
    @objc func ileriAlKomutu(_ sender: Any?) { ileriAl() }

    private func geriAl() {
        guard let yonetici = metinGorunumu.undoManager, yonetici.canUndo else { return }
        yonetici.undo()
        geriAlmaSonrasi()
    }

    private func ileriAl() {
        guard let yonetici = metinGorunumu.undoManager, yonetici.canRedo else { return }
        yonetici.redo()
        geriAlmaSonrasi()
    }

    /// Geri/ileri alma metni değiştirir; kaydı ve göstergeleri tazeler, odağı metne verir.
    private func geriAlmaSonrasi() {
        icerikDegisti()
        gecmisDugmeleriniGuncelle()
        puntoGostergesiniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    private func gecmisDugmeleriniGuncelle() {
        baslikCubugu.gecmisDurumunuGoster(geriAlinabilir: metinGorunumu.undoManager?.canUndo ?? false,
                                           ileriAlinabilir: metinGorunumu.undoManager?.canRedo ?? false)
    }

    /// Başka bir not açılırken geçmişi temizler; aksi halde ⌘Z önceki notun
    /// içeriğini şu anki notun üzerine geri getirebilir.
    private func gecmisiSifirla() {
        metinGorunumu.undoManager?.removeAllActions()
        gecmisDugmeleriniGuncelle()
    }

    // MARK: Görsel ekleme

    /// Yapıştırılan/sürüklenen görseli, sayfanın kendi klasöründeki "Görseller"
    /// altına PNG olarak yazar. Dosya adı, görselin eklendiği bölümün başlığıdır
    /// (ör. "Başlık1.png", ikincisi "Başlık1-2.png"); başlık yoksa "Görsel" olur.
    private func gorseliDiskeYaz(_ gorsel: NSImage, bolumBasligi: String?) -> ResimEki? {
        guard let tiff = gorsel.tiffRepresentation,
              let temsil = NSBitmapImageRep(data: tiff),
              let png = temsil.representation(using: .png, properties: [:]) else { return nil }

        // Sayfa henüz kaydedilmemişse görseller kök klasöre yazılır.
        let hedefKlasor = gorsellerKlasoru(mevcutDosyaURL.map { sayfaKlasoru($0) } ?? notlarKlasoru())
        var taban = (bolumBasligi ?? "Görsel")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if taban.isEmpty { taban = "Görsel" }
        if taban.count > 40 { taban = String(taban.prefix(40)) }

        var hedef = hedefKlasor.appendingPathComponent("\(taban).png")
        var sayac = 2
        while FileManager.default.fileExists(atPath: hedef.path) {
            hedef = hedefKlasor.appendingPathComponent("\(taban)-\(sayac).png")
            sayac += 1
        }
        guard (try? png.write(to: hedef)) != nil else { return nil }

        // Ek, ekrandaki piksel boyutunu değil görselin nokta boyutunu kullanır.
        let noktaBoyutu = NSSize(width: temsil.pixelsWide, height: temsil.pixelsHigh)
        let gercekGorsel = NSImage(size: noktaBoyutu)
        gercekGorsel.addRepresentation(temsil)
        return resimEkiUret(gorsel: gercekGorsel, dosyaURL: hedef,
                            bagYolu: "\(kGorsellerKlasorAdi)/\(hedef.lastPathComponent)")
    }

    // MARK: Otomatik kayıt

    /// İçerik değiştiğinde çağrılır; 5 saniyelik tek atımlık bir zamanlayıcı kurar.
    /// Zamanlayıcı zaten kuruluysa yenisi açılmaz, yani kesintisiz yazarken de
    /// en fazla 5 saniyede bir disk yazımı olur; boştayken hiç zamanlayıcı dönmez.
    private func icerikDegisti() {
        duzenlendiMi = true
        guard otomatikKayitZamanlayici == nil else { return }
        let zamanlayici = Timer(timeInterval: kOtomatikKayitAraligi, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.otomatikKayitZamanlayici = nil
            self.otomatikKaydet()
        }
        zamanlayici.tolerance = 1  // Sistemin uyandırmaları birleştirmesine izin verir (enerji dostu).
        RunLoop.main.add(zamanlayici, forMode: .common)  // Menü/kaydırma sırasında da işler.
        otomatikKayitZamanlayici = zamanlayici
    }

    private func otomatikKayitBekleyeniIptalEt() {
        otomatikKayitZamanlayici?.invalidate()
        otomatikKayitZamanlayici = nil
    }

    private func otomatikKaydet() {
        guard duzenlendiMi else { return }
        let metin = markdownMetniUret(metinGorunumu.attributedString())
        guard metin != sonYazilanIcerik else {
            duzenlendiMi = false
            return
        }
        guard !metinGorunumu.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard let mevcutURL = mevcutDosyaURL else {
            // Henüz kaydedilmemiş not: ilk satırdan bir ad üretip dosyayı oluşturur.
            otomatikAdlandirildiMi = true
            kaydetURLe(benzersizDosyaURL(taban: otomatikBaslikUret(icerik: metinGorunumu.string)), hazirMetin: metin)
            return
        }

        // Adı otomatik üretilmiş bir notun ilk satırı değiştiyse dosya adı da takip etsin.
        if otomatikAdlandirildiMi {
            let istenenAd = otomatikBaslikUret(icerik: metinGorunumu.string)
            if istenenAd != sayfaAdi(mevcutURL) {
                // Sayfa taşınırken alt sayfalarını tutan klasör de birlikte taşınır.
                if let yeniURL = sayfayiYenidenAdlandir(mevcutURL, yeniAd: istenenAd), yeniURL != mevcutURL {
                    kaydetURLe(yeniURL, hazirMetin: metin)
                    return
                }
            }
        }

        // Normal durum: aynı dosyanın üzerine yaz, kenar paneli boşuna tazeleme
        // (panel tüm notları yeniden okuduğu için asıl maliyet orada).
        kaydetURLe(mevcutURL, hazirMetin: metin, panelYenile: false)
    }

    private func isimSorVeKaydet() {
        let uyari = NSAlert()
        uyari.messageText = "Notu Kaydet"
        uyari.informativeText = "Not için bir isim girin:"
        uyari.addButton(withTitle: "Kaydet")
        uyari.addButton(withTitle: "Vazgeç")
        let girisAlani = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        girisAlani.placeholderString = "Örn: Alışveriş Listesi"
        uyari.accessoryView = girisAlani
        uyari.window.initialFirstResponder = girisAlani

        guard uyari.runModal() == .alertFirstButtonReturn else { return }

        var isim = girisAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if isim.isEmpty { isim = "Adsız Not" }
        isim = isim.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")

        let hedefURL = benzersizDosyaURL(taban: isim)
        otomatikAdlandirildiMi = false
        kaydetURLe(hedefURL)
    }

    /// Yeni sayfayı, kenar panelde seçili olanın yanında oluşturur.
    private func benzersizDosyaURL(taban: String, klasor verilenKlasor: URL? = nil) -> URL {
        benzersizSayfaURL(taban: taban, klasor: verilenKlasor ?? kenarPaneli.hedefKlasor())
    }

    /// Uygulama tamamen kapanırken (Cmd+Q gibi) mevcut dosyayı üzerine kaydeder.
    func kapanistaGerekirseKaydet() {
        otomatikKayitBekleyeniIptalEt()
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        }
    }

    // MARK: Kalın yazı (Cmd+B)

    @objc func kalinKomutu(_ sender: Any?) { kalinYap() }

    private func kalinYap() {
        guard let textStorage = metinGorunumu.textStorage else { return }
        let secilen = metinGorunumu.selectedRange()

        if secilen.length == 0 {
            var oznitelikler = metinGorunumu.typingAttributes
            let mevcutFont = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            let kalinMi = NSFontManager.shared.traits(of: mevcutFont).contains(.boldFontMask)
            oznitelikler[.font] = kalinMi
                ? NSFontManager.shared.convert(mevcutFont, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(mevcutFont, toHaveTrait: .boldFontMask)
            metinGorunumu.typingAttributes = oznitelikler
            return
        }

        var tumuKalin = true
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, _, durdur in
            let font = (deger as? NSFont) ?? varsayilanFont()
            if !NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                tumuKalin = false
                durdur.pointee = true
            }
        }

        // shouldChangeText/didChangeText çifti, öznitelik değişikliğini geri alma
        // yığınına kaydeder ve textDidChange'i tetikler.
        guard metinGorunumu.shouldChangeText(in: secilen, replacementString: nil) else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, altAralik, _ in
            let font = (deger as? NSFont) ?? varsayilanFont()
            let yeniFont = tumuKalin
                ? NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: yeniFont, range: altAralik)
        }
        textStorage.endEditing()
        metinGorunumu.didChangeText()
    }

    // MARK: Punto (Cmd+* büyüt / Cmd+- küçült)

    @objc func yaziBuyutKomutu(_ sender: Any?) { yaziBoyutunuDegistir(fark: 1) }
    @objc func yaziKucultKomutu(_ sender: Any?) { yaziBoyutunuDegistir(fark: -1) }

    /// Seçili metnin puntosunu değiştirir. Seçim yoksa, bundan sonra yazılacak
    /// metnin (ve varsayılan) puntosu değişir.
    private func yaziBoyutunuDegistir(fark: CGFloat) {
        guard let textStorage = metinGorunumu.textStorage else { return }
        let secilen = metinGorunumu.selectedRange()

        if secilen.length == 0 {
            var oznitelikler = metinGorunumu.typingAttributes
            let mevcutFont = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            let yeniBoyut = boyutSinirla(mevcutFont.pointSize + fark)
            guard yeniBoyut != mevcutFont.pointSize else { return }
            oznitelikler[.font] = fontUret(boyut: yeniBoyut, kalin: kalinMi(mevcutFont))
            metinGorunumu.typingAttributes = oznitelikler
            // Yalnızca imlecin o anki yazım puntosu; kalıcı DEĞİL (kayma olmasın).
            gYaziBoyutu = yeniBoyut
            puntoGostergesiniGuncelle()
            return
        }

        guard metinGorunumu.shouldChangeText(in: secilen, replacementString: nil) else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, altAralik, _ in
            let eskiFont = (deger as? NSFont) ?? varsayilanFont()
            let yeniBoyut = boyutSinirla(eskiFont.pointSize + fark)
            textStorage.addAttribute(.font, value: fontUret(boyut: yeniBoyut, kalin: kalinMi(eskiFont)), range: altAralik)
        }
        textStorage.endEditing()
        metinGorunumu.didChangeText()
        puntoGostergesiniGuncelle()
    }

    /// İmlecin/seçimin bulunduğu yerin puntosunu kenar paneldeki göstergeye yazar.
    private func puntoGostergesiniGuncelle() {
        kenarPaneli.puntoyuGoster(mevcutPunto())
    }

    private func mevcutPunto() -> CGFloat {
        let secilen = metinGorunumu.selectedRange()
        if secilen.length > 0, let textStorage = metinGorunumu.textStorage,
           secilen.location < textStorage.length,
           let font = textStorage.attribute(.font, at: secilen.location, effectiveRange: nil) as? NSFont {
            return font.pointSize
        }
        return ((metinGorunumu.typingAttributes[.font] as? NSFont) ?? varsayilanFont()).pointSize
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        puntoGostergesiniGuncelle()
    }

    // MARK: Tema (Görünüm menüsü)

    @objc func temaSecKomutu(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, temaListesi.indices.contains(index) else { return }
        gTemaIndex = index
        UserDefaults.standard.set(index, forKey: "temaIndex")
        temaUygulaTumUI()
    }

    private func temaUygulaTumUI() {
        backgroundColor = aktifTema.arkaplan
        icerikGorunum.layer?.backgroundColor = aktifTema.arkaplan.cgColor
        metinGorunumu.backgroundColor = aktifTema.arkaplan
        baslikCubugu.temayiUygula()
        kenarPaneli.temayiUygula()
    }

    // MARK: Notlar arasında gezinme (Cmd+[ / Cmd+])

    @objc func oncekiNotKomutu(_ sender: Any?) { notGezin(yon: -1) }
    @objc func sonrakiNotKomutu(_ sender: Any?) { notGezin(yon: 1) }

    private func notGezin(yon: Int) {
        // Arama filtresi aktifken de gezinme tüm notlar arasında çalışsın diye filtrelenmemiş listeyi kullanır.
        let liste = kenarPaneli.tumNotUrlListesi
        guard !liste.isEmpty else { return }
        guard let mevcut = mevcutDosyaURL, let index = liste.firstIndex(of: mevcut) else {
            notuAc(liste[0])
            return
        }
        let yeniIndex = index + yon
        guard yeniIndex >= 0, yeniIndex < liste.count else { return }
        notuAc(liste[yeniIndex])
    }

    // MARK: Kenar paneli göster/gizle

    private func kenarPaneliniAcKapa() {
        kenarPanelGizli.toggle()
        UserDefaults.standard.set(kenarPanelGizli, forKey: "kenarPanelGizli")

        if !kenarPanelGizli {
            kenarPaneli.isHidden = false
            surukleTutamaci.isHidden = false
        }

        let hedefGenislik: CGFloat = kenarPanelGizli ? 0 : gKenarPanelGenislik
        let toplamGenislik = icerikGorunum.bounds.width
        let yukseklik = kenarPaneli.frame.height

        NSAnimationContext.runAnimationGroup({ baglam in
            baglam.duration = 0.2
            baglam.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            kenarPaneli.animator().frame = NSRect(x: 0, y: 0, width: hedefGenislik, height: yukseklik)
            surukleTutamaci.animator().frame = NSRect(x: hedefGenislik - 3, y: 0, width: 6, height: yukseklik)
            kaydirmaGorunumu.animator().frame = NSRect(x: hedefGenislik, y: 0, width: max(0, toplamGenislik - hedefGenislik), height: yukseklik)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.kenarPaneli.isHidden = self.kenarPanelGizli
            self.surukleTutamaci.isHidden = self.kenarPanelGizli
        })
    }

    /// Kenar panelin genişliğini fare ile sürükleyerek ayarlar.
    private func kenarPaneliSurukleniyor(_ event: NSEvent) {
        guard !kenarPanelGizli else { return }
        let nokta = icerikGorunum.convert(event.locationInWindow, from: nil)
        let yeniGenislik = min(max(nokta.x, kKenarPanelMinGenislik), kKenarPanelMaksGenislik)
        gKenarPanelGenislik = yeniGenislik
        UserDefaults.standard.set(Double(yeniGenislik), forKey: "kenarPanelGenislik")

        var panelKare = kenarPaneli.frame
        panelKare.size.width = yeniGenislik
        kenarPaneli.frame = panelKare

        surukleTutamaci.frame.origin.x = yeniGenislik - 3

        var editorKare = kaydirmaGorunumu.frame
        editorKare.origin.x = yeniGenislik
        editorKare.size.width = max(0, icerikGorunum.bounds.width - yeniGenislik)
        kaydirmaGorunumu.frame = editorKare
    }

    // MARK: Kapatma

    /// Menü eşleşmeleri klavye düzenine göre kaçabildiği için (⌘* Türkçe Q'da
    /// shift'siz, ABD düzeninde shift'li üretilir) punto kısayollarını burada
    /// düzenden bağımsız olarak yakalarız.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let bayraklar = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let karakterKucuk = event.charactersIgnoringModifiers?.lowercased()

        // Tam ekran: Fn+F veya standart ⌃⌘F.
        if karakterKucuk == "f",
           bayraklar.contains(.function) || bayraklar.isSuperset(of: [.command, .control]) {
            toggleFullScreen(nil)
            return true
        }

        let tuslar = bayraklar.subtracting(.shift)  // Shift'i yok say: "*" bazı düzenlerde shift ister.
        if tuslar == .command, let karakter = event.charactersIgnoringModifiers {
            switch karakter.lowercased() {
            case "y":
                ileriAl()
                return true
            case "z":
                // ⌘Z menüden gelir; buraya asıl ⇧⌘Z (yinele) düşer.
                if event.modifierFlags.contains(.shift) { ileriAl() } else { geriAl() }
                return true
            case "*", "+", "=":
                yaziBoyutunuDegistir(fark: 1)
                return true
            case "-", "_":
                yaziBoyutunuDegistir(fark: -1)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Pencere odağı kaybettiğinde bekleyen değişikliği hemen yazar.
    override func resignKey() {
        super.resignKey()
        if duzenlendiMi { otomatikKaydet() }
    }

    override func close() {
        kapanistaGerekirseKaydet()
        super.close()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Menü

func anaMenuyuOlustur(delege: UygulamaDelegesi) -> NSMenu {
    let anaMenu = NSMenu()

    let uygulamaMenuOgesi = NSMenuItem()
    let uygulamaMenu = NSMenu()
    uygulamaMenu.delegate = delege
    uygulamaMenu.addItem(withTitle: "Not Defteri Hakkında", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    uygulamaMenu.addItem(NSMenuItem.separator())
    let girisOgesi = NSMenuItem(title: "Girişte Otomatik Başlat", action: #selector(UygulamaDelegesi.girisKomutuTetiklendi(_:)), keyEquivalent: "")
    girisOgesi.target = delege
    uygulamaMenu.addItem(girisOgesi)
    uygulamaMenu.addItem(NSMenuItem.separator())
    uygulamaMenu.addItem(withTitle: "Not Defteri'nden Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    uygulamaMenuOgesi.submenu = uygulamaMenu
    anaMenu.addItem(uygulamaMenuOgesi)

    let dosyaMenuOgesi = NSMenuItem()
    let dosyaMenu = NSMenu(title: "Dosya")
    dosyaMenu.addItem(withTitle: "Kaydet", action: #selector(NotPenceresi.kaydetKomutu(_:)), keyEquivalent: "s")
    dosyaMenuOgesi.submenu = dosyaMenu
    anaMenu.addItem(dosyaMenuOgesi)

    let duzenMenuOgesi = NSMenuItem()
    let duzenMenu = NSMenu(title: "Düzen")
    duzenMenu.addItem(withTitle: "Geri Al", action: #selector(NotPenceresi.geriAlKomutu(_:)), keyEquivalent: "z")
    let yineleOgesi = NSMenuItem(title: "Yinele", action: #selector(NotPenceresi.ileriAlKomutu(_:)), keyEquivalent: "y")
    duzenMenu.addItem(yineleOgesi)  // ⇧⌘Z de yineler (performKeyEquivalent içinde).
    duzenMenu.addItem(NSMenuItem.separator())
    duzenMenu.addItem(withTitle: "Kes", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    duzenMenu.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    duzenMenu.addItem(withTitle: "Yapıştır", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    duzenMenu.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    duzenMenuOgesi.submenu = duzenMenu
    anaMenu.addItem(duzenMenuOgesi)

    let bicimMenuOgesi = NSMenuItem()
    let bicimMenu = NSMenu(title: "Biçim")
    bicimMenu.addItem(withTitle: "Kalın", action: #selector(NotPenceresi.kalinKomutu(_:)), keyEquivalent: "b")
    bicimMenuOgesi.submenu = bicimMenu
    anaMenu.addItem(bicimMenuOgesi)

    let gorunumMenuOgesi = NSMenuItem()
    let gorunumMenu = NSMenu(title: "Görünüm")
    // Tam ekran: menüden ⌃⌘F; ayrıca Fn+F (performKeyEquivalent içinde).
    let tamEkranOgesi = NSMenuItem(title: "Tam Ekran", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
    tamEkranOgesi.keyEquivalentModifierMask = [.command, .control]
    gorunumMenu.addItem(tamEkranOgesi)
    gorunumMenu.addItem(NSMenuItem.separator())
    let puntoArttirOgesi = NSMenuItem(title: "Puntoyu Büyüt", action: #selector(NotPenceresi.yaziBuyutKomutu(_:)), keyEquivalent: "*")
    puntoArttirOgesi.keyEquivalentModifierMask = [.command]
    gorunumMenu.addItem(puntoArttirOgesi)
    gorunumMenu.addItem(withTitle: "Puntoyu Küçült", action: #selector(NotPenceresi.yaziKucultKomutu(_:)), keyEquivalent: "-")
    gorunumMenu.addItem(NSMenuItem.separator())
    let temaMenuOgesi = NSMenuItem(title: "Tema", action: nil, keyEquivalent: "")
    let temaAltMenu = NSMenu(title: "Tema")
    for (index, tema) in temaListesi.enumerated() {
        let oge = NSMenuItem(title: tema.ad, action: #selector(NotPenceresi.temaSecKomutu(_:)), keyEquivalent: "")
        oge.representedObject = index
        temaAltMenu.addItem(oge)
    }
    temaMenuOgesi.submenu = temaAltMenu
    gorunumMenu.addItem(temaMenuOgesi)
    gorunumMenuOgesi.submenu = gorunumMenu
    anaMenu.addItem(gorunumMenuOgesi)

    let notMenuOgesi = NSMenuItem()
    let notMenu = NSMenu(title: "Not")
    notMenu.addItem(withTitle: "Önceki Not", action: #selector(NotPenceresi.oncekiNotKomutu(_:)), keyEquivalent: "[")
    notMenu.addItem(withTitle: "Sonraki Not", action: #selector(NotPenceresi.sonrakiNotKomutu(_:)), keyEquivalent: "]")
    notMenuOgesi.submenu = notMenu
    anaMenu.addItem(notMenuOgesi)

    return anaMenu
}

// MARK: - Uygulama giriş noktası

final class UygulamaDelegesi: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var pencere: NotPenceresi?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = anaMenuyuOlustur(delege: self)
        let p = NotPenceresi()
        self.pencere = p
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        pencere?.kapanistaGerekirseKaydet()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func girisKomutuTetiklendi(_ sender: NSMenuItem) {
        giristeAcmayiAyarla(!giristeAcikMi())
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let oge = menu.items.first(where: { $0.action == #selector(girisKomutuTetiklendi(_:)) }) {
            oge.state = giristeAcikMi() ? .on : .off
        }
    }
}

let app = NSApplication.shared
let delege = UygulamaDelegesi()
app.delegate = delege
app.run()
