import CGtk
import Foundation
import NotDefteriCekirdek

private final class KatlamaSinyali {
    weak var hedef: LinuxKatlama?
    init(_ hedef: LinuxKatlama) { self.hedef = hedef }
}

private func katlamaHedefi(_ veri: gpointer?) -> LinuxKatlama? {
    veri.flatMap { Unmanaged<KatlamaSinyali>.fromOpaque($0).takeUnretainedValue().hedef }
}

private let katlamaEkleC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextIter>?, UnsafePointer<CChar>?, Int32, gpointer?) -> Void = {
    _, iter, _, _, veri in
    if let iter { katlamaHedefi(veri)?.degisecek(iter.pointee, iter.pointee) }
}
private let katlamaSilC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextIter>?, UnsafeMutablePointer<GtkTextIter>?, gpointer?) -> Void = {
    _, bas, son, veri in
    if let bas, let son { katlamaHedefi(veri)?.degisecek(bas.pointee, son.pointee) }
}
private let katlamaSecimC: @convention(c) (gpointer?, gpointer?, UnsafeMutablePointer<GtkTextMark>?, gpointer?) -> Void = {
    _, _, mark, veri in
    guard let mark, let ad = gtk_text_mark_get_name(mark), ["insert", "selection_bound"].contains(String(cString: ad)) else { return }
    katlamaHedefi(veri)?.secimiAc()
}
private let katlamaEtiketC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextTag>?, UnsafeMutablePointer<GtkTextIter>?, UnsafeMutablePointer<GtkTextIter>?, gpointer?) -> Void = {
    _, tag, bas, son, veri in
    guard let tag, let bas, let son, let hedef = katlamaHedefi(veri), tag == hedef.aramaEtiketi else { return }
    hedef.araligiAc(bas.pointee, son.pointee)
}
private let katlamaFareC: @convention(c) (gpointer?, Double, Double, gpointer?) -> Void = {
    _, x, y, veri in katlamaHedefi(veri)?.fareyiAyarla(x, y)
}
private let katlamaCikisC: @convention(c) (gpointer?, gpointer?) -> Void = {
    _, veri in katlamaHedefi(veri)?.fareyiAyarla(nil, nil)
}

/// Metin ve anlamsal belgeye dokunmaz; katlama yalnızca görünüm etiketi ve overlay'dir.
final class LinuxKatlama {
    private final class Baslik {
        let bas: UnsafeMutablePointer<GtkTextMark>
        let govde: UnsafeMutablePointer<GtkTextMark>
        let metin: String
        let seviye: Int
        var son: UnsafeMutablePointer<GtkTextMark>?
        var katli: Bool
        init(bas: UnsafeMutablePointer<GtkTextMark>, govde: UnsafeMutablePointer<GtkTextMark>,
             metin: String, seviye: Int, katli: Bool) {
            self.bas = bas; self.govde = govde; self.metin = metin; self.seviye = seviye; self.katli = katli
        }
    }
    private final class Isaret {
        let dugme = gtk_button_new()!
        let nokta = gtk_label_new("…")!
        weak var baslik: Baslik?
    }
    private weak var editor: LinuxEditor?
    private let tampon: UnsafeMutablePointer<GtkTextBuffer>
    private let gorunum: UnsafeMutablePointer<GtkTextView>
    private let gizli: UnsafeMutablePointer<GtkTextTag>
    fileprivate let aramaEtiketi: UnsafeMutablePointer<GtkTextTag>?
    private var basliklar: [Baslik] = []
    private var isaretler: [Isaret] = []
    private var kirliBas: UnsafeMutablePointer<GtkTextMark>?
    private var kirliSon: UnsafeMutablePointer<GtkTextMark>?
    private var degisenKatlilar: [Baslik] = []
    private var metinIslemiBekliyor = false
    private var iptal: ZamanlayiciIptal?
    private var nesil = 0
    private var url: URL?
    private var yol: String?
    private var fare: (Int32, Int32)?
    private var cizimGerekli = true
    private var sonKare = GdkRectangle()
    private var gorunumDegisiyor = false
    private var panoNesli = 0
    private static var sayfalar: [String: [String]] = [:]

    static func kur(pencere: LinuxPencere, editor: LinuxEditor) {
        let katlama = LinuxKatlama(editor)
        let veri = Unmanaged.passRetained(katlama).toOpaque()
        g_object_set_data_full(UnsafeMutableRawPointer(editor.metinGorunumu).assumingMemoryBound(to: GObject.self),
                               "nd-katlama", veri, { veri in
            if let veri { Unmanaged<LinuxKatlama>.fromOpaque(veri).release() }
        })
    }

    private init(_ editor: LinuxEditor) {
        self.editor = editor
        tampon = editor.tampon
        gorunum = UnsafeMutableRawPointer(editor.metinGorunumu).assumingMemoryBound(to: GtkTextView.self)
        gizli = gtk_text_tag_new("katla-gizli")!
        let tablo = gtk_text_buffer_get_tag_table(tampon)!
        gtk_text_tag_table_add(tablo, gizli)
        g_object_unref(UnsafeMutableRawPointer(gizli))
        gNesneOzelligi(UnsafeMutableRawPointer(gizli), "invisible", .mantik(true))
        aramaEtiketi = gtk_text_tag_table_lookup(tablo, "nd-bul-eslesmesi")
        kancalariBagla(editor)
        sayfayiAc()
    }

    deinit { iptal?() }

