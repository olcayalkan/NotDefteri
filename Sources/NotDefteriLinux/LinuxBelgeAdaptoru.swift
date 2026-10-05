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
    private(set) var belge = NSMutableAttributedString()
    /// Belgeyi kendimiz değiştirirken tampon sinyalleri aynalanmaz.
    private(set) var programatik = false
    private let tampon: UnsafeMutablePointer<GtkTextBuffer>
    private let tablo: OpaquePointer
    private var etiketler: [String: UnsafeMutablePointer<GtkTextTag>] = [:]
    private var bekleyen: NSRange?

    // Mac'teki system renkleri, 0.14 saydamlıkla (uyarı kutusu).
    private static let uyariRenkleri = ["mavi": "0,122,255", "sarı": "255,204,0", "kırmızı": "255,59,48",
                                       "yeşil": "52,199,89", "gri": "142,142,147"]

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
        etiket("kodBlogu", [("paragraph-background", .metin("rgba(0,0,0,0.08)"))])
        etiket("vurgu", [("background", .metin("rgba(255,204,0,0.3)"))])
        etiket("baglanti", [("foreground", .metin("#2a6fdb")),
                            ("underline", .sayim(pango_underline_get_type(), Int32(PANGO_UNDERLINE_SINGLE.rawValue)))])
        // Ayırıcı: Mac'teki ince yatay çizginin karşılığı; ince, tam genişlikte paragraf arka planı.
        etiket("ayirici", [("scale", .ondalik(0.2)), ("paragraph-background", .metin("rgba(128,128,128,0.45)"))])
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
        let kapsam = ns.paragraphRange(for: NSRange(location: konum, length: min(aralik.length, ns.length - konum)))
        guard kapsam.length > 0 else { return }
        var (bas, son) = GtkKoprusu.iterler(tampon, kapsam, metin: ns)
        // Yalnızca adaptörün etiketlerini temizle; kod-/uyari-/katla- sahipleri korunur.
        for etiket in etiketler.values { gtk_text_buffer_remove_tag(tampon, etiket, &bas, &son) }
        var iter = bas
        belge.enumerateAttributes(in: kapsam) { o, alt, _ in
            var sonraki = iter
            gtk_text_iter_forward_chars(&sonraki, Int32(LinuxMetinDonusumu.karakterSayisi(ns, alt)))
            for ad in etiketAdlari(o, paragrafBasi: ns.paragraphRange(for: NSRange(location: alt.location, length: 0)).location) {
                gtk_text_buffer_apply_tag(tampon, ad, &iter, &sonraki)
            }
            iter = sonraki
        }
    }

    private func etiketAdlari(_ o: Oznitelikler, paragrafBasi: Int) -> [UnsafeMutablePointer<GtkTextTag>] {
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
        if satirIciKod || kod { adlar.append("mono") }
        if satirIciKod { adlar.append("kodArka") }
        if kod { adlar.append("kodBlogu") }
        if o[kVurguAnahtari] as? Bool == true { adlar.append("vurgu") }
        if o[kBaglantiAnahtari] != nil || o[kSayfaBagiAnahtari] != nil { adlar.append("baglanti") }
        if blok?.tur == .ayirici { adlar.append("ayirici") }
        if let blok, blok.tur == .uyari {
            let rgb = Self.uyariRenkleri[blok.renk] ?? Self.uyariRenkleri["gri"]!
            adlar.append(dinamik("uyari:\(rgb)", [("paragraph-background", .metin("rgba(\(rgb),0.14)"))]))
        }
        if let geometri = o[kParagrafGeometrisiAnahtari] as? [String: Any] {
            let gizliBas = blok?.tur == .uyari && blok?.devam == false && belge.mutableString.character(at: paragrafBasi) == 0x200B
            adlar.append(paragrafEtiketi(geometri, uyariBasiGizli: gizliBas))
        }
        return adlar.compactMap { etiketler[$0] }
    }

    /// Mac'teki NSParagraphStyle eşdeğeri. GTK'da negatif indent asılı girintidir:
    /// ilk satır sol kenarda, diğerleri |indent| kadar içeride; sekme durağı ilk satır başından ölçülür.
    private func paragrafEtiketi(_ g: [String: Any], uyariBasiGizli: Bool) -> String {
        func deger(_ ad: String) -> Double { (g[ad] as? Double) ?? 0 }
        var govde = deger("govdeGirintisi")
        if let numara = g["numaraMetni"] as? String, !numara.isEmpty {
            // ponytail: Pango ölçümü yerine taban puntoda rakam genişliği tahmini.
            let isaret = max(deger("isaretEnAzGenisligi"), Double(numara.count) * Double(kTabanPunto) * 0.6 + deger("isaretSonuBoslugu"))
            govde += isaret - deger("isaretEnAzGenisligi")
        }
        let ilk = uyariBasiGizli ? govde : deger("ilkSatirGirintisi")
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
        for (ozellik, deger) in ozellikler { gNesneOzelligi(UnsafeMutableRawPointer(yeni), ozellik, deger) }
        gtk_text_tag_table_add(tablo, yeni)
        g_object_unref(UnsafeMutableRawPointer(yeni)) // Tablo sahiplendi.
        etiketler[ad] = yeni
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
