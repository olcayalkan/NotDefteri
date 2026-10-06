import CGtk
import Foundation
import NotDefteriCekirdek

enum LinuxKodVeUyari {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor) {
        let araclar = KodVeUyariAraclari(pencere: pencere, editor: editor)
        // Kancalar bileşeni yaşatır; bileşen editörü zayıf tutar.
        editor.degisiklikSonrasi.append { araclar.degisti() }
        LinuxEklentiler.yasamDongusunuIzle(editor) { araclar.notAcildi() }
    }
}

private final class KodUyariEylemi<Eylem> {
    let calistir: Eylem
    init(_ calistir: Eylem) { self.calistir = calistir }
}

private func kodUyariSinyali<Eylem>(_ nesne: gpointer, _ ad: String, _ callback: GCallback, _ eylem: Eylem) {
    let veri = Unmanaged.passRetained(KodUyariEylemi(eylem)).toOpaque()
    g_signal_connect_data(nesne, ad, callback, veri, { veri, _ in
        if let veri { Unmanaged<AnyObject>.fromOpaque(veri).release() }
    }, GConnectFlags(rawValue: 0))
}

private let kodEklemeC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextIter>?, UnsafePointer<CChar>?, Int32, gpointer?) -> Void = {
    _, iter, _, _, veri in
    guard let iter, let veri else { return }
    Unmanaged<KodUyariEylemi<(GtkTextIter, GtkTextIter) -> Void>>.fromOpaque(veri)
        .takeUnretainedValue().calistir(iter.pointee, iter.pointee)
}

private let kodSilmeC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextIter>?, UnsafeMutablePointer<GtkTextIter>?, gpointer?) -> Void = {
    _, bas, son, veri in
    guard let bas, let son, let veri else { return }
    Unmanaged<KodUyariEylemi<(GtkTextIter, GtkTextIter) -> Void>>.fromOpaque(veri)
        .takeUnretainedValue().calistir(bas.pointee, son.pointee)
}

private let kodHareketC: @convention(c) (gpointer?, Double, Double, gpointer?) -> Void = {
    _, x, y, veri in
    guard let veri else { return }
    Unmanaged<KodUyariEylemi<(Double, Double) -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir(x, y)
}

private let uyariTiklamaC: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = {
    jest, adet, x, y, veri in
    guard let veri, adet == 1 else { return }
    if Unmanaged<KodUyariEylemi<(Double, Double) -> Bool>>.fromOpaque(veri).takeUnretainedValue().calistir(x, y), let jest {
        gtk_gesture_set_state(jest, GTK_EVENT_SEQUENCE_CLAIMED)
    }
}

private let kodCerceveC: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = {
    _, cr, _, _, veri in
    guard let cr, let veri else { return }
    Unmanaged<KodUyariEylemi<(OpaquePointer) -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir(cr)
}

private let kodEtiketC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextTag>?, UnsafeMutablePointer<GtkTextIter>?, UnsafeMutablePointer<GtkTextIter>?, gpointer?) -> Void = {
    _, _, _, _, veri in
    guard let veri else { return }
    Unmanaged<KodUyariEylemi<() -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir()
}

private let kodKuyrugu = DispatchQueue(label: "NotDefteriLinux.kod-renklendirme", qos: .userInitiated)

private final class KodVeUyariAraclari {
    private struct Kirli {
        let bas: UnsafeMutablePointer<GtkTextMark>
        let son: UnsafeMutablePointer<GtkTextMark>
    }
    private struct KodBlogu {
        let aralik: NSRange
        let ofset: Int32
        let metin: String
        let dil: String
    }
    private struct UyariHedefi {
        let konum: Int
        let kimlik: String
        let nesil: Int
        let url: URL
    }

