import CGtk
import Foundation
import NotDefteriCekirdek

/// macOS Menu.swift ile eşlik: başka dosyada karşılığı bulunmayan menü öğeleri ve kenar panelin
/// alt çubukları (B1/B2/B3/Aa başlık düzeyi, A−/A+ punto). Kısayollar Cmd → Ctrl olarak taşınır.
enum LinuxMenuler {
    /// macOS'ta paket/Info.plist olmadığı için tek sürüm kaynağı yok; Hakkında penceresi bunu gösterir.
    private static let surum = "1.0 (Linux)"

    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        uygulamaMenusu(pencere)
        duzenMenusu(pencere, editor)
        gorunumMenusu(pencere, editor)
        notMenusu(pencere, editor, panel)
        PanelCubuklari.kur(pencere: pencere, editor: editor)
    }

    // MARK: Not Defteri (macOS uygulama menüsü)

    private static func uygulamaMenusu(_ pencere: LinuxPencere) {
        pencere.menuEkle(["Not Defteri", "Not Defteri Hakkında"], kisayol: nil) { [weak pencere] in
            guard let ust = pencere?.pencere else { return }
            let hakkinda = gtk_about_dialog_new()!
            gtk_about_dialog_set_program_name(OpaquePointer(hakkinda), "Not Defteri")
            gtk_about_dialog_set_version(OpaquePointer(hakkinda), surum)
            gtk_about_dialog_set_comments(OpaquePointer(hakkinda), "Markdown tabanlı, bağımlılıksız not defteri.")
            gtk_window_set_transient_for(nd_window(hakkinda), nd_window(ust))
            gtk_window_set_modal(nd_window(hakkinda), 1)
            gtk_window_present(nd_window(hakkinda))
        }
        let giris = ["Not Defteri", "Girişte Otomatik Başlat"]
        pencere.menuEkle(giris, kisayol: nil) { [weak pencere] in
            let istenen = !giristeAcikMi()
            giristeAcmayiAyarla(istenen)
            // Ayar yazılamadıysa işaret gerçek duruma döner ve kullanıcı bilgilendirilir.
            pencere?.menuDurumu(giris, etkin: true, isaretli: giristeAcikMi())
            if giristeAcikMi() != istenen, let ust = pencere?.pencere {
                LinuxDiyalog.bilgi(ust: ust, baslik: "Girişte başlatma ayarlanamadı",
                                   aciklama: "~/.config/autostart/notdefteri.desktop yazılamadı veya silinemedi.", hata: true)
            }
        }
        pencere.menuDurumu(giris, etkin: true, isaretli: giristeAcikMi())
        // Tek pencere: kapatma isteği kaydetme sorusunu (close-request) çalıştırır.
        pencere.menuEkle(["Not Defteri", "Not Defteri'nden Çık"], kisayol: "<Control>q") { [weak pencere] in
            if let ust = pencere?.pencere { gtk_window_close(nd_window(ust)) }
        }
    }

    // MARK: Düzen

    private static func duzenMenusu(_ pencere: LinuxPencere, _ editor: LinuxEditor) {
        // GtkTextView yerleşik eylemleri; Ctrl+X/C/V/A'yı GTK zaten işler, menüde yalnızca görünür.
        let eylemler = [("Kes", "<Control>x", "clipboard.cut"), ("Kopyala", "<Control>c", "clipboard.copy"),
                        ("Yapıştır", "<Control>v", "clipboard.paste"), ("Tümünü Seç", "<Control>a", "selection.select-all")]
        for (ad, tetik, eylem) in eylemler {
            pencere.menuEkle(["Düzen", ad], kisayol: tetik, kisayoluKaydet: false) { [weak editor] in
                guard let editor, editor.editorEtkin else { return }
                gtk_widget_grab_focus(editor.metinGorunumu)
                gtk_widget_activate_action_variant(editor.metinGorunumu, eylem, nil)
            }
        }
    }

    // MARK: Görünüm

    private static func gorunumMenusu(_ pencere: LinuxPencere, _ editor: LinuxEditor) {
        pencere.menuEkle(["Görünüm", "Tam Ekran"], kisayol: "F11") { [weak pencere] in pencere?.tamEkraniAcKapa() }
        pencere.menuEkle(["Görünüm", "Puntoyu Büyüt"], kisayol: "<Control>asterisk") { [weak editor] in
            editor?.puntoDegistir(fark: 1)
        }
        pencere.menuEkle(["Görünüm", "Puntoyu Küçült"], kisayol: "<Control>minus") { [weak editor] in
            editor?.puntoDegistir(fark: -1)
        }
        let yollar = LinuxTema.adlar.map { ["Görünüm", "Tema", $0] }
        let isaretle = { [weak pencere] in
            for (sira, yol) in yollar.enumerated() { pencere?.menuDurumu(yol, etkin: true, isaretli: sira == gTemaIndex) }
        }
        for (sira, yol) in yollar.enumerated() {
            pencere.menuEkle(yol, kisayol: nil) { [weak pencere] in
                gTemaIndex = sira
                gAyarlar.set(sira, forKey: "temaIndex")
                pencere?.temayiUygula()
                isaretle()
            }
        }
        isaretle()
    }

    // MARK: Not

    private static func notMenusu(_ pencere: LinuxPencere, _ editor: LinuxEditor, _ panel: LinuxKenarPaneli) {
        for (ad, tetik, yon) in [("Önceki Not", "<Control>bracketleft", -1), ("Sonraki Not", "<Control>bracketright", 1)] {
            pencere.menuEkle(["Not", ad], kisayol: tetik) { [weak editor, weak panel] in
                // Arama süzgeci açıkken de tüm notlar arasında gezilir (Mac notGezin).
                guard let editor, let liste = panel?.tumNotUrlListesi, !liste.isEmpty else { return }
                guard let mevcut = editor.acikURL, let sira = liste.firstIndex(of: mevcut) else { editor.notuAc(liste[0]); return }
                if liste.indices.contains(sira + yon) { editor.notuAc(liste[sira + yon]) }
            }
        }
    }
}

