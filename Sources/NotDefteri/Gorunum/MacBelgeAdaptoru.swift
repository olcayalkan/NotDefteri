import AppKit
import NotDefteriCekirdek

/// Editör ve özel kontrollerin seçili temaya göre değişen ana metin rengi.
var kMetinRenk: NSColor { aktifTema.metin }

/// Etiketsiz metnin temel fontu: her zaman sabit taban punto (kayma olmaması için).
func varsayilanFont() -> NSFont { fontUret(boyut: kTabanPunto, kalin: false) }

/// Başlık düzeylerinin punto çarpanları: /1 en büyük.
func baslikFontu(_ seviye: Int) -> NSFont {
    let carpan: CGFloat = seviye == 1 ? 1.75 : seviye == 2 ? 1.40 : 1.15
    return fontUret(boyut: (kTabanPunto * carpan).rounded(), kalin: true)
}

func fontUret(boyut: CGFloat, kalin: Bool) -> NSFont {
    let temel = NSFont.systemFont(ofSize: boyut)
    return kalin ? NSFontManager.shared.convert(temel, toHaveTrait: .boldFontMask) : temel
}

func kalinMi(_ font: NSFont) -> Bool { NSFontManager.shared.traits(of: font).contains(.boldFontMask) }
func italikMi(_ font: NSFont) -> Bool { NSFontManager.shared.traits(of: font).contains(.italicFontMask) }

// MARK: - Anlamsal belge ↔ AppKit görünümü
//
// Editör deposunda esas olan anlamsal özniteliklerdir (bkz. AnlamsalOznitelikler).
// Font, renk, üstü çizgi, arka plan, bağ, paragraf stili ve görsel eki her düzenlemede
// yalnızca değişen paragraflar için bunlardan türetilir. Kayıt bu görünüm
// özniteliklerini hiç okumaz; böylece görünüm ölçeği gibi salt görünüm ayarları
// dosyaya sızamaz.

/// Eskiden fonta gömülü olan anlamlar. Kodun "varsayılan fonta dön" dediği her yerde
/// bu anahtarlar birlikte kaldırılır.
// Kaynak biçimiyle yapıştırmanın font ailesi/renkleri ve başlıkta geçici punto
// değişikliği yalnızca Mac görünümüne aittir; Markdown bunları okumaz.
private let kMacKaynakGorunumu = NSAttributedString.Key("macKaynakGorunumu")
private let kMacBaslikPuntosu = NSAttributedString.Key("macBaslikPuntosu")
let kFontAnlamAnahtarlari: [NSAttributedString.Key] = [kKalinAnahtari, kItalikAnahtari, kPuntoOlcegiAnahtari,
                                                    kMacBaslikPuntosu, kMacKaynakGorunumu]

func fontAnlamlariniKaldir(_ metin: NSMutableAttributedString, aralik: NSRange) {
    for anahtar in kFontAnlamAnahtarlari { metin.removeAttribute(anahtar, range: aralik) }
}

/// Kod bloğu gövdesi ve işareti; dil ve kimlik okuyucunun ürettiğiyle aynıdır.
func kodBloguOznitelikleri(_ sinirlar: [String: String]) -> [NSAttributedString.Key: Any] {
    [kKodBloguAnahtari: sinirlar, kKodBloguDiliAnahtari: kodBloguDilEtiketi(sinirlar),
     kBlokKimligiAnahtari: sinirlar["kimlik"] ?? ""]
}

final class MacBelgeAdaptoru {
    /// "Küçük yazı" sayfa seçeneğinin görünüm ölçeği; kayda yazılmaz.
    var olcek: CGFloat = 1
    private var uygulaniyor = false

    private static let gorunumAnahtarlari: [NSAttributedString.Key] =
        [.font, .foregroundColor, .strikethroughStyle, .backgroundColor, .link, .paragraphStyle,
         .underlineStyle, .underlineColor, .strikethroughColor, .baselineOffset, .kern, .ligature,
         .strokeWidth, .strokeColor, .shadow, .obliqueness, .expansion, .writingDirection,
         .verticalGlyphForm, .textEffect, .superscript]
    private static var solukRenk: NSColor { kMetinRenk.withAlphaComponent(0.45) }
    private static var kodArkaplani: NSColor { kMetinRenk.withAlphaComponent(0.08) }
    private static let vurguArkaplani = NSColor.systemYellow.withAlphaComponent(0.3)
    private static var fontlar: [String: NSFont] = [:]