    private func bagla(_ nesne: gpointer, _ ad: String, _ callback: GCallback) {
        let veri = Unmanaged.passRetained(KatlamaSinyali(self)).toOpaque()
        g_signal_connect_data(nesne, ad, callback, veri, { veri, _ in
            if let veri { Unmanaged<KatlamaSinyali>.fromOpaque(veri).release() }
        }, GConnectFlags(rawValue: 0))
    }

    private func kancalariBagla(_ editor: LinuxEditor) {
        let buffer = UnsafeMutableRawPointer(tampon)
        bagla(buffer, "insert-text", unsafeBitCast(katlamaEkleC, to: GCallback.self))
        bagla(buffer, "delete-range", unsafeBitCast(katlamaSilC, to: GCallback.self))
        bagla(buffer, "mark-set", unsafeBitCast(katlamaSecimC, to: GCallback.self))
        bagla(buffer, "apply-tag", unsafeBitCast(katlamaEtiketC, to: GCallback.self))
        GtkKoprusu.sinyalBagla(buffer, "changed") { [weak self] in
            self?.panoNesli += 1
            self?.cizimGerekli = true
        }
        editor.notAcildi.append { [weak self] _ in self?.sayfayiAc() }
        editor.degisiklikSonrasi.append { [weak self] in self?.degisiklikBitti() }
        editor.tusOncesi.append { [weak self] tus, durum in self?.tus(tus, durum) ?? false }
        editor.yapistirmaOncesi.append { [weak self] pano in self?.yapistir(pano, kaynak: false) ?? false }
        let hareket = gtk_event_controller_motion_new()!
        bagla(UnsafeMutableRawPointer(hareket), "motion", unsafeBitCast(katlamaFareC, to: GCallback.self))
        bagla(UnsafeMutableRawPointer(hareket), "leave", unsafeBitCast(katlamaCikisC, to: GCallback.self))
        gtk_widget_add_controller(editor.metinGorunumu, hareket)
        let veri = Unmanaged.passRetained(KatlamaSinyali(self)).toOpaque()
        gtk_widget_add_tick_callback(editor.metinGorunumu, { _, _, veri in
            katlamaHedefi(veri)?.isaretleriYerlestir()
            return 1
        }, veri, { veri in
            if let veri { Unmanaged<KatlamaSinyali>.fromOpaque(veri).release() }
        })
    }

    private func iter(_ mark: UnsafeMutablePointer<GtkTextMark>) -> GtkTextIter {
        var iter = GtkTextIter()
        gtk_text_buffer_get_iter_at_mark(tampon, &iter, mark)
        return iter
    }

    private func konum(_ mark: UnsafeMutablePointer<GtkTextMark>) -> Int32 {
        var i = iter(mark)
        return gtk_text_iter_get_offset(&i)
    }

    private func bolum(_ baslik: Baslik) -> (GtkTextIter, GtkTextIter) {
        let bas = iter(baslik.govde)
        var son = GtkTextIter()
        if let mark = baslik.son { son = iter(mark) }
        else { gtk_text_buffer_get_end_iter(tampon, &son) }
        return (bas, son)
    }

    private func anahtarlar() -> [String] {
        var adetler: [String: Int] = [:]
        return basliklar.map {
            let temel = "\($0.seviye):\($0.metin.utf8.count):\($0.metin)"
            let adet = adetler[temel, default: 0]
            adetler[temel] = adet + 1
            return "\(temel):\(adet)"
        }
    }

    private func sakla() {
        guard let yol else { return }
        let anahtarlar = anahtarlar()
        let katlilar = basliklar.indices.filter { basliklar[$0].katli }.map { anahtarlar[$0] }
        Self.sayfalar[yol] = katlilar
        UserDefaults.standard.set(katlilar, forKey: "baslikKatlama." + yol)
    }

    private func sayfayiAc() {
        sakla()
        nesil += 1; panoNesli += 1
        iptal?(); iptal = nil
        kirliyiSil()
        degisenKatlilar.removeAll()
        metinIslemiBekliyor = false
        for baslik in basliklar { basligiSil(baslik) }
        basliklar.removeAll()
        for isaret in isaretler { gtk_widget_set_visible(isaret.dugme, 0); gtk_widget_set_visible(isaret.nokta, 0) }
        fare = nil
        url = editor?.acikURL
        // Standartlaştırma yanında symlink de çözülür; kök dışı yol kalıcı anahtar olamaz.
        let kok = notlarKlasoru().standardizedFileURL.resolvingSymlinksInPath().path + "/"
        yol = url.flatMap {
            let tam = $0.standardizedFileURL.resolvingSymlinksInPath().path
            return tam.hasPrefix(kok) ? String(tam.dropFirst(kok.count)) : nil
        }
        let yuklenecek = Set(yol.map { Self.sayfalar[$0] ?? UserDefaults.standard.stringArray(forKey: "baslikKatlama." + $0) ?? [] } ?? [])
        editor?.belgeyiOku { belge in basliklariOku(belge, NSRange(location: 0, length: belge.length)) }
        let anahtarlar = anahtarlar()
        for sira in basliklar.indices { basliklar[sira].katli = yuklenecek.contains(anahtarlar[sira]) }
        bolumleriHesapla()
        gorunurluguUygula()
        secimiAc()
    }

    private func basligiSil(_ baslik: Baslik) {
        gtk_text_buffer_delete_mark(tampon, baslik.bas)
        gtk_text_buffer_delete_mark(tampon, baslik.govde)
    }

    private func kirliyiSil() {
        if let kirliBas { gtk_text_buffer_delete_mark(tampon, kirliBas) }
        if let kirliSon { gtk_text_buffer_delete_mark(tampon, kirliSon) }
        kirliBas = nil; kirliSon = nil
    }

