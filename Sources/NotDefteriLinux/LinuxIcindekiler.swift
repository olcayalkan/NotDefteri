import CGtk
import Foundation
import NotDefteriCekirdek

/// Sağ panelin sahipliği GTK yuvasında; editör ve pencereye geri bağlar zayıftır.
final class LinuxIcindekiler {
    private struct Girdi: Equatable {
        let metin: String
        let seviye: Int
        let konum: Int
    }

    private weak var pencere: LinuxPencere?
    private weak var editor: LinuxEditor?
    private let kaydirma = gtk_scrolled_window_new()!
    private let icerik = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
    private let baslikKutusu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    private let bagKutusu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    private var girdiler: [Girdi] = []
    private var satirlar: [UnsafeMutablePointer<GtkWidget>] = []
    private var etkinSira: Int?
    private var gizli = false
    private var konumlarGecersiz = false
    private var baslikNesli = 0
    private var baslikIptal: ZamanlayiciIptal?
    private var bagNesli = 0
    private var bagOnbellegi: [URL: OnbellekGirdisi] = [:]
    private var sayfaOnbellegi: [URL: SayfaSecenegi] = [:]
    private var baglantiVerenler: [SayfaSecenegi] = []
    /// Panel (180) ile editörün okunur en küçük genişliği; daha dar alanda panel gösterilmez.
    /// Gösterilseydi GTK en küçük genişliği karşılamak için pencereyi büyütüyordu.
    private static let gerekenGenislik: Int32 = 180 + 420

    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let icindekiler = LinuxIcindekiler(pencere: pencere, editor: editor)
        panel.veriDegisti.append { [weak icindekiler] in icindekiler?.geriBaglantilariTazele() }
        let veri = Unmanaged.passRetained(icindekiler).toOpaque()
        let yuva: UnsafeMutablePointer<GObject> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(pencere.sagPanelYuvasi))
        g_object_set_data_full(yuva, "nd-icindekiler", veri, { veri in
            if let veri { Unmanaged<LinuxIcindekiler>.fromOpaque(veri).release() }
        })
    }

    private init(pencere: LinuxPencere, editor: LinuxEditor) {
        self.pencere = pencere
        self.editor = editor
        gorunumuKur(pencere)
        kancalariBagla(pencere, editor)
        if editor.editorEtkin { notAcildi() }
    }

    deinit { baslikIptal?() }

    private func gorunumuKur(_ pencere: LinuxPencere) {
        gtk_widget_set_size_request(kaydirma, 180, -1)
        gtk_widget_set_vexpand(kaydirma, 1)
        gtk_scrolled_window_set_policy(OpaquePointer(kaydirma), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_widget_set_margin_top(icerik, 10)
        gtk_widget_set_margin_bottom(icerik, 10)
        gtk_widget_set_margin_start(icerik, 8)
        gtk_widget_set_margin_end(icerik, 8)
        gtk_box_append(nd_box(icerik), baslikKutusu)
        gtk_box_append(nd_box(icerik), bagKutusu)
        gtk_scrolled_window_set_child(OpaquePointer(kaydirma), icerik)
        gtk_box_append(nd_box(pencere.sagPanelYuvasi), kaydirma)
    }

    private func kancalariBagla(_ pencere: LinuxPencere, _ editor: LinuxEditor) {
        editor.degisiklikSonrasi.append { [weak self] in self?.basliklariPlanla() }
        LinuxEklentiler.yasamDongusunuIzle(editor) { [weak self] in self?.notAcildi() }
        editor.kayitSonrasi.append { [weak self] url, metin in
            self?.bagOnbellegi[url] = onbellekGirdisiUret(metin, tarih: degistirilmeTarihi(URL(fileURLWithPath: url.path)))
            self?.geriBaglantilariTazele()
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.tampon), "changed") { [weak self] in
            // degisiklikSonrasi ana döngüde gelir; eski konumları hemen geçersiz kıl.
            self?.konumlariGecersizKil()
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.tampon), "notify::cursor-position") {
            [weak self] (_: gpointer?) in self?.etkinBasligiGuncelle()
        }
        // Alan değişince panelin sığıp sığmadığı yeniden değerlendirilir. Sayfa ana sayfadan ilk
        // gösterildiğinde genişlik henüz 0'dır; ilk boyut dağıtımı da bu kancayı tetikler.
        editor.boyutDegisti.append { [weak self] in self?.gorunurluguGuncelle() }
        // macOS hover ile açılır; Linux'ta kalıcı panel ve gizleme kısayolu kullanılır.
        pencere.menuEkle(["Görünüm", "İçindekiler paneli"], kisayol: "<Control><Shift>backslash") { [weak self] in
            guard let self else { return }
            self.gizli.toggle()
            self.gorunurluguGuncelle()
            Platform.anaIsParcaciginda { [weak self] in self?.etkinSatiriGoster() }
        }
    }

    private func notAcildi() {
        baslikNesli += 1
        baslikIptal?()
        baslikIptal = nil
        bagNesli += 1
        baglantiVerenler = []
        kutuyuBosalt(bagKutusu)
        basliklariGuncelle()
        geriBaglantilariTazele()
    }

    private func konumlariGecersizKil() {
        konumlarGecersiz = true
        etkinligiAyarla(nil)
    }

    private func basliklariPlanla() {
        baslikNesli += 1
        baslikIptal?()
        guard editor?.editorEtkin == true else {
            baslikIptal = nil
            notAcildi()
            return
        }
        konumlariGecersizKil()
        let nesil = baslikNesli
        baslikIptal = Platform.zamanlayici(0.15) { [weak self] in
            guard let self, self.baslikNesli == nesil else { return }
            self.baslikIptal = nil
            self.basliklariGuncelle()
        }
    }

    private func basliklariGuncelle() {
        let yeni: [Girdi]
        if let editor, editor.editorEtkin { yeni = basliklariTopla(editor.belge) }
        else { yeni = [] }
        if girdiler != yeni {
            etkinligiAyarla(nil)
            girdiler = yeni
            kutuyuBosalt(baslikKutusu)
            satirlar = yeni.map { girdi in
                let dugme = dugmeUret(girdi.metin, kutu: baslikKutusu)
                gtk_widget_set_margin_start(dugme, Int32((girdi.seviye - 1) * 12))
                GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked") { [weak self] in
                    self?.basligaGit(girdi.konum)
                }
                return dugme
            }
        }
        konumlarGecersiz = false
        gorunurluguGuncelle()
        etkinBasligiGuncelle()
    }

    /// macOS gibi yalnızca paragraf başındaki düzey geçerli; boş başlıklar atlanır.
    private func basliklariTopla(_ belge: NSAttributedString) -> [Girdi] {
        let ns = belge.string as NSString
        var sonuc: [Girdi] = []
        belge.enumerateAttribute(kBaslikSeviyesiAnahtari, in: NSRange(location: 0, length: belge.length)) { deger, aralik, _ in
            guard let seviye = deger as? Int, (1...3).contains(seviye) else { return }
            var konum = aralik.location
            while konum < NSMaxRange(aralik) {
                let paragraf = ns.paragraphRange(for: NSRange(location: konum, length: 0))
                let metin = ns.substring(with: paragraf).replacingOccurrences(of: "\u{200B}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !metin.isEmpty, sonuc.last?.konum != paragraf.location,
                   let duzey = belge.attribute(kBaslikSeviyesiAnahtari, at: paragraf.location, effectiveRange: nil) as? Int,
                   (1...3).contains(duzey) {
                    sonuc.append(Girdi(metin: metin, seviye: duzey, konum: paragraf.location))
                }
                konum = max(NSMaxRange(paragraf), konum + 1)
            }
        }
        return sonuc
    }

    private func etkinBasligiGuncelle() {
        guard !konumlarGecersiz, let editor, editor.editorEtkin else { return }
        var iter = GtkTextIter()
        gtk_text_buffer_get_iter_at_mark(editor.tampon, &iter, gtk_text_buffer_get_insert(editor.tampon))
        let konum = LinuxMetinDonusumu.konum(iter)
        var alt = 0, ust = girdiler.count
        while alt < ust {
            let orta = alt + (ust - alt) / 2
            if girdiler[orta].konum <= konum { alt = orta + 1 } else { ust = orta }
        }
        let yeni: Int? = alt > 0 ? alt - 1 : nil
        guard yeni != etkinSira else { return }
        etkinligiAyarla(yeni)
        Platform.anaIsParcaciginda { [weak self] in self?.etkinSatiriGoster() }
    }

    private func etkinligiAyarla(_ yeni: Int?) {
        if let etkinSira {
            gtk_widget_remove_css_class(satirlar[etkinSira], "nd-etkin")
            gtk_widget_add_css_class(satirlar[etkinSira], "flat")
        }
        etkinSira = yeni
        if let yeni {
            gtk_widget_remove_css_class(satirlar[yeni], "flat")
            // suggested-action temanın mavi vurgusudur; kağıt temasıyla uyumlu kendi sınıfımız kullanılır.
            gtk_widget_add_css_class(satirlar[yeni], "nd-etkin")
        }
    }

    private func etkinSatiriGoster() {
        guard !gizli, !konumlarGecersiz, let etkinSira else { return }
        var kare = graphene_rect_t()
        guard gtk_widget_compute_bounds(satirlar[etkinSira], icerik, &kare) != 0 else { return }
        let ayar = gtk_scrolled_window_get_vadjustment(OpaquePointer(kaydirma))!
        let bas = Double(kare.origin.y), son = bas + Double(kare.size.height)
        let ust = gtk_adjustment_get_value(ayar), boy = gtk_adjustment_get_page_size(ayar)
        if bas < ust { gtk_adjustment_set_value(ayar, bas) }
        else if son > ust + boy { gtk_adjustment_set_value(ayar, max(0, son - boy)) }
    }

    private func basligaGit(_ konum: Int) {
        guard !konumlarGecersiz, let editor, editor.editorEtkin, konum < editor.belge.length else { return }
        var iter = LinuxMetinDonusumu.iter(editor.tampon, konum)
        gtk_text_buffer_place_cursor(editor.tampon, &iter)
        let gorunum: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(editor.metinGorunumu))
        gtk_text_view_scroll_to_iter(gorunum, &iter, 0.1, 0, 0, 0)
        gtk_widget_grab_focus(editor.metinGorunumu)
        etkinBasligiGuncelle()
    }

    /// Disk taraması yalnızca açılış/kayıtta; eski işler not değişiminde uygulanmaz.
    private func geriBaglantilariTazele() {
        bagNesli += 1
        guard let hedef = editor?.acikURL else { return }
        let nesil = bagNesli, eskiBaglar = bagOnbellegi, eskiSayfalar = sayfaOnbellegi
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sonuc = Self.geriBagSonucu(hedef, eskiBaglar: eskiBaglar, eskiSayfalar: eskiSayfalar)
            Platform.anaIsParcaciginda { [weak self] in
                guard let self, self.bagNesli == nesil, self.editor?.acikURL == hedef else { return }
                self.bagOnbellegi = sonuc.baglar
                self.sayfaOnbellegi = sonuc.sayfalar
                self.baglariGuncelle(sonuc.verenler)
            }
        }
    }

    private static func geriBagSonucu(_ hedef: URL, eskiBaglar: [URL: OnbellekGirdisi],
                                      eskiSayfalar: [URL: SayfaSecenegi])
        -> (baglar: [URL: OnbellekGirdisi], sayfalar: [URL: SayfaSecenegi], verenler: [SayfaSecenegi]) {
        let sayfalar = notlariDuzlestir(agaciYukle()).map { eskiSayfalar[$0] ?? SayfaSecenegi(url: $0) }
        let indeks = SayfaBaglantilari()
        indeks.guncelle(sayfalar)
        var baglar: [URL: OnbellekGirdisi] = [:]
        for sayfa in sayfalar {
            let tarih = degistirilmeTarihi(URL(fileURLWithPath: sayfa.url.path))
            if let eski = eskiBaglar[sayfa.url], eski.tarih == tarih { baglar[sayfa.url] = eski }
            else {
                do {
                    let metin = try String(contentsOf: sayfa.url, encoding: .utf8)
                    baglar[sayfa.url] = onbellekGirdisiUret(metin, tarih: tarih)
                } catch {
                    FileHandle.standardError.write(Data("[NotDefteri] Geri bağlantı okunamadı (\(sayfa.url.path)): \(error.localizedDescription)\n".utf8))
                }
            }
        }
        let verenler = sayfalar.filter { sayfa in
            baglar[sayfa.url]?.bagHedefleri.contains { indeks.coz($0) == hedef } ?? false
        }.sorted { $0.yol.localizedStandardCompare($1.yol) == .orderedAscending }
        return (baglar, Dictionary(sayfalar.map { ($0.url, $0) }, uniquingKeysWith: { ilk, _ in ilk }), verenler)
    }

    private static func notlariDuzlestir(_ dugumler: [AgacDugumu]) -> [URL] {
        dugumler.flatMap { ($0.icerikURL.map { [$0] } ?? []) + notlariDuzlestir($0.cocuklar) }
    }

    private func baglariGuncelle(_ sayfalar: [SayfaSecenegi]) {
        guard sayfalar != baglantiVerenler else { return }
        baglantiVerenler = sayfalar
        kutuyuBosalt(bagKutusu)
        guard !sayfalar.isEmpty else { return }
        let baslik = gtk_label_new("Bağlantı verenler")!
        gtk_label_set_xalign(nd_label(baslik), 0)
        gtk_widget_add_css_class(baslik, "dim-label")
        gtk_widget_set_margin_top(baslik, 12)
        gtk_box_append(nd_box(bagKutusu), baslik)
        for sayfa in sayfalar {
            let dugme = dugmeUret(sayfa.yol, kutu: bagKutusu)
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked") { [weak self] in
                self?.editor?.notuAc(sayfa.url)
            }
        }
    }

    private func dugmeUret(_ metin: String, kutu: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWidget> {
        let dugme = gtk_button_new_with_label(metin)!
        gtk_widget_add_css_class(dugme, "flat")
        gtk_widget_set_focus_on_click(dugme, 0)
        gtk_widget_set_tooltip_text(dugme, metin)
        let buton: UnsafeMutablePointer<GtkButton> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(dugme))
        if let etiket = gtk_button_get_child(buton) {
            gtk_label_set_xalign(nd_label(etiket), 0)
            gtk_label_set_ellipsize(nd_label(etiket), PANGO_ELLIPSIZE_END)
            gtk_label_set_max_width_chars(nd_label(etiket), 22)
        }
        gtk_box_append(nd_box(kutu), dugme)
        return dugme
    }

    private func kutuyuBosalt(_ kutu: UnsafeMutablePointer<GtkWidget>) {
        while let cocuk = gtk_widget_get_first_child(kutu) { gtk_box_remove(nd_box(kutu), cocuk) }
    }

    private func gorunurluguGuncelle() {
        guard let pencere else { return }
        // Editör ve panel aynı kutudadır; kutunun genişliği panelin görünürlüğüyle değişmez.
        let alan = gtk_widget_get_parent(pencere.sagPanelYuvasi).map { gtk_widget_get_width($0) } ?? 0
        let gorunur = !gizli && !girdiler.isEmpty && editor?.editorEtkin == true && alan >= Self.gerekenGenislik
        if !gorunur, let odak = gtk_window_get_focus(nd_window(pencere.pencere)),
           odak == pencere.sagPanelYuvasi || gtk_widget_is_ancestor(odak, pencere.sagPanelYuvasi) != 0,
           let editor { gtk_widget_grab_focus(editor.metinGorunumu) }
        gtk_widget_set_visible(pencere.sagPanelYuvasi, gorunur ? 1 : 0)
    }
}
