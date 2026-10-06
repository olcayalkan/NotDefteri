import CGtk
import Foundation
import NotDefteriCekirdek

/// Sayfa klasöründeki Markdown dışı dosyalar (macOS SayfaDosyalariAlani). Toplama ve okuma
/// çekirdek SayfaDosyalari güvenlik sınırından, arka plan kuyruğunda geçer.
enum LinuxSayfaDosyalari {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let alan = SayfaDosyalariAlani(pencere: pencere, editor: editor)
        // Alan, sayfa altı yuvasıyla yaşar; pencereye ve editöre geri bağları zayıftır.
        let yuva: UnsafeMutablePointer<GObject> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(pencere.sayfaAltYuvasi))
        g_object_set_data_full(yuva, "nd-sayfa-dosyalari", Unmanaged.passRetained(alan).toOpaque(), { veri in
            if let veri { Unmanaged<SayfaDosyalariAlani>.fromOpaque(veri).release() }
        })
    }

    /// Işaretçi arka plan kuyruğundan yalnızca taşınır; GTK'ya yalnızca ana iş parçacığında dokunulur.
    private struct PencereIsaretcisi: @unchecked Sendable { let deger: UnsafeMutablePointer<GtkWidget> }

    private static let kuyruk = DispatchQueue(label: "NotDefteriLinux.sayfa-dosyalari", qos: .userInitiated)

    /// Linux'ta Finder karşılığı: dosyanın bulunduğu klasörü varsayılan dosya yöneticisinde açar.
    /// Dosyanın kendisi açılmaz (çalıştırılabilir olabilir); URI yalnızca doğrulanmış yoldan üretilen file:// klasörüdür.
    /// `sonuc` ana iş parçacığında çağrılır; nil başarıdır.
    static func klasordeGoster(ust: UnsafeMutablePointer<GtkWidget>, url: URL, kok: URL, sonuc: @escaping (Error?) -> Void) {
        let pencere = PencereIsaretcisi(deger: ust)
        kuyruk.async {
            let dogrulama = Result { try SayfaDosyalari.dogrula(url, kok: kok) }
            Platform.anaIsParcaciginda {
                switch dogrulama {
                case .success:
                    gtk_show_uri(nd_window(pencere.deger), url.deletingLastPathComponent().absoluteString, 0)
                    sonuc(nil)
                case .failure(let hata): sonuc(hata)
                }
            }
        }
    }

    fileprivate static func topla(klasor: URL, kok: URL, bitti: @escaping ([SayfaDosyasi]) -> Void) {
        kuyruk.async {
            let dosyalar = SayfaDosyalari.topla(sayfaKlasoru: klasor, kok: kok)
            Platform.anaIsParcaciginda { bitti(dosyalar) }
        }
    }
}

private final class SayfaDosyalariAlani {
    private weak var pencere: LinuxPencere?
    private weak var editor: LinuxEditor?
    private let genisletici = gtk_expander_new("")!
    private let kaydirma = gtk_scrolled_window_new()!
    private let liste = gtk_list_box_new()!
    private var satirlar: [(klasor: String, dosya: SayfaDosyasi?)] = []
    private var nesil = 0

    init(pencere: LinuxPencere, editor: LinuxEditor) {
        self.pencere = pencere
        self.editor = editor
        gtk_list_box_set_selection_mode(OpaquePointer(liste), GTK_SELECTION_NONE)
        gtk_scrolled_window_set_policy(OpaquePointer(kaydirma), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_max_content_height(OpaquePointer(kaydirma), 144)
        gtk_scrolled_window_set_propagate_natural_height(OpaquePointer(kaydirma), 1)
        gtk_scrolled_window_set_child(OpaquePointer(kaydirma), liste)
        gtk_expander_set_child(OpaquePointer(genisletici), kaydirma)
        gtk_widget_set_margin_start(genisletici, 8)
        gtk_widget_set_margin_end(genisletici, 8)
        gtk_widget_set_visible(genisletici, 0)
        gtk_box_append(nd_box(pencere.sayfaAltYuvasi), genisletici)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(liste), "row-activated") { [weak self] (satir: gpointer?) in
            guard let satir else { return }
            self?.satirSecildi(Int(gtk_list_box_row_get_index(satir.assumingMemoryBound(to: GtkListBoxRow.self))))
        }
        LinuxEklentiler.yasamDongusunuIzle(editor) { [weak self] in self?.tazele() }
        tazele()
    }

