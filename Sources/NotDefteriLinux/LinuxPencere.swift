import CGtk
import Foundation
import NotDefteriCekirdek

final class LinuxPencere {
    let pencere: UnsafeMutablePointer<GtkWidget>
    let kenarPanelYuvasi = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    let editorYuvasi = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    let sagPanelYuvasi = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    // Bileşenler pencereyle yaşar; bileşenlerin pencereye geri bağı weak olmalıdır.
    var kenarPaneli: AnyObject?
    var editor: LinuxEditor?

    let anaSayfaYuvasi = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    let sayfaUstYuvasi = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    let sayfaAltYuvasi = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    private let sayfaKutusu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    private var anaSayfaAcik = false
    private let menuModeli = g_menu_new()!
    private let menuEylemleri = g_simple_action_group_new()!
    private var altMenuler: [[String]: OpaquePointer] = [:]
    private var menuKayitlari: [[String]: (eylem: OpaquePointer, isaretli: Bool?, govde: () -> Void)] = [:]
    private var menuSirasi: [[String]] = []
    private var menuTetikleri: [[String]: String] = [:]
    /// Menü macOS'taki sırayla açılır; öğeler hangi eklentiden gelirse gelsin kendi başlığına düşer.
    private static let ustMenuler = ["Not Defteri", "Dosya", "Düzen", "Biçim", "Görünüm", "Not", "Git", "Yardım"]