    fileprivate func degisecek(_ bas: GtkTextIter, _ son: GtkTextIter) {
        // Yükleme de GTK'de silme/ekleme yayar. notAcildi gelmeden katlama
        // durumunu bozma; gerçek düzenlemeyi degisiklikSonrasi doğrular.
        degisenKatlilar.append(contentsOf: kesisenBasliklar(bas, son))
        metinIslemiBekliyor = true
        var b = bas, s = son
        gtk_text_iter_set_line_offset(&b, 0)
        gtk_text_iter_forward_to_line_end(&s)
        if gtk_text_iter_is_end(&s) == 0 { gtk_text_iter_forward_char(&s) }
        if let kirliBas {
            var onceki = iter(kirliBas)
            if gtk_text_iter_compare(&b, &onceki) < 0 { gtk_text_buffer_move_mark(tampon, kirliBas, &b) }
        } else { kirliBas = gtk_text_buffer_create_mark(tampon, nil, &b, 1) }
        if let kirliSon {
            var onceki = iter(kirliSon)
            if gtk_text_iter_compare(&s, &onceki) > 0 { gtk_text_buffer_move_mark(tampon, kirliSon, &s) }
        } else { kirliSon = gtk_text_buffer_create_mark(tampon, nil, &s, 0) }
    }

    private func degisiklikBitti() {
        guard editor?.acikURL == url else { sayfayiAc(); return }
        metinIslemiBekliyor = false
        if !degisenKatlilar.isEmpty {
            for baslik in degisenKatlilar { baslik.katli = false }
            degisenKatlilar.removeAll()
            gorunurluguUygula(); sakla()
        }
        secimiAc()
        guard kirliBas != nil else { return }
        nesil += 1
        let beklenen = nesil
        iptal?()
        iptal = Platform.zamanlayici(0.15) { [weak self] in
            guard let self, self.nesil == beklenen else { return }
            self.iptal = nil
            self.basliklariTazele()
        }
    }

    /// Düzenlemeden sonra yalnızca işaretlerle taşınan değişmiş paragraflar okunur.
    private func basliklariTazele() {
        guard let editor, editor.acikURL == url, let kirliBas, let kirliSon else { return }
        var b = iter(kirliBas), s = iter(kirliSon)
        gtk_text_iter_set_line_offset(&b, 0)
        if gtk_text_iter_get_line_offset(&s) != 0 {
            gtk_text_iter_forward_to_line_end(&s)
            if gtk_text_iter_is_end(&s) == 0 { gtk_text_iter_forward_char(&s) }
        }
        let alt = gtk_text_iter_get_offset(&b), ust = gtk_text_iter_get_offset(&s)
        let aralik = LinuxMetinDonusumu.aralik(b, s)
        var eskiler: [Int32: Baslik] = [:]
        basliklar.removeAll { baslik in
            let yer = konum(baslik.bas)
            guard yer >= alt && (yer < ust || yer == alt) else { return false }
            eskiler[yer] = baslik
            return true
        }
        editor.belgeyiOku { belge in basliklariOku(belge, aralik, eskiler: eskiler) }
        for eski in eskiler.values { basligiSil(eski) }
        basliklar.sort { konum($0.bas) < konum($1.bas) }
        kirliyiSil()
        bolumleriHesapla()
        gorunurluguUygula()
        secimiAc()
        sakla()
    }

