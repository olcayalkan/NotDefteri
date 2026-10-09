import CGtk
import Foundation
import NotDefteriCekirdek

private final class GirisEylemi {
    let eylem: () -> Void
    init(_ eylem: @escaping () -> Void) { self.eylem = eylem }
}

/// GtkEventControllerMotion::enter (controller, x, y, veri): koordinatlar double'dır; tek işaretçili
/// köprüyle bağlanınca veri yanlış yazmaçtan okunup çöküyordu.
private let girisC: @convention(c) (gpointer?, Double, Double, gpointer?) -> Void = { _, _, _, veri in
    guard let veri else { return }
    Unmanaged<GirisEylemi>.fromOpaque(veri).takeUnretainedValue().eylem()
}

/// macOS IcindekilerPaneli: editörün sağ üstünde yüzer, yer kaplamaz. Kapalıyken başlıklar
/// düzeye göre kısalan çizgilerdir; fareyle üzerine gelince adlarıyla açılır. Sahiplik panelin
/// GTK kabındadır; editör ve pencereye geri bağlar zayıftır.
final class LinuxIcindekiler {
    private struct Girdi: Equatable {
        let metin: String
        let seviye: Int
        let konum: Int
    }

    private weak var pencere: LinuxPencere?
    private weak var editor: LinuxEditor?
    private let cerceve = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    private let kaydirma = gtk_scrolled_window_new()!
    private let icerik = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
    private let baslikKutusu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    private let bagKutusu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    private var girdiler: [Girdi] = []
    private var satirlar: [UnsafeMutablePointer<GtkWidget>] = []
    /// Satır başına (çizgi, ad): kapalıyken çizgi, açıkken ad görünür.
    private var satirParcalari: [(cizgi: UnsafeMutablePointer<GtkWidget>, ad: UnsafeMutablePointer<GtkWidget>)] = []
    private var acik = false
    private var etkinSira: Int?
    private var gizli = false
    private var konumlarGecersiz = false
    private var baslikNesli = 0
    private var baslikIptal: ZamanlayiciIptal?
    private var bagNesli = 0
    private var bagOnbellegi: [URL: OnbellekGirdisi] = [:]
    private var sayfaOnbellegi: [URL: SayfaSecenegi] = [:]
    private var baglantiVerenler: [SayfaSecenegi] = []

    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let icindekiler = LinuxIcindekiler(pencere: pencere, editor: editor)
        panel.veriDegisti.append { [weak icindekiler] in icindekiler?.geriBaglantilariTazele() }
        let veri = Unmanaged.passRetained(icindekiler).toOpaque()
        let yuva: UnsafeMutablePointer<GObject> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(icindekiler.cerceve))
        g_object_set_data_full(yuva, "nd-icindekiler", veri, { veri in
            if let veri { Unmanaged<LinuxIcindekiler>.fromOpaque(veri).release() }
        })
    }

    private init(pencere: LinuxPencere, editor: LinuxEditor) {
        self.pencere = pencere
        self.editor = editor
        gorunumuKur(editor)
        kancalariBagla(pencere, editor)
        if editor.editorEtkin { notAcildi() }
    }

    deinit { baslikIptal?() }

    private func gorunumuKur(_ editor: LinuxEditor) {
        gtk_widget_add_css_class(cerceve, "nd-icindekiler")
        gtk_widget_set_halign(cerceve, GTK_ALIGN_END)
        gtk_widget_set_valign(cerceve, GTK_ALIGN_START)
        gtk_widget_set_margin_top(cerceve, 10)
        gtk_widget_set_margin_end(cerceve, 10)
        let kaydirici = OpaquePointer(kaydirma)
        gtk_scrolled_window_set_policy(kaydirici, GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_propagate_natural_height(kaydirici, 1)
        gtk_scrolled_window_set_propagate_natural_width(kaydirici, 1)
        gtk_widget_set_margin_top(icerik, 6)
        gtk_widget_set_margin_bottom(icerik, 6)
        gtk_widget_set_margin_start(icerik, 4)
        gtk_widget_set_margin_end(icerik, 4)
        gtk_box_append(nd_box(icerik), baslikKutusu)
        gtk_box_append(nd_box(icerik), bagKutusu)
        gtk_widget_set_visible(bagKutusu, 0)
        gtk_scrolled_window_set_child(kaydirici, icerik)
        gtk_box_append(nd_box(cerceve), kaydirma)
        // GtkOverlay yalnızca ana çocuğunu ölçer: panel editörün genişliğine katılmaz, pencereyi büyütmez.
        gtk_overlay_add_overlay(OpaquePointer(editor.ustKatman), cerceve)
        let hareket = gtk_event_controller_motion_new()!
        let giris = Unmanaged.passRetained(GirisEylemi { [weak self] in self?.acikligiAyarla(true) }).toOpaque()
        g_signal_connect_data(UnsafeMutableRawPointer(hareket), "enter", unsafeBitCast(girisC, to: GCallback.self), giris, { veri, _ in
            if let veri { Unmanaged<GirisEylemi>.fromOpaque(veri).release() }
        }, GConnectFlags(rawValue: 0))
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(hareket), "leave") { [weak self] in
            self?.acikligiAyarla(false)
        }
        gtk_widget_add_controller(cerceve, hareket)
    }

    /// macOS hover davranışı: açıkken başlık adları ve bağlantı verenler, kapalıyken yalnız çizgiler.
    private func acikligiAyarla(_ yeni: Bool) {
        guard acik != yeni else { return }
        acik = yeni
        if yeni { gtk_widget_add_css_class(cerceve, "acik") } else { gtk_widget_remove_css_class(cerceve, "acik") }
        for parca in satirParcalari {
            gtk_widget_set_visible(parca.cizgi, yeni ? 0 : 1)
            gtk_widget_set_visible(parca.ad, yeni ? 1 : 0)
        }
        gtk_widget_set_visible(bagKutusu, yeni && !baglantiVerenler.isEmpty ? 1 : 0)
        Platform.anaIsParcaciginda { [weak self] in self?.etkinSatiriGoster() }
    }

    /// Panel editörün yüksekliğini aşmaz; aşan başlıklar panelin içinde kayar.
    private func yuksekligiSinirla() {
        guard let editor else { return }
        let yukseklik = gtk_widget_get_height(editor.ustKatman)
        guard yukseklik > 0 else { return }
        gtk_scrolled_window_set_max_content_height(OpaquePointer(kaydirma), max(60, yukseklik - 40))
    }

    private func kancalariBagla(_ pencere: LinuxPencere, _ editor: LinuxEditor) {
        editor.degisiklikSonrasi.append { [weak self] in self?.basliklariPlanla() }
        LinuxEklentiler.yasamDongusunuIzle(editor) { [weak self] in self?.notAcildi() }
        editor.kayitSonrasi.append { [weak self] url, _ in
            // Girdi arka plandaki taramada diskten yeniden üretilir; ana döngüde büyük notta
            // ~250 ms sürüyordu.
            self?.bagOnbellegi[url] = nil
            self?.geriBaglantilariTazele()
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.tampon), "changed") { [weak self] in
            // degisiklikSonrasi ana döngüde gelir; eski konumları hemen geçersiz kıl.
            self?.konumlariGecersizKil()
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.tampon), "notify::cursor-position") {
            [weak self] (_: gpointer?) in
            guard let self, let editor = self.editor else { return }
            var iter = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &iter, gtk_text_buffer_get_insert(editor.tampon))
            self.etkinBasligiGuncelle(LinuxMetinDonusumu.konum(iter))
        }
        // Kaydırırken etkin başlık imleci değil okunan bölümü izler (macOS ile aynı).
        editor.kaydirildi.append { [weak self] in
            guard let self, let editor = self.editor else { return }
            self.etkinBasligiGuncelle(editor.okunanKonum())
        }
        editor.boyutDegisti.append { [weak self] in self?.yuksekligiSinirla() }
        // boyutDegisti yatay ayardan gelir; yalnız yükseklik değişince de sınır güncellensin (sayfa
        // boyu = görünür yükseklik). Boyut dağıtımı içinde sınır yazmamak için ertelenir.
        if let dikey = gtk_scrollable_get_vadjustment(OpaquePointer(editor.metinGorunumu)) {
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dikey), "notify::page-size") { [weak self] (_: gpointer?) in
                Platform.anaIsParcaciginda { [weak self] in self?.yuksekligiSinirla() }
            }
        }
        // Panel yer kaplamaz; yine de istenirse gizlenebilir.
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
            satirParcalari = []
            satirlar = yeni.map { girdi in
                let (dugme, cizgi, ad) = basliksatiriUret(girdi)
                satirParcalari.append((cizgi, ad))
                GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked") { [weak self] in
                    self?.basligaGit(girdi.konum)
                }
                return dugme
            }
        }
        konumlarGecersiz = false
        gorunurluguGuncelle()
        if let editor {
            var iter = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &iter, gtk_text_buffer_get_insert(editor.tampon))
            etkinBasligiGuncelle(LinuxMetinDonusumu.konum(iter))
        }
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

    /// Kapalıyken çizgi (düzeye göre kısalır, sağa yaslı), açıkken girintili ad (macOS ile aynı).
    private func basliksatiriUret(_ girdi: Girdi) -> (UnsafeMutablePointer<GtkWidget>, UnsafeMutablePointer<GtkWidget>, UnsafeMutablePointer<GtkWidget>) {
        let dugme = gtk_button_new()!
        gtk_widget_add_css_class(dugme, "flat")
        gtk_widget_set_focus_on_click(dugme, 0)
        gtk_widget_set_tooltip_text(dugme, girdi.metin)
        let kutu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        // GtkButton çocuğunu ortalar; satır tam genişlik olmalı ki ad sola, çizgi sağa yaslansın.
        gtk_widget_set_hexpand(kutu, 1)
        gtk_widget_set_halign(kutu, GTK_ALIGN_FILL)
        let ad = gtk_label_new(girdi.metin)!
        gtk_label_set_xalign(nd_label(ad), 0)
        gtk_label_set_ellipsize(nd_label(ad), PANGO_ELLIPSIZE_END)
        gtk_label_set_max_width_chars(nd_label(ad), 24)
        gtk_widget_set_hexpand(ad, 1)
        gtk_widget_set_margin_start(ad, Int32((girdi.seviye - 1) * 12))
        gtk_widget_set_visible(ad, acik ? 1 : 0)
        let cizgi = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(cizgi, "nd-cizgi")
        gtk_widget_set_size_request(cizgi, [18, 12, 8][min(2, max(0, girdi.seviye - 1))], 2)
        gtk_widget_set_halign(cizgi, GTK_ALIGN_END)
        gtk_widget_set_valign(cizgi, GTK_ALIGN_CENTER)
        gtk_widget_set_hexpand(cizgi, 1)
        gtk_widget_set_visible(cizgi, acik ? 0 : 1)
        gtk_box_append(nd_box(kutu), ad)
        gtk_box_append(nd_box(kutu), cizgi)
        gtk_button_set_child(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(dugme)), kutu)
        gtk_box_append(nd_box(baslikKutusu), dugme)
        return (dugme, cizgi, ad)
    }

    private func etkinBasligiGuncelle(_ konum: Int) {
        guard !konumlarGecersiz, let editor, editor.editorEtkin else { return }
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

    /// Etkin başlık listenin ortasında durur (macOS etkinSatiriOrtala).
    private func etkinSatiriGoster() {
        guard !gizli, !konumlarGecersiz, let etkinSira, satirlar.indices.contains(etkinSira) else { return }
        var kare = graphene_rect_t()
        guard gtk_widget_compute_bounds(satirlar[etkinSira], icerik, &kare) != 0 else { return }
        let ayar = gtk_scrolled_window_get_vadjustment(OpaquePointer(kaydirma))!
        let boy = gtk_adjustment_get_page_size(ayar)
        let enFazla = max(0, gtk_adjustment_get_upper(ayar) - boy)
        let orta = Double(kare.origin.y) + Double(kare.size.height) / 2
        gtk_adjustment_set_value(ayar, min(max(0, orta - boy / 2), enFazla))
    }

    private func basligaGit(_ konum: Int) {
        guard !konumlarGecersiz, let editor, editor.editorEtkin, konum < editor.belge.length else { return }
        var iter = LinuxMetinDonusumu.iter(editor.tampon, konum)
        gtk_text_buffer_place_cursor(editor.tampon, &iter)
        let gorunum: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(editor.metinGorunumu))
        gtk_text_view_scroll_to_iter(gorunum, &iter, 0.1, 0, 0, 0)
        gtk_widget_grab_focus(editor.metinGorunumu)
        etkinBasligiGuncelle(konum)
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
        gtk_widget_set_visible(bagKutusu, acik && !sayfalar.isEmpty ? 1 : 0)
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

    /// Panel yer kaplamadığı için pencere genişliğinden bağımsızdır; başlık yoksa ya da gizlendiyse görünmez.
    private func gorunurluguGuncelle() {
        let gorunur = !gizli && !girdiler.isEmpty && editor?.editorEtkin == true
        if !gorunur { acikligiAyarla(false) }
        gtk_widget_set_visible(cerceve, gorunur ? 1 : 0)
        yuksekligiSinirla()
    }
}