    // MARK: Anlamsal → görünüm

    /// Kaydın okuduğu ölçüsüz punto: başlıkta başlık puntosu, diğerlerinde punto ölçeği.
    func punto(_ o: [NSAttributedString.Key: Any]) -> CGFloat {
        if let seviye = o[kBaslikSeviyesiAnahtari] as? Int, o[kKodBloguAnahtari] == nil {
            return (o[kMacBaslikPuntosu] as? CGFloat) ?? baslikFontu(seviye).pointSize
        }
        return kTabanPunto * CGFloat((o[kPuntoOlcegiAnahtari] as? Double) ?? 1)
    }

    func font(_ o: [NSAttributedString.Key: Any]) -> NSFont {
        let boyut = punto(o) * olcek
        let kalin = kalinMi(o)
        if o[kSatirIciKodAnahtari] as? Bool != true, o[kKodBloguAnahtari] == nil,
           let kaynak = o[kMacKaynakGorunumu] as? [NSAttributedString.Key: Any], let font = kaynak[.font] as? NSFont {
            let yonetici = NSFontManager.shared
            var yeni = yonetici.convert(font, toSize: boyut)
            yeni = kalin ? yonetici.convert(yeni, toHaveTrait: .boldFontMask) : yonetici.convert(yeni, toNotHaveTrait: .boldFontMask)
            return o[kItalikAnahtari] as? Bool == true
                ? yonetici.convert(yeni, toHaveTrait: .italicFontMask) : yonetici.convert(yeni, toNotHaveTrait: .italicFontMask)
        }
        return Self.fontUret(boyut: boyut,
                             kalin: kalin,
                             italik: o[kItalikAnahtari] as? Bool == true,
                             mono: o[kSatirIciKodAnahtari] as? Bool == true || o[kKodBloguAnahtari] != nil)
    }

    func kalinMi(_ o: [NSAttributedString.Key: Any]) -> Bool {
        (o[kKalinAnahtari] as? Bool) ?? (o[kBaslikSeviyesiAnahtari] != nil)
    }

    func bicimiYaz(_ anahtar: NSAttributedString.Key, etkin: Bool,
                  oznitelikler: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var o = oznitelikler
        o[anahtar] = etkin ? true : (anahtar == kKalinAnahtari && o[kBaslikSeviyesiAnahtari] != nil ? false : nil)
        if var kaynak = o[kMacKaynakGorunumu] as? [NSAttributedString.Key: Any] {
            if anahtar == kUstuCiziliAnahtari { kaynak.removeValue(forKey: .strikethroughStyle) }
            if anahtar == kVurguAnahtari || anahtar == kSatirIciKodAnahtari { kaynak.removeValue(forKey: .backgroundColor) }
            if anahtar == kSatirIciKodAnahtari { kaynak.removeValue(forKey: .font) }
            o[kMacKaynakGorunumu] = kaynak
        }
        return o
    }

    func puntoyuYaz(_ punto: CGFloat, oznitelikler: inout [NSAttributedString.Key: Any]) {
        if oznitelikler[kBaslikSeviyesiAnahtari] != nil, oznitelikler[kKodBloguAnahtari] == nil {
            oznitelikler[kMacBaslikPuntosu] = punto
        } else {
            oznitelikler[kPuntoOlcegiAnahtari] = punto == kTabanPunto ? nil : Double(punto / kTabanPunto)
        }
    }

