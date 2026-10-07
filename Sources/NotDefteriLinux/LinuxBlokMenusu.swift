import CGtk
import Foundation
import NotDefteriCekirdek

private typealias Widget = UnsafeMutablePointer<GtkWidget>

private final class MenuEylemi<Eylem> {
    let calistir: Eylem
    init(_ calistir: Eylem) { self.calistir = calistir }
}

private func menuVerisiniBirak(_ veri: gpointer?, _ closure: UnsafeMutablePointer<GClosure>?) {
    if let veri { Unmanaged<AnyObject>.fromOpaque(veri).release() }
}

private let secimDegistiC: @convention(c) (gpointer?, gpointer?, gpointer?, gpointer?) -> Void = {
    _, _, _, veri in
    guard let veri else { return }
    Unmanaged<MenuEylemi<() -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir()
}

private let menuTusuC: @convention(c) (gpointer?, guint, guint, GdkModifierType, gpointer?) -> gboolean = {
    _, tus, _, durum, veri in
    guard let veri else { return 0 }
    return Unmanaged<MenuEylemi<(UInt32, UInt32) -> Bool>>.fromOpaque(veri)
        .takeUnretainedValue().calistir(tus, durum.rawValue) ? 1 : 0
}

/// 048 kancalarını kullanır; belge/tampon değişikliklerinin sahibi editördür.
enum LinuxBlokMenusu {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor) {
        let araclar = LinuxDuzenlemeAraclari(pencere: pencere, editor: editor)
        // GTK closure verileri ve eklenti durumu pencereyle yaşar, geri bağlar weak'tir.
        g_object_set_data_full(UnsafeMutableRawPointer(araclar.bulCubugu).assumingMemoryBound(to: GObject.self),
                              "nd-duzenleme-araclari", Unmanaged.passRetained(araclar).toOpaque(), { veri in
            if let veri { Unmanaged<LinuxDuzenlemeAraclari>.fromOpaque(veri).release() }
        })
    }
}

private final class LinuxDuzenlemeAraclari {
    private enum Komut: Int, CaseIterable {
        case baslik1, baslik2, baslik3, madde, numarali, yapilacak, alinti, kod, uyari, ayirici, sayfa
        var ad: String {
            ["Başlık 1", "Başlık 2", "Başlık 3", "Madde listesi", "Numaralı liste", "Yapılacak",
             "Alıntı", "Kod bloğu", "Uyarı kutusu", "Ayırıcı", "Alt sayfa"][rawValue]
        }
        var kisayollar: [String] {
            switch self {
            case .baslik1: return ["1", "b1"]
            case .baslik2: return ["2", "b2"]
            case .baslik3: return ["3", "b3"]
            case .kod: return ["code", "kod"]
            case .uyari: return ["att", "uyari"]
            case .sayfa: return ["page", "sayfa"]
            default: return []
            }
        }
        var tur: MetinBlogu.Tur? {
            switch self {
            case .madde: return .madde
            case .numarali: return .numarali
            case .yapilacak: return .yapilacak
            case .alinti: return .alinti
            case .uyari: return .uyari
            case .ayirici: return .ayirici
            default: return nil
            }
        }
    }

    private weak var pencere: LinuxPencere?
    private weak var editor: LinuxEditor?
    private let menu = gtk_popover_new()!
    private let bicimCubugu = gtk_popover_new()!
    private let baglanti = gtk_popover_new()!
    private var capalar: [Widget: Widget] = [:]
    private let menuKutusu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    private var menuDugmeleri: [Widget] = []
    private var komutlar: [Komut] = []
    private let diller = ["", "swift", "go", "python", "javascript", "typescript", "bash", "json", "sql", "html", "css"]
    private var dilEslesmeleri: [String] = []
    private var dilSorgusu: String?
    private var secili = 0
    private var slashAraligi: NSRange?
    private var kapatilanSlash: Int?
    private var baglantiSecimi: NSRange?
    private let urlGirisi = gtk_entry_new()!
    private let urlHatasi = gtk_label_new("")!
    let bulCubugu = gtk_search_bar_new()!
    private let bulGirisi = gtk_search_entry_new()!
    private let degistirGirisi = gtk_entry_new()!
    private let degistirSatiri = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
    private let bulSayaci = gtk_label_new("")!
    private var eslesmeler: [NSRange] = []
    private var etkinEslesme: NSRange?
    private let bulEtiketi: UnsafeMutablePointer<GtkTextTag>
    private var guncellemeBekliyor = false
    private var uygulaniyor = false
    private var nesil = 0
    private var yazimBicimleri: [NSAttributedString.Key: Bool] = [:]
    private var bulKapaniyor = false

