import CGtk
import Foundation
import NotDefteriCekirdek

typealias Oznitelikler = [NSAttributedString.Key: Any]

/// g_object_set variadic olduğu için özellikler tek tek GValue ile yazılır.
enum GDeger {
    case metin(String), tam(Int32), ondalik(Double), mantik(Bool), sayim(GType, Int32), kutu(GType, UnsafeRawPointer)
}

func gNesneOzelligi(_ nesne: UnsafeMutableRawPointer, _ ad: String, _ deger: GDeger) {
    var v = GValue()
    switch deger {
    case .metin(let s): g_value_init(&v, g_type_from_name("gchararray")); g_value_set_string(&v, s)
    case .tam(let i): g_value_init(&v, g_type_from_name("gint")); g_value_set_int(&v, i)
    case .ondalik(let x): g_value_init(&v, g_type_from_name("gdouble")); g_value_set_double(&v, x)
    case .mantik(let b): g_value_init(&v, g_type_from_name("gboolean")); g_value_set_boolean(&v, b ? 1 : 0)
    case .sayim(let tur, let i): g_value_init(&v, tur); g_value_set_enum(&v, i)
    case .kutu(let tur, let p): g_value_init(&v, tur); g_value_set_boxed(&v, p)
    }
    g_object_set_property(nesne.assumingMemoryBound(to: GObject.self), ad, &v)
    g_value_unset(&v)
}

/// macOS MacBelgeAdaptoru'nun Linux eşi. Esas belge anlamsal `belge`dir; GtkTextBuffer
/// yalnızca onun görünümüdür. Tampondaki her metin değişikliği belgeye aynalanır, etiketler
/// her düzenlemede yalnızca değişen paragraflar için anlamsaldan türetilir. Kayıt
/// etiketleri hiç okumaz; böylece görünüm ayarları dosyaya sızamaz.
final class LinuxBelgeAdaptoru {
    private(set) var belge = NSMutableAttributedString(string: "")
    /// Belgeyi kendimiz değiştirirken tampon sinyalleri aynalanmaz.
    private(set) var programatik = false
    private let tampon: UnsafeMutablePointer<GtkTextBuffer>
    private let tablo: OpaquePointer
    private var etiketler: [String: UnsafeMutablePointer<GtkTextTag>] = [:]
    /// Etiketin `left-margin`'i görünümün kenar boşluğuna eklenmez, onun yerine geçer; ortalanan
    /// sayfada listeler/kod/uyarı sola kayıyordu. Taban girinti saklanır, sayfa kenarı üstüne eklenir.
    private var solTabanlar: [String: Int32] = [:]
    private var sayfaKenari: Int32 = 0
    private var bekleyen: NSRange?

    init(tampon: UnsafeMutablePointer<GtkTextBuffer>) {
        self.tampon = tampon
        tablo = gtk_text_buffer_get_tag_table(tampon)
        // Oluşturma sırası önceliktir: sonra gelen etiket öncekini ezer (vurgu > kod arka planı).
        for seviye in 1...3 { etiket("baslik\(seviye)", [("scale", .ondalik(seviye == 1 ? 1.75 : seviye == 2 ? 1.40 : 1.15))]) }
        etiket("kalin", [("weight", .tam(700))])
        etiket("italik", [("style", .sayim(pango_style_get_type(), Int32(PANGO_STYLE_ITALIC.rawValue)))])
        etiket("ustuCizili", [("strikethrough", .mantik(true))])
        etiket("soluk", [("foreground", .metin("rgba(128,128,128,0.9)"))])
        etiket("mono", [("family", .metin("monospace"))])
        etiket("kodArka", [("background", .metin("rgba(0,0,0,0.08)"))])
        etiket("tablo", [("background", .metin("rgba(0,0,0,0.075)")), ("left-margin", .tam(14)),
                          ("pixels-above-lines", .tam(0)), ("pixels-below-lines", .tam(0))])
        etiket("tabloBaslik", [("background", .metin("rgba(0,0,0,0.20)"))])
        etiket("tabloAlternatif", [("background", .metin("rgba(0,0,0,0.035)"))])
        etiket("tabloCerceve", [("foreground", .metin("rgba(0,0,0,0.62)"))])
        etiket("tabloSarmaYok", [
            ("wrap-mode", .sayim(gtk_wrap_mode_get_type(), Int32(GTK_WRAP_NONE.rawValue)))
        ])
        etiket("kod-girinti", [("left-margin", .tam(24)), ("indent", .tam(0))])
        etiket("vurgu", [("background", .metin("rgba(255,204,0,0.3)"))])
        // macOS: web bağlantısı metin renginde altı çizili, sayfa bağı systemBlue altı çizili.
        etiket("sayfaBagi", [("foreground", .metin("#007aff")),
                             ("underline", .sayim(pango_underline_get_type(), Int32(PANGO_UNDERLINE_SINGLE.rawValue)))])
        etiket("baglanti", [("foreground", .metin("#000000")),
                            ("underline", .sayim(pango_underline_get_type(), Int32(PANGO_UNDERLINE_SINGLE.rawValue)))])
        // Ayırıcı: Mac'teki ince yatay çizginin karşılığı; ince, tam genişlikte paragraf arka planı.
        etiket("ayirici", [("scale", .ondalik(0.2)), ("paragraph-background", .metin("rgba(128,128,128,0.45)"))])
        etiket(Self.kutuUstEtiketi, [("pixels-above-lines", .tam(Self.kutuBoslugu))])
        etiket(Self.kutuAltEtiketi, [("pixels-below-lines", .tam(Self.kutuBoslugu))])
        temayiUygula()
    }