    private func basliklariOku(_ belge: NSAttributedString, _ aralik: NSRange, eskiler: [Int32: Baslik] = [:]) {
        guard aralik.location <= belge.length, NSMaxRange(aralik) <= belge.length else { return }
        let ns = belge.string as NSString
        var yer = aralik.location
        var gtkIter = LinuxMetinDonusumu.iter(tampon, yer)
        while yer < NSMaxRange(aralik) {
            let paragraf = ns.paragraphRange(for: NSRange(location: yer, length: 0))
            guard paragraf.length > 0 else { break }
            var son = gtkIter
            gtk_text_iter_forward_chars(&son, Int32(LinuxMetinDonusumu.karakterSayisi(ns, paragraf)))
            if let seviye = belge.attribute(kBaslikSeviyesiAnahtari, at: yer, effectiveRange: nil) as? Int,
               (1...3).contains(seviye) {
                let metin = ns.substring(with: paragraf).replacingOccurrences(of: "\u{200B}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let eski = eskiler[gtk_text_iter_get_offset(&gtkIter)]
                let baslik = Baslik(bas: gtk_text_buffer_create_mark(tampon, nil, &gtkIter, 1)!,
                                    govde: gtk_text_buffer_create_mark(tampon, nil, &son, 1)!,
                                    metin: metin, seviye: seviye, katli: eski?.seviye == seviye && eski?.katli == true)
                if !metin.isEmpty { basliklar.append(baslik) } else { basligiSil(baslik) }
            }
            yer = NSMaxRange(paragraf)
            gtkIter = son
        }
    }

    private func bolumleriHesapla() {
        var acik: [Baslik] = []
        for baslik in basliklar {
            while let ust = acik.last, ust.seviye >= baslik.seviye { acik.removeLast().son = baslik.bas }
            acik.append(baslik)
        }
        for baslik in acik { baslik.son = nil }
    }

    private func gorunurluguUygula() {
        gorunumDegisiyor = true
        defer { gorunumDegisiyor = false }
        var bas = GtkTextIter(), son = GtkTextIter()
        gtk_text_buffer_get_bounds(tampon, &bas, &son)
        gtk_text_buffer_remove_tag(tampon, gizli, &bas, &son)
        for baslik in basliklar where baslik.katli {
            var (b, s) = bolum(baslik)
            if gtk_text_iter_compare(&b, &s) < 0 { gtk_text_buffer_apply_tag(tampon, gizli, &b, &s) }
        }
        cizimGerekli = true
    }

    fileprivate func araligiAc(_ bas: GtkTextIter, _ son: GtkTextIter) {
        guard !gorunumDegisiyor else { return }
        let hedefler = kesisenBasliklar(bas, son)
        guard !hedefler.isEmpty else { return }
        for baslik in hedefler { baslik.katli = false }
        gorunurluguUygula(); sakla()
    }

    private func kesisenBasliklar(_ bas: GtkTextIter, _ son: GtkTextIter) -> [Baslik] {
        var b = bas, s = son
        let alt = gtk_text_iter_get_offset(&b), ust = gtk_text_iter_get_offset(&s)
        let uzunluk = gtk_text_buffer_get_char_count(tampon)
        var hedefler: [Baslik] = []
        for baslik in basliklar where baslik.katli {
            var (bb, ss) = bolum(baslik)
            let bolumBas = gtk_text_iter_get_offset(&bb), bolumSon = gtk_text_iter_get_offset(&ss)
            guard bolumSon > bolumBas else { continue }
            let iceride = alt == ust ? alt >= bolumBas && (alt < bolumSon || alt == uzunluk && bolumSon == uzunluk)
                : alt < bolumSon && ust > bolumBas
            if iceride { hedefler.append(baslik) }
        }
        return hedefler
    }

    fileprivate func secimiAc() {
        guard !metinIslemiBekliyor else { return }
        var b = GtkTextIter(), s = GtkTextIter()
        gtk_text_buffer_get_selection_bounds(tampon, &b, &s)
        araligiAc(b, s)
    }

    private func degistir(_ katla: Bool, _ hedefler: [Baslik]) {
        var secimBas = GtkTextIter(), secimSon = GtkTextIter()
        gtk_text_buffer_get_selection_bounds(tampon, &secimBas, &secimSon)
        let alt = gtk_text_iter_get_offset(&secimBas), ust = gtk_text_iter_get_offset(&secimSon)
        for baslik in hedefler {
            var (b, s) = bolum(baslik)
            let bolumBas = gtk_text_iter_get_offset(&b), bolumSon = gtk_text_iter_get_offset(&s)
            guard bolumSon > bolumBas else { continue }
            if katla, (alt == ust ? alt >= bolumBas && alt <= bolumSon : alt < bolumSon && ust > bolumBas) {
                var bas = iter(baslik.bas)
                gtk_text_buffer_place_cursor(tampon, &bas)
            }
            baslik.katli = katla
        }
        gorunurluguUygula(); sakla()
    }

    private func tus(_ tus: UInt32, _ durum: UInt32) -> Bool {
        guard let editor, editor.acikURL != nil, gtk_text_view_get_editable(gorunum) != 0 else { return false }
        let mask = durum & (GDK_CONTROL_MASK.rawValue | GDK_ALT_MASK.rawValue | GDK_SHIFT_MASK.rawValue | GDK_SUPER_MASK.rawValue)
        if mask == GDK_CONTROL_MASK.rawValue | GDK_SHIFT_MASK.rawValue, tus == 0x76 || tus == 0x56,
           let pano = gtk_widget_get_clipboard(editor.metinGorunumu) {
            return yapistir(pano, kaynak: true)
        }
        if tus == 0xff0d || tus == 0xff8d {
            var imlec = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(tampon, &imlec, gtk_text_buffer_get_insert(tampon))
            if gtk_text_iter_ends_line(&imlec) != 0,
               let baslik = basliklar.last(where: { konum($0.bas) <= gtk_text_iter_get_offset(&imlec) }), baslik.katli {
                var govde = iter(baslik.govde)
                if gtk_text_iter_get_line(&imlec) + 1 == gtk_text_iter_get_line(&govde) { degistir(false, [baslik]) }
            }
        }
        guard mask & ~GDK_SHIFT_MASK.rawValue == GDK_CONTROL_MASK.rawValue | GDK_ALT_MASK.rawValue,
              [0x5b, 0x5d, 0x7b, 0x7d].contains(tus) else { return false }
        if kirliBas != nil { iptal?(); iptal = nil; basliklariTazele() }
        var imlec = GtkTextIter()
        gtk_text_buffer_get_iter_at_mark(tampon, &imlec, gtk_text_buffer_get_insert(tampon))
        let hedef = basliklar.last { konum($0.bas) <= gtk_text_iter_get_offset(&imlec) }
        degistir(tus == 0x5b || tus == 0x7b, mask & GDK_SHIFT_MASK.rawValue != 0 ? basliklar : hedef.map { [$0] } ?? [])
        return true
    }

    fileprivate func fareyiAyarla(_ x: Double?, _ y: Double?) {
        if let x, let y {
            var bx: Int32 = 0, by: Int32 = 0
            gtk_text_view_window_to_buffer_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, Int32(x), Int32(y), &bx, &by)
            fare = (bx, by)
        } else { fare = nil }
        cizimGerekli = true
    }