/// Mac KenarPaneli.baslikCubuguKur / puntoCubuguKur: panelin altındaki iki düğme şeridi.
private final class PanelCubuklari {
    private weak var editor: LinuxEditor?
    private let etiket = gtk_label_new("14 pt")!
    private var seritler: [UnsafeMutablePointer<GtkWidget>] = []
    private var bekliyor = false

    static func kur(pencere: LinuxPencere, editor: LinuxEditor) {
        let cubuklar = PanelCubuklari(editor)
        let yuva = pencere.kenarPanelYuvasi
        for serit in [cubuklar.baslikSeridi(), cubuklar.puntoSeridi()] {
            cubuklar.seritler.append(serit)
            gtk_box_append(nd_box(yuva), serit)
        }
        // Closure'lar nesneyi tampon/editör ömrü boyunca tutar.
        for ad in ["notify::cursor-position", "notify::has-selection"] {
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.tampon), ad) { (_: gpointer?) in cubuklar.planla() }
        }
        editor.degisiklikSonrasi.append { cubuklar.planla() }
        editor.durumDegisti.append { cubuklar.guncelle() }
        cubuklar.guncelle()
    }

    private init(_ editor: LinuxEditor) {
        self.editor = editor
    }

    private func serit() -> UnsafeMutablePointer<GtkWidget> {
        let kutu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 2)!
        gtk_box_set_homogeneous(nd_box(kutu), 1)
        gtk_widget_set_margin_start(kutu, 8)
        gtk_widget_set_margin_end(kutu, 8)
        gtk_widget_set_margin_top(kutu, 4)
        return kutu
    }

    private func dugme(_ yazi: String, _ ipucu: String, _ eylem: @escaping () -> Void) -> UnsafeMutablePointer<GtkWidget> {
        let d = gtk_button_new_with_label(yazi)!
        gtk_widget_add_css_class(d, "flat")
        gtk_widget_set_focus_on_click(d, 0)
        gtk_widget_set_tooltip_text(d, ipucu)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(d), "clicked", eylem)
        return d
    }

    private func baslikSeridi() -> UnsafeMutablePointer<GtkWidget> {
        let kutu = serit()
        let tanimlar = [("B1", 1, "En büyük başlık (satır başında /1 + boşluk)"), ("B2", 2, "Alt başlık (/2 + boşluk)"),
                        ("B3", 3, "Küçük başlık (/3 + boşluk)"), ("Aa", 0, "Normal metin (/0 + boşluk)")]
        for (yazi, seviye, ipucu) in tanimlar {
            gtk_box_append(nd_box(kutu), dugme(yazi, ipucu) { [weak self] in self?.editor?.baslikSeviyesiUygula(seviye) })
        }
        return kutu
    }

    private func puntoSeridi() -> UnsafeMutablePointer<GtkWidget> {
        let kutu = serit()
        gtk_box_append(nd_box(kutu), dugme("A−", "Seçili yazının puntosunu küçült (Ctrl+−)") { [weak self] in self?.degistir(-1) })
        gtk_widget_add_css_class(etiket, "dim-label")
        gtk_box_append(nd_box(kutu), etiket)
        gtk_box_append(nd_box(kutu), dugme("A+", "Seçili yazının puntosunu büyüt (Ctrl+*)") { [weak self] in self?.degistir(1) })
        return kutu
    }

    private func degistir(_ fark: CGFloat) {
        editor?.puntoDegistir(fark: fark)
        guncelle()
    }

    /// İmleç/seçim değişimi belge aynalamasından önce gelebilir; okuma ana döngüye ertelenir.
    func planla() {
        guard !bekliyor else { return }
        bekliyor = true
        Platform.anaIsParcaciginda { [weak self] in
            self?.bekliyor = false
            self?.guncelle()
        }
    }

    func guncelle() {
        guard let editor else { return }
        // Ana sayfada editör yok: düğmeler pasif (Mac anaSayfa.isHidden kontrolü).
        for serit in seritler { gtk_widget_set_sensitive(serit, editor.editorEtkin ? 1 : 0) }
        guard editor.editorEtkin else { return }
        gtk_label_set_text(nd_label(etiket), "\(boyutMetni(editor.imlecPuntosu)) pt")
    }
}