    /// GtkTextTag renkleri CSS mirasını ezdiği için tema değişiminde ayrıca güncellenir.
    func temayiUygula() {
        let koyu = LinuxTema.koyuMu
        let metin = LinuxTema.metinRengi
        let soluk = koyu ? "rgba(242,240,247,0.55)" : "rgba(0,0,0,0.45)"
        let kodArka = koyu ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)"
        let tabloArka = koyu ? "rgba(255,255,255,0.075)" : "rgba(0,0,0,0.075)"
        let tabloBaslik = koyu ? "rgba(255,255,255,0.20)" : "rgba(0,0,0,0.20)"
        let tabloAlternatif = koyu ? "rgba(255,255,255,0.035)" : "rgba(0,0,0,0.035)"
        let tabloCerceve = koyu ? "rgba(242,240,247,0.62)" : "rgba(0,0,0,0.62)"
        let ayirici = koyu ? "rgba(242,240,247,0.45)" : "rgba(128,128,128,0.45)"
        if let tag = etiketler["soluk"] { gNesneOzelligi(UnsafeMutableRawPointer(tag), "foreground", .metin(soluk)) }
        if let tag = etiketler["kodArka"] { gNesneOzelligi(UnsafeMutableRawPointer(tag), "background", .metin(kodArka)) }
        if let tag = etiketler["tablo"] { gNesneOzelligi(UnsafeMutableRawPointer(tag), "background", .metin(tabloArka)) }
        if let tag = etiketler["tabloBaslik"] { gNesneOzelligi(UnsafeMutableRawPointer(tag), "background", .metin(tabloBaslik)) }
        if let tag = etiketler["tabloAlternatif"] { gNesneOzelligi(UnsafeMutableRawPointer(tag), "background", .metin(tabloAlternatif)) }
        if let tag = etiketler["tabloCerceve"] { gNesneOzelligi(UnsafeMutableRawPointer(tag), "foreground", .metin(tabloCerceve)) }
        if let tag = etiketler["baglanti"] { gNesneOzelligi(UnsafeMutableRawPointer(tag), "foreground", .metin(metin)) }
        if let tag = etiketler["ayirici"] { gNesneOzelligi(UnsafeMutableRawPointer(tag), "paragraph-background", .metin(ayirici)) }
    }

    // MARK: Yükleme ve programatik değişiklik

    /// Açılış geri alınamaz; geçmiş temiz başlar.
    func yukle(_ anlamsal: NSAttributedString) {
        GtkKoprusu.aynalamaHatasiniSifirla(tampon)
        programatik = true
        defer { programatik = false }
        belge = NSMutableAttributedString(attributedString: anlamsal)
        bekleyen = nil
        gtk_text_buffer_begin_irreversible_action(tampon)
        gtk_text_buffer_set_text(tampon, "", -1)
        var bas = GtkTextIter()
        gtk_text_buffer_get_start_iter(tampon, &bas)
        metniEkle(belge, konuma: &bas)
        let tumu = NSRange(location: 0, length: belge.length)
        gtk_text_buffer_end_irreversible_action(tampon)
        gorunumuUygula(tumu)
    }

    /// Belge ile tampon aynı aralıkta aynı metne geçer; etiketler yeniden türetilir.
    func degistir(_ aralik: NSRange, ile yeni: NSAttributedString) {
        LinuxGorseller.duzenleme(tampon, aralik: aralik, eski: belge.attributedSubstring(from: aralik), yeni: yeni)
        programatik = true
        defer { programatik = false }
        var (bas, son) = GtkKoprusu.iterler(tampon, aralik, metin: belge.mutableString)
        gtk_text_buffer_delete(tampon, &bas, &son)
        metniEkle(yeni, konuma: &bas)
        belge.replaceCharacters(in: aralik, with: yeni)
        let degisen = NSRange(location: aralik.location, length: yeni.length)
        gorunumuUygula(degisen)
    }

    /// Kayıt sınırında aynalama kayması veri kaybına dönüşmeden durdurulur.
    func aynalamaHatasi() -> String? {
        if let neden = GtkKoprusu.aynalamaHatasi(tampon) { return neden }
        var bas = GtkTextIter(), son = GtkTextIter()
        gtk_text_buffer_get_bounds(tampon, &bas, &son)
        let gorunen = GtkKoprusu.dilim(tampon, bas: bas, son: son)
        let beklenen = gorunumMetni(belge)
        // Yalnızca karşılaştırma normalleşir; anlamsal belge ve dosya satır sonları korunur.
        func satirSonlari(_ metin: String) -> String {
            metin.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        }
        guard !satirSonlari(gorunen).utf16.elementsEqual(satirSonlari(beklenen).utf16) else { return nil }
        let neden = "Editör tamponu ile anlamsal belge eşleşmiyor; dosyaya yazılmadı."
        // Not içeriği günlüğe dökülmez; yalnızca uzunluklar tanı için yeterlidir.
        FileHandle.standardError.write(Data("[NotDefteri] Aynalama kayması: GTK=\((gorunen as NSString).length), belge=\(belge.length) UTF-16\n".utf8))
        return neden
    }

    // MARK: Tampon → belge aynalama (kullanıcı yazımı, geri alma)

    func eklendi(konum: Int, metin: String, yazim: Oznitelikler) {
        guard !programatik else { return }
        let eklenen = NSAttributedString(string: metin, attributes: yazim)
        guard konum >= 0 && konum <= belge.length else {
            GtkKoprusu.aynalamaKaymasi(tampon, "Aynalama ekleme konumu geçersiz: \(konum), belge=\(belge.length)")
            return
        }
        guard GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
        LinuxGorseller.duzenleme(tampon, aralik: NSRange(location: konum, length: 0),
                                eski: NSAttributedString(string: ""), yeni: eklenen)
        belge.insert(eklenen, at: konum)
        isaretle(NSRange(location: konum, length: eklenen.length))
    }

    func silindi(_ aralik: NSRange) {
        guard !programatik else { return }
        guard aralik.location >= 0, aralik.length >= 0, aralik.location <= belge.length,
              aralik.length <= belge.length - aralik.location else {
            GtkKoprusu.aynalamaKaymasi(tampon, "Aynalama silme aralığı geçersiz: \(aralik), belge=\(belge.length)")
            return
        }
        guard GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
        LinuxGorseller.duzenleme(tampon, aralik: aralik, eski: belge.attributedSubstring(from: aralik),
                                yeni: NSAttributedString(string: ""))
        belge.deleteCharacters(in: aralik)
        isaretle(NSRange(location: aralik.location, length: 0))
    }

    /// "changed" sinyalinde: değişen paragrafların görünümü güncellenir.
    func bekleyeniUygula() {
        guard let aralik = bekleyen else { return }
        bekleyen = nil
        gorunumuUygula(aralik)
    }

    private func isaretle(_ aralik: NSRange) {
        bekleyen = bekleyen.map { NSUnionRange($0, aralik) } ?? aralik
    }

    // MARK: Anlamsal → etiket

    func gorunumuUygula(_ aralik: NSRange) {
        let ns = belge.mutableString
        let konum = min(aralik.location, ns.length)
        var kapsam = ns.paragraphRange(for: NSRange(location: konum, length: min(aralik.length, ns.length - konum)))
        guard kapsam.length > 0 else { return }
        // Kutu kenarındaki boşluk ilk/son paragrafa bağlıdır; kutu büyüyüp küçülünce eski kenar
        // paragrafında boşluk kalmasın diye kapsam kutunun tamamına genişler (macOS ile aynı).
        kapsam = kutularaGenislet(kapsam)
        var (bas, son) = GtkKoprusu.iterler(tampon, kapsam, metin: ns)
        // Yalnızca adaptörün etiketlerini temizle; eklentilerin kod-/uyari-/katla- etiketleri korunur.
        for etiket in etiketler.values { gtk_text_buffer_remove_tag(tampon, etiket, &bas, &son) }
        var iter = bas
        func uygula(_ o: Oznitelikler, _ alt: NSRange) {
            var sonraki = iter
            gtk_text_iter_forward_chars(&sonraki, Int32(LinuxMetinDonusumu.karakterSayisi(ns, alt)))
            var adlar = etiketAdlari(o)
            if let kenar = kutuKenari(o, alt) {
                if kenar.ust, let ust = etiketler[Self.kutuUstEtiketi] { adlar.append(ust) }
                if kenar.alt, let alt = etiketler[Self.kutuAltEtiketi] { adlar.append(alt) }
            }
            for ad in adlar { gtk_text_buffer_apply_tag(tampon, ad, &iter, &sonraki) }
            iter = sonraki
        }
        belge.enumerateAttributes(in: kapsam) { o, alt, _ in
            // Kod gövdesi çok satırlı tek parçadır; kenar yalnızca ilk/son paragrafa gitsin diye bölünür.
            guard Self.kutuAnahtarlari.contains(where: { o[$0] != nil }) else { uygula(o, alt); return }
            var bas = alt.location
            while bas < NSMaxRange(alt) {
                let paragraf = NSIntersectionRange(ns.paragraphRange(for: NSRange(location: bas, length: 0)), alt)
                uygula(o, paragraf)
                bas = max(NSMaxRange(paragraf), bas + 1)
            }
        }
    }

    private static let kutuAnahtarlari = [kKodBloguAnahtari, kUyariKutusuAnahtari]
    static let kutuUstEtiketi = "kutu-ust", kutuAltEtiketi = "kutu-alt"
    /// Kutunun üstünde/altında bırakılan görünüm boşluğu (macOS kKutuDisBoslugu); çerçeve bunu dışarıda bırakır.
    static let kutuBoslugu = Int32(kKutuDisBoslugu)

    private func kutularaGenislet(_ kapsam: NSRange) -> NSRange {
        let tumu = NSRange(location: 0, length: belge.length)
        var sonuc = kapsam
        for konum in [kapsam.location, max(kapsam.location, NSMaxRange(kapsam) - 1)] where konum < belge.length {
            for anahtar in Self.kutuAnahtarlari {
                var blok = NSRange()
                if belge.attribute(anahtar, at: konum, longestEffectiveRange: &blok, in: tumu) != nil {
                    sonuc = NSUnionRange(sonuc, blok)
                }
            }
        }
        return sonuc
    }

    /// Parça kutunun ilk paragrafındaysa üst, son paragrafındaysa alt kenardadır.
    private func kutuKenari(_ o: Oznitelikler, _ alt: NSRange) -> (ust: Bool, alt: Bool)? {
        guard let anahtar = Self.kutuAnahtarlari.first(where: { o[$0] != nil }) else { return nil }
        let ns = belge.mutableString
        var blok = NSRange()
        _ = belge.attribute(anahtar, at: alt.location, longestEffectiveRange: &blok, in: NSRange(location: 0, length: belge.length))
        guard blok.length > 0 else { return nil }
        let ilk = ns.paragraphRange(for: NSRange(location: blok.location, length: 0))
        let son = ns.paragraphRange(for: NSRange(location: NSMaxRange(blok) - 1, length: 0))
        let kenar = (ust: NSLocationInRange(alt.location, ilk), alt: NSLocationInRange(alt.location, son))
        return kenar.ust || kenar.alt ? kenar : nil
    }

    private func etiketAdlari(_ o: Oznitelikler) -> [UnsafeMutablePointer<GtkTextTag>] {
        var adlar: [String] = []
        let blok = MetinBlogu(oznitelik: o[kMetinBloguAnahtari])
        let kod = o[kKodBloguAnahtari] != nil
        if let seviye = o[kBaslikSeviyesiAnahtari] as? Int, !kod, (1...3).contains(seviye) {
            adlar.append("baslik\(seviye)")
        } else if let oran = o[kPuntoOlcegiAnahtari] as? Double, oran != 1, oran.isFinite, oran > 0 {
            adlar.append(dinamik("olcek:\(oran)", [("scale", .ondalik(oran))]))
        }
        if (o[kKalinAnahtari] as? Bool) ?? (o[kBaslikSeviyesiAnahtari] != nil && !kod) { adlar.append("kalin") }
        if o[kItalikAnahtari] as? Bool == true { adlar.append("italik") }
        // Tamamlanan görevde işaret (☑) soluklaşmaz; yalnızca metin.
        let soluk = blok?.tur == .yapilacak && blok?.tamamlandi == true && o[kBlokIsaretiAnahtari] as? Bool != true
        if soluk { adlar.append("soluk") }
        if soluk || o[kUstuCiziliAnahtari] as? Bool == true { adlar.append("ustuCizili") }
        let satirIciKod = o[kSatirIciKodAnahtari] as? Bool == true
        let tablo = o[kTabloSatiriAnahtari] as? String
        if satirIciKod || kod || tablo != nil { adlar.append("mono") }
        if satirIciKod { adlar.append("kodArka") }
        if let tablo {
            adlar.append("tablo")
            adlar.append("tabloSarmaYok")
            if tablo == TabloSatiriTuru.baslik.rawValue { adlar.append("tabloBaslik") }
            if tablo == TabloSatiriTuru.govdeAlternatif.rawValue { adlar.append("tabloAlternatif") }
            if tablo == TabloSatiriTuru.cerceve.rawValue { adlar.append("tabloCerceve") }
        }
        if kod { adlar.append("kod-girinti") }
        if o[kVurguAnahtari] as? Bool == true { adlar.append("vurgu") }
        if o[kSayfaBagiAnahtari] != nil { adlar.append("sayfaBagi") }
        else if o[kBaglantiAnahtari] != nil { adlar.append("baglanti") }
        if blok?.tur == .ayirici { adlar.append("ayirici") }
        if let blok, blok.tur == .uyari {
            adlar.append(dinamik("uyari-girinti-\(blok.seviye)", [("left-margin", .tam(Int32(blok.seviye * 24 + 24))),
                ("indent", .tam(0)), ("pixels-above-lines", .tam(4)), ("pixels-below-lines", .tam(4))]))
        } else if !kod, let geometri = o[kParagrafGeometrisiAnahtari] as? [String: Any] {
            adlar.append(paragrafEtiketi(geometri))
        }
        return adlar.compactMap { etiketler[$0] }
    }

    /// Mac'teki NSParagraphStyle eşdeğeri. GTK'da negatif indent asılı girintidir:
    /// ilk satır sol kenarda, diğerleri |indent| kadar içeride; sekme durağı ilk satır başından ölçülür.
    private func paragrafEtiketi(_ g: [String: Any]) -> String {
        func deger(_ ad: String) -> Double { (g[ad] as? Double) ?? 0 }
        var govde = deger("govdeGirintisi")
        if let numara = g["numaraMetni"] as? String, !numara.isEmpty {
            // ponytail: Pango ölçümü yerine taban puntoda rakam genişliği tahmini.
            let isaret = max(deger("isaretEnAzGenisligi"), Double(numara.count) * Double(kTabanPunto) * 0.6 + deger("isaretSonuBoslugu"))
            govde += isaret - deger("isaretEnAzGenisligi")
        }
        let ilk = deger("ilkSatirGirintisi")
        let sol = Int32(min(ilk, govde)), girinti = Int32(ilk - govde)
        let sekme = Int32(govde > ilk ? govde - ilk : max(1, deger("sekmeAraligi")))
        let bosluk = Int32(deger("paragrafBoslugu"))
        let ad = "paragraf:\(sol):\(girinti):\(sekme):\(bosluk)"
        guard etiketler[ad] == nil else { return ad }
        let sekmeler = pango_tab_array_new(1, 1)!
        pango_tab_array_set_tab(sekmeler, 0, PANGO_TAB_LEFT, sekme)
        dinamik(ad, [("left-margin", .tam(sol)), ("indent", .tam(girinti)),
                     ("tabs", .kutu(pango_tab_array_get_type(), UnsafeRawPointer(sekmeler))),
                     ("pixels-above-lines", .tam(bosluk)), ("pixels-below-lines", .tam(bosluk))])
        pango_tab_array_free(sekmeler) // GValue kopyaladı.
        return ad
    }

    @discardableResult
    private func dinamik(_ ad: String, _ ozellikler: [(String, GDeger)]) -> String {
        if etiketler[ad] == nil { etiket(ad, ozellikler) }
        return ad
    }

    private func etiket(_ ad: String, _ ozellikler: [(String, GDeger)]) {
        let yeni = gtk_text_tag_new(ad)!
        for (ozellik, deger) in ozellikler {
            if ozellik == "left-margin", case .tam(let taban) = deger {
                solTabanlar[ad] = taban
                gNesneOzelligi(UnsafeMutableRawPointer(yeni), ozellik, .tam(taban + sayfaKenari))
            } else {
                gNesneOzelligi(UnsafeMutableRawPointer(yeni), ozellik, deger)
            }
        }
        gtk_text_tag_table_add(tablo, yeni)
        g_object_unref(UnsafeMutableRawPointer(yeni)) // Tablo sahiplendi.
        etiketler[ad] = yeni
        // Sonra eklenen etiket öncekini ezer; uyarı/paragraf etiketlerinin kendi pixels-above/below
        // değerleri kutu kenarı boşluğunu yutmasın diye kenar etiketleri hep en üstte tutulur.
        for kenar in [Self.kutuUstEtiketi, Self.kutuAltEtiketi] where kenar != ad {
            if let etiket = etiketler[kenar] { gtk_text_tag_set_priority(etiket, gtk_text_tag_table_get_size(tablo) - 1) }
        }
    }

    /// Editör sayfayı ortalarken görünümün sol kenar boşluğuyla birlikte çağırır.
    func sayfaKenariniAyarla(_ kenar: Int32) {
        guard kenar != sayfaKenari else { return }
        sayfaKenari = kenar
        for (ad, taban) in solTabanlar {
            if let etiket = etiketler[ad] { gNesneOzelligi(UnsafeMutableRawPointer(etiket), "left-margin", .tam(taban + kenar)) }
        }
    }

    // MARK: Görseller

    /// get_slice anchor'ı U+FFFC olarak verir; görünüm ve belge aynı konumları taşır.
    private func gorunumMetni(_ anlamsal: NSAttributedString) -> String {
        anlamsal.string
    }

    private func metniEkle(_ anlamsal: NSAttributedString, konuma iter: inout GtkTextIter) {
        let ns = anlamsal.string as NSString
        var bas = 0
        anlamsal.enumerateAttribute(kGorselAnahtari, in: NSRange(location: 0, length: ns.length)) { deger, alt, _ in
            guard let gorsel = deger as? [String: Any] else { return }
            for konum in alt.location..<NSMaxRange(alt) where ns.character(at: konum) == 0xFFFC {
                gtk_text_buffer_insert(tampon, &iter, ns.substring(with: NSRange(location: bas, length: konum - bas)), -1)
                let anchor = gtk_text_buffer_create_child_anchor(tampon, &iter)!
                LinuxGorseller.anchorEklendi(tampon, anchor: anchor, gorsel: gorsel)
                bas = konum + 1
            }
        }
        gtk_text_buffer_insert(tampon, &iter, ns.substring(from: bas), -1)
    }
}