    private func isaretUret() -> Isaret {
        let isaret = Isaret()
        gtk_widget_add_css_class(isaret.dugme, "flat")
        gtk_widget_add_css_class(isaret.dugme, "dim-label")
        gtk_widget_set_focusable(isaret.dugme, 0)
        gtk_widget_set_size_request(isaret.dugme, 22, -1)
        gtk_widget_set_tooltip_text(isaret.dugme, "Bölümü katla / aç (Ctrl+Alt+[ / ])")
        gtk_widget_add_css_class(isaret.nokta, "dim-label")
        gtk_widget_set_can_target(isaret.nokta, 0)
        gtk_text_view_add_overlay(gorunum, isaret.dugme, 0, 0)
        gtk_text_view_add_overlay(gorunum, isaret.nokta, 0, 0)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(isaret.dugme), "clicked") { [weak self, weak isaret] in
            guard let self, let baslik = isaret?.baslik else { return }
            self.degistir(!baslik.katli, [baslik])
        }
        isaretler.append(isaret)
        return isaret
    }

    /// Yalnızca görünür başlıklar için overlay; konumlar buffer koordinatıdır.
    private func isaretleriYerlestir() {
        var kare = GdkRectangle()
        gtk_text_view_get_visible_rect(gorunum, &kare)
        guard cizimGerekli || kare.x != sonKare.x || kare.y != sonKare.y || kare.width != sonKare.width || kare.height != sonKare.height else { return }
        cizimGerekli = false; sonKare = kare
        var ilk = GtkTextIter(), son = GtkTextIter()
        gtk_text_view_get_iter_at_location(gorunum, &ilk, kare.x, kare.y)
        gtk_text_view_get_iter_at_location(gorunum, &son, kare.x + kare.width, kare.y + kare.height)
        let alt = gtk_text_iter_get_offset(&ilk), ust = gtk_text_iter_get_offset(&son)
        var sol = 0, sag = basliklar.count
        while sol < sag {
            let orta = (sol + sag) / 2
            if konum(basliklar[orta].govde) < alt { sol = orta + 1 } else { sag = orta }
        }
        var kullanilan = 0
        for baslik in basliklar.dropFirst(sol) {
            var bas = iter(baslik.bas)
            if gtk_text_iter_get_offset(&bas) > ust { break }
            if gtk_text_iter_has_tag(&bas, gizli) != 0 { continue }
            var (b, s) = bolum(baslik)
            if gtk_text_iter_compare(&b, &s) >= 0 { continue }
            var yer = GdkRectangle()
            gtk_text_view_get_iter_location(gorunum, &bas, &yer)
            let isaret = kullanilan < isaretler.count ? isaretler[kullanilan] : isaretUret()
            kullanilan += 1; isaret.baslik = baslik
            let uzerinde = fare.map { $0.0 >= yer.x - 24 && $0.0 <= kare.x + kare.width && $0.1 >= yer.y && $0.1 < yer.y + yer.height } ?? false
            gtk_button_set_label(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(isaret.dugme)),baslik.katli ? "▸" : "▾")
            gtk_text_view_move_overlay(gorunum, isaret.dugme, yer.x - 24, yer.y)
            gtk_widget_set_visible(isaret.dugme, uzerinde ? 1 : 0)
            // Başlık sonundaki boşlukları atla; metne gerçek üç nokta eklenmez.
            var bitis = bas
            gtk_text_iter_forward_to_line_end(&bitis)
            while gtk_text_iter_compare(&bitis, &bas) > 0 {
                var once = bitis
                gtk_text_iter_backward_char(&once)
                if !CharacterSet.whitespaces.contains(UnicodeScalar(gtk_text_iter_get_char(&once)) ?? " ") { break }
                bitis = once
            }
            var sonYer = GdkRectangle()
            gtk_text_view_get_iter_location(gorunum, &bitis, &sonYer)
            gtk_text_view_move_overlay(gorunum, isaret.nokta, min(sonYer.x + 5, kare.x + kare.width - 16), sonYer.y)
            gtk_widget_set_visible(isaret.nokta, baslik.katli ? 1 : 0)
        }
        for isaret in isaretler.dropFirst(kullanilan) {
            isaret.baslik = nil
            gtk_widget_set_visible(isaret.dugme, 0); gtk_widget_set_visible(isaret.nokta, 0)
        }
    }
}

private extension LinuxKatlama {
    func yapistir(_ pano: OpaquePointer, kaynak: Bool) -> Bool {
        guard let editor, let url = editor.acikURL, gtk_text_view_get_editable(gorunum) != 0 else { return false }
        let bicimler = gdk_clipboard_get_formats(pano)
        let html = gdk_content_formats_contain_mime_type(bicimler, "text/html") != 0
        let metin = gdk_content_formats_contain_gtype(bicimler, g_type_from_name("gchararray")) != 0
            || gdk_content_formats_contain_mime_type(bicimler, "text/plain") != 0
            || gdk_content_formats_contain_mime_type(bicimler, "text/plain;charset=utf-8") != 0
        guard html || metin else { return false } // 053'ün görsel kancası kendi pano türünü işler.
        let aralik = LinuxMetinDonusumu.secim(tampon)
        let oznitelikler = editor.belgeyiOku { belge -> Oznitelikler in
            guard belge.length > 0 else { return [:] }
            return belge.attributes(at: min(aralik.location, belge.length - 1), effectiveRange: nil)
        }
        let kod = oznitelikler[kKodBloguAnahtari] != nil || oznitelikler[kSatirIciKodAnahtari] != nil
        let beklenen = panoNesli
        let okuma = PanoOkumasi(pano: pano) { [weak self, weak editor] sonuc in
            guard let self, let editor, editor.acikURL == url, self.panoNesli == beklenen,
                  gtk_text_view_get_editable(self.gorunum) != 0,
                  LinuxMetinDonusumu.secim(self.tampon) == aralik else { return }
            guard let (yazi, htmlMi) = sonuc else { gtk_widget_error_bell(editor.metinGorunumu); return }
            let gelen: NSAttributedString
            if kod { gelen = NSAttributedString(string: yazi, attributes: oznitelikler) }
            else if htmlMi { gelen = LinuxPanoHTML.cevir(yazi, kaynak: kaynak) }
            else if kaynak { gelen = NSAttributedString(string: yazi) }
            else { gelen = disMetniNotBicimineCevir(yazi, taban: sayfaKlasoru(url)) }
            let guvenli = NSMutableAttributedString(attributedString: gelen)
            // Markdown pano yolu da HTML ile aynı URL güvenlik sınırından geçer.
            guvenli.enumerateAttribute(kBaglantiAnahtari, in: NSRange(location: 0, length: guvenli.length)) { deger, alt, _ in
                if deger != nil, let bag = deger as? URL, ["http", "https", "mailto"].contains(bag.scheme?.lowercased() ?? "") { return }
                guvenli.removeAttribute(kBaglantiAnahtari, range: alt)
            }
            if guvenli.length > 0 { editor.aralikDegistir(aralik, ile: guvenli) }
        }
        okuma.baslat(html: html && !kod)
        return true
    }
}