    /// AppKit font panelinin komutu da fontu kayıt biçimi olarak kullanmaz.
    func fontuDegistir(_ yonetici: NSFontManager, oznitelikler: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var o = oznitelikler
        let yeni = yonetici.convert(font(o))
        let ozellikler = yonetici.traits(of: yeni)
        o[kKalinAnahtari] = ozellikler.contains(.boldFontMask)
        o[kItalikAnahtari] = ozellikler.contains(.italicFontMask)
        puntoyuYaz(yeni.pointSize / olcek, oznitelikler: &o)
        var kaynak = (o[kMacKaynakGorunumu] as? [NSAttributedString.Key: Any]) ?? [:]
        kaynak[.font] = yeni
        o[kMacKaynakGorunumu] = kaynak
        return o
    }

    /// Önizleme gibi NSTextStorage delegesi olmayan tüketiciler için yükleme sınırı.
    func gorunumluBelge(_ anlamsal: NSAttributedString) -> NSAttributedString {
        let belge = NSMutableAttributedString(attributedString: anlamsal)
        gorunumuUygula(belge, aralik: NSRange(location: 0, length: belge.length))
        return belge
    }

    /// Çekirdek dosyanın varlığını, Mac ise codec'i doğrular. Çözülemeyen
    /// görsel eski okuyucudaki gibi kaynak metin olarak kalır.
    /// `olcek`: hedef editörün yazı ölçeği. Görünüm burada bir kez doğru ölçekle kurulur;
    /// editör yüklerken aynı hesabı (büyük notta açılışın üçte biri) tekrarlamaz.
    static func markdownuAc(_ markdown: String, taban: URL = notlarKlasoru(), olcek: CGFloat = 1) -> NSAttributedString {
        belgeyiAc(markdowndenAttributedStringUret(markdown, taban: taban), taban: taban, olcek: olcek)
    }

    static func belgeyiAc(_ anlamsal: NSAttributedString, taban: URL, olcek: CGFloat = 1) -> NSAttributedString {
        let adaptor = MacBelgeAdaptoru()
        adaptor.olcek = olcek
        let belge = NSMutableAttributedString(attributedString: adaptor.gorunumluBelge(anlamsal))
        var degisiklikler: [(NSRange, NSAttributedString)] = []
        var konum = 0
        while konum < belge.length {
            let satir = belge.mutableString.lineRange(for: NSRange(location: konum, length: 0))
            let parca = belge.attributedSubstring(from: satir)
            if let yeni = okunamayanGorselleriMetneCevir(parca, taban: taban) {
                let gorunumlu = NSMutableAttributedString(attributedString: adaptor.gorunumluBelge(yeni))
                gorselKaynakKanoniginiGuncelle(gorunumlu, onceki: yeni)
                degisiklikler.append((satir, gorunumlu))
            } else if gorselSayisi(parca) > 0 {
                let yeni = NSMutableAttributedString(attributedString: parca)
                gorselKaynakKanoniginiGuncelle(yeni, onceki: anlamsal.attributedSubstring(from: satir))
                degisiklikler.append((satir, yeni))
            }
            konum = NSMaxRange(satir)
        }
        for (aralik, yeni) in degisiklikler.reversed() { belge.replaceCharacters(in: aralik, with: yeni) }
        return belge
    }

    /// Doğal/küçük görsel boyutu kayda taşınır; düzenlenmemiş kaynak yine aynen kalır.
    private static func gorselKaynakKanoniginiGuncelle(_ belge: NSMutableAttributedString, onceki: NSAttributedString) {
        guard gorselSayisi(belge) > 0,
              let kaynak = MarkdownKaynagi(oznitelik: onceki.attribute(kMarkdownKaynakAnahtari, at: 0, effectiveRange: nil)),
              markdownMetniUret(onceki) == kaynak.metin else { return }
        let tumu = NSRange(location: 0, length: belge.length)
        belge.removeAttribute(kMarkdownKaynakAnahtari, range: tumu)
        let kanonik = markdownMetniUret(belge)
        belge.addAttribute(kMarkdownKaynakAnahtari, value: MarkdownKaynagi(metin: kaynak.metin, kanonik: kanonik).oznitelikDegeri, range: tumu)
    }