    private let bolme = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL)!
    private let baslik = gtk_label_new("Not Defteri")!
    // macOS BaslikCubugu.sayfaYolunuGoster: iki ve daha çok sayfalık yol tıklanabilir düğmelerle gösterilir.
    private let yolKutusu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 2)!
    private var yolSayfalari: [URL] = []
    private let kisayollar = gtk_shortcut_controller_new()!
    private let tema: LinuxTema
    private var kenarPanelGizli = gAyarlar.bool(forKey: "kenarPanelGizli")
    private var genislikAyarlaniyor = false

    init(uygulama: UnsafeMutablePointer<GtkApplication>) {
        pencere = gtk_application_window_new(uygulama)!
        tema = LinuxTema(display: gtk_widget_get_display(pencere)!)
        gtk_widget_add_css_class(pencere, "notdefteri")
        gtk_window_set_title(nd_window(pencere), "Not Defteri")
        gtk_window_set_default_size(nd_window(pencere), 680, 520)
        gtk_widget_set_size_request(pencere, 460, 320)
        gtk_widget_insert_action_group(pencere, "pencere", OpaquePointer(menuEylemleri))
        ustMenuleriKur()
        baslikCubugunuKur()
        yuvalariKur()
        gtk_shortcut_controller_set_scope(nd_shortcut_controller(kisayollar), GTK_SHORTCUT_SCOPE_GLOBAL)
        gtk_event_controller_set_propagation_phase(kisayollar, GTK_PHASE_CAPTURE)
        gtk_widget_add_controller(pencere, kisayollar) // Controller'ın sahipliği pencereye geçer.
        menuEkle(["Görünüm", "Kenar paneli"], kisayol: "<Control>backslash") { [weak self] in self?.kenarPaneliniAcKapa() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(bolme), "notify::position") { [weak self] (_: gpointer?) in
            self?.panelGenisliginiKaydet()
        }
    }

    deinit {
        for menu in altMenuler.values { g_object_unref(UnsafeMutableRawPointer(menu)) }
        g_object_unref(UnsafeMutableRawPointer(menuModeli))
        g_object_unref(UnsafeMutableRawPointer(menuEylemleri))
    }

    /// `kisayoluKaydet: false`: kısayolu başka bir yol (GTK metin görünümü, editör tuş kancası) zaten işler;
    /// burada yalnızca menüde ve kısayol penceresinde görünür, çift tetiklenmez.
    func menuEkle(_ yol: [String], kisayol: String?, kisayoluKaydet: Bool = true, eylem: @escaping () -> Void) {
        guard let baslik = yol.last, !baslik.isEmpty, menuKayitlari[yol] == nil else { return }
        let ad = "eylem\(menuKayitlari.count)"
        menuEyleminiKur(yol, ad: ad, etkin: true, isaretli: nil, govde: eylem)
        let calistir: () -> Void = { [weak self] in self?.menuyuCalistir(yol) }
        var menu = menuModeli
        var ustYol: [String] = []
        for parca in yol.dropLast() {
            ustYol.append(parca)
            if let mevcut = altMenuler[ustYol] { menu = mevcut; continue }
            let alt = g_menu_new()!
            g_menu_append_submenu(menu, parca, GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(alt)))
            altMenuler[ustYol] = alt
            menu = alt
        }
        let oge = g_menu_item_new(baslik, "pencere." + ad)!
        if let kisayol { g_menu_item_set_attribute_value(oge, "accel", g_variant_new_string(kisayol)) }
        g_menu_append_item(menu, oge)
        g_object_unref(UnsafeMutableRawPointer(oge))
        menuSirasi.append(yol)
        if let kisayol {
            menuTetikleri[yol] = kisayol
            if kisayoluKaydet { kisayolEkle(kisayol, calistir) }
        }
    }

    /// Kayıtlı menü öğeleri ve kısayolları (macOS NSApp.mainMenu); `kisayol` görünen metindir ("Ctrl+S").
    var menuKisayollari: [(yol: [String], kisayol: String?)] {
        Self.ustMenuler.flatMap { baslik in
            menuSirasi.filter { $0.first == baslik }.map { (yol: $0, kisayol: menuTetikleri[$0].map(kisayolMetni)) }
        }
    }

    private func kisayolMetni(_ tetik: String) -> String {
        guard let trigger = gtk_shortcut_trigger_parse_string(tetik) else { return tetik }
        defer { g_object_unref(UnsafeMutableRawPointer(trigger)) }
        guard let ham = gtk_shortcut_trigger_to_label(trigger, gtk_widget_get_display(pencere)) else { return tetik }
        defer { g_free(ham) }
        return String(cString: ham)
    }

    private func ustMenuleriKur() {
        for baslik in Self.ustMenuler {
            let alt = g_menu_new()!
            g_menu_append_submenu(menuModeli, baslik, GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(alt)))
            altMenuler[[baslik]] = alt
        }
    }

    func menuDurumu(_ yol: [String], etkin: Bool, isaretli: Bool?) {
        guard let kayit = menuKayitlari[yol] else { return }
        if (kayit.isaretli != nil) != (isaretli != nil) {
            let ad = String(cString: g_action_get_name(kayit.eylem))
            menuEyleminiKur(yol, ad: ad, etkin: etkin, isaretli: isaretli, govde: kayit.govde)
            return
        }
        g_simple_action_set_enabled(kayit.eylem, etkin ? 1 : 0)
        if let isaretli { g_simple_action_set_state(kayit.eylem, g_variant_new_boolean(isaretli ? 1 : 0)) }
        menuKayitlari[yol]?.isaretli = isaretli
    }

    private func menuEyleminiKur(_ yol: [String], ad: String, etkin: Bool, isaretli: Bool?, govde: @escaping () -> Void) {
        let eylem = isaretli.map { g_simple_action_new_stateful(ad, nil, g_variant_new_boolean($0 ? 1 : 0))! }
            ?? g_simple_action_new(ad, nil)!
        g_simple_action_set_enabled(eylem, etkin ? 1 : 0)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(eylem), "activate") { [weak self] (_: gpointer?) in
            self?.menuyuCalistir(yol)
        }
        menuKayitlari[yol] = (eylem, isaretli, govde)
        g_action_map_add_action(OpaquePointer(menuEylemleri), eylem)
        g_object_unref(UnsafeMutableRawPointer(eylem))
    }

    private func menuyuCalistir(_ yol: [String]) {
        let beklenen = editor?.nesil
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.editor?.nesil == beklenen, let kayit = self.menuKayitlari[yol],
                  g_action_get_enabled(kayit.eylem) != 0 else { return }
            kayit.govde()
        }
    }

    func icerigiGoster(anaSayfa: Bool) {
        guard anaSayfa != anaSayfaAcik else { return }
        if anaSayfa, let editor {
            editor.islemOncesi { [weak self] in self?.icerikModunuUygula(anaSayfa: true) }
        } else {
            icerikModunuUygula(anaSayfa: anaSayfa)
        }
    }

    private func icerikModunuUygula(anaSayfa: Bool) {
        anaSayfaAcik = anaSayfa
        gtk_widget_set_visible(sayfaKutusu, anaSayfa ? 0 : 1)
        gtk_widget_set_visible(anaSayfaYuvasi, anaSayfa ? 1 : 0)
        editor?.etkinligiAyarla(anaSayfa: anaSayfa)
        if anaSayfa { basligiAyarla([]) }
        else if let url = editor?.acikURL { basligiAyarla(sayfaYolu(url)) }
    }

    /// Pencere başlığı ve başlık çubuğu yolu; yol iki ve daha çok sayfaysa her adım bir düğmedir.
    func basligiAyarla(_ yol: [URL]) {
        let metin = yol.isEmpty ? "Not Defteri" : yol.map(sayfaAdi).joined(separator: " › ")
        gtk_label_set_text(nd_label(baslik), metin)
        gtk_widget_set_tooltip_text(baslik, metin)
        gtk_window_set_title(nd_window(pencere), metin)
        sayfaYolunuGoster(yol)
    }

    private func sayfaYolunuGoster(_ yeni: [URL]) {
        guard yolSayfalari != yeni else { return }
        yolSayfalari = yeni
        while let alt = gtk_widget_get_first_child(yolKutusu) { gtk_box_remove(nd_box(yolKutusu), alt) }
        let yolVar = yeni.count >= 2
        gtk_widget_set_visible(yolKutusu, yolVar ? 1 : 0)
        gtk_widget_set_visible(baslik, yolVar ? 0 : 1)
        guard yolVar else { return }
        for (sira, url) in yeni.enumerated() {
            if sira > 0 { gtk_box_append(nd_box(yolKutusu), gtk_label_new("›")) }
            let dugme = gtk_button_new_with_label(sayfaAdi(url))!
            gtk_widget_add_css_class(dugme, "flat")
            gtk_widget_set_focus_on_click(dugme, 0)
            gtk_widget_set_tooltip_text(dugme, sayfaAdi(url))
            if let etiket = gtk_button_get_child(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(dugme))) {
                gtk_label_set_ellipsize(nd_label(etiket), PANGO_ELLIPSIZE_MIDDLE)
                gtk_label_set_max_width_chars(nd_label(etiket), 24)
            }
            // Tıklama yolu yeniden kurar; düğme kendi sinyalinden sökülmesin diye ana döngüye ertelenir.
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked") { [weak self] in
                Platform.anaIsParcaciginda { self?.notSecildi(url) }
            }
            gtk_box_append(nd_box(yolKutusu), dugme)
        }
    }

    func kisayolEkle(_ tetik: String, _ eylem: @escaping () -> Void) {
        guard let trigger = gtk_shortcut_trigger_parse_string(tetik) else {
            preconditionFailure("Geçersiz GTK kısayolu: \(tetik)")
        }
        // new ve add_shortcut, trigger/action ve shortcut sahipliğini devralır.
        let kisayol = gtk_shortcut_new(trigger, GtkKoprusu.kisayolEylemi(eylem))!
        gtk_shortcut_controller_add_shortcut(nd_shortcut_controller(kisayollar), kisayol)
    }

    /// 046'nın seçim çıkışı, 047'nin editörüne buradan bağlanır.
    func notSecildi(_ url: URL) { editor?.notuAc(url) }

    func temayiUygula() { tema.uygula() }

    func kenarPaneliniAcKapa() {
        kenarPanelGizli.toggle()
        gAyarlar.set(kenarPanelGizli, forKey: "kenarPanelGizli")
        if kenarPanelGizli, let odak = gtk_window_get_focus(nd_window(pencere)),
           odak == kenarPanelYuvasi || gtk_widget_is_ancestor(odak, kenarPanelYuvasi) != 0 {
            gtk_widget_child_focus(editorYuvasi, GTK_DIR_TAB_FORWARD)
        }
        genislikAyarlaniyor = true
        gtk_widget_set_visible(kenarPanelYuvasi, kenarPanelGizli ? 0 : 1)
        if !kenarPanelGizli { gtk_paned_set_position(nd_paned(bolme), Int32(gKenarPanelGenislik)) }
        genislikAyarlaniyor = false
    }

    private func baslikCubugunuKur() {
        let cubuk = gtk_header_bar_new()!
        gtk_widget_add_css_class(cubuk, "nd-baslik")
        gtk_label_set_ellipsize(nd_label(baslik), PANGO_ELLIPSIZE_END)
        let baslikKutusu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_box_append(nd_box(baslikKutusu), baslik)
        gtk_box_append(nd_box(baslikKutusu), yolKutusu)
        gtk_widget_set_visible(yolKutusu, 0)
        gtk_header_bar_set_title_widget(nd_header_bar(cubuk), baslikKutusu)
        let panelButonu = gtk_button_new_from_icon_name("sidebar-show-symbolic")!
        gtk_widget_set_tooltip_text(panelButonu, "Kenar Paneli Göster/Gizle (Ctrl+\\)")
        gtk_widget_set_focus_on_click(panelButonu, 0)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(panelButonu), "clicked") { [weak self] in
            self?.kenarPaneliniAcKapa()
        }
        gtk_header_bar_pack_start(nd_header_bar(cubuk), panelButonu)
        // macOS BaslikCubugu: Geri Al / Yinele düğmeleri.
        for (ikon, ipucu, ileri) in [("edit-undo-symbolic", "Geri Al (Ctrl+Z)", false), ("edit-redo-symbolic", "Yinele (Ctrl+Y)", true)] {
            let dugme = gtk_button_new_from_icon_name(ikon)!
            gtk_widget_set_tooltip_text(dugme, ipucu)
            gtk_widget_set_focus_on_click(dugme, 0)
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked") { [weak self] in
                self?.editor?.geriAlIstendi(ileri: ileri)
            }
            gtk_header_bar_pack_start(nd_header_bar(cubuk), dugme)
        }
        let menuDugmesi = gtk_menu_button_new()!
        gtk_menu_button_set_icon_name(OpaquePointer(menuDugmesi), "open-menu-symbolic")
        gtk_menu_button_set_menu_model(OpaquePointer(menuDugmesi), GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(menuModeli)))
        gtk_header_bar_pack_end(nd_header_bar(cubuk), menuDugmesi)
        // macOS "Arka plana at": GNOME başlık çubuğu simge durumuna küçültme düğmesini varsayılan göstermez.
        let kucult = gtk_button_new_from_icon_name("window-minimize-symbolic")!
        gtk_widget_set_tooltip_text(kucult, "Arka plana at")
        gtk_widget_set_focus_on_click(kucult, 0)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(kucult), "clicked") { [weak self] in
            if let pencere = self?.pencere { gtk_window_minimize(nd_window(pencere)) }
        }
        gtk_header_bar_pack_end(nd_header_bar(cubuk), kucult)
        gtk_window_set_titlebar(nd_window(pencere), cubuk)
    }

    private func yuvalariKur() {
        gtk_widget_add_css_class(kenarPanelYuvasi, "nd-kenar-panel")
        gtk_widget_add_css_class(editorYuvasi, "nd-editor")
        gtk_widget_set_hexpand(editorYuvasi, 1)
        gtk_widget_set_vexpand(editorYuvasi, 1)
        gtk_widget_set_size_request(kenarPanelYuvasi, Int32(kKenarPanelMinGenislik), -1)
        gtk_widget_set_size_request(editorYuvasi, 220, -1)
        gtk_paned_set_start_child(nd_paned(bolme), kenarPanelYuvasi)
        let editorVeSagPanel = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_box_append(nd_box(editorVeSagPanel), editorYuvasi)
        gtk_box_append(nd_box(editorVeSagPanel), sagPanelYuvasi)
        gtk_widget_set_visible(sagPanelYuvasi, 0)
        gtk_box_append(nd_box(sayfaKutusu), sayfaUstYuvasi)
        gtk_box_append(nd_box(sayfaKutusu), editorVeSagPanel)
        gtk_box_append(nd_box(sayfaKutusu), sayfaAltYuvasi)
        let icerik = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(nd_box(icerik), sayfaKutusu)
        gtk_box_append(nd_box(icerik), anaSayfaYuvasi)
        gtk_widget_set_vexpand(anaSayfaYuvasi, 1)
        gtk_widget_set_hexpand(anaSayfaYuvasi, 1)
        gtk_widget_set_visible(anaSayfaYuvasi, 0)
        gtk_paned_set_end_child(nd_paned(bolme), icerik)
        gtk_paned_set_resize_start_child(nd_paned(bolme), 0)
        gtk_paned_set_shrink_start_child(nd_paned(bolme), 0)
        gtk_paned_set_resize_end_child(nd_paned(bolme), 1)
        gtk_paned_set_shrink_end_child(nd_paned(bolme), 0)
        let kayitli = gKenarPanelGenislik.isFinite ? gKenarPanelGenislik : 190
        gKenarPanelGenislik = min(max(kayitli, kKenarPanelMinGenislik), kKenarPanelMaksGenislik)
        gtk_paned_set_position(nd_paned(bolme), Int32(gKenarPanelGenislik))
        gtk_widget_set_visible(kenarPanelYuvasi, kenarPanelGizli ? 0 : 1)
        gtk_window_set_child(nd_window(pencere), bolme)
    }

    private func panelGenisliginiKaydet() {
        guard !kenarPanelGizli, !genislikAyarlaniyor, gtk_widget_get_mapped(bolme) != 0 else { return }
        let konum = gtk_paned_get_position(nd_paned(bolme))
        let genislik = min(max(CGFloat(konum), kKenarPanelMinGenislik), kKenarPanelMaksGenislik)
        genislikAyarlaniyor = true
        if Int32(genislik) != konum { gtk_paned_set_position(nd_paned(bolme), Int32(genislik)) }
        genislikAyarlaniyor = false
        gKenarPanelGenislik = genislik
        gAyarlar.set(Double(genislik), forKey: "kenarPanelGenislik")
    }
}