/// Pano akışı ana thread'i bekletmeden, sınırlı parçalarla okunur. Her async çağrı
/// kendi retained verisini callback'te bırakır; sinyal closure'ları destroy_data kullanır.
private final class PanoOkumasi {
    private let pano: OpaquePointer
    private var akim: UnsafeMutablePointer<GInputStream>?
    private var veri = Data()
    private let tamamla: ((String, Bool)?) -> Void
    private static let sinir = 16 * 1024 * 1024

    init(pano: OpaquePointer, tamamla: @escaping ((String, Bool)?) -> Void) {
        self.pano = pano; self.tamamla = tamamla
        g_object_ref(UnsafeMutableRawPointer(pano))
    }
    deinit {
        if let akim { g_object_unref(UnsafeMutableRawPointer(akim)) }
        g_object_unref(UnsafeMutableRawPointer(pano))
    }

    func baslat(html: Bool) {
        guard html else { duzMetniOku(); return }
        "text/html".withCString { mime in
            var tipler: [UnsafePointer<CChar>?] = [mime, nil]
            tipler.withUnsafeMutableBufferPointer { turler in
                gdk_clipboard_read_async(pano, turler.baseAddress, G_PRIORITY_DEFAULT, nil, { _, sonuc, veri in
                    guard let veri else { return }
                    let istek = Unmanaged<PanoOkumasi>.fromOpaque(veri).takeRetainedValue()
                    var hata: UnsafeMutablePointer<GError>?
                    istek.akim = gdk_clipboard_read_finish(istek.pano, sonuc, nil, &hata)
                    if let hata { istek.hatayiYaz(hata) }
                    if istek.akim != nil { istek.parcaOku() } else { istek.duzMetniOku() }
                }, Unmanaged.passRetained(self).toOpaque())
            }
        }
    }

    private func duzMetniOku() {
        gdk_clipboard_read_text_async(pano, nil, { _, sonuc, veri in
            guard let veri else { return }
            let istek = Unmanaged<PanoOkumasi>.fromOpaque(veri).takeRetainedValue()
            var hata: UnsafeMutablePointer<GError>?
            let metin = gdk_clipboard_read_text_finish(istek.pano, sonuc, &hata)
            if let hata { istek.hatayiYaz(hata) }
            guard let metin else { istek.tamamla(nil); return }
            defer { g_free(metin) }
            let yazi = String(cString: metin)
            guard yazi.utf8.count <= PanoOkumasi.sinir else { istek.sinirAsildi(); return }
            istek.tamamla((yazi, false))
        }, Unmanaged.passRetained(self).toOpaque())
    }

    private func parcaOku() {
        guard let akim else { return }
        g_input_stream_read_bytes_async(akim, 64 * 1024, G_PRIORITY_DEFAULT, nil, { _, sonuc, veri in
            guard let veri else { return }
            let istek = Unmanaged<PanoOkumasi>.fromOpaque(veri).takeRetainedValue()
            guard let akim = istek.akim else { return }
            var hata: UnsafeMutablePointer<GError>?
            let parca = g_input_stream_read_bytes_finish(akim, sonuc, &hata)
            if let hata { istek.hatayiYaz(hata) }
            guard let parca else { istek.tamamla(nil); return }
            defer { g_bytes_unref(parca) }
            var uzunluk = 0
            let baytlar = g_bytes_get_data(parca, &uzunluk)
            guard uzunluk > 0 else {
                let kodlama: String.Encoding = istek.veri.starts(with: [0xff, 0xfe]) || istek.veri.starts(with: [0xfe, 0xff]) ? .utf16 : .utf8
                guard let html = String(data: istek.veri, encoding: kodlama) else {
                    FileHandle.standardError.write(Data("[NotDefteri] HTML pano metni çözülemedi.\n".utf8))
                    istek.tamamla(nil); return
                }
                istek.tamamla((html, true)); return
            }
            guard uzunluk <= PanoOkumasi.sinir - istek.veri.count else { istek.sinirAsildi(); return }
            if let baytlar { istek.veri.append(baytlar.assumingMemoryBound(to: UInt8.self), count: uzunluk) }
            istek.parcaOku()
        }, Unmanaged.passRetained(self).toOpaque())
    }

    private func hatayiYaz(_ hata: UnsafeMutablePointer<GError>) {
        FileHandle.standardError.write(Data("[NotDefteri] Pano okunamadı: \(String(cString: hata.pointee.message))\n".utf8))
        g_error_free(hata)
    }
    private func sinirAsildi() {
        FileHandle.standardError.write(Data("[NotDefteri] Pano 16 MiB sınırını aştı.\n".utf8))
        tamamla(nil)
    }
}

