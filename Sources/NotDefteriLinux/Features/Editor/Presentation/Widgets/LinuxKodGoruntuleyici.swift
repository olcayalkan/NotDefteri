import CGtk
import Foundation
import NotDefteriCekirdek

/// Salt okunur kod görüntüleyici (macOS KodGoruntuleyici). Pencere sayfa dosyaları alanından
/// istek üzerine açılır; kur bir şey kaydetmez.
enum LinuxKodGoruntuleyici {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {}

    static func goster(pencere: LinuxPencere, url: URL, goreliYol: String, kok: URL) {
        _ = KodGoruntuleyiciPenceresi(pencere: pencere, url: url, goreliYol: goreliYol, kok: kok)
    }

    /// Esc ile kapanan yardımcı pencereler için (kısayol penceresi de kullanır).
    static func escIleKapat(_ pencere: UnsafeMutablePointer<GtkWidget>) {
        let denetleyici = gtk_shortcut_controller_new()!
        gtk_shortcut_controller_set_scope(nd_shortcut_controller(denetleyici), GTK_SHORTCUT_SCOPE_GLOBAL)
        gtk_event_controller_set_propagation_phase(denetleyici, GTK_PHASE_CAPTURE)
        gtk_widget_add_controller(pencere, denetleyici) // Sahiplik pencereye geçer.
        let tetik = gtk_shortcut_trigger_parse_string("Escape")!
        // Denetleyici pencereyle yok olur; eylem pencere yaşarken çalışır. Yok etme olay işlenmesinden sonraya bırakılır.
        let eylem = GtkKoprusu.kisayolEylemi {
            Platform.anaIsParcaciginda { gtk_window_destroy(nd_window(pencere)) }
        }
        gtk_shortcut_controller_add_shortcut(nd_shortcut_controller(denetleyici), gtk_shortcut_new(tetik, eylem)!)
    }
}

private let etiketAdlari: [KodTokenTuru: String] = [
    .anahtarKelime: "kod-anahtar", .metin: "kod-metin", .sayi: "kod-sayi", .yorum: "kod-yorum",
    .tur: "kod-tur", .fonksiyon: "kod-fonksiyon", .operator: "kod-operator"]

/// Pencere, nesneyi "nd-kod-goruntuleyici" verisiyle yaşatır; yok edilince nesil artar ve gecikmeli sonuçlar atılır.
private final class KodGoruntuleyiciPenceresi {
    private let url: URL
    private let kok: URL
    private let pencere = gtk_window_new()!
    private let tampon: UnsafeMutablePointer<GtkTextBuffer>
    private let durum = gtk_label_new("Yükleniyor…")!
    private let kopyala = gtk_button_new_with_label("Tümünü kopyala")!
    private let klasorDugmesi = gtk_button_new_with_label("Klasörde göster")!
    private let etiketler: [KodTokenTuru: UnsafeMutablePointer<GtkTextTag>]
    private var nesil = 0
    private var hamMetin: String?

    init(pencere ust: LinuxPencere, url: URL, goreliYol: String, kok: URL) {
        self.url = url
        self.kok = kok
        // Editörün etiket tablosu paylaşılır: LinuxKodVeUyari'nin renk etiketleri (açık/koyu tema dahil) aynen gelir.
        let tablo = gtk_text_buffer_get_tag_table(ust.editor!.tampon)!
        tampon = gtk_text_buffer_new(tablo)!
        etiketler = etiketAdlari.reduce(into: [:]) { sonuc, girdi in
            if let etiket = gtk_text_tag_table_lookup(tablo, girdi.value) { sonuc[girdi.key] = etiket }
        }
        arayuzuKur(ust: ust.pencere, baslik: goreliYol)
        yukle()
    }

    private func arayuzuKur(ust: UnsafeMutablePointer<GtkWidget>, baslik: String) {
        gtk_window_set_title(nd_window(pencere), baslik)
        gtk_window_set_default_size(nd_window(pencere), 720, 480)
        gtk_widget_set_size_request(pencere, 480, 320)
        gtk_window_set_transient_for(nd_window(pencere), nd_window(ust))
        gtk_window_set_modal(nd_window(pencere), 1)
        gtk_window_set_destroy_with_parent(nd_window(pencere), 1)
        gtk_widget_add_css_class(pencere, "notdefteri")

        let gorunum = gtk_text_view_new_with_buffer(tampon)!
        g_object_unref(UnsafeMutableRawPointer(tampon)) // Görünüm kendi referansını tutar.
        let metin: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(gorunum))
        gtk_text_view_set_editable(metin, 0)
        gtk_text_view_set_cursor_visible(metin, 0)
        gtk_text_view_set_monospace(metin, 1)
        gtk_text_view_set_wrap_mode(metin, GTK_WRAP_NONE)
        gtk_text_view_set_top_margin(metin, 8)
        gtk_text_view_set_bottom_margin(metin, 8)
        gtk_text_view_set_left_margin(metin, 8)
        gtk_text_view_set_right_margin(metin, 8)

        let kaydirma = gtk_scrolled_window_new()!
        gtk_widget_add_css_class(kaydirma, "nd-editor") // LinuxTema'nın editör renkleri.
        gtk_widget_set_vexpand(kaydirma, 1)
        gtk_widget_set_hexpand(kaydirma, 1)
        gtk_scrolled_window_set_child(OpaquePointer(kaydirma), gorunum)

