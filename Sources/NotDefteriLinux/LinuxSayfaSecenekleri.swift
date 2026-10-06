import CGtk
import Foundation
import NotDefteriCekirdek

/// macOS NotPenceresi+SayfaSecenekleri karşılığı: tam genişlik ve küçük yazı. Üstbilgi değişimi
/// `ustbilgiyiDegistir` ile yapılır (tek adım); genişliği editör kendi kenar hesabıyla uygular,
/// küçük yazı ise metin görünümüne eklenen sınıfla ölçeklenir.
final class LinuxSayfaSecenekleri {
    private static let genislikYolu = ["Görünüm", "Tam genişlik"]
    private static let yaziYolu = ["Görünüm", "Küçük yazı"]
    private static let kucukSinif = "nd-kucuk-yazi"

    private weak var pencere: LinuxPencere?
    private weak var editor: LinuxEditor?
    private let stil = gtk_css_provider_new()!
    private let ekran: OpaquePointer
    private var sonDurum: (etkin: Bool, tam: Bool, kucuk: Bool)?

    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let secenekler = LinuxSayfaSecenekleri(pencere: pencere, editor: editor)
        let veri = Unmanaged.passRetained(secenekler).toOpaque()
        let yuva: UnsafeMutablePointer<GObject> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(pencere.sayfaUstYuvasi))
        g_object_set_data_full(yuva, "nd-sayfa-secenekleri", veri, { veri in
            if let veri { Unmanaged<LinuxSayfaSecenekleri>.fromOpaque(veri).release() }
        })
    }

    private init(pencere: LinuxPencere, editor: LinuxEditor) {
        self.pencere = pencere
        self.editor = editor
        ekran = gtk_widget_get_display(pencere.pencere)!
        // Mac'te 0,85 ölçek; taban punto 14 → 11,9. Başlık/öznitelik boyutları görünür sonuçta denenmeli.
        gtk_css_provider_load_from_data(stil, "textview.nd-metin.\(Self.kucukSinif) { font-size: \(Double(kTabanPunto) * 0.85)px; }", -1)
        gtk_style_context_add_provider_for_display(ekran, nd_style_provider(stil),
                                                   guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
        pencere.menuEkle(Self.genislikYolu, kisayol: nil) { [weak self] in self?.degistir(genislik: true) }
        pencere.menuEkle(Self.yaziYolu, kisayol: nil) { [weak self] in self?.degistir(genislik: false) }
        editor.durumDegisti.append { [weak self] in self?.durumuYansit() }
        durumuYansit()
    }

    deinit {
        gtk_style_context_remove_provider_for_display(ekran, nd_style_provider(stil))
        g_object_unref(UnsafeMutableRawPointer(stil))
    }

    /// Sayfa açık ve düzenlenebilirken geçerlidir (ana sayfada editör gizli: ustbilgiyiDegistir reddeder).
    private func degistir(genislik: Bool) {
        guard let editor, editor.editorEtkin else { return }
        var bilgi = editor.sayfaUstbilgisi
        if genislik { bilgi.genislik = bilgi.genislik == "tam" ? "" : "tam" }
        else { bilgi.yazi = bilgi.yazi == "kucuk" ? "" : "kucuk" }
        editor.ustbilgiyiDegistir(bilgi)
    }

    /// Açma, mod değişimi ve üstbilgi bildiriminde menü durumu ve yazı ölçeği editörle eşitlenir.
    private func durumuYansit() {
        guard let pencere, let editor else { return }
        let bilgi = editor.sayfaUstbilgisi
        let durum = (etkin: editor.editorEtkin, tam: bilgi.genislik == "tam", kucuk: bilgi.yazi == "kucuk")
        guard sonDurum?.etkin != durum.etkin || sonDurum?.tam != durum.tam || sonDurum?.kucuk != durum.kucuk else { return }
        sonDurum = durum
        pencere.menuDurumu(Self.genislikYolu, etkin: durum.etkin, isaretli: durum.tam)
        pencere.menuDurumu(Self.yaziYolu, etkin: durum.etkin, isaretli: durum.kucuk)
        if durum.kucuk { gtk_widget_add_css_class(editor.metinGorunumu, Self.kucukSinif) }
        else { gtk_widget_remove_css_class(editor.metinGorunumu, Self.kucukSinif) }
    }
}