/// HTML'nin notta karşılığı olan etiketlerini okur; kaynak çalıştırılmaz, URL/görsel
/// indirilmez. Bozuk kapanışlar en yakın açık etikette toparlanır.
private final class LinuxPanoHTML {
    private struct Cerceve { let ad: String; let onceki: Oznitelikler }
    private struct Liste { let ad: String; var numara: Int }
    private let sonuc = NSMutableAttributedString(string: "")
    private var oznitelikler: Oznitelikler = [:]
    private var yigin: [Cerceve] = []
    private var listeler: [Liste] = []
    private var gizlenen: [String] = []
    private static let bloklar: Set<String> = ["p", "div", "section", "article", "blockquote", "li", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "tr"]
    private static let atilanlar: Set<String> = ["script", "style", "head", "template", "svg", "iframe", "object"]
    private static let token = try! NSRegularExpression(pattern: #"(?s)<!--.*?-->|<![^>]*>|<\s*/?\s*[A-Za-z][A-Za-z0-9:-]*(?:[^>\"']|\"[^\"]*\"|'[^']*')*>|[^<]+|<"#)
    private static let ozellik = try! NSRegularExpression(pattern: #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#)
    private static let varlik = try! NSRegularExpression(pattern: #"&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|[A-Za-z][A-Za-z0-9]+);"#)

    static func cevir(_ html: String, kaynak: Bool) -> NSAttributedString {
        let parser = LinuxPanoHTML()
        let ns = html as NSString
        token.enumerateMatches(in: html, range: NSRange(location: 0, length: ns.length)) { eslesme, _, _ in
            if let eslesme { parser.isle(ns.substring(with: eslesme.range)) }
        }
        parser.sadelestir()
        // Çekirdeğin başlık tahmini ve dış içerik normalleştirmesi ortak kalır.
        let sade = kaynak ? NSMutableAttributedString(attributedString: parser.sonuc)
            : NSMutableAttributedString(attributedString: disIcerigiNotBicimineCevir(parser.sonuc))
        if !kaynak {
            parser.sonuc.enumerateAttributes(in: NSRange(location: 0, length: parser.sonuc.length)) { o, alt, _ in
                for anahtar in [kBaslikSeviyesiAnahtari, kItalikAnahtari, kBaglantiAnahtari, kMetinBloguAnahtari, kParagrafGeometrisiAnahtari] {
                    if let deger = o[anahtar] { sade.addAttribute(anahtar, value: deger, range: alt) }
                }
            }
        }
        var eklemeler: [(Int, MetinBlogu)] = []
        let metin = sade.string as NSString
        var konum = 0
        while konum < sade.length {
            let paragraf = metin.paragraphRange(for: NSRange(location: konum, length: 0))
            if let blok = MetinBlogu(oznitelik: sade.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil)) {
                sade.removeAttribute(kBaslikSeviyesiAnahtari, range: paragraf)
                eklemeler.append((konum, blok))
            }
            konum = NSMaxRange(paragraf)
        }
        for (konum, blok) in eklemeler.reversed() { sade.insert(blokIsaretiniUret(blok), at: konum) }
        return sade
    }

    private func isle(_ parca: String) {
        guard parca.hasPrefix("<"), parca != "<" else { if gizlenen.isEmpty { metinEkle(parca) }; return }
        if parca.hasPrefix("<!") { return }
        let kapanis = parca.dropFirst().trimmingCharacters(in: .whitespaces).hasPrefix("/")
        let govde = parca.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        let ad = govde.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).prefix { $0.isLetter || $0.isNumber || $0 == ":" || $0 == "-" }.lowercased()
        if !gizlenen.isEmpty {
            if kapanis, ad == gizlenen.last { gizlenen.removeLast() }
            else if !kapanis, Self.atilanlar.contains(ad) { gizlenen.append(ad) }
            return
        }
        if Self.atilanlar.contains(ad) { if !kapanis { gizlenen.append(ad) }; return }
        if ad == "img" || ad == "meta" || ad == "link" || ad == "input" { return }
        if ad == "br" { yeniSatir(zorla: true); return }
        if kapanis { kapat(ad); return }
        let o = Self.ozellikleriOku(parca)
        if Self.bloklar.contains(ad) { yeniSatir() }
        // HTML'de </li> ve </p> isteğe bağlıdır.
        if (ad == "li" || ad == "p"), yigin.last?.ad == ad { kapat(ad) }
        yigin.append(Cerceve(ad: ad, onceki: oznitelikler))
        if ad == "ul" || ad == "ol" {
            yeniSatir()
            listeler.append(Liste(ad: ad, numara: max(1, Int(o["start"] ?? "1") ?? 1)))
            oznitelikler.removeValue(forKey: kMetinBloguAnahtari)
            oznitelikler.removeValue(forKey: kParagrafGeometrisiAnahtari)
        }
        if ad.count == 2, ad.first == "h", let duzey = Int(ad.dropFirst()), (1...6).contains(duzey) {
            oznitelikler[kBaslikSeviyesiAnahtari] = min(duzey, 3)
            oznitelikler[kKalinAnahtari] = true
        }
        if ad == "b" || ad == "strong" { oznitelikler[kKalinAnahtari] = true }
        if ad == "i" || ad == "em" { oznitelikler[kItalikAnahtari] = true }
        if ad == "a", let metin = o["href"], let url = URL(string: metin), ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            oznitelikler[kBaglantiAnahtari] = url
        }
        if ad == "li", var liste = listeler.last {
            if let deger = o["value"].flatMap(Int.init), deger > 0 { liste.numara = deger }
            let blok = MetinBlogu(tur: liste.ad == "ol" ? .numarali : .madde, seviye: max(0, listeler.count - 1), numara: liste.numara)
            oznitelikler.merge(blok.oznitelikler) { _, yeni in yeni }
            listeler[listeler.count - 1].numara = liste.numara == Int.max ? 1 : liste.numara + 1
        }
        stilUygula(o["style"] ?? "")
        if parca.hasSuffix("/>") { kapat(ad) }
    }