    private weak var editor: LinuxEditor?
    private var gorunum: UnsafeMutablePointer<GtkTextView> { GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(editor!.metinGorunumu)) }
    private let arac = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
    private let dilEtiketi = gtk_label_new("")!
    private let kopyala = gtk_button_new_with_label("Kopyala")!
    private var kopyalaDugmesi: UnsafeMutablePointer<GtkButton> { GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(kopyala)) }
    private let cerceveAlani = gtk_drawing_area_new()!
    private let renkMenusu = gtk_popover_new()!
    private let ayarlar: OpaquePointer
    private var ayarSinyalleri: [gulong] = []
    private var kodEtiketleri: [KodTokenTuru: UnsafeMutablePointer<GtkTextTag>] = [:]
    private var kirli: [Kirli] = []
    private var nesil = 0
    private var kapandi = false
    private var debounce: ZamanlayiciIptal?
    private var bildirim: ZamanlayiciIptal?
    private var yerlesimBekliyor = false
    private var fare: (Double, Double)?
    private var aracKaresi = GdkRectangle()
    private var aracBlogu: (aralik: NSRange, kimlik: String)?
    private var uyariHedefi: UyariHedefi?
    private struct Cerceve {
        let kare: GdkRectangle
        let renk: GdkRGBA
    }
    private var cerceveler: [Cerceve] = []
    private var sonAlan = GdkRectangle()
    private var cerceveKirli = true
    private static let renkler = ["gri", "mavi", "sarı", "kırmızı", "yeşil"]

    init(pencere: LinuxPencere, editor: LinuxEditor) {
        self.editor = editor
        ayarlar = gtk_settings_get_for_display(gtk_widget_get_display(editor.metinGorunumu))!
        for widget in [arac, cerceveAlani, renkMenusu] { g_object_ref_sink(UnsafeMutableRawPointer(widget)) }
        arayuzuKur()
        etiketleriKur()
        sinyalleriKur(pencere)
        notAcildi()
    }

    deinit {
        debounce?()
        bildirim?()
        for kimlik in ayarSinyalleri { g_signal_handler_disconnect(UnsafeMutableRawPointer(ayarlar), kimlik) }
        for widget in [arac, cerceveAlani, renkMenusu] { g_object_unref(UnsafeMutableRawPointer(widget)) }
    }

    private func arayuzuKur() {
        gtk_widget_set_can_target(cerceveAlani, 0)
        gtk_text_view_add_overlay(gorunum, cerceveAlani, 0, 0)
        let veri = Unmanaged.passRetained(KodUyariEylemi { [weak self] (cr: OpaquePointer) -> Void in self?.cerceveleriCiz(cr) }).toOpaque()
        gtk_drawing_area_set_draw_func(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(cerceveAlani)), kodCerceveC, veri, { veri in
            if let veri { Unmanaged<AnyObject>.fromOpaque(veri).release() }
        })
        gtk_widget_add_css_class(arac, "background")
        gtk_widget_add_css_class(dilEtiketi, "dim-label")
        gtk_widget_set_margin_start(dilEtiketi, 8)
        gtk_widget_set_focusable(kopyala, 0)
        gtk_box_append(nd_box(arac), dilEtiketi)
        gtk_box_append(nd_box(arac), kopyala)
        gtk_widget_set_visible(arac, 0)
        gtk_text_view_add_overlay(gorunum, arac, 0, 0)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(kopyala), "clicked") { [weak self] in self?.kodKopyala() }
        gtk_widget_set_parent(renkMenusu, editor!.metinGorunumu)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(renkMenusu), "closed") { [weak self] in self?.uyariHedefi = nil }
        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
        for renk in Self.renkler {
            let dugme = gtk_button_new_with_label(renk.capitalized(with: Locale(identifier: "tr_TR")))!
            gtk_widget_add_css_class(dugme, "flat")
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked") { [weak self] in
                Platform.anaIsParcaciginda { [weak self] in self?.uyariDegistir(renk) }
            }
            gtk_box_append(nd_box(kutu), dugme)
        }
        gtk_popover_set_child(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(renkMenusu)), kutu)
    }

    private func sinyalleriKur(_ pencere: LinuxPencere) {
        guard let editor else { return }
        for (ad, callback) in [("insert-text", unsafeBitCast(kodEklemeC, to: GCallback.self)),
                               ("delete-range", unsafeBitCast(kodSilmeC, to: GCallback.self))] {
            kodUyariSinyali(UnsafeMutableRawPointer(editor.tampon), ad, callback,
                           { [weak self] (bas: GtkTextIter, son: GtkTextIter) in self?.isaretle(bas, son) })
        }
        for ad in ["apply-tag", "remove-tag"] {
            kodUyariSinyali(UnsafeMutableRawPointer(editor.tampon), ad, unsafeBitCast(kodEtiketC, to: GCallback.self),
                           { [weak self] () -> Void in self?.cerceveKirli = true; self?.yerlesimiPlanla() })
        }
        let veri = Unmanaged.passRetained(KodUyariEylemi { [weak self] in
            guard let self, !self.kapandi else { return }
            self.cerceveleriGuncelle()
        }).toOpaque()
        gtk_widget_add_tick_callback(editor.metinGorunumu, { _, _, veri in
            if let veri { Unmanaged<KodUyariEylemi<() -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir() }
            return 1
        }, veri, { veri in
            if let veri { Unmanaged<AnyObject>.fromOpaque(veri).release() }
        })
        let hareket = gtk_event_controller_motion_new()!
        gtk_event_controller_set_propagation_phase(hareket, GTK_PHASE_CAPTURE)
        kodUyariSinyali(UnsafeMutableRawPointer(hareket), "motion", unsafeBitCast(kodHareketC, to: GCallback.self),
                       { [weak self] (x: Double, y: Double) in self?.fare = (x, y); self?.araciGuncelle() })
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(hareket), "leave") { [weak self] in
            self?.fare = nil
            self?.araciGizle()
        }
        gtk_widget_add_controller(editor.metinGorunumu, hareket)
        do {
            let tik = gtk_gesture_click_new()!
            gtk_gesture_single_set_button(tik, 3)
            gtk_event_controller_set_propagation_phase(tik, GTK_PHASE_CAPTURE)
            kodUyariSinyali(UnsafeMutableRawPointer(tik), "pressed", unsafeBitCast(uyariTiklamaC, to: GCallback.self),
                           { [weak self] (x: Double, y: Double) in self?.uyariTiklandi(x, y) ?? false })
            gtk_widget_add_controller(editor.metinGorunumu, tik)
        }
        for ayar in [gtk_scrollable_get_hadjustment(OpaquePointer(editor.metinGorunumu)),
                     gtk_scrollable_get_vadjustment(OpaquePointer(editor.metinGorunumu))].compactMap({ $0 }) {
            for ad in ["changed", "value-changed"] {
                GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(ayar), ad) { [weak self] in self?.yerlesimiPlanla() }
            }
        }
        for ad in ["notify::gtk-application-prefer-dark-theme", "notify::gtk-theme-name"] {
            ayarSinyalleri.append(GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(ayarlar), ad) { [weak self] (_: gpointer?) in
                self?.renkleriGuncelle()
            })
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.metinGorunumu), "notify::visible") { [weak self] (_: gpointer?) in
            self?.panelleriKapat(); self?.yerlesimiPlanla()
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(pencere.pencere), "destroy") { [weak self] in self?.kapat() }
    }

    private func etiket(_ ad: String) -> UnsafeMutablePointer<GtkTextTag> {
        let tablo = gtk_text_buffer_get_tag_table(editor!.tampon)!
        if let mevcut = gtk_text_tag_table_lookup(tablo, ad) { return mevcut }
        let yeni = gtk_text_tag_new(ad)!
        gtk_text_tag_table_add(tablo, yeni)
        g_object_unref(UnsafeMutableRawPointer(yeni)) // Sahibi tablo.
        return yeni
    }

    private func etiketleriKur() {
        for (tur, ad) in [(KodTokenTuru.anahtarKelime, "anahtar"), (.metin, "metin"), (.sayi, "sayi"),
                          (.yorum, "yorum"), (.tur, "tur"), (.fonksiyon, "fonksiyon"), (.operator, "operator")] {
            kodEtiketleri[tur] = etiket("kod-" + ad)
        }
        renkleriGuncelle()
    }

    private func renkleriGuncelle() {
        guard !kapandi else { return }
        let koyu = nd_settings_dark(ayarlar) != 0
        // KodRenkleri.swift: açıkta mor/kırmızı/mavi, koyuda pembe/yeşil/turuncu.
        let renkler: [KodTokenTuru: String] = [.anahtarKelime: koyu ? "#ef91b6" : "#9342ae",
            .metin: koyu ? "#8edb9b" : "#b93931", .sayi: koyu ? "#f4b76b" : "#2869ad",
            .yorum: koyu ? "#c2c2c2" : "#565656", .tur: koyu ? "#8ad8df" : "#32868c",
            .fonksiyon: koyu ? "#81b4f1" : "#2869ad", .operator: koyu ? "#eeeeec" : "#292929"]
        for (tur, tag) in kodEtiketleri { gNesneOzelligi(UnsafeMutableRawPointer(tag), "foreground", .metin(renkler[tur]!)) }
        cerceveKirli = true
        yerlesimiPlanla()
    }

    /// Sinyal sırasında belge okunmaz. Sol/sağ yerçekimi eklenen metni kapsar;
    /// silinen aralık daralır. Iter'lar callback dışına taşınmaz.
    private func isaretle(_ ilk: GtkTextIter, _ son: GtkTextIter) {
        guard !kapandi, let editor else { return }
        nesil += 1
        debounce?(); debounce = nil
        araciGizle()
        panelleriKapat()
        var bas = ilk, bitis = son
        for aralik in kirli {
            var b = GtkTextIter(), s = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &b, aralik.bas)
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &s, aralik.son)
            if gtk_text_iter_compare(&bas, &s) <= 0 && gtk_text_iter_compare(&bitis, &b) >= 0 {
                if gtk_text_iter_compare(&bas, &b) < 0 { gtk_text_buffer_move_mark(editor.tampon, aralik.bas, &bas) }
                if gtk_text_iter_compare(&bitis, &s) > 0 { gtk_text_buffer_move_mark(editor.tampon, aralik.son, &bitis) }
                return
            }
        }
        kirli.append(Kirli(bas: gtk_text_buffer_create_mark(editor.tampon, nil, &bas, 1)!,
                           son: gtk_text_buffer_create_mark(editor.tampon, nil, &bitis, 0)!))
    }

    func degisti() {
        guard !kapandi, let editor else { return }
        guard editor.editorEtkin else { sifirla(); return }
        cerceveKirli = true
        yerlesimiPlanla()
        debounce?()
        guard !kirli.isEmpty else { return }
        let surum = nesil
        debounce = Platform.zamanlayici(0.15) { [weak self] in
            guard let self, self.nesil == surum else { return }
            self.debounce = nil
            self.renklendir()
        }
    }

    func notAcildi() {
        guard !kapandi, let editor else { return }
        sifirla()
        var bas = GtkTextIter(), son = GtkTextIter()
        gtk_text_buffer_get_bounds(editor.tampon, &bas, &son)
        isaretle(bas, son) // Tüm belge yalnızca not açılışında.
        degisti()
    }

    private func kirliAraliklar() -> [NSRange] {
        guard let editor else { return [] }
        return kirli.map { aralik in
            var bas = GtkTextIter(), son = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &bas, aralik.bas)
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &son, aralik.son)
            // Silme sınırının iki yanındaki paragrafı da onar.
            gtk_text_iter_backward_char(&bas)
            gtk_text_iter_set_line_offset(&bas, 0)
            gtk_text_iter_forward_char(&son)
            if gtk_text_iter_ends_line(&son) == 0 { gtk_text_iter_forward_to_line_end(&son) }
            gtk_text_iter_forward_char(&son)
            return LinuxMetinDonusumu.aralik(bas, son)
        }
    }

    private func renklendir() {
        guard let editor, let url = editor.acikURL else { return }
        let surum = nesil, araliklar = kirliAraliklar()
        let bloklar = editor.belgeyiOku { belge -> [KodBlogu] in
            var sonuc: [KodBlogu] = [], gorulen = Set<Int>()
            let tumu = NSRange(location: 0, length: belge.length)
            for kirli in araliklar {
                let kapsam = NSIntersectionRange(kirli, tumu)
                var konum = kapsam.location
                while konum < NSMaxRange(kapsam) {
                    var blok = NSRange()
                    let bilgi = belge.attribute(kKodBloguAnahtari, at: konum, longestEffectiveRange: &blok, in: tumu) as? [String: String]
                    if let bilgi, gorulen.insert(blok.location).inserted {
                        var iter = GtkKoprusu.iter(editor.tampon, utf16: blok.location)
                        sonuc.append(KodBlogu(aralik: blok, ofset: gtk_text_iter_get_offset(&iter),
                                              metin: (belge.string as NSString).substring(with: blok), dil: kodBloguDilEtiketi(bilgi)))
                    }
                    konum = NSMaxRange(blok)
                }
            }
            return sonuc
        }
        // Swift/Foundation verisi dışında arka planda GTK veya canlı belgeye erişilmez.
        kodKuyrugu.async { [weak self] in
            let tokenlar = bloklar.map { kodVurgula($0.metin, dil: $0.dil) }
            Platform.anaIsParcaciginda { [weak self] in
                guard let self, !self.kapandi, self.nesil == surum, self.editor?.acikURL == url else { return }
                self.tokenlariUygula(bloklar, tokenlar, kirli: araliklar)
                self.isaretleriSil()
                self.yerlesimiPlanla()
            }
        }
    }

    private func enUsteAl(_ tag: UnsafeMutablePointer<GtkTextTag>) {
        guard let editor else { return }
        gtk_text_tag_set_priority(tag, gtk_text_tag_table_get_size(gtk_text_buffer_get_tag_table(editor.tampon)) - 1)
    }

    private func tokenlariUygula(_ bloklar: [KodBlogu], _ tokenlar: [[(aralik: NSRange, tur: KodTokenTuru)]], kirli: [NSRange]) {
        guard let editor else { return }
        editor.belgeyiOku { belge in
            let ns = belge.string as NSString
            for aralik in kirli + bloklar.map(\.aralik) where aralik.length > 0 {
                var (bas, son) = GtkKoprusu.iterler(editor.tampon, aralik, metin: ns)
                for tag in kodEtiketleri.values { gtk_text_buffer_remove_tag(editor.tampon, tag, &bas, &son) }
            }
        }
        for (blok, renklenen) in zip(bloklar, tokenlar) {
            // Tokenların UTF-16 konumları yalnızca blok içinde dönüştürülür.
            let ns = blok.metin as NSString
            var iter = GtkTextIter(), oncekiSon = 0
            gtk_text_buffer_get_iter_at_offset(editor.tampon, &iter, blok.ofset)
            for token in renklenen {
                gtk_text_iter_forward_chars(&iter, Int32(LinuxMetinDonusumu.karakterSayisi(ns,
                    NSRange(location: oncekiSon, length: token.aralik.location - oncekiSon))))
                var son = iter
                gtk_text_iter_forward_chars(&son, Int32(LinuxMetinDonusumu.karakterSayisi(ns, token.aralik)))
                if let tag = kodEtiketleri[token.tur] {
                    enUsteAl(tag)
                    gtk_text_buffer_apply_tag(editor.tampon, tag, &iter, &son)
                }
                iter = son; oncekiSon = NSMaxRange(token.aralik)
            }
        }
    }

    private func gizliMi(_ konum: GtkTextIter) -> Bool {
        var iter = konum
        let liste = gtk_text_iter_get_tags(&iter)
        defer { g_slist_free(liste) }
        var oge = liste
        while let dugum = oge {
            let nesne = dugum.pointee.data!.assumingMemoryBound(to: GObject.self)
            var ad = GValue(), gizli = GValue()
            g_value_init(&ad, g_type_from_name("gchararray"))
            g_object_get_property(nesne, "name", &ad)
            let katli = g_value_get_string(&ad).map { String(cString: $0).hasPrefix("katla-") } ?? false
            g_value_unset(&ad)
            if katli {
                g_value_init(&gizli, g_type_from_name("gboolean"))
                g_object_get_property(nesne, "invisible", &gizli)
                let sonuc = g_value_get_boolean(&gizli) != 0
                g_value_unset(&gizli)
                if sonuc { return true }
            }
            oge = dugum.pointee.next
        }
        return false
    }

    private func noktadakiIter(_ x: Double, _ y: Double) -> GtkTextIter? {
        guard let editor, !kapandi, editor.acikURL != nil,
              gtk_widget_get_visible(editor.metinGorunumu) != 0, gtk_text_view_get_editable(gorunum) != 0 else { return nil }
        var bx: Int32 = 0, by: Int32 = 0, iter = GtkTextIter(), alan = GdkRectangle()
        gtk_text_view_window_to_buffer_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, Int32(x), Int32(y), &bx, &by)
        gtk_text_view_get_visible_rect(gorunum, &alan)
        guard bx >= alan.x + gtk_text_view_get_left_margin(gorunum),
              bx < alan.x + alan.width - gtk_text_view_get_right_margin(gorunum),
              by >= alan.y, by < alan.y + alan.height else { return nil }
        gtk_text_view_get_iter_at_location(gorunum, &iter, bx, by)
        var ust: Int32 = 0, yukseklik: Int32 = 0
        gtk_text_view_get_line_yrange(gorunum, &iter, &ust, &yukseklik)
        guard by >= ust, by < ust + yukseklik, !gizliMi(iter) else { return nil }
        return iter
    }

    private func araciGuncelle() {
        guard let editor, let (x, y) = fare, var iter = noktadakiIter(x, y) else { araciGizle(); return }
        var bx: Int32 = 0, by: Int32 = 0
        gtk_text_view_window_to_buffer_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, Int32(x), Int32(y), &bx, &by)
        let aracta = gtk_widget_get_visible(arac) != 0 && icerir(aracKaresi, bx, by)
        let konum = aracta ? aracBlogu?.aralik.location ?? 0 : GtkKoprusu.utf16(iter)
        let blok = editor.belgeyiOku { belge -> (NSRange, [String: String])? in
            guard konum < belge.length else { return nil }
            var aralik = NSRange()
            guard let bilgi = belge.attribute(kKodBloguAnahtari, at: konum, longestEffectiveRange: &aralik,
                                              in: NSRange(location: 0, length: belge.length)) as? [String: String] else { return nil }
            return (aralik, bilgi)
        }
        guard let (aralik, bilgi) = blok else { araciGizle(); return }
        iter = GtkKoprusu.iter(editor.tampon, utf16: aralik.location)
        guard !gizliMi(iter) else { araciGizle(); return }
        var kare = GdkRectangle(), gorunen = GdkRectangle(), en: Int32 = 0, boy: Int32 = 0
        gtk_text_view_get_iter_location(gorunum, &iter, &kare)
        gtk_text_view_get_visible_rect(gorunum, &gorunen)
        let kimlik = bilgi["kimlik"] ?? ""
        if aracBlogu?.kimlik != kimlik { bildirim?(); gtk_button_set_label(kopyalaDugmesi, "Kopyala") }
        gtk_label_set_text(nd_label(dilEtiketi), kodBloguDilEtiketi(bilgi))
        gtk_widget_measure(arac, GTK_ORIENTATION_HORIZONTAL, -1, nil, &en, nil, nil)
        gtk_widget_measure(arac, GTK_ORIENTATION_VERTICAL, en, nil, &boy, nil, nil)
        aracKaresi = GdkRectangle(x: max(gtk_text_view_get_left_margin(gorunum), gorunen.x + gorunen.width - gtk_text_view_get_right_margin(gorunum) - en - 6),
                                 y: kare.y, width: en, height: boy)
        guard kare.y >= gorunen.y, kare.y < gorunen.y + gorunen.height else { araciGizle(); return }
        aracBlogu = (aralik, kimlik)
        // GtkTextView overlay konumu buffer koordinatıdır; pencere koordinatı değildir.
        gtk_text_view_move_overlay(gorunum, arac, aracKaresi.x, aracKaresi.y)
        gtk_widget_set_visible(arac, 1)
    }

    private func icerir(_ kare: GdkRectangle, _ x: Int32, _ y: Int32) -> Bool {
        x >= kare.x && x < kare.x + kare.width && y >= kare.y && y < kare.y + kare.height
    }

    private func kodKopyala() {
        guard !kapandi, let editor, let blok = aracBlogu, gtk_text_view_get_editable(gorunum) != 0 else { return }
        let govde = editor.belgeyiOku { belge -> String? in
            guard NSMaxRange(blok.aralik) <= belge.length, blok.aralik.length > 0,
                  let bilgi = belge.attribute(kKodBloguAnahtari, at: blok.aralik.location, effectiveRange: nil) as? [String: String],
                  bilgi["kimlik"] == blok.kimlik else { return nil }
            return kodBloguGovdesi(belge.attributedSubstring(from: blok.aralik))
        }
        guard let govde else { return }
        gdk_clipboard_set_text(gtk_widget_get_clipboard(editor.metinGorunumu), govde)
        gtk_button_set_label(kopyalaDugmesi, "Kopyalandı")
        bildirim?()
        bildirim = Platform.zamanlayici(1.2) { [weak self] in
            guard let self, !self.kapandi else { return }
            self.bildirim = nil
            gtk_button_set_label(self.kopyalaDugmesi, "Kopyala")
            self.araciGuncelle()
        }
        araciGuncelle()
    }

    private func uyariTiklandi(_ x: Double, _ y: Double) -> Bool {
        guard let editor, let url = editor.acikURL, let iter = noktadakiIter(x, y) else { return false }
        let konum = GtkKoprusu.utf16(iter)
        let bilgi = editor.belgeyiOku { belge -> (NSRange, MetinBlogu)? in
            guard konum < belge.length else { return nil }
            let ns = belge.string as NSString
            let aralik = ns.paragraphRange(for: NSRange(location: konum, length: 0))
            guard let blok = MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: aralik.location, effectiveRange: nil)), blok.tur == .uyari else { return nil }
            return (aralik, blok)
        }
        guard let (aralik, blok) = bilgi else { return false }
        panelleriKapat()
        uyariHedefi = UyariHedefi(konum: aralik.location, kimlik: blok.uyariKimligi, nesil: nesil, url: url)
        let panel: UnsafeMutablePointer<GtkPopover> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(renkMenusu))
        var kare = GdkRectangle(x: Int32(x), y: Int32(y), width: 1, height: 1)
        gtk_popover_set_pointing_to(panel, &kare) // Popover ise parent/widget koordinatı ister.
        gtk_popover_popup(panel)
        return true
    }

    private func uyariDegistir(_ renk: String) {
        guard !kapandi, let editor, let hedef = uyariHedefi, hedef.nesil == nesil,
              editor.acikURL == hedef.url, gtk_text_view_get_editable(gorunum) != 0 else { return }
        var secim = LinuxMetinDonusumu.secim(editor.tampon)
        var secimSonu = NSMaxRange(secim), imlec = gtkImleci(), secimBitisi = GtkTextIter()
        gtk_text_buffer_get_selection_bounds(editor.tampon, nil, &secimBitisi)
        let imlecSonda = gtk_text_iter_equal(&imlec, &secimBitisi) != 0
        let degisim = editor.belgeyiOku { belge -> (NSRange, NSAttributedString)? in
            guard hedef.konum < belge.length,
                  belge.attribute(kUyariKutusuAnahtari, at: hedef.konum, effectiveRange: nil) as? String == hedef.kimlik else { return nil }
            var kapsam = NSRange()
            _ = belge.attribute(kUyariKutusuAnahtari, at: hedef.konum, longestEffectiveRange: &kapsam,
                                in: NSRange(location: 0, length: belge.length))
            let yeni = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: kapsam))
            var konum = 0
            while konum < yeni.length {
                var paragraf = yeni.mutableString.paragraphRange(for: NSRange(location: konum, length: 0))
                guard var blok = MetinBlogu(oznitelik: yeni.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil)), blok.tur == .uyari else { return nil }
                blok.renk = renk
                blok.kaynakOnEk = nil
                let uzunluk = blokIsaretiUzunlugu(yeni, konum: konum)
                let isaret = blokIsaretiniUret(blok)
                let bas = kapsam.location + konum, son = bas + uzunluk
                let fark = isaret.length - uzunluk
                func tasi(_ uc: Int) -> Int {
                    if uc >= son { return uc + fark }
                    return uc < bas ? uc : bas + min(uc - bas, isaret.length)
                }
                secim.location = tasi(secim.location)
                secimSonu = tasi(secimSonu)
                yeni.replaceCharacters(in: NSRange(location: konum, length: uzunluk), with: isaret)
                paragraf.length += isaret.length - uzunluk
                blokBiciminiUygula(blok, metne: yeni, aralik: paragraf)
                konum = NSMaxRange(paragraf)
            }
            return (kapsam, yeni)
        }
        guard let (kapsam, yeni) = degisim else { return }
        panelleriKapat()
        editor.aralikDegistir(kapsam, ile: yeni)
        // Tamamı değiştirilen kutunun içindeki mark'lar silmede çöker. Seçim
        // uçları önek uzunluklarıyla taşınır; yeni iter'lar yazımdan sonra alınır.
        secim.length = max(0, secimSonu - secim.location)
        var (bas, son) = LinuxMetinDonusumu.iterler(editor.tampon, secim)
        if imlecSonda { gtk_text_buffer_select_range(editor.tampon, &son, &bas) }
        else { gtk_text_buffer_select_range(editor.tampon, &bas, &son) }
        gtk_widget_grab_focus(editor.metinGorunumu)
    }

    private func gtkImleci() -> GtkTextIter {
        var iter = GtkTextIter()
        gtk_text_buffer_get_iter_at_mark(editor!.tampon, &iter, gtk_text_buffer_get_insert(editor!.tampon))
        return iter
    }

    private func yerlesimiPlanla() {
        guard !kapandi, !yerlesimBekliyor else { return }
        yerlesimBekliyor = true
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, !self.kapandi else { return }
            self.yerlesimBekliyor = false
            self.araciGuncelle()
            self.cerceveleriGuncelle()
        }
    }

    /// Yalnızca görünür bloklar ölçülür; tam blok sınırları kullanılarak çok
    /// paragraflı kutu tek çerçeve kalır. Cairo görünüm dışını kendisi kırpar.
    private func cerceveleriGuncelle() {
        guard let editor else { return }
        var alan = GdkRectangle(), bas = GtkTextIter(), son = GtkTextIter()
        gtk_text_view_get_visible_rect(gorunum, &alan)
        guard cerceveKirli || alan.x != sonAlan.x || alan.y != sonAlan.y ||
                alan.width != sonAlan.width || alan.height != sonAlan.height else { return }
        cerceveKirli = false; sonAlan = alan
        cerceveler.removeAll()
        if gtk_widget_get_visible(editor.metinGorunumu) != 0, editor.acikURL != nil {
            gtk_text_view_get_line_at_y(gorunum, &bas, alan.y, nil)
            gtk_text_view_get_line_at_y(gorunum, &son, alan.y + alan.height, nil)
            gtk_text_iter_forward_to_line_end(&son)
            gtk_text_iter_forward_char(&son)
            let aralik = LinuxMetinDonusumu.aralik(bas, son)
            editor.belgeyiOku { belge in
                gorunenCerceveleriOlc(belge, aralik: aralik, alan: alan)
            }
        }
        gtk_widget_set_size_request(cerceveAlani, max(1, alan.width), max(1, alan.height))
        gtk_text_view_move_overlay(gorunum, cerceveAlani, alan.x, alan.y)
        gtk_widget_queue_draw(cerceveAlani)
    }

    private func gorunenCerceveleriOlc(_ belge: NSAttributedString, aralik: NSRange, alan: GdkRectangle) {
        guard let editor else { return }
        let tumu = NSRange(location: 0, length: belge.length)
        let kapsam = NSIntersectionRange(aralik, tumu)
        for anahtar in [kKodBloguAnahtari, kUyariKutusuAnahtari] {
            belge.enumerateAttribute(anahtar, in: kapsam) { deger, alt, _ in
                guard deger != nil, !gizliMi(GtkKoprusu.iter(editor.tampon, utf16: alt.location)) else { return }
                var blok = NSRange()
                _ = belge.attribute(anahtar, at: alt.location, longestEffectiveRange: &blok, in: tumu)
                let kod = anahtar == kKodBloguAnahtari
                let uyari = MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: alt.location, effectiveRange: nil))
                var renk = GdkRGBA()
                let renkler = ["gri": "#8e8e93", "mavi": "#007aff", "sarı": "#ffcc00", "kırmızı": "#ff3b30", "yeşil": "#34c759"]
                let renkAdi = kod ? (nd_settings_dark(ayarlar) != 0 ? "#eeeeec" : "#292929") : renkler[uyari?.renk ?? "gri"] ?? "#8e8e93"
                gdk_rgba_parse(&renk, renkAdi)
                let seviye = Int32(kod ? 0 : (uyari?.seviye ?? 0) * 24)
                let x = gtk_text_view_get_left_margin(gorunum) + seviye
                let en = alan.width - gtk_text_view_get_left_margin(gorunum) - gtk_text_view_get_right_margin(gorunum) - seviye
                cerceveler.append(Cerceve(kare: cerceveKaresi(blok, x: x, en: en, alan: alan), renk: renk))
            }
        }
    }

    private func cerceveKaresi(_ blok: NSRange, x: Int32, en: Int32, alan: GdkRectangle) -> GdkRectangle {
        var bas = GtkKoprusu.iter(editor!.tampon, utf16: blok.location)
        var son = GtkKoprusu.iter(editor!.tampon, utf16: NSMaxRange(blok))
        gtk_text_iter_backward_char(&son)
        var ust: Int32 = 0, alt: Int32 = 0, boy: Int32 = 0
        gtk_text_view_get_line_yrange(gorunum, &bas, &ust, nil)
        gtk_text_view_get_line_yrange(gorunum, &son, &alt, &boy)
        return GdkRectangle(x: x - alan.x, y: ust - alan.y - 3, width: max(1, en), height: max(1, alt + boy - ust + 6))
    }

    private func cerceveleriCiz(_ cr: OpaquePointer) {
        for cerceve in cerceveler {
            let k = cerceve.kare, renk = cerceve.renk
            let x = Double(k.x) + 0.5, y = Double(k.y) + 0.5
            let en = Double(k.width) - 1, boy = Double(k.height) - 1
            let r = min(6, min(en, boy) / 2)
            cairo_new_sub_path(cr)
            cairo_arc(cr, x + en - r, y + r, r, -.pi / 2, 0)
            cairo_arc(cr, x + en - r, y + boy - r, r, 0, .pi / 2)
            cairo_arc(cr, x + r, y + boy - r, r, .pi / 2, .pi)
            cairo_arc(cr, x + r, y + r, r, .pi, .pi * 1.5)
            cairo_close_path(cr)
            cairo_set_source_rgba(cr, Double(renk.red), Double(renk.green), Double(renk.blue), 0.7)
            cairo_set_line_width(cr, 1)
            cairo_stroke(cr)
        }
    }

    private func araciGizle() {
        aracBlogu = nil
        bildirim?(); bildirim = nil
        gtk_button_set_label(kopyalaDugmesi, "Kopyala")
        gtk_widget_set_visible(arac, 0)
    }

    private func panelleriKapat() {
        uyariHedefi = nil
        gtk_popover_popdown(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(renkMenusu)))
    }

    private func isaretleriSil() {
        if let editor {
            for aralik in kirli {
                gtk_text_buffer_delete_mark(editor.tampon, aralik.bas)
                gtk_text_buffer_delete_mark(editor.tampon, aralik.son)
            }
        }
        kirli.removeAll()
    }

    private func sifirla() {
        nesil += 1
        debounce?(); debounce = nil
        isaretleriSil()
        araciGizle()
        panelleriKapat()
        fare = nil
        cerceveler.removeAll()
        cerceveKirli = true
        gtk_widget_queue_draw(cerceveAlani)
    }

    private func kapat() {
        guard !kapandi else { return }
        sifirla()
        gtk_text_view_remove(gorunum, cerceveAlani)
        gtk_text_view_remove(gorunum, arac)
        gtk_widget_unparent(renkMenusu)
        kapandi = true
    }
}