    private func isaretci<T>(_ widget: Widget) -> UnsafeMutablePointer<T> {
        GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(widget))
    }
    private var gorunum: UnsafeMutablePointer<GtkTextView>? { editor.map { isaretci($0.metinGorunumu) } }
    private func acik(_ widget: Widget) -> Bool { gtk_widget_get_visible(widget) != 0 }
    private func giris(_ widget: Widget) -> String { String(cString: gtk_editable_get_text(OpaquePointer(widget))) }

    init(pencere: LinuxPencere, editor: LinuxEditor) {
        self.pencere = pencere
        self.editor = editor
        bulEtiketi = gtk_text_tag_new("nd-bul-eslesmesi")!
        var renk = GValue()
        g_value_init(&renk, g_type_from_name("gchararray"))
        g_value_set_string(&renk, "#d9a441")
        g_object_set_property(UnsafeMutableRawPointer(bulEtiketi).assumingMemoryBound(to: GObject.self), "background", &renk)
        g_value_unset(&renk)
        gtk_text_tag_table_add(gtk_text_buffer_get_tag_table(editor.tampon), bulEtiketi)
        g_object_unref(UnsafeMutableRawPointer(bulEtiketi)) // Tag table sahipliği devraldı.
        popoverKur(menu, konum: GTK_POS_BOTTOM)
        popoverKur(bicimCubugu, konum: GTK_POS_TOP)
        popoverKur(baglanti, konum: GTK_POS_TOP, odakli: true)
        gtk_popover_set_child(isaretci(menu), menuKutusu)
        bicimCubugunuKur()
        baglantiGirisiniKur()
        bulCubugunuKur(pencere)
        kancalariKur(editor, pencere)
    }

    private func dugme(_ ad: String, kutu: Widget, odakli: Bool = false, _ eylem: @escaping () -> Void) -> Widget {
        let widget = gtk_button_new_with_label(ad)!
        gtk_widget_set_focusable(widget, odakli ? 1 : 0)
        gtk_widget_set_focus_on_click(widget, odakli ? 1 : 0)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(widget), "clicked", eylem)
        gtk_box_append(nd_box(kutu), widget)
        return widget
    }

    private func popoverKur(_ popover: Widget, konum: GtkPositionType, odakli: Bool = false) {
        guard let gorunum else { return }
        // GtkMenuButton popover'ın yerleşimini ve yok edilmesini GTK 4.6'da yönetir.
        let capa = gtk_menu_button_new()!
        gtk_menu_button_set_child(OpaquePointer(capa), gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0))
        gtk_menu_button_set_has_frame(OpaquePointer(capa), 0)
        gtk_widget_set_focusable(capa, 0)
        gtk_widget_set_can_target(capa, 0)
        gtk_widget_set_size_request(capa, 1, 1)
        gtk_menu_button_set_popover(OpaquePointer(capa), popover)
        gtk_popover_set_position(isaretci(popover), konum)
        gtk_popover_set_has_arrow(isaretci(popover), 0)
        gtk_popover_set_autohide(isaretci(popover), odakli ? 1 : 0)
        gtk_text_view_add_overlay(gorunum, capa, 0, 0)
        capalar[popover] = capa
    }

    private func goster(_ popover: Widget, secimBasi: Bool = false) {
        guard let editor, let gorunum, let capa = capalar[popover] else { return }
        var iter = GtkTextIter(), kare = GdkRectangle()
        if secimBasi {
            var son = GtkTextIter()
            if gtk_text_buffer_get_selection_bounds(editor.tampon, &iter, &son) == 0 {
                gtk_text_buffer_get_iter_at_mark(editor.tampon, &iter, gtk_text_buffer_get_insert(editor.tampon))
            }
        } else {
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &iter, gtk_text_buffer_get_insert(editor.tampon))
        }
        gtk_text_view_get_iter_location(gorunum, &iter, &kare)
        var x: Int32 = 0, y: Int32 = 0
        gtk_text_view_buffer_to_window_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, kare.x, kare.y, &x, &y)
        guard y >= 0, y < gtk_widget_get_height(editor.metinGorunumu) else {
            gtk_popover_popdown(isaretci(popover)); return
        }
        gtk_text_view_move_overlay(gorunum, capa, kare.x, kare.y)
        var yerel = GdkRectangle(x: 0, y: 0, width: max(1, kare.width), height: max(1, kare.height))
        gtk_popover_set_pointing_to(isaretci(popover), &yerel)
        if !acik(popover) { gtk_popover_popup(isaretci(popover)) }
        gtk_popover_present(isaretci(popover))
    }

    private func tusBagla(_ widget: Widget, _ eylem: @escaping (UInt32, UInt32) -> Bool) {
        let controller = gtk_event_controller_key_new()!
        let veri = Unmanaged.passRetained(MenuEylemi(eylem)).toOpaque()
        g_signal_connect_data(UnsafeMutableRawPointer(controller), "key-pressed", unsafeBitCast(menuTusuC, to: GCallback.self),
                              veri, menuVerisiniBirak, GConnectFlags(rawValue: 0))
        gtk_event_controller_set_propagation_phase(controller, GTK_PHASE_CAPTURE)
        gtk_widget_add_controller(widget, controller)
    }

    private func kancalariKur(_ editor: LinuxEditor, _ pencere: LinuxPencere) {
        editor.tusOncesi.append { [weak self] in self?.tus($0, $1) ?? false }
        editor.degisiklikSonrasi.append { [weak self] in self?.guncellemeyiPlanla() }
        LinuxEklentiler.yasamDongusunuIzle(editor) { [weak self] in self?.sifirla() }
        // Tür açık yazılır: `self?.f()` çıkarımı `() -> Void?` verir ve generic kutu secimDegistiC'nin okuduğu `() -> Void` ile uyuşmaz.
        let veri = Unmanaged.passRetained(MenuEylemi<() -> Void> { [weak self] in self?.secimDegisti() }).toOpaque()
        g_signal_connect_data(UnsafeMutableRawPointer(editor.tampon), "mark-set", unsafeBitCast(secimDegistiC, to: GCallback.self),
                              veri, menuVerisiniBirak, GConnectFlags(rawValue: 0))
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.metinGorunumu), "notify::has-focus") { [weak self] (_: gpointer?) in
            self?.guncellemeyiPlanla()
        }
        if let kaydirma = gtk_widget_get_parent(editor.metinGorunumu) {
            for ayar in [gtk_scrolled_window_get_vadjustment(OpaquePointer(kaydirma)),
                         gtk_scrolled_window_get_hadjustment(OpaquePointer(kaydirma))] {
                if let ayar { GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(ayar), "value-changed") { [weak self] in self?.guncellemeyiPlanla() } }
            }
        }
        for (tetik, degistir) in [("<Control>f", false), ("<Control><Alt>f", true)] {
            pencere.kisayolEkle(tetik) { [weak self] in
                guard let self, self.duzenlemeOdagiVar else { return }
                self.bulAc(degistir: degistir)
            }
        }
        menuleriKaydet(pencere)
    }

    /// macOS Düzen > Bul ve Biçim menüleri. Kısayollar yukarıdaki kayıt ile editör tuş kancasında işlenir;
    /// menüde yalnızca görünür (çift tetiklenmez).
    private func menuleriKaydet(_ pencere: LinuxPencere) {
        let bul: [(String, String, () -> Void)] = [
            ("Bul…", "<Control>f", { [weak self] in self?.bulAc(degistir: false) }),
            ("Bul ve Değiştir…", "<Control><Alt>f", { [weak self] in self?.bulAc(degistir: true) }),
            ("Sonrakini Bul", "<Control>g", { [weak self] in self?.bulMenudenGezin(1) }),
            ("Öncekini Bul", "<Control><Shift>g", { [weak self] in self?.bulMenudenGezin(-1) })]
        for (ad, tetik, eylem) in bul { pencere.menuEkle(["Düzen", "Bul", ad], kisayol: tetik, kisayoluKaydet: false, eylem: eylem) }
        let bicim: [(String, String, () -> Void)] = [
            ("Üstü Çizili", "<Control><Shift>x", { [weak self] in self?.bicimDegistir(kUstuCiziliAnahtari) }),
            ("Satır İçi Kod", "<Control>e", { [weak self] in self?.bicimDegistir(kSatirIciKodAnahtari) }),
            ("Vurgu", "<Control><Alt>h", { [weak self] in self?.bicimDegistir(kVurguAnahtari) }),
            ("Bağlantı", "<Control>k", { [weak self] in self?.baglantiAc() })]
        for (ad, tetik, eylem) in bicim {
            pencere.menuEkle(["Biçim", ad], kisayol: tetik, kisayoluKaydet: false) { [weak self] in
                guard let editor = self?.editor, editor.editorEtkin else { return }
                gtk_widget_grab_focus(editor.metinGorunumu)
                eylem()
            }
        }
    }

    private func bulMenudenGezin(_ yon: Int) {
        guard editor?.editorEtkin == true else { return }
        bulGezin(yon)
    }

    private var duzenlemeOdagiVar: Bool {
        guard let pencere, let editor, editor.editorEtkin, let odak = gtk_window_get_focus(nd_window(pencere.pencere)) else { return false }
        return odak == editor.metinGorunumu || odak == bulCubugu || gtk_widget_is_ancestor(odak, bulCubugu) != 0
    }

    private func secimDegisti() {
        guard !uygulaniyor else { return }
        yazimBicimleri.removeAll()
        guncellemeyiPlanla()
    }

    private func guncellemeyiPlanla() {
        guard !guncellemeBekliyor, !uygulaniyor else { return }
        guncellemeBekliyor = true
        let beklenen = nesil
        // changed/mark-set anlamsal aynalama tamamlanmadan gelebilir.
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.nesil == beklenen else { return }
            self.guncellemeBekliyor = false
            self.guncelle()
        }
    }

    private func sifirla() {
        nesil += 1
        guncellemeBekliyor = false
        menuKapat()
        kapatilanSlash = nil
        baglantiSecimi = nil; yazimBicimleri.removeAll()
        gtk_popover_popdown(isaretci(bicimCubugu))
        gtk_popover_popdown(isaretci(baglanti))
        bulKapat(odakla: false)
        gtk_editable_set_text(OpaquePointer(bulGirisi), "")
        gtk_editable_set_text(OpaquePointer(degistirGirisi), "")
    }

    private func guncelle() {
        guard let editor, editor.editorEtkin else { sifirla(); return }
        if acik(bulCubugu), gtk_search_bar_get_search_mode(OpaquePointer(bulCubugu)) != 0 { eslesmeleriGuncelle() }
        guard gtk_widget_has_focus(editor.metinGorunumu) != 0, baglantiSecimi == nil else {
            menuKapat(); gtk_popover_popdown(isaretci(bicimCubugu)); return
        }
        let secim = LinuxMetinDonusumu.secim(editor.tampon)
        if secim.length > 0 {
            menuKapat()
            if gtk_search_bar_get_search_mode(OpaquePointer(bulCubugu)) == 0 { goster(bicimCubugu, secimBasi: true) }
            return
        }
        gtk_popover_popdown(isaretci(bicimCubugu))
        if dilSorgusu != nil {
            guard let slashAraligi, secim.location == NSMaxRange(slashAraligi) else { menuKapat(); return }
            goster(menu); return
        }
        slashGuncelle(secim)
    }

    @discardableResult
    private func slashGuncelle(_ secim: NSRange, kisayol: Bool = false) -> Bool {
        guard let editor, secim.length == 0 else { menuKapat(); return false }
        let imlec = secim.location
        // Tüm belgeyi NSString'e çevirmek yerine yalnızca imlecin satırının başından imlece kadarı okunur;
        // `yerel` belge konumunu bu dilime çevirir.
        var satirBasiIter = LinuxMetinDonusumu.iter(editor.tampon, imlec)
        gtk_text_iter_set_line_offset(&satirBasiIter, 0)
        let satirBasi = LinuxMetinDonusumu.konum(satirBasiIter)
        func yerel(_ aralik: NSRange) -> NSRange { NSRange(location: aralik.location - satirBasi, length: aralik.length) }
        return editor.belgeyiOku { belge in
            guard satirBasi <= imlec, imlec <= belge.length else { menuKapat(); return false }
            let ns = belge.attributedSubstring(from: NSRange(location: satirBasi, length: imlec - satirBasi)).string as NSString
            let yerelSlash = ns.range(of: "/", options: .backwards).location
            guard yerelSlash != NSNotFound else { menuKapat(); kapatilanSlash = nil; return false }
            let slash = satirBasi + yerelSlash
            guard
                  yerelSlash == blokIsaretiUzunlugu(belge, konum: satirBasi) ||
                    (yerelSlash > 0 && ns.rangeOfCharacter(from: .whitespaces, range: NSRange(location: yerelSlash - 1, length: 1)).location != NSNotFound),
                  belge.attribute(kKodBloguAnahtari, at: slash, effectiveRange: nil) == nil,
                  belge.attribute(kSatirIciKodAnahtari, at: slash, effectiveRange: nil) == nil else {
                menuKapat(); kapatilanSlash = nil; return false
            }
            let aralik = NSRange(location: slash, length: imlec - slash)
            let metin = ns.substring(with: yerel(aralik))
            let sorgu = String(metin.dropFirst())
            // Escape yalnızca menüyü kapatır; tam kısayol metni yine uygulanır.
            if kisayol, let komut = [Komut.kod, .uyari].first(where: { $0.kisayollar.contains(sorgu.lowercased()) }) {
                kapatilanSlash = nil
                slashAraligi = aralik
                komutlar = [komut]; secili = 0
                menuSeciminiPlanla(kisayol: true)
                return true
            }
            guard slash != kapatilanSlash else { menuKapat(); return false }
            guard sorgu.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { menuKapat(); return false }
            let sade = aramaIcinSadelestir(sorgu)
            let yeni = Komut.allCases.filter { sade.isEmpty || aramaIcinSadelestir($0.ad).contains(sade) || $0.kisayollar.contains { $0.hasPrefix(sade) } }
            guard !yeni.isEmpty else { menuKapat(); return false }
            slashAraligi = aralik
            if komutlar != yeni || menuDugmeleri.isEmpty {
                komutlar = yeni; secili = 0; menuSatirlariniKur(yeni.map(\.ad))
            }
            goster(menu)
            return false
        }
    }

    private func menuSatirlariniKur(_ adlar: [String]) {
        while let cocuk = gtk_widget_get_first_child(menuKutusu) { gtk_box_remove(nd_box(menuKutusu), cocuk) }
        menuDugmeleri.removeAll()
        if let sorgu = dilSorgusu {
            let dilBasligi = gtk_label_new("")!
            gtk_label_set_text(nd_label(dilBasligi), sorgu.isEmpty ? "Dil: yazarak filtrele" : "Dil: " + sorgu)
            gtk_box_append(nd_box(menuKutusu), dilBasligi)
        }
        for (sira, ad) in adlar.enumerated() {
            menuDugmeleri.append(dugme(ad, kutu: menuKutusu) { [weak self] in self?.secili = sira; self?.menuSeciminiPlanla() })
        }
        menuVurgula()
    }

    private func menuVurgula() {
        for (sira, dugme) in menuDugmeleri.enumerated() {
            // suggested-action temanın mavi vurgusudur; kağıt temasıyla uyumlu kendi sınıfımız kullanılır.
            if sira == secili { gtk_widget_add_css_class(dugme, "nd-etkin") }
            else { gtk_widget_remove_css_class(dugme, "nd-etkin") }
        }
    }

    private func menuKapat() {
        gtk_popover_popdown(isaretci(menu))
        slashAraligi = nil; dilSorgusu = nil; komutlar.removeAll()
    }

    private func tus(_ tus: UInt32, _ durum: UInt32) -> Bool {
        let ctrl = durum & GDK_CONTROL_MASK.rawValue != 0
        let alt = durum & GDK_ALT_MASK.rawValue != 0
        let shift = durum & GDK_SHIFT_MASK.rawValue != 0
        if ctrl {
            switch gdk_keyval_to_lower(tus) {
            case 0x67 where !alt: bulGezin(shift ? -1 : 1)
            case 0x78 where shift && !alt: bicimDegistir(kUstuCiziliAnahtari)
            case 0x65 where !alt && !shift: bicimDegistir(kSatirIciKodAnahtari)
            case 0x68 where alt && !shift: bicimDegistir(kVurguAnahtari)
            case 0x6b where !alt && !shift: baglantiAc()
            default: return false
            }
            return true
        }
        guard !alt else { return false }
        if tus == 0xff1b {
            guard acik(menu) || acik(bicimCubugu) || gtk_search_bar_get_search_mode(OpaquePointer(bulCubugu)) != 0 else { return false }
            kapatilanSlash = slashAraligi?.location
            menuKapat(); gtk_popover_popdown(isaretci(bicimCubugu)); bulKapat()
            return true
        }
        guard let editor, LinuxMetinDonusumu.secim(editor.tampon).length == 0 else { menuKapat(); return false }
        if !shift, dilSorgusu == nil, [0xff0d, 0xff8d, 0x20].contains(tus),
           slashGuncelle(LinuxMetinDonusumu.secim(editor.tampon), kisayol: true) {
            return true
        }
        guard acik(menu), !shift || dilSorgusu != nil else { return false }
        switch tus {
        case 0xff52, 0xff54:
            guard !menuDugmeleri.isEmpty else { return true }
            secili = (secili + (tus == 0xff52 ? -1 : 1) + menuDugmeleri.count) % menuDugmeleri.count
            menuVurgula()
        case 0xff0d, 0xff8d: menuSeciminiPlanla(kisayol: true)
        default:
            guard var sorgu = dilSorgusu else { return false }
            if tus == 0xff08 { if !sorgu.isEmpty { sorgu.removeLast() } }
            else if let scalar = UnicodeScalar(gdk_keyval_to_unicode(tus)), CharacterSet.alphanumerics.contains(scalar) { sorgu.append(String(scalar)) }
            dilSorgusu = sorgu; dilleriFiltrele()
        }
        return true
    }

    private func dilleriFiltrele() {
        let sorgu = dilSorgusu?.lowercased() ?? ""
        dilEslesmeleri = diller.filter { sorgu.isEmpty || $0.contains(sorgu) || dilAdiniNormallestir(sorgu) == $0 }
        secili = 0
        menuSatirlariniKur(dilEslesmeleri.map { $0.isEmpty ? "Dil yok" : $0 })
        goster(menu)
    }

    private func kisayolMu(_ komut: Komut) -> Bool {
        guard let editor, let aralik = slashAraligi else { return false }
        return editor.belgeyiOku { belge in
            guard NSMaxRange(aralik) <= belge.length else { return false }
            let sorgu = String((belge.string as NSString).substring(with: aralik).dropFirst()).lowercased()
            return komut.kisayollar.contains(sorgu)
        }
    }

    private func menuSeciminiPlanla(kisayol: Bool = false) {
        guard let editor else { return }
        let url = editor.acikURL, aralik = slashAraligi, secim = LinuxMetinDonusumu.secim(editor.tampon), surum = nesil
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.nesil == surum, editor.acikURL == url, self.slashAraligi == aralik,
                  LinuxMetinDonusumu.secim(editor.tampon) == secim else { return }
            self.menuSec(kisayol: kisayol)
        }
    }

    private func menuSec(kisayol: Bool = false) {
        guard let editor, let aralik = slashAraligi, NSMaxRange(aralik) <= editor.belge.length else { menuKapat(); return }
        guard LinuxMetinDonusumu.secim(editor.tampon) == NSRange(location: NSMaxRange(aralik), length: 0),
              (editor.belge.string as NSString).substring(with: aralik).hasPrefix("/") else { menuKapat(); return }
        if dilSorgusu != nil {
            guard dilEslesmeleri.indices.contains(secili) else { return }
            let dil = dilEslesmeleri[secili]
            menuKapat(); paragrafDonustur(aralik, dil: dil); return
        }
        guard komutlar.indices.contains(secili) else { return }
        let komut = komutlar[secili]
        if komut == .kod {
            if kisayol, kisayolMu(.kod) { menuKapat(); paragrafDonustur(aralik, dil: ""); return }
            dilSorgusu = ""; dilleriFiltrele(); return
        }
        menuKapat()
        if komut.rawValue <= Komut.baslik3.rawValue { paragrafDonustur(aralik, baslik: komut.rawValue + 1); return }
        uygulaniyor = true
        gtk_text_buffer_begin_user_action(editor.tampon)
        editor.aralikDegistir(aralik, ile: NSAttributedString(string: ""))
        if let tur = komut.tur { editor.blokUygula(tur) }
        gtk_text_buffer_end_user_action(editor.tampon)
        uygulaniyor = false
        if komut == .sayfa { altSayfaOlustur() }
        guncellemeyiPlanla()
    }

    private func paragrafDonustur(_ slash: NSRange, baslik: Int? = nil, dil: String? = nil) {
        guard let editor else { return }
        let belge = editor.belge
        let paragraf = (belge.string as NSString).paragraphRange(for: NSRange(location: slash.location, length: 0))
        guard NSMaxRange(slash) <= NSMaxRange(paragraf) else { return }
        let yeni = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: paragraf))
        yeni.deleteCharacters(in: NSRange(location: slash.location - paragraf.location, length: slash.length))
        var isaretler: [NSRange] = []
        yeni.enumerateAttribute(kBlokIsaretiAnahtari, in: NSRange(location: 0, length: yeni.length)) { deger, alt, _ in
            if deger as? Bool == true { isaretler.append(alt) }
        }
        for alt in isaretler.reversed() { yeni.deleteCharacters(in: alt) }
        blokBiciminiKaldir(yeni)
        let tumu = NSRange(location: 0, length: yeni.length)
        for anahtar in [kKodBloguAnahtari, kKodBloguDiliAnahtari, kBaslikSeviyesiAnahtari, kKalinAnahtari, kItalikAnahtari, kPuntoOlcegiAnahtari, kMarkdownKaynakAnahtari] {
            yeni.removeAttribute(anahtar, range: tumu)
        }
        var oznitelikler: [NSAttributedString.Key: Any] = [:]
        if let baslik { oznitelikler[kBaslikSeviyesiAnahtari] = baslik }
        if let dil {
            let sinirlar = kodBloguSinirlari(acilis: "```" + dil + "\n", kapanis: "```\n")
            oznitelikler = [kKodBloguAnahtari: sinirlar, kKodBloguDiliAnahtari: dil, kBlokKimligiAnahtari: sinirlar["kimlik"]!]
            yeni.setAttributes(oznitelikler, range: tumu)
        } else { yeni.addAttributes(oznitelikler, range: tumu) }
        let isaretGerekli = dil != nil || yeni.length == 0
        if isaretGerekli {
            var isaret = oznitelikler; isaret[kBlokIsaretiAnahtari] = true
            yeni.insert(NSAttributedString(string: "\u{200B}", attributes: isaret), at: 0)
        }
        uygulaniyor = true
        let kapsam = listeKapsami(paragraf, belge: belge)
        let degisim = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: kapsam))
        degisim.replaceCharacters(in: NSRange(location: paragraf.location - kapsam.location, length: paragraf.length), with: yeni)
        var secim = NSRange(location: paragraf.location - kapsam.location + (isaretGerekli ? 1 : 0), length: 0)
        blokNumaralariniGuncelle(degisim, secim: &secim)
        editor.aralikDegistir(kapsam, ile: degisim)
        secim.location += kapsam.location
        LinuxMetinDonusumu.secimiAyarla(editor.tampon, secim)
        for (anahtar, deger) in oznitelikler { editor.satirIciBicimUygula(anahtar, deger: deger) }
        uygulaniyor = false
        guncellemeyiPlanla()
    }

    private func listeKapsami(_ paragraf: NSRange, belge: NSAttributedString) -> NSRange {
        guard paragraf.location < belge.length,
              MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: paragraf.location, effectiveRange: nil))?.listeMi == true else { return paragraf }
        let ns = belge.string as NSString
        var bas = paragraf.location, son = NSMaxRange(paragraf)
        func listeMi(_ konum: Int) -> Bool {
            MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil))?.listeMi == true
        }
        while bas > 0 {
            let onceki = ns.paragraphRange(for: NSRange(location: bas - 1, length: 0))
            guard listeMi(onceki.location) else { break }
            bas = onceki.location
        }
        while son < ns.length, listeMi(son) {
            son = NSMaxRange(ns.paragraphRange(for: NSRange(location: son, length: 0)))
        }
        return NSRange(location: bas, length: son - bas)
    }

    private func altSayfaOlustur() {
        guard let editor, let ust = editor.acikURL else { return }
        editor.islemOncesi { [weak self] in self?.altSayfayiYaz(ust) }
    }

    private func altSayfayiYaz(_ ust: URL) {
        guard let editor, editor.acikURL == ust else { return }
        let url = benzersizSayfaURLSonucu(taban: "Yeni Sayfa", klasor: sayfaKlasoru(ust)).url
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: url, atomically: true, encoding: .utf8)
            (pencere?.kenarPaneli as? LinuxKenarPaneli)?.yenile()
            editor.yeniSayfayiAc(url)
        } catch { hataGoster("Sayfa oluşturulamadı: " + error.localizedDescription) }
    }

    private func bicimCubugunuKur() {
        let kutu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 2)!
        let bicimler = [("Kalın", kKalinAnahtari), ("İtalik", kItalikAnahtari), ("Çizili", kUstuCiziliAnahtari), ("Kod", kSatirIciKodAnahtari), ("Vurgu", kVurguAnahtari)]
        for (ad, anahtar) in bicimler { _ = dugme(ad, kutu: kutu) { [weak self] in self?.bicimDegistir(anahtar) } }
        _ = dugme("Bağlantı", kutu: kutu) { [weak self] in self?.baglantiAc() }
        gtk_popover_set_child(isaretci(bicimCubugu), kutu)
    }

    private func bicimDegistir(_ anahtar: NSAttributedString.Key) {
        guard let editor else { return }
        let secim = LinuxMetinDonusumu.secim(editor.tampon), belge = editor.belge
        func etkin(_ o: [NSAttributedString.Key: Any]) -> Bool {
            anahtar == kKalinAnahtari ? (o[anahtar] as? Bool ?? (o[kBaslikSeviyesiAnahtari] != nil)) : o[anahtar] as? Bool == true
        }
        var tumuEtkin = true
        if secim.length > 0 {
            belge.enumerateAttributes(in: secim) { o, _, dur in
                if !etkin(o) { tumuEtkin = false; dur.pointee = true }
            }
        } else {
            tumuEtkin = yazimBicimleri[anahtar] ?? (belge.length > 0 && etkin(belge.attributes(at: min(max(0, secim.location - 1), belge.length - 1), effectiveRange: nil)))
        }
        uygulaniyor = true
        // false başlıkta doğal kalınlığı da geçersiz kılar.
        editor.satirIciBicimUygula(anahtar, deger: tumuEtkin ? (anahtar == kKalinAnahtari ? false : nil) : true)
        uygulaniyor = false
        if secim.length == 0 { yazimBicimleri[anahtar] = !tumuEtkin }
        guncellemeyiPlanla()
    }

    private func baglantiGirisiniKur() {
        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6)!
        gtk_entry_set_placeholder_text(isaretci(urlGirisi), "https://… (boş: bağlantıyı kaldır)")
        gtk_widget_set_size_request(urlGirisi, 320, -1)
        gtk_box_append(nd_box(kutu), urlGirisi)
        gtk_label_set_wrap(nd_label(urlHatasi), 1)
        gtk_box_append(nd_box(kutu), urlHatasi)
        let dugmeler = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        _ = dugme("Uygula", kutu: dugmeler, odakli: true) { [weak self] in self?.baglantiUygula() }
        _ = dugme("Vazgeç", kutu: dugmeler, odakli: true) { [weak self] in self?.baglantiKapat() }
        gtk_box_append(nd_box(kutu), dugmeler)
        gtk_popover_set_child(isaretci(baglanti), kutu)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(urlGirisi), "activate") { [weak self] in self?.baglantiUygula() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(baglanti), "closed") { [weak self] in self?.baglantiSecimi = nil }
    }

    private func baglantiAc() {
        guard let editor else { return }
        baglantiSecimi = LinuxMetinDonusumu.secim(editor.tampon)
        let belge = editor.belge, konum = baglantiSecimi!.location
        let url = konum < belge.length ? belge.attribute(kBaglantiAnahtari, at: konum, effectiveRange: nil) as? URL : nil
        gtk_editable_set_text(OpaquePointer(urlGirisi), url?.absoluteString ?? "")
        gtk_label_set_text(nd_label(urlHatasi), "")
        menuKapat(); gtk_popover_popdown(isaretci(bicimCubugu))
        goster(baglanti, secimBasi: true)
        gtk_widget_grab_focus(urlGirisi)
    }

    private func baglantiUygula() {
        guard let editor, let secim = baglantiSecimi, NSMaxRange(secim) <= editor.belge.length else { baglantiKapat(); return }
        let metin = giris(urlGirisi).trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: metin)
        guard metin.isEmpty || url.map(disBaglantiGecerliMi) == true else {
            gtk_label_set_text(nd_label(urlHatasi), "Yalnızca http, https veya mailto URL kullanılabilir."); return
        }
        uygulaniyor = true
        gtk_text_buffer_begin_user_action(editor.tampon)
        LinuxMetinDonusumu.secimiAyarla(editor.tampon, secim)
        if secim.length == 0, !metin.isEmpty {
            let o = editor.belgeyiOku { belge in
                var o = belge.length > 0 ? belge.attributes(at: min(max(0, secim.location - 1), belge.length - 1), effectiveRange: nil) : [:]
                for anahtar in [kBlokIsaretiAnahtari, kGorselAnahtari, kBosKodSatiriAnahtari, kMarkdownKaynakAnahtari] { o.removeValue(forKey: anahtar) }
                return o
            }
            editor.aralikDegistir(secim, ile: NSAttributedString(string: metin, attributes: o))
            LinuxMetinDonusumu.secimiAyarla(editor.tampon, NSRange(location: secim.location, length: (metin as NSString).length))
        }
        editor.satirIciBicimUygula(kCiplakBagAnahtari, deger: nil)
        editor.satirIciBicimUygula(kBaglantiAnahtari, deger: metin.isEmpty ? nil : url)
        gtk_text_buffer_end_user_action(editor.tampon)
        uygulaniyor = false
        baglantiKapat()
    }

    private func baglantiKapat() {
        baglantiSecimi = nil
        gtk_popover_popdown(isaretci(baglanti))
        if let editor { gtk_widget_grab_focus(editor.metinGorunumu) }
        guncellemeyiPlanla()
    }

    private func hataGoster(_ mesaj: String) {
        // GTK 4.6; giriş aralığı taşımayan mevcut popover içinde görünür hata.
        baglantiSecimi = nil
        gtk_editable_set_text(OpaquePointer(urlGirisi), "")
        gtk_label_set_text(nd_label(urlHatasi), mesaj)
        goster(baglanti)
    }

    private func bulCubugunuKur(_ pencere: LinuxPencere) {
        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4)!
        let satir = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        gtk_widget_set_hexpand(bulGirisi, 1)
        gtk_box_append(nd_box(satir), bulGirisi)
        gtk_box_append(nd_box(satir), bulSayaci)
        let onceki = dugme("↑", kutu: satir, odakli: true) { [weak self] in self?.bulGezin(-1) }
        let sonraki = dugme("↓", kutu: satir, odakli: true) { [weak self] in self?.bulGezin(1) }
        gtk_widget_set_tooltip_text(onceki, "Öncekini bul (Shift+Enter)")
        gtk_widget_set_tooltip_text(sonraki, "Sonrakini bul (Enter)")
        gtk_box_append(nd_box(kutu), satir)
        gtk_entry_set_placeholder_text(isaretci(degistirGirisi), "Yerine…")
        gtk_widget_set_hexpand(degistirGirisi, 1)
        gtk_box_append(nd_box(degistirSatiri), degistirGirisi)
        _ = dugme("Değiştir", kutu: degistirSatiri, odakli: true) { [weak self] in self?.bulDegistir(tumu: false) }
        _ = dugme("Tümünü değiştir", kutu: degistirSatiri, odakli: true) { [weak self] in self?.bulDegistir(tumu: true) }
        gtk_box_append(nd_box(kutu), degistirSatiri)
        gtk_search_bar_set_child(OpaquePointer(bulCubugu), kutu)
        gtk_search_bar_connect_entry(OpaquePointer(bulCubugu), OpaquePointer(bulGirisi))
        gtk_search_bar_set_show_close_button(OpaquePointer(bulCubugu), 1)
        gtk_box_prepend(nd_box(pencere.editorYuvasi), bulCubugu)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(bulGirisi), "search-changed") { [weak self] in
            self?.etkinEslesme = nil; self?.eslesmeleriGuncelle(); self?.bulGezin(1)
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(bulCubugu), "notify::search-mode-enabled") { [weak self] (_: gpointer?) in
            guard let self, !self.bulKapaniyor, gtk_search_bar_get_search_mode(OpaquePointer(self.bulCubugu)) == 0 else { return }
            self.bulKapat(odakla: self.duzenlemeOdagiVar)
        }
        tusBagla(bulCubugu) { [weak self] tus, durum in
            guard let self else { return false }
            if tus == 0xff1b { self.bulKapat(); return true }
            if tus == 0xff0d || tus == 0xff8d { self.bulGezin(durum & GDK_SHIFT_MASK.rawValue != 0 ? -1 : 1); return true }
            return false
        }
        bulKapat(odakla: false)
    }

    private func bulAc(degistir: Bool) {
        guard let editor, editor.editorEtkin else { return }
        menuKapat(); gtk_popover_popdown(isaretci(bicimCubugu)); baglantiSecimi = nil
        gtk_popover_popdown(isaretci(baglanti))
        let secim = LinuxMetinDonusumu.secim(editor.tampon)
        if secim.length > 0 { gtk_editable_set_text(OpaquePointer(bulGirisi), (editor.belge.string as NSString).substring(with: secim)) }
        gtk_widget_set_visible(degistirSatiri, degistir ? 1 : 0)
        gtk_widget_set_visible(bulCubugu, 1)
        gtk_search_bar_set_search_mode(OpaquePointer(bulCubugu), 1)
        eslesmeleriGuncelle()
        gtk_widget_grab_focus(bulGirisi)
    }

    private func bulKapat(odakla: Bool = true) {
        guard !bulKapaniyor else { return }
        bulKapaniyor = true
        defer { bulKapaniyor = false }
        gtk_search_bar_set_search_mode(OpaquePointer(bulCubugu), 0)
        gtk_widget_set_visible(bulCubugu, 0)
        eslesmeler.removeAll(); etkinEslesme = nil
        bulVurgulariniSil()
        if odakla, let editor { gtk_widget_grab_focus(editor.metinGorunumu) }
    }

    private func bulVurgulariniSil() {
        guard let editor else { return }
        var bas = GtkTextIter(), son = GtkTextIter()
        gtk_text_buffer_get_bounds(editor.tampon, &bas, &son)
        gtk_text_buffer_remove_tag(editor.tampon, bulEtiketi, &bas, &son)
    }

    private func eslesmeleriGuncelle() {
        guard let editor else { return }
        bulVurgulariniSil(); eslesmeler.removeAll()
        guard gtk_search_bar_get_search_mode(OpaquePointer(bulCubugu)) != 0 else { return }
        let sorgu = giris(bulGirisi), belge = editor.belge, ns = belge.string as NSString
        // Adaptör yeni etiketler oluşturabilir; arama vurgusu onların üstünde kalır.
        let tablo = gtk_text_buffer_get_tag_table(editor.tampon)
        gtk_text_tag_set_priority(bulEtiketi, gtk_text_tag_table_get_size(tablo) - 1)
        if !sorgu.isEmpty {
            var konum = 0
            while konum < ns.length {
                let alt = ns.range(of: sorgu, options: .caseInsensitive, range: NSRange(location: konum, length: ns.length - konum))
                guard alt.location != NSNotFound, alt.length > 0 else { break }
                var yapisal = false
                belge.enumerateAttributes(in: alt) { o, _, _ in
                    if o[kBlokIsaretiAnahtari] as? Bool == true || o[kGorselAnahtari] != nil || o[kBosKodSatiriAnahtari] as? Bool == true { yapisal = true }
                }
                if !yapisal {
                    eslesmeler.append(alt)
                    var (bas, son) = GtkKoprusu.iterler(editor.tampon, alt, metin: ns)
                    gtk_text_buffer_apply_tag(editor.tampon, bulEtiketi, &bas, &son)
                }
                konum = NSMaxRange(alt)
            }
        }
        if let etkinEslesme, !eslesmeler.contains(etkinEslesme) { self.etkinEslesme = nil }
        sayaciGuncelle()
    }

    private func sayaciGuncelle() {
        let sira = etkinEslesme.flatMap { eslesmeler.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        gtk_label_set_text(nd_label(bulSayaci), "\(sira)/\(eslesmeler.count)")
    }

    private func bulGezin(_ yon: Int) {
        guard let editor, let gorunum else { return }
        eslesmeleriGuncelle()
        guard !eslesmeler.isEmpty else { return }
        let sira: Int
        if let etkinEslesme, let mevcut = eslesmeler.firstIndex(of: etkinEslesme) {
            sira = (mevcut + yon + eslesmeler.count) % eslesmeler.count
        } else {
            let konum = LinuxMetinDonusumu.secim(editor.tampon).location
            sira = yon > 0 ? (eslesmeler.firstIndex { $0.location >= konum } ?? 0)
                : (eslesmeler.lastIndex { $0.location < konum } ?? eslesmeler.count - 1)
        }
        let hedef = eslesmeler[sira]
        etkinEslesme = hedef
        uygulaniyor = true
        LinuxMetinDonusumu.secimiAyarla(editor.tampon, hedef)
        uygulaniyor = false
        var iter = LinuxMetinDonusumu.iter(editor.tampon, hedef.location)
        gtk_text_view_scroll_to_iter(gorunum, &iter, 0.15, 0, 0, 0)
        sayaciGuncelle()
    }

    private func bulDegistir(tumu: Bool) {
        guard let editor else { return }
        eslesmeleriGuncelle()
        if !tumu, etkinEslesme == nil { bulGezin(1) }
        let hedefler = tumu ? eslesmeler : etkinEslesme.map { [$0] } ?? []
        guard let ilk = hedefler.first, let son = hedefler.last else { return }
        let belge = editor.belge, metin = giris(degistirGirisi)
        let kapsam = NSRange(location: ilk.location, length: NSMaxRange(son) - ilk.location)
        let yeni = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: kapsam))
        for alt in hedefler.reversed() {
            var o = belge.attributes(at: alt.location, effectiveRange: nil)
            for anahtar in [kMarkdownKaynakAnahtari, kCiplakBagAnahtari, kSayfaBagiAnahtari, kKacisliKoseParantezAnahtari] { o.removeValue(forKey: anahtar) }
            yeni.replaceCharacters(in: NSRange(location: alt.location - kapsam.location, length: alt.length),
                                  with: NSAttributedString(string: metin, attributes: o))
        }
        uygulaniyor = true
        // Tümü için de tek aynalama ve tek undo; GtkTextIter değişim boyunca tutulmaz.
        editor.aralikDegistir(kapsam, ile: yeni)
        uygulaniyor = false
        etkinEslesme = nil
        eslesmeleriGuncelle()
        if !tumu { bulGezin(1) }
    }
}
