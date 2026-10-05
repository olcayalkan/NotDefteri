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
    var editor: LinuxEditorProtokolu?

    private let bolme = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL)!
    private let baslik = gtk_label_new("Not Defteri")!
    private let kisayollar = gtk_shortcut_controller_new()!
    private let tema: LinuxTema
    private var kenarPanelGizli = UserDefaults.standard.bool(forKey: "kenarPanelGizli")
    private var genislikAyarlaniyor = false

    init(uygulama: UnsafeMutablePointer<GtkApplication>) {
        pencere = gtk_application_window_new(uygulama)!
        tema = LinuxTema(display: gtk_widget_get_display(pencere)!)
        gtk_widget_add_css_class(pencere, "notdefteri")
        gtk_window_set_title(nd_window(pencere), "Not Defteri")
        gtk_window_set_default_size(nd_window(pencere), 680, 520)
        gtk_widget_set_size_request(pencere, 460, 320)
        baslikCubugunuKur()
        yuvalariKur()
        gtk_shortcut_controller_set_scope(nd_shortcut_controller(kisayollar), GTK_SHORTCUT_SCOPE_GLOBAL)
        gtk_event_controller_set_propagation_phase(kisayollar, GTK_PHASE_CAPTURE)
        gtk_widget_add_controller(pencere, kisayollar) // Controller'ın sahipliği pencereye geçer.
        kisayolEkle("<Control>backslash") { [weak self] in self?.kenarPaneliniAcKapa() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(bolme), "notify::position") { [weak self] (_: gpointer?) in
            self?.panelGenisliginiKaydet()
        }
    }

    func basligiAyarla(_ yol: [String]) {
        let metin = yol.isEmpty ? "Not Defteri" : yol.joined(separator: " › ")
        gtk_label_set_text(nd_label(baslik), metin)
        gtk_widget_set_tooltip_text(baslik, metin)
        gtk_window_set_title(nd_window(pencere), metin)
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
        UserDefaults.standard.set(kenarPanelGizli, forKey: "kenarPanelGizli")
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
        gtk_header_bar_set_title_widget(nd_header_bar(cubuk), baslik)
        let panelButonu = gtk_button_new_from_icon_name("sidebar-show-symbolic")!
        gtk_widget_set_tooltip_text(panelButonu, "Kenar Paneli Göster/Gizle (Ctrl+\\)")
        gtk_widget_set_focus_on_click(panelButonu, 0)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(panelButonu), "clicked") { [weak self] in
            self?.kenarPaneliniAcKapa()
        }
        gtk_header_bar_pack_start(nd_header_bar(cubuk), panelButonu)
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
        gtk_paned_set_end_child(nd_paned(bolme), editorVeSagPanel)
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
        UserDefaults.standard.set(Double(genislik), forKey: "kenarPanelGenislik")
    }
}