    /// Not, yol veya mod değişince; yarış olursa eski sonuç nesil/URL denetimiyle atılır.
    private func tazele() {
        nesil += 1
        guard let editor else { return }
        guncelle([])
        guard editor.editorEtkin, let url = editor.acikURL else { return }
        let beklenen = nesil
        LinuxSayfaDosyalari.topla(klasor: sayfaKlasoru(url), kok: notlarKlasoru()) { [weak self] dosyalar in
            guard let self, self.nesil == beklenen, self.editor?.acikURL == url else { return }
            self.guncelle(dosyalar)
        }
    }

    private func guncelle(_ dosyalar: [SayfaDosyasi]) {
        while let alt = gtk_widget_get_first_child(liste) { gtk_list_box_remove(OpaquePointer(liste), alt) }
        satirlar = []
        var sonKlasor: String?
        for dosya in dosyalar {
            if sonKlasor != dosya.klasor {
                satirlar.append((dosya.klasor.isEmpty ? "Bu klasör" : dosya.klasor, nil))
                sonKlasor = dosya.klasor
            }
            satirlar.append((dosya.klasor, dosya))
        }
        for satir in satirlar {
            let gorunum = satirGorunumu(satir)
            gtk_list_box_append(OpaquePointer(liste), gorunum)
            // Klasör başlığı tıklanmaz ve vurgulanmaz.
            if satir.dosya == nil, let kap = gtk_widget_get_parent(gorunum) {
                gtk_list_box_row_set_activatable(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(kap)), 0)
            }
        }
        gtk_expander_set_label(OpaquePointer(genisletici), "Dosyalar (\(dosyalar.count))")
        gtk_expander_set_expanded(OpaquePointer(genisletici), 0) // macOS gibi her yenilemede katlı başlar.
        gtk_widget_set_visible(genisletici, dosyalar.isEmpty ? 0 : 1)
    }

    private func satirGorunumu(_ satir: (klasor: String, dosya: SayfaDosyasi?)) -> UnsafeMutablePointer<GtkWidget> {
        let kutu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        let etiket = gtk_label_new(satir.dosya?.goreliYol ?? satir.klasor)!
        gtk_label_set_xalign(nd_label(etiket), 0)
        gtk_label_set_ellipsize(nd_label(etiket), PANGO_ELLIPSIZE_MIDDLE)
        gtk_widget_set_hexpand(etiket, 1)
        guard let dosya = satir.dosya else {
            gtk_widget_add_css_class(etiket, "dim-label")
            gtk_box_append(nd_box(kutu), etiket)
            return kutu
        }
        let (simge, ad) = dosya.kodMu ? ("text-x-script-symbolic", "Kod")
            : dosya.metinMi ? ("text-x-generic-symbolic", "Metin") : ("x-office-document-symbolic", "Dosya")
        let resim = gtk_image_new_from_icon_name(simge)!
        gtk_widget_set_tooltip_text(resim, ad)
        gtk_widget_set_tooltip_text(etiket, dosya.goreliYol)
        let boyut = gtk_label_new(ByteCountFormatter.string(fromByteCount: dosya.boyut, countStyle: .file))!
        gtk_widget_add_css_class(boyut, "dim-label")
        gtk_box_append(nd_box(kutu), resim)
        gtk_box_append(nd_box(kutu), etiket)
        gtk_box_append(nd_box(kutu), boyut)
        return kutu
    }

    private func satirSecildi(_ sira: Int) {
        guard satirlar.indices.contains(sira), let dosya = satirlar[sira].dosya,
              let pencere, editor?.editorEtkin == true else { return }
        let kok = notlarKlasoru()
        if dosya.metinMi {
            LinuxKodGoruntuleyici.goster(pencere: pencere, url: dosya.url, goreliYol: dosya.goreliYol, kok: kok)
            return
        }
        let beklenen = nesil
        LinuxSayfaDosyalari.klasordeGoster(ust: pencere.pencere, url: dosya.url, kok: kok) { [weak self] hata in
            guard let hata, let self, self.nesil == beklenen, let pencere = self.pencere else { return }
            LinuxDiyalog.bilgi(ust: pencere.pencere, baslik: "Dosya gösterilemedi",
                               aciklama: hata.localizedDescription, hata: true)
        }
    }
}