    private func kapat(_ ad: String) {
        guard let sira = yigin.lastIndex(where: { $0.ad == ad }) else { return }
        if Self.bloklar.contains(ad) || ad == "ul" || ad == "ol" { yeniSatir() }
        for cerceve in yigin[sira...] where cerceve.ad == "ul" || cerceve.ad == "ol" {
            if listeler.last?.ad == cerceve.ad { listeler.removeLast() }
        }
        oznitelikler = yigin[sira].onceki
        yigin.removeSubrange(sira...)
    }

    private func yeniSatir(zorla: Bool = false) {
        if zorla || sonuc.length > 0 && !sonuc.string.hasSuffix("\n") {
            sonuc.append(NSAttributedString(string: "\n", attributes: oznitelikler))
        }
    }

    private func metinEkle(_ ham: String) {
        let metin = Self.varliklariAc(ham)
        let pre = yigin.contains { $0.ad == "pre" }
        var yazi = pre ? metin : metin.replacingOccurrences(of: #"[\t\r\n ]+"#, with: " ", options: .regularExpression)
        if !pre, sonuc.length == 0 || sonuc.string.hasSuffix("\n") || sonuc.string.hasSuffix(" ") {
            yazi = String(yazi.drop(while: { $0 == " " }))
        }
        sonuc.append(NSAttributedString(string: yazi, attributes: oznitelikler))
    }

    private func stilUygula(_ stil: String) {
        for ifade in stil.split(separator: ";") {
            let parcalar = ifade.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            guard parcalar.count == 2 else { continue }
            let deger = parcalar[1]
            if parcalar[0] == "font-weight", deger == "bold" || (Int(deger) ?? 0) >= 600 { oznitelikler[kKalinAnahtari] = true }
            if parcalar[0] == "font-style", deger == "italic" || deger == "oblique" { oznitelikler[kItalikAnahtari] = true }
            if parcalar[0] == "font-size" {
                let sayi = Double(deger.prefix { $0.isNumber || $0 == "." }) ?? 0
                let oran = deger.hasSuffix("pt") ? sayi / Double(kTabanPunto)
                    : deger.hasSuffix("px") ? sayi * 0.75 / Double(kTabanPunto)
                    : deger.hasSuffix("em") ? sayi : deger.hasSuffix("%") ? sayi / 100 : 0
                if oran.isFinite, (0.25...8).contains(oran) { oznitelikler[kPuntoOlcegiAnahtari] = oran }
            }
        }
    }

    private static func ozellikleriOku(_ etiket: String) -> [String: String] {
        let ns = etiket as NSString
        var sonuc: [String: String] = [:]
        for eslesme in ozellik.matches(in: etiket, range: NSRange(location: 0, length: ns.length)) {
            let ad = ns.substring(with: eslesme.range(at: 1)).lowercased()
            if let alt = (2...4).map({ eslesme.range(at: $0) }).first(where: { $0.location != NSNotFound }) {
                sonuc[ad] = varliklariAc(ns.substring(with: alt))
            }
        }
        return sonuc
    }

    private static func varliklariAc(_ metin: String) -> String {
        let sonuc = NSMutableString(string: metin)
        let adlar = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
                     "ndash": "–", "mdash": "—", "hellip": "…", "bull": "•", "lsquo": "‘", "rsquo": "’",
                     "ldquo": "“", "rdquo": "”", "copy": "©", "reg": "®", "trade": "™"]
        for eslesme in varlik.matches(in: metin, range: NSRange(location: 0, length: sonuc.length)).reversed() {
            let ad = sonuc.substring(with: eslesme.range(at: 1))
            var deger = adlar[ad]
            if ad.hasPrefix("#") {
                let hex = ad.lowercased().hasPrefix("#x")
                if let kod = UInt32(ad.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10), let scalar = UnicodeScalar(kod), kod != 0 {
                    deger = String(scalar)
                }
            }
            if let deger { sonuc.replaceCharacters(in: eslesme.range, with: deger) }
        }
        return sonuc as String
    }

    private func sadelestir() {
        // Çekirdeğe aynı metin verilir; böylece dönen anlamların UTF-16 aralıkları
        // başlık/liste/link aralıklarıyla birebir kalır (kaynak HTML boşlukları dahil).
        let kurallar: [(String, String, Bool)] = [
            ("\r\n", "\n", false), ("\r", "\n", false), ("\u{2028}", "\n", false), ("\u{2029}", "\n", false),
            ("\u{00A0}", " ", false), ("\u{200B}", "", false), ("\u{FEFF}", "", false),
            ("(?m)^[\\t ]*([\u{2022}\u{25E6}\u{25AA}\u{00B7}])[\\t ]+", "• ", true),
            ("(?m)[ \\t]+$", "", true)
        ]
        for (desen, yeni, regex) in kurallar {
            sonuc.mutableString.replaceOccurrences(of: desen, with: yeni, options: regex ? .regularExpression : [], range: NSRange(location: 0, length: sonuc.length))
        }
    }
}
