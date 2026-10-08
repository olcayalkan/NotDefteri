import CGtk
import Foundation
import NotDefteriCekirdek

/// Sayfa geçmişi (macOS GecmisPaneli + NotPenceresi.surumuGeriYukle): solda sürüm listesi, sağda
/// salt okunur önizleme. Geri yüklemede önce güncel içerik geçmişe kaydedilir ve başarısı doğrulanır.
enum LinuxGecmis {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let yol = ["Not", "Sayfa geçmişi…"]
        pencere.menuEkle(yol, kisayol: "<Control><Alt>y") { [weak pencere, weak editor] in
            guard let pencere, let editor else { return }
            LinuxGecmisPenceresi.ac(pencere: pencere, editor: editor)
        }
        let durumuGuncelle: () -> Void = { [weak pencere, weak editor] in
            guard let pencere else { return }
            pencere.menuDurumu(yol, etkin: editor?.editorEtkin == true && editor?.acikURL != nil, isaretli: nil)
        }
        editor.durumDegisti.append(durumuGuncelle)
        durumuGuncelle()
    }
}

private final class LinuxGecmisPenceresi {
    private static weak var acik: LinuxGecmisPenceresi?

    private weak var anaPencere: LinuxPencere?
    private weak var editor: LinuxEditor?
    private let url: URL
    private let pencere = gtk_window_new()!
    private let liste = gtk_list_box_new()!
    private let tampon = gtk_text_buffer_new(nil)!
    private let adaptor: LinuxBelgeAdaptoru
    private let yukle = gtk_button_new_with_label("Bu sürümü geri yükle")!
    private let bicim = DateFormatter()
    private var surumler: [SayfaSurumu] = []
    private var geriYuklemeBekliyor = false
    private var kapatildi = false

    /// Açık sayfa önce kaydedilir (başarısızsa "Kaydetmeden Devam" sorulur); sonra pencere açılır.
    static func ac(pencere: LinuxPencere, editor: LinuxEditor) {
        if let acik { gtk_window_present(nd_window(acik.pencere)); return }
        editor.islemOncesi { [weak pencere, weak editor] in
            guard let pencere, let editor, editor.editorEtkin, let url = editor.acikURL, acik == nil else { return }
            let yeni = LinuxGecmisPenceresi(anaPencere: pencere, editor: editor, url: url)
            acik = yeni
            yeni.goster()
        }
    }

    private init(anaPencere: LinuxPencere, editor: LinuxEditor, url: URL) {
        self.anaPencere = anaPencere
        self.editor = editor
        self.url = url
        // Önbellek, adaptörün tampon değişikliklerinden önce kurulmalı (editörle aynı sıra).
        GtkKoprusu.konumOnbelleginiKur(tampon)
        adaptor = LinuxBelgeAdaptoru(tampon: tampon)
        bicim.locale = Locale(identifier: "tr_TR")
    }

    private func goster() {
        guard let anaPencere else { return }
        // Ana pencereyle aynı kağıt teması (LinuxTema yalnızca .notdefteri altını boyar).
        gtk_widget_add_css_class(pencere, "notdefteri")
        gtk_window_set_title(nd_window(pencere), "Sayfa geçmişi")
        gtk_window_set_transient_for(nd_window(pencere), nd_window(anaPencere.pencere))
        gtk_window_set_modal(nd_window(pencere), 1)
        gtk_window_set_destroy_with_parent(nd_window(pencere), 1)
        gtk_window_set_default_size(nd_window(pencere), 640, 420)
        gtk_window_set_child(nd_window(pencere), icerigiKur())
        kisayoluKur()
        let nesne = UnsafeMutableRawPointer(pencere)
        // Pencere kapanana dek yaşar; kapanınca yok edilme bildirimi referansı bırakır.
        g_object_set_data_full(GtkKoprusu.gtkIsaretci(nesne), "nd-gecmis", Unmanaged.passRetained(self).toOpaque(), { veri in
            if let veri { Unmanaged<LinuxGecmisPenceresi>.fromOpaque(veri).release() }
        })
        GtkKoprusu.sinyalBagla(nesne, "destroy") { [weak self] in self?.kapatildi = true }
        gtk_window_present(nd_window(pencere))
        SayfaGecmisi.listele(url) { [weak self] sonuc in self?.listeyiDoldur(sonuc) }
    }

