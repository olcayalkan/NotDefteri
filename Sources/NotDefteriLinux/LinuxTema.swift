import CGtk
import Foundation
import NotDefteriCekirdek

final class LinuxTema {
    // Tema.swift ile aynı sıra ve RGB değerleri: Sepya, Yeşilimsi Kağıt, Gri Kağıt, Krem.
    private static let renkler = [
        ("rgb(84%,81%,73%)", "rgb(78%,74%,65%)", "rgb(80%,77%,69%)"),
        ("rgb(79%,83%,76%)", "rgb(72%,77%,70%)", "rgb(75%,80%,73%)"),
        ("rgb(80%,80%,80%)", "rgb(73%,73%,73%)", "rgb(76%,76%,76%)"),
        ("rgb(86%,83%,76%)", "rgb(80%,76%,67%)", "rgb(82%,79%,71%)")
    ]
    private let display: OpaquePointer
    private let saglayici = gtk_css_provider_new()!
    private let ayarlar: OpaquePointer
    private var sinyaller: [gulong] = []

    init(display: OpaquePointer) {
        self.display = display
        ayarlar = gtk_settings_get_for_display(display)!
        gtk_style_context_add_provider_for_display(display, nd_style_provider(saglayici),
                                                   guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
        for ad in ["notify::gtk-application-prefer-dark-theme", "notify::gtk-theme-name"] {
            sinyaller.append(GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(ayarlar), ad) { [weak self] (_: gpointer?) in
                self?.uygula()
            })
        }
        uygula()
    }

    deinit {
        for kimlik in sinyaller { g_signal_handler_disconnect(UnsafeMutableRawPointer(ayarlar), kimlik) }
        gtk_style_context_remove_provider_for_display(display, nd_style_provider(saglayici))
        g_object_unref(UnsafeMutableRawPointer(saglayici))
    }

    func uygula() {
        if !Self.renkler.indices.contains(gTemaIndex) { gTemaIndex = 0 }
        let (zemin, baslik, panel) = Self.renkler[gTemaIndex]
        let koyu = nd_settings_dark(ayarlar) != 0
        let renk = koyu ? "#eeeeec" : "#333333"
        let css = """
        @define-color nd-zemin \(zemin);
        @define-color nd-baslik \(baslik);
        @define-color nd-panel \(panel);
        window.notdefteri { background-color: \(koyu ? "shade(@nd-zemin, 0.28)" : "@nd-zemin"); color: \(renk); }
        .notdefteri .nd-baslik { background-image: none; background-color: \(koyu ? "shade(@nd-baslik, 0.28)" : "@nd-baslik"); color: \(renk); }
        .notdefteri .nd-kenar-panel, .notdefteri .nd-kenar-panel listview { background-color: \(koyu ? "shade(@nd-panel, 0.28)" : "@nd-panel"); color: \(renk); }
        .notdefteri .nd-editor, .notdefteri .nd-editor textview, .notdefteri .nd-editor textview text { background-color: \(koyu ? "shade(@nd-zemin, 0.28)" : "@nd-zemin"); color: \(renk); caret-color: \(renk); }
        .notdefteri .nd-kenar-panel row:selected { background-color: \(koyu ? "shade(@nd-panel, 0.45)" : "shade(@nd-panel, 0.82)"); }
        """
        gtk_css_provider_load_from_data(saglayici, css, -1)
    }
}
