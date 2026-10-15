import CGtk

/// GTK tam ekranda başlık çubuğunu gizler; çıkış ve pencere eylemleri içerikte kalır.
final class LinuxTamEkranKontrolleri {
    let widget = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
    let cikisDugmesi = gtk_button_new_with_label("Tam Ekrandan Çık (F11)")!
    let kucultDugmesi = gtk_button_new_from_icon_name("window-minimize-symbolic")!
    let kapatDugmesi = gtk_button_new_from_icon_name("window-close-symbolic")!

    init(cik: @escaping () -> Void, kucult: @escaping () -> Void, kapat: @escaping () -> Void) {
        gtk_widget_add_css_class(widget, "nd-baslik")
        gtk_widget_set_margin_start(widget, 6)
        gtk_widget_set_margin_end(widget, 6)
        gtk_widget_set_margin_top(widget, 4)
        gtk_widget_set_margin_bottom(widget, 4)
        let bosluk = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_set_hexpand(bosluk, 1)
        gtk_box_append(nd_box(widget), bosluk)
        for (dugme, ipucu, eylem) in [(cikisDugmesi, "Tam Ekrandan Çık (F11)", cik),
                                      (kucultDugmesi, "Arka plana at", kucult),
                                      (kapatDugmesi, "Kapat", kapat)] {
            gtk_widget_set_focus_on_click(dugme, 0)
            gtk_widget_set_tooltip_text(dugme, ipucu)
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked", eylem)
            gtk_box_append(nd_box(widget), dugme)
        }
        gorunurluguAyarla(tamEkran: false)
    }

    func gorunurluguAyarla(tamEkran: Bool) {
        gtk_widget_set_visible(widget, tamEkran ? 1 : 0)
    }
}