    private func icerigiKur() -> UnsafeMutablePointer<GtkWidget> {
        let kok = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8)!
        for kenar in [gtk_widget_set_margin_top, gtk_widget_set_margin_bottom,
                      gtk_widget_set_margin_start, gtk_widget_set_margin_end] { kenar(kok, 12) }
        let orta = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_widget_set_vexpand(orta, 1)
        let sol = gtk_scrolled_window_new()!
        gtk_widget_set_size_request(sol, 190, -1)
        gtk_scrolled_window_set_policy(OpaquePointer(sol), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(OpaquePointer(sol), liste)
        let gorunumWidget = gtk_text_view_new_with_buffer(tampon)!
        let gorunum: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(gorunumWidget))
        g_object_unref(UnsafeMutableRawPointer(tampon)) // Görünüm sahiplendi; adaptör yalnızca ham işaretçi tutar.
        gtk_widget_add_css_class(gorunumWidget, "nd-metin")
        gtk_text_view_set_editable(gorunum, 0)
        gtk_text_view_set_cursor_visible(gorunum, 0)
        gtk_text_view_set_wrap_mode(gorunum, GTK_WRAP_WORD_CHAR)
        gtk_text_view_set_left_margin(gorunum, 8)
        gtk_text_view_set_right_margin(gorunum, 8)
        gtk_text_view_set_top_margin(gorunum, 8)
        let sag = gtk_scrolled_window_new()!
        gtk_widget_set_hexpand(sag, 1)
        gtk_scrolled_window_set_policy(OpaquePointer(sag), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(OpaquePointer(sag), gorunumWidget)
        gtk_box_append(nd_box(orta), sol)
        gtk_box_append(nd_box(orta), sag)
        let dugmeler = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_widget_set_halign(dugmeler, GTK_ALIGN_END)
        let kapat = gtk_button_new_with_label("Kapat")!
        gtk_box_append(nd_box(dugmeler), kapat)
        gtk_box_append(nd_box(dugmeler), yukle)
        gtk_widget_set_sensitive(yukle, 0)
        gtk_box_append(nd_box(kok), orta)
        gtk_box_append(nd_box(kok), dugmeler)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(kapat), "clicked") { [weak self] in self?.kapat() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(yukle), "clicked") { [weak self] in self?.geriYukle() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(liste), "row-selected") { [weak self] (_: gpointer?) in
            self?.secimDegisti()
        }
        return kok
    }

    /// Mac'te Esc "Kapat" düğmesidir.
    private func kisayoluKur() {
        let denetim = gtk_shortcut_controller_new()!
        let tetik = gtk_shortcut_trigger_parse_string("Escape")!
        let eylem = GtkKoprusu.kisayolEylemi { [weak self] in self?.kapat() }
        gtk_shortcut_controller_add_shortcut(nd_shortcut_controller(denetim), gtk_shortcut_new(tetik, eylem)!)
        gtk_widget_add_controller(pencere, denetim)
    }

    private func kapat() {
        kapatildi = true
        gtk_window_destroy(nd_window(pencere))
    }

    private func listeyiDoldur(_ sonuc: [SayfaSurumu]) {
        guard !kapatildi else { return }
        surumler = sonuc
        guard !sonuc.isEmpty else { onizlemeMetni("Henüz kayıtlı sürüm yok."); return }
        for surum in sonuc {
            let etiket = gtk_label_new(tarihEtiketi(surum.tarih))!
            gtk_widget_set_halign(etiket, GTK_ALIGN_START)
            gtk_widget_set_margin_top(etiket, 4)
            gtk_widget_set_margin_bottom(etiket, 4)
            gtk_list_box_append(OpaquePointer(liste), etiket)
        }
        gtk_list_box_select_row(OpaquePointer(liste), gtk_list_box_get_row_at_index(OpaquePointer(liste), 0))
    }

    private func tarihEtiketi(_ tarih: Date) -> String {
        let takvim = Calendar.current
        bicim.dateFormat = "HH:mm"
        let saat = bicim.string(from: tarih)
        if takvim.isDateInToday(tarih) { return "Bugün " + saat }
        if takvim.isDateInYesterday(tarih) { return "Dün " + saat }
        bicim.dateFormat = "d MMM yyyy HH:mm"
        return bicim.string(from: tarih)
    }

    private var seciliSira: Int? {
        gtk_list_box_get_selected_row(OpaquePointer(liste)).map { Int(gtk_list_box_row_get_index($0)) }
    }

    private func onizlemeMetni(_ metin: String) { adaptor.yukle(NSAttributedString(string: metin)) }

    private func secimDegisti() {
        guard !kapatildi else { return }
        guard let sira = seciliSira, surumler.indices.contains(sira) else {
            gtk_widget_set_sensitive(yukle, 0)
            return
        }
        gtk_widget_set_sensitive(yukle, geriYuklemeBekliyor ? 0 : 1)
        do {
            let metin = try SayfaGecmisi.surumMetniniOku(surumler[sira])
            adaptor.yukle(markdowndenAttributedStringUret(sayfaUstbilgisiniAyir(metin).govde, taban: sayfaKlasoru(url)))
        } catch {
            gtk_widget_set_sensitive(yukle, 0)
            onizlemeMetni("Sürüm okunamadı.")
            bildir("Sürüm okunamadı", error)
        }
    }

    private func bildir(_ baslik: String, _ hata: Error) {
        guard !kapatildi else { return }
        LinuxDiyalog.bilgi(ust: pencere, baslik: baslik, aciklama: hata.localizedDescription, hata: true)
    }

    private struct GeriYuklemeHatasi: LocalizedError {
        let neden: String
        var errorDescription: String? { neden }
    }

    /// Önce güncel içerik diske ve geçmişe (doğrulanarak) yazılır; sonra editör tek undo adımıyla
    /// seçilen sürümün gövdesine geçer. Üstbilgi mevcut hâliyle kalır. Okuma hatası boş gövde sayılmaz.
    private func geriYukle() {
        guard !geriYuklemeBekliyor, !kapatildi, let editor, let sira = seciliSira, surumler.indices.contains(sira) else { return }
        do {
            let govde = sayfaUstbilgisiniAyir(try SayfaGecmisi.surumMetniniOku(surumler[sira])).govde
            guard editor.editorEtkin, editor.acikURL == url else {
                throw GeriYuklemeHatasi(neden: "Sayfa artık açık değil. Geçmiş penceresini yeniden açın.")
            }
            if case .hata(let neden) = editor.simdiKaydetSonucu(bildir: false) {
                throw GeriYuklemeHatasi(neden: "Güncel içerik kaydedilemedi: \(neden)")
            }
            try notlarYolunuDogrula(url)
            let mevcut = try String(contentsOf: url, encoding: .utf8)
            let beklenen = editor.nesil
            geriYuklemeBekliyor = true
            gtk_widget_set_sensitive(yukle, 0)
            SayfaGecmisi.kaydet(metin: mevcut, icerikURL: url, zorla: true) { [weak self] sonuc in
                self?.korumaKaydedildi(sonuc, govde: govde, mevcut: mevcut, nesil: beklenen)
            }
        } catch { bildir("Sürüm geri yüklenemedi", error) }
    }

    private func korumaKaydedildi(_ sonuc: Result<URL?, Error>, govde: String, mevcut: String, nesil: UInt) {
        guard !kapatildi, let editor else { return }
        do {
            _ = try sonuc.get()
            try notlarYolunuDogrula(url)
            // Koruma sürümü beklenirken sayfa değiştiyse eski yedekle geri yükleme yapılmaz.
            guard editor.editorEtkin, editor.acikURL == url, editor.nesil == nesil,
                  try String(contentsOf: url, encoding: .utf8) == mevcut else {
                throw GeriYuklemeHatasi(neden: "Sayfa değişti. Geçmiş penceresini yeniden açın.")
            }
            // Kayıt hatasında tek diyalog: editörünki kapatılır, aşağıdaki geriYuklemeBasarisiz gösterir.
            editor.acikBelgeyiGuncelle(url, metin: markdowndenAttributedStringUret(govde, taban: sayfaKlasoru(url)),
                                       kayitBildir: false) { [weak self] sonuc in
                guard let self, !self.kapatildi else { return }
                if case .hata(let neden) = sonuc { self.geriYuklemeBasarisiz(GeriYuklemeHatasi(neden: neden)) }
                else { self.kapat() }
            }
        } catch { geriYuklemeBasarisiz(error) }
    }

    private func geriYuklemeBasarisiz(_ hata: Error) {
        geriYuklemeBekliyor = false
        gtk_widget_set_sensitive(yukle, 1)
        bildir("Sürüm geri yüklenemedi", hata)
    }
}