        gtk_label_set_xalign(nd_label(durum), 0)
        gtk_label_set_ellipsize(nd_label(durum), PANGO_ELLIPSIZE_END)
        gtk_widget_set_hexpand(durum, 1)
        gtk_widget_set_sensitive(kopyala, 0)
        gtk_widget_set_visible(klasorDugmesi, 0)
        let kapat = gtk_button_new_with_label("Kapat")!
        let alt = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        for parca in [durum, kopyala, klasorDugmesi, kapat] { gtk_box_append(nd_box(alt), parca) }

        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8)!
        gtk_widget_set_margin_start(kutu, 12)
        gtk_widget_set_margin_end(kutu, 12)
        gtk_widget_set_margin_top(kutu, 12)
        gtk_widget_set_margin_bottom(kutu, 12)
        gtk_box_append(nd_box(kutu), kaydirma)
        gtk_box_append(nd_box(kutu), alt)
        gtk_window_set_child(nd_window(pencere), kutu)

        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(kopyala), "clicked") { [weak self] in self?.tumunuKopyala() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(klasorDugmesi), "clicked") { [weak self] in self?.klasordeGoster() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(kapat), "clicked") { [weak self] in
            if let pencere = self?.pencere { gtk_window_destroy(nd_window(pencere)) }
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(pencere), "destroy") { [weak self] in self?.nesil += 1 }
        LinuxKodGoruntuleyici.escIleKapat(pencere)
        g_object_set_data_full(UnsafeMutableRawPointer(pencere).assumingMemoryBound(to: GObject.self), "nd-kod-goruntuleyici",
                               Unmanaged.passRetained(self).toOpaque(), { veri in
            if let veri { Unmanaged<KodGoruntuleyiciPenceresi>.fromOpaque(veri).release() }
        })
        gtk_window_present(nd_window(pencere))
    }

    private func yukle() {
        nesil += 1
        let beklenen = nesil, url = url, kok = kok
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let sonuc = try SayfaDosyalari.oku(url, kok: kok)
                var araliklar: [(bas: Int, son: Int, tur: KodTokenTuru)] = []
                if case .metin(let ham) = sonuc {
                    araliklar = Self.karakterAraliklari(ham, kodVurgula(ham, dil: dilAdiniNormallestir(url.pathExtension)))
                }
                Platform.anaIsParcaciginda {
                    guard let self, self.nesil == beklenen else { return }
                    switch sonuc {
                    case .metin(let ham): self.goster(ham, araliklar)
                    case .buyuk: self.gosterilemedi("Dosya çok büyük — Klasörde göster")
                    case .ikili: self.gosterilemedi("Metin değil — Klasörde göster")
                    }
                }
            } catch {
                let mesaj = error.localizedDescription
                Platform.anaIsParcaciginda {
                    guard let self, self.nesil == beklenen else { return }
                    self.gosterilemedi(mesaj)
                }
            }
        }
    }

    /// Çekirdek UTF-16 aralığı verir; GtkTextBuffer karakter (Unicode scalar) konumuyla çalışır.
    /// BMP dışı karakter yoksa ikisi aynıdır, tablo yalnızca gerektiğinde kurulur.
    private static func karakterAraliklari(_ ham: String, _ tokenlar: [(aralik: NSRange, tur: KodTokenTuru)])
        -> [(bas: Int, son: Int, tur: KodTokenTuru)] {
        let birebir = !ham.unicodeScalars.contains { $0.value > 0xFFFF }
        var harita: [Int] = []
        if !birebir {
            harita.reserveCapacity(ham.utf16.count + 1)
            var sira = 0
            for karakter in ham.unicodeScalars {
                harita.append(sira)
                if karakter.value > 0xFFFF { harita.append(sira) }
                sira += 1
            }
            harita.append(sira)
        }
        return tokenlar.compactMap { token in
            let bas = token.aralik.location, son = NSMaxRange(token.aralik)
            if birebir { return (bas, son, token.tur) }
            guard bas >= 0, son < harita.count else { return nil }
            return (harita[bas], harita[son], token.tur)
        }
    }

    private func goster(_ ham: String, _ araliklar: [(bas: Int, son: Int, tur: KodTokenTuru)]) {
        hamMetin = ham
        gtk_text_buffer_set_text(tampon, ham, -1)
        var bas = GtkTextIter(), son = GtkTextIter()
        for aralik in araliklar {
            guard let etiket = etiketler[aralik.tur] else { continue }
            gtk_text_buffer_get_iter_at_offset(tampon, &bas, Int32(aralik.bas))
            gtk_text_buffer_get_iter_at_offset(tampon, &son, Int32(aralik.son))
            gtk_text_buffer_apply_tag(tampon, etiket, &bas, &son)
        }
        gtk_widget_set_sensitive(kopyala, 1)
        gtk_label_set_text(nd_label(durum), "Salt okunur")
    }

    private func gosterilemedi(_ mesaj: String) {
        gtk_text_buffer_set_text(tampon, mesaj, -1)
        gtk_label_set_text(nd_label(durum), "Görüntülenemedi")
        gtk_widget_set_visible(klasorDugmesi, 1)
    }

    private func tumunuKopyala() {
        guard let hamMetin else { return }
        gdk_clipboard_set_text(gtk_widget_get_clipboard(pencere), hamMetin)
    }

    private func klasordeGoster() {
        let beklenen = nesil
        LinuxSayfaDosyalari.klasordeGoster(ust: pencere, url: url, kok: kok) { [weak self] hata in
            guard let hata, let self, self.nesil == beklenen else { return }
            self.gosterilemedi(hata.localizedDescription)
        }
    }
}