    private static func okunamayanGorselleriMetneCevir(_ parca: NSAttributedString, taban: URL) -> NSAttributedString? {
        var yollar = Set<String>()
        parca.enumerateAttributes(in: NSRange(location: 0, length: parca.length)) { o, _, _ in
            if o[.attachment] == nil, let gorsel = o[kGorselAnahtari] as? [String: Any], let yol = gorsel["yol"] as? String {
                yollar.insert(yol)
            }
        }
        guard !yollar.isEmpty,
              let ham = MarkdownKaynagi(oznitelik: parca.attribute(kMarkdownKaynakAnahtari, at: 0, effectiveRange: nil))?.metin else { return nil }
        let metin = NSMutableString(string: ham)
        var yeni = markdowndenAttributedStringUret(ham, taban: taban)
        let desen = try! NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)]{0,1024})\)"#)
        // ponytail: yalnızca bozuk görselli satırda aday başına yeniden ayrıştırma;
        // büyük bozuk satırlar yaygınlaşırsa çekirdeğe kaynak aralığı eklenebilir.
        for aday in desen.matches(in: ham, range: NSRange(location: 0, length: metin.length)).reversed() {
            guard yollar.contains(metin.substring(with: aday.range(at: 1))) else { continue }
            let onceki = gorselSayisi(yeni)
            metin.insert("\\", at: aday.range.location)
            let cozum = markdowndenAttributedStringUret(metin as String, taban: taban)
            // Aynı yol inline kodda veya zaten kaçırılmış metinde de bulunabilir.
            // Yalnızca gerçek bir görseli kaldıran kaçış kabul edilir.
            if gorselSayisi(cozum) < onceki { yeni = cozum }
            else { metin.deleteCharacters(in: NSRange(location: aday.range.location, length: 1)) }
        }
        let sonuc = NSMutableAttributedString(attributedString: yeni)
        let tumu = NSRange(location: 0, length: sonuc.length)
        // Tek başına ayrıştırılan uyarı devamı, önceki paragrafın kimliğini korur.
        if let blok = MetinBlogu(oznitelik: parca.attribute(kMetinBloguAnahtari, at: 0, effectiveRange: nil)) {
            sonuc.addAttributes(blok.oznitelikler, range: tumu)
        }
        sonuc.removeAttribute(kMarkdownKaynakAnahtari, range: tumu)
        let kanonik = markdownMetniUret(sonuc)
        sonuc.addAttribute(kMarkdownKaynakAnahtari, value: MarkdownKaynagi(metin: ham, kanonik: kanonik).oznitelikDegeri, range: tumu)
        return sonuc
    }

    private static func gorselSayisi(_ metin: NSAttributedString) -> Int {
        var sayi = 0
        metin.enumerateAttribute(kGorselAnahtari, in: NSRange(location: 0, length: metin.length)) { deger, aralik, _ in
            if deger != nil { sayi += aralik.length }
        }
        return sayi
    }

    /// Yazım öznitelikleri: anlamsal sözlüğe güncel görünüm eklenir.
    /// AppKit eki veya bağı yazıma taşımadıysa anlamsal karşılıkları da taşınmaz.
    func gorunumlu(_ oznitelikler: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var o = oznitelikler
        o.removeValue(forKey: kGorselAnahtari)
        if o[.link] == nil {
            o.removeValue(forKey: kBaglantiAnahtari)
            o.removeValue(forKey: kCiplakBagAnahtari)
        }
        for anahtar in Self.gorunumAnahtarlari { o.removeValue(forKey: anahtar) }
        return o.merging(gorunum(o)) { _, yeni in yeni }
    }

    /// Depodaki aralığın görünümünü anlamsala eşitler; yalnızca farklı olan öznitelik yazılır.
    func gorunumuUygula(_ depo: NSMutableAttributedString, aralik: NSRange) {
        let aralik = NSIntersectionRange(aralik, NSRange(location: 0, length: depo.length))
        guard !uygulaniyor, aralik.length > 0 else { return }
        uygulaniyor = true
        defer { uygulaniyor = false }
        var islemler: [(NSRange, [NSAttributedString.Key: Any], [NSAttributedString.Key])] = []
        depo.enumerateAttributes(in: aralik) { o, alt, _ in
            let istenen = gorunum(o)
            var ekle: [NSAttributedString.Key: Any] = [:]
            var sil: [NSAttributedString.Key] = []
            for anahtar in Self.gorunumAnahtarlari {
                switch (o[anahtar], istenen[anahtar]) {
                case (nil, nil): break
                case (_, nil): sil.append(anahtar)
                case (let eski?, let yeni?): if !(eski as AnyObject).isEqual(yeni) { ekle[anahtar] = yeni }
                case (nil, let yeni?): ekle[anahtar] = yeni
                }
            }
            if !ekle.isEmpty || !sil.isEmpty { islemler.append((alt, ekle, sil)) }
        }
        for (alt, ekle, sil) in islemler {
            if !ekle.isEmpty { depo.addAttributes(ekle, range: alt) }
            for anahtar in sil { depo.removeAttribute(anahtar, range: alt) }
        }
        gorselleriEsle(depo, aralik: aralik)
    }

    private func gorunum(_ o: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        let blok = MetinBlogu(oznitelik: o[kMetinBloguAnahtari])
        // Tamamlanan görevde işaret (☑) soluklaşmaz; yalnızca metin.
        let soluk = blok?.tur == .yapilacak && blok?.tamamlandi == true && o[kBlokIsaretiAnahtari] as? Bool != true
        var g = (o[kMacKaynakGorunumu] as? [NSAttributedString.Key: Any]) ?? [:]
        g[.font] = font(o)
        g[.foregroundColor] = soluk ? Self.solukRenk : (g[.foregroundColor] ?? kMetinRenk)
        if soluk || o[kUstuCiziliAnahtari] as? Bool == true { g[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if o[kVurguAnahtari] as? Bool == true {
            g[.backgroundColor] = Self.vurguArkaplani
        } else if o[kSatirIciKodAnahtari] as? Bool == true {
            g[.backgroundColor] = Self.kodArkaplani
        }
        if let bag = o[kBaglantiAnahtari] { g[.link] = bag }
        // Kodun görsel girintisi yalnızca Mac stilidir; gövdeye ve kayda sekme eklenmez.
        let geometri: [String: Any]? = o[kKodBloguAnahtari] != nil
            ? ["ilkSatirGirintisi": 24.0, "govdeGirintisi": 24.0, "sekmeAraligi": 24.0]
            : o[kParagrafGeometrisiAnahtari] as? [String: Any]
        if let stil = paragrafStili(geometri) {
            g[.paragraphStyle] = stil
        }
        return g
    }

    /// Paragraf geometrisi taban punto uzayındadır; görünüm ölçeğinden etkilenmez.
    private func paragrafStili(_ g: [String: Any]?) -> NSParagraphStyle? {
        guard let g else { return nil }
        func deger(_ ad: String) -> CGFloat { CGFloat((g[ad] as? Double) ?? 0) }
        var govde = deger("govdeGirintisi")
        if let numara = g["numaraMetni"] as? String, !numara.isEmpty {
            let isaret = max(deger("isaretEnAzGenisligi"),
                             (numara as NSString).size(withAttributes: [.font: varsayilanFont()]).width + deger("isaretSonuBoslugu"))
            govde += isaret - deger("isaretEnAzGenisligi")
        }
        let stil = NSMutableParagraphStyle()
        stil.firstLineHeadIndent = deger("ilkSatirGirintisi")
        stil.headIndent = govde
        stil.tabStops = [NSTextTab(textAlignment: .left, location: govde)]
        stil.defaultTabInterval = deger("sekmeAraligi")
        if deger("enAzSatirYuksekligi") > 0 { stil.minimumLineHeight = deger("enAzSatirYuksekligi") }
        stil.paragraphSpacingBefore = deger("paragrafBoslugu")
        stil.paragraphSpacing = deger("paragrafBoslugu")
        return stil
    }

    private static func fontUret(boyut: CGFloat, kalin: Bool, italik: Bool, mono: Bool) -> NSFont {
        let anahtar = "\(boyut)|\(kalin)|\(italik)|\(mono)"
        if let font = fontlar[anahtar] { return font }
        let yonetici = NSFontManager.shared
        var font = mono ? NSFont.monospacedSystemFont(ofSize: boyut, weight: .regular) : NSFont.systemFont(ofSize: boyut)
        if kalin { font = yonetici.convert(font, toHaveTrait: .boldFontMask) }
        if italik { font = yonetici.convert(font, toHaveTrait: .italicFontMask) }
        fontlar[anahtar] = font
        return font
    }

    // MARK: Görseller

    /// Anlamsal görsel ile ek eşlenir: aynı dosyanın eki korunur (tutamaç durumu
    /// kaybolmasın), yoksa diskten üretilir. Eki olup anlamsalı olmayan görsel
    /// kayıttan düşmesin diye anlamsala çevrilir.
    private func gorselleriEsle(_ depo: NSMutableAttributedString, aralik: NSRange) {
        var ekler: [(Int, ResimEki)] = []
        var anlamsallar: [(Int, [String: Any])] = []
        depo.enumerateAttribute(kGorselAnahtari, in: aralik) { deger, alt, _ in
            guard let gorsel = deger as? [String: Any] else { return }
            for konum in alt.location..<NSMaxRange(alt) {
                let mevcut = depo.attribute(.attachment, at: konum, effectiveRange: nil) as? ResimEki
                let ek: ResimEki
                if let mevcut, Self.eslesir(mevcut, gorsel) {
                    let boyut = Self.boyut(gorsel).flatMap { $0.width >= kEnKucukResimEni ? $0 : nil }
                        ?? mevcut.dogalGosterimBoyutu
                    if mevcut.gosterimBoyutu != boyut { mevcut.gosterimBoyutu = boyut }
                    ek = mevcut
                } else if let yeni = Self.resimEki(gorsel) {
                    ekler.append((konum, yeni))
                    ek = yeni
                } else { continue }
                if let yeni = Self.gorselAnlamsali(ek),
                   gorsel["genislik"] as? Double != yeni["genislik"] as? Double ||
                   gorsel["yukseklik"] as? Double != yeni["yukseklik"] as? Double {
                    anlamsallar.append((konum, yeni))
                }
            }
        }
        depo.enumerateAttribute(.attachment, in: aralik) { deger, alt, _ in
            guard let ek = deger as? ResimEki, depo.attribute(kGorselAnahtari, at: alt.location, effectiveRange: nil) == nil,
                  let gorsel = Self.gorselAnlamsali(ek) else { return }
            anlamsallar.append((alt.location, gorsel))
        }
        for (konum, ek) in ekler { depo.addAttribute(.attachment, value: ek, range: NSRange(location: konum, length: 1)) }
        for (konum, gorsel) in anlamsallar { depo.addAttribute(kGorselAnahtari, value: gorsel, range: NSRange(location: konum, length: 1)) }
    }

    private static func eslesir(_ ek: ResimEki, _ gorsel: [String: Any]) -> Bool {
        guard let url = gorsel["dosyaURL"] as? URL else { return false }
        return ek.dosyaURL?.standardizedFileURL == url.standardizedFileURL && ek.bagYolu == gorsel["yol"] as? String
    }

    private static func boyut(_ gorsel: [String: Any]) -> NSSize? {
        guard let en = gorsel["genislik"] as? Double, let boy = gorsel["yukseklik"] as? Double,
              anlamsalGorselBoyutuGecerliMi(en: en, boy: boy) else { return nil }
        return NSSize(width: en, height: boy)
    }

    /// Eski okuyucu gibi doğal boyutu ve minimum genişlik davranışını ek üreticisi çözer.
    private static func resimEki(_ gorsel: [String: Any]) -> ResimEki? {
        guard let url = gorsel["dosyaURL"] as? URL, let resim = NSImage(contentsOf: url) else { return nil }
        return resimEkiUret(gorsel: resim, dosyaURL: url, bagYolu: gorsel["yol"] as? String, gosterimBoyutu: boyut(gorsel))
    }

    /// Ekten anlamsal görsel; eski yazıcı gibi geçersiz boyutta 200x150 yazılır.
    static func gorselAnlamsali(_ ek: ResimEki) -> [String: Any]? {
        guard let url = ek.dosyaURL else { return nil }
        let boyut = resimBoyutuGecerliMi(ek.gosterimBoyutu) ? ek.gosterimBoyutu : NSSize(width: 200, height: 150)
        return ["yol": ek.bagYolu ?? "\(kGorsellerKlasorAdi)/\(url.lastPathComponent)", "dosyaURL": url,
                "genislik": Double(boyut.width), "yukseklik": Double(boyut.height)]
    }

    // MARK: Görünüm → anlamsal (dış zengin metin)

    /// RTF/RTFD/HTML'den gelen fontu ve ekleri anlamsala indirger.
    /// `kaynakBicimi`: ⇧⌘V — eski yazıcının fonttan okuduğu italik ve bağ da korunur.
    static func disIcerigiAnlamsalaCevir(_ zengin: NSAttributedString, kaynakBicimi: Bool = false) -> NSAttributedString {
        let sonuc = NSMutableAttributedString(string: zengin.string)
        zengin.enumerateAttributes(in: NSRange(location: 0, length: zengin.length)) { o, alt, _ in
            var yeni: [NSAttributedString.Key: Any] = [:]
            if kaynakBicimi {
                // ⇧⌘V'nin renk, paragraf ve font ailesi aynı oturumda aynen görünür.
                // Kalıcı anlamlar aşağıda ayrıca çıkarılır; kayıt bu sözlüğü okumaz.
                yeni[kMacKaynakGorunumu] = o.filter { Self.gorunumAnahtarlari.contains($0.key) && $0.key != .link }
            }
            if let ek = o[.attachment] as? ResimEki, let gorsel = gorselAnlamsali(ek) {
                yeni[kGorselAnahtari] = gorsel
                yeni[.attachment] = ek
            }
            if let font = o[.font] as? NSFont {
                if NSFontManager.shared.traits(of: font).contains(.boldFontMask) { yeni[kKalinAnahtari] = true }
                if kaynakBicimi, italikMi(font) { yeni[kItalikAnahtari] = true }
                let oran = Double(font.pointSize / kTabanPunto)
                if abs(oran - 1) > 0.0001 { yeni[kPuntoOlcegiAnahtari] = oran }
            }
            if kaynakBicimi, let bag = o[.link] {
                yeni[kBaglantiAnahtari] = (bag as? URL) ?? URL(string: String(describing: bag))
            }
            sonuc.setAttributes(yeni, range: alt)
        }
        return sonuc
    }

    /// Ortak HTML yazıcısının gömdüğü görselleri macOS'taki eski PNG çıktısına
    /// uyarlar. Yalnızca yazıcının ürettiği img etiketleri işlenir; kök klasör
    /// doğrulaması htmlUret içinde, dosya okunmadan önce yapılmıştır.
    static func htmlGorselleriniUyarla(_ html: String) throws -> String {
        let desen = try NSRegularExpression(pattern: #"<img alt=""(?: style="width:([0-9]+)px")? src="data:[^;"]+;base64,([^"]+)">"#)
        let sonuc = NSMutableString(string: html)
        for eslesme in desen.matches(in: html, range: NSRange(location: 0, length: sonuc.length)).reversed() {
            guard let veri = Data(base64Encoded: sonuc.substring(with: eslesme.range(at: 2))),
                  let resim = NSImage(data: veri), let tiff = resim.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let istenen = eslesme.range(at: 1).location == NSNotFound ? nil
                : Double(sonuc.substring(with: eslesme.range(at: 1)))
            let dogal = resim.size.width.isFinite && resim.size.width > 0 ? min(resim.size.width, 360) : 200
            let en = istenen.flatMap { $0 >= kEnKucukResimEni ? $0 : nil } ?? dogal.rounded()
            sonuc.replaceCharacters(in: eslesme.range,
                with: "<img alt=\"\" style=\"width:\(Int(en))px\" src=\"data:image/png;base64,\(png.base64EncodedString())\">")
        }
        return sonuc as String
    }
}
