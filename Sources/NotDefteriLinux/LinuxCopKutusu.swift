import CGtk
import Foundation
import NotDefteriCekirdek

private typealias Parca = UnsafeMutablePointer<GtkWidget>

private func ham(_ p: Parca) -> UnsafeMutableRawPointer { UnsafeMutableRawPointer(p) }

/// Çöp kutusu penceresi (macOS CopKutusuPaneli) ve açılıştaki 30 günlük temizlik.
/// Dosya işlemleri yeniden yazılmaz: hepsi paneldeki tek `CopKutusu` örneğinden (ortak kilit) geçer.
final class LinuxCopKutusu {
    private static let geriAlinamaz = "Bu işlem geri alınamaz. Alt sayfalar ve görseller de kalıcı silinir."

    private weak var editor: LinuxEditor?
    private weak var panel: LinuxKenarPaneli?
    private let copKutusu: CopKutusu
    private let pencere = gtk_window_new()!
    private let arama = gtk_search_entry_new()!
    private let liste = gtk_list_box_new()!
    private let durum = gtk_label_new("")!
    private let bosalt = gtk_button_new_with_label("Çöpü boşalt")!
    private var ogeler: [CopOgesi] = []
    private var okumaHatalari: [String] = []
    private var yuklemeNesli = 0

    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let cop = LinuxCopKutusu(ust: pencere.pencere, editor: editor, panel: panel)
        let dugme = GtkKoprusu.simgeliDugme("user-trash-symbolic", "Çöp kutusu")
        gtk_widget_set_margin_top(dugme, 4)
        gtk_widget_set_margin_bottom(dugme, 8)
        gtk_widget_set_margin_start(dugme, 8)
        gtk_widget_set_margin_end(dugme, 8)
        // Sinyal closure'ı örneği düğmenin (ana pencerenin) ömrü boyunca tutar.
        GtkKoprusu.sinyalBagla(ham(dugme), "clicked") { cop.goster() }
        pencere.menuEkle(["Dosya", "Çöp kutusu"], kisayol: nil) { cop.goster() }
        gtk_box_append(nd_box(pencere.kenarPanelYuvasi), dugme)
        eskileriTemizle(panel.copKutusu, pencere: pencere)
    }

    /// macOS'taki gibi açılışta arka planda; hatalar yalnızca bildirilir.
    private static func eskileriTemizle(_ copKutusu: CopKutusu, pencere: LinuxPencere) {
        DispatchQueue.global(qos: .utility).async { [weak pencere] in
            let hatalar = copKutusu.temizle(eskiOlanlar: true)
            guard !hatalar.isEmpty else { return }
            Platform.anaIsParcaciginda {
                guard let ust = pencere?.pencere else { return }
                LinuxDiyalog.bilgi(ust: ust, baslik: "Eski çöp öğeleri temizlenemedi",
                                   aciklama: hatalar.joined(separator: "\n"), hata: true)
            }
        }
    }

    private init(ust: Parca, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        self.editor = editor
        self.panel = panel
        copKutusu = panel.copKutusu
        // Kip penceresi: açıkken ağaç değişemez, liste bayatlamaz.
        gtk_window_set_title(nd_window(pencere), "Çöp kutusu")
        gtk_window_set_transient_for(nd_window(pencere), nd_window(ust))
        gtk_window_set_modal(nd_window(pencere), 1)
        gtk_window_set_destroy_with_parent(nd_window(pencere), 1)
        gtk_window_set_hide_on_close(nd_window(pencere), 1)
        gtk_window_set_default_size(nd_window(pencere), 450, 360)

        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8)!
        for kenar in [gtk_widget_set_margin_top, gtk_widget_set_margin_bottom,
                      gtk_widget_set_margin_start, gtk_widget_set_margin_end] { kenar(kutu, 12) }
        gNesneOzelligi(ham(arama), "placeholder-text", .metin("Çöp kutusunda ara"))
        // Yalnızca yüklenmiş adlar süzülür; tuş başına disk taraması yok.
        GtkKoprusu.sinyalBagla(ham(arama), "search-changed") { [weak self] in self?.filtrele() }
        gtk_box_append(nd_box(kutu), arama)

        gtk_list_box_set_selection_mode(OpaquePointer(ham(liste)), GTK_SELECTION_NONE)
        let kaydirma = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_policy(OpaquePointer(ham(kaydirma)), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(OpaquePointer(ham(kaydirma)), liste)
        gtk_widget_set_vexpand(kaydirma, 1)
        gtk_box_append(nd_box(kutu), kaydirma)

        let alt = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_label_set_xalign(nd_label(durum), 0)
        gtk_widget_set_hexpand(durum, 1)
        gtk_widget_add_css_class(durum, "dim-label")
        gtk_box_append(nd_box(alt), durum)
        gtk_widget_add_css_class(bosalt, "destructive-action")
        GtkKoprusu.sinyalBagla(ham(bosalt), "clicked") { [weak self] in self?.bosaltSor() }
        gtk_box_append(nd_box(alt), bosalt)
        gtk_box_append(nd_box(kutu), alt)
        gtk_window_set_child(nd_window(pencere), kutu)
    }

    private func goster() {
        gtk_editable_set_text(OpaquePointer(ham(arama)), "")
        yenile()
        gtk_window_present(nd_window(pencere))
    }

    /// Açılıştaki temizlik aynı kilidi tutabilir; okuma arka planda yapılır ki pencere donmasın.
    private func yenile() {
        yuklemeNesli &+= 1
        let nesil = yuklemeNesli
        gtk_label_set_text(nd_label(durum), "Yükleniyor…")
        DispatchQueue.global(qos: .userInitiated).async { [copKutusu, weak self] in
            let sonuc = Result { try copKutusu.ogeler() }
            Platform.anaIsParcaciginda { [weak self] in
                guard let self, self.yuklemeNesli == nesil else { return }
                switch sonuc {
                case .success(let veri):
                    self.ogeler = veri.ogeler
                    self.okumaHatalari = veri.hatalar
                    self.filtrele()
                case .failure(let hata):
                    self.hataGoster(hata.localizedDescription)
                }
            }
        }
    }

    private func filtrele() {
        let metin = gtk_editable_get_text(OpaquePointer(ham(arama))).map { String(cString: $0) } ?? ""
        let sorgu = aramaIcinSadelestir(metin)
        let kutu = OpaquePointer(ham(liste))
        while let cocuk = gtk_widget_get_first_child(liste) { gtk_list_box_remove(kutu, cocuk) }
        for oge in ogeler where sorgu.isEmpty || aramaIcinSadelestir(oge.ad).contains(sorgu) {
            gtk_list_box_append(kutu, satir(oge))
        }
        var yazi = ogeler.isEmpty ? "Çöp kutusu boş" : "\(ogeler.count) öğe · 30 gün saklanır"
        if !okumaHatalari.isEmpty { yazi += " · \(okumaHatalari.count) öğe okunamadı" }
        gtk_label_set_text(nd_label(durum), yazi)
        gtk_widget_set_tooltip_text(durum, okumaHatalari.isEmpty ? nil : okumaHatalari.joined(separator: "\n"))
        gtk_widget_set_sensitive(bosalt, ogeler.isEmpty && okumaHatalari.isEmpty ? 0 : 1)
    }

    private func satir(_ oge: CopOgesi) -> Parca {
        let kutu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_widget_set_margin_top(kutu, 4)
        gtk_widget_set_margin_bottom(kutu, 4)
        let bilgi = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
        gtk_widget_set_hexpand(bilgi, 1)
        // Emoji (📁/📄) yerine simge temasından simge: emoji yazı tipi olmayan sistemlerde kutu görünüyordu.
        let baslik = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        gtk_box_append(nd_box(baslik), gtk_image_new_from_icon_name(oge.bilgi.icerikDosyasi == nil ? "folder-symbolic" : "text-x-generic-symbolic"))
        let ad = gtk_label_new(oge.ad)!
        gtk_label_set_xalign(nd_label(ad), 0)
        gtk_label_set_ellipsize(nd_label(ad), PANGO_ELLIPSIZE_END)
        gtk_widget_set_tooltip_text(ad, oge.bilgi.ozgunYol)
        gtk_box_append(nd_box(baslik), ad)
        gtk_box_append(nd_box(bilgi), baslik)
        let zaman = gtk_label_new(Self.zamanMetni(oge.bilgi.silinmeTarihi))!
        gtk_label_set_xalign(nd_label(zaman), 0)
        gtk_widget_add_css_class(zaman, "dim-label")
        gtk_box_append(nd_box(bilgi), zaman)
        gtk_box_append(nd_box(kutu), bilgi)
        // Satır, işlemden sonra yeniden kurulur; düğme kendi sinyali içinde yok edilmesin diye eylem sonraki döngüdedir.
        let eylemler: [(String, () -> Void)] = [
            ("Geri yükle", { [weak self] in self?.geriYukle(oge) }),
            ("Kalıcı sil", { [weak self] in self?.kaliciSilSor(oge) })
        ]
        for (baslik, eylem) in eylemler {
            let dugme = gtk_button_new_with_label(baslik)!
            gtk_widget_set_valign(dugme, GTK_ALIGN_CENTER)
            GtkKoprusu.sinyalBagla(ham(dugme), "clicked") { Platform.anaIsParcaciginda(eylem) }
            gtk_box_append(nd_box(kutu), dugme)
        }
        return kutu
    }

    /// corelibs'te RelativeDateTimeFormatter'a güvenilmez; gün sayısı yeterli.
    private static func zamanMetni(_ tarih: Date) -> String {
        let gun = Calendar.current.dateComponents([.day], from: tarih, to: Date()).day ?? 0
        return gun <= 0 ? "Bugün silindi" : "\(gun) gün önce silindi"
    }

    /// Çekirdek özgün üst yoksa/hedef doluysa kökte benzersiz ad seçer; birleştirme/üzerine yazma yok.
    private func geriYukle(_ oge: CopOgesi) {
        do {
            try copKutusu.geriYukle(oge)
            panel?.yenile()
        } catch { hataGoster(error.localizedDescription) }
        yenile()
    }

    private func kaliciSilSor(_ oge: CopOgesi) {
        LinuxDiyalog.onay(ust: pencere, baslik: "\"\(oge.ad)\" kalıcı silinsin mi?", aciklama: Self.geriAlinamaz,
                          onay: "Kalıcı sil", iptal: "Vazgeç") { [weak self] evet in
            guard evet, let self else { return }
            do { try self.copKutusu.kaliciSil(oge) } catch { self.hataGoster(error.localizedDescription) }
            self.yenile()
        }
    }

    private func bosaltSor() {
        LinuxDiyalog.onay(ust: pencere, baslik: "Çöp kutusu boşaltılsın mı?", aciklama: Self.geriAlinamaz,
                          onay: "Çöpü boşalt", iptal: "Vazgeç") { [weak self] evet in
            guard evet, let editor = self?.editor else { return }
            // Boşaltma kayıt kancasından geçer; kancada iptal edilirse hiçbir şey silinmez.
            // Kayıt uyarısı modal çöp penceresinin arkasında kalmasın diye ona bağlanır.
            editor.islemOncesi(ust: self?.pencere) { [weak self] in
                guard let self else { return }
                let hatalar = self.copKutusu.temizle(eskiOlanlar: false)
                if !hatalar.isEmpty { self.hataGoster(hatalar.joined(separator: "\n")) }
                self.yenile()
            }
        }
    }

    private func hataGoster(_ mesaj: String) {
        LinuxDiyalog.bilgi(ust: pencere, baslik: "Çöp kutusu işlemi tamamlanamadı", aciklama: mesaj, hata: true)
    }
}
