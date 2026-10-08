import CGtk
import Foundation
import NotDefteriCekirdek

/// macOS AnaSayfa + NotPenceresi+AnaSayfa karşılığı. Sayfa `anaSayfaYuvasi`nda durur; editör
/// tamponu korunur (gizleme/gösterme `LinuxPencere.icerigiGoster` ile). Tıklama sinyalleri eylemi
/// sonraki döngüye bırakır ve `nesil` değiştiyse düşürür; çizim sinyal içinden yapılmaz.
final class LinuxAnaSayfa {
    private typealias Parca = UnsafeMutablePointer<GtkWidget>

    private weak var pencere: LinuxPencere?
    private weak var editor: LinuxEditor?
    private weak var panel: LinuxKenarPaneli?
    private let kaydirma = gtk_scrolled_window_new()!
    private let stil = gtk_css_provider_new()!
    private let ekran: OpaquePointer
    private var gorunuyor = false
    private var cizimPlanli = false
    private var basaDonulsun = false
    private var kaydirmaKorunsun = false
    /// Editörün diskte olduğuna inandığı açık sayfa metni (macOS `kaydedici.sonYazilanIcerik`).
    /// EKSİK KANCA: LinuxEditor bunu açmıyor; açılış ve kayıt kancalarından izlenir.
    private var sonYazilan: (url: URL, metin: String)?

    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let anaSayfa = LinuxAnaSayfa(pencere: pencere, editor: editor, panel: panel)
        let veri = Unmanaged.passRetained(anaSayfa).toOpaque()
        let yuva: UnsafeMutablePointer<GObject> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(pencere.anaSayfaYuvasi))
        g_object_set_data_full(yuva, "nd-ana-sayfa", veri, { veri in
            if let veri { Unmanaged<LinuxAnaSayfa>.fromOpaque(veri).release() }
        })
        if gAcilistaAnaSayfa { pencere.icerigiGoster(anaSayfa: true) }
    }

    private init(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        self.pencere = pencere
        self.editor = editor
        self.panel = panel
        ekran = gtk_widget_get_display(pencere.pencere)!
        gtk_scrolled_window_set_policy(OpaquePointer(kaydirma), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_widget_set_vexpand(kaydirma, 1)
        gtk_widget_set_hexpand(kaydirma, 1)
        gtk_box_append(nd_box(pencere.anaSayfaYuvasi), kaydirma)
        // macOS AnaSayfa ile aynı: metin siyah %90 (soluk %60), kart kenar panel renginde ve üstünde
        // başlık çubuğu renginde 38 px şerit. Renkler LinuxTema'nın @nd-* tanımlarından gelir.
        gtk_css_provider_load_from_data(stil, """
        .nd-ana-selam { font-size: 28px; font-weight: 700; color: alpha(black, 0.9); }
        .nd-ana-bolum { font-size: 16px; font-weight: 600; color: alpha(black, 0.9); }
        .nd-ana-soluk { color: alpha(black, 0.6); }
        .nd-ana-kart-baslik { font-weight: 600; color: alpha(black, 0.9); }
        button.nd-ana-kart { background-image: none; background-color: @nd-panel; border: none; box-shadow: none; border-radius: 8px; padding: 0; }
        button.nd-ana-kart:hover { background-color: @nd-grup; }
        .nd-ana-kart-serit { background-color: @nd-baslik; min-height: 38px; }
        .nd-ana-kart .nd-ana-soluk { font-size: 11px; }
        """, -1)
        gtk_style_context_add_provider_for_display(ekran, nd_style_provider(stil),
                                                   guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
        kancalariBagla(editor, panel)
        menuleriEkle(pencere)
    }

    deinit {
        gtk_style_context_remove_provider_for_display(ekran, nd_style_provider(stil))
        g_object_unref(UnsafeMutableRawPointer(stil))
    }

    private func kancalariBagla(_ editor: LinuxEditor, _ panel: LinuxKenarPaneli) {
        editor.durumDegisti.append { [weak self] in self?.gorunurlukDegisti() }
        // Açılan belgenin kendisi kullanılır; diski yeniden okumak okuma ile açılış arasında yarışır.
        editor.notAcildi.append { [weak self] url, metin in self?.sonYazilan = metin.map { (url, $0) } }
        editor.kayitSonrasi.append { [weak self] url, metin in self?.sonYazilan = (url, metin) }
        panel.veriDegisti.append { [weak self] in
            if self?.gorunuyor == true { self?.cizimiPlanla() }
        }
    }

    private func menuleriEkle(_ pencere: LinuxPencere) {
        pencere.menuEkle(["Git", "Ana Sayfa"], kisayol: "<Control><Shift>h") { [weak pencere] in
            pencere?.icerigiGoster(anaSayfa: true)
        }
        let acilis = ["Görünüm", "Açılışta Ana Sayfa"]
        pencere.menuEkle(acilis, kisayol: nil) { [weak pencere] in
            gAcilistaAnaSayfa.toggle()
            pencere?.menuDurumu(acilis, etkin: true, isaretli: gAcilistaAnaSayfa)
        }
        pencere.menuDurumu(acilis, etkin: true, isaretli: gAcilistaAnaSayfa)
    }

    // MARK: Gösterim

    /// Mod değişimi `etkinligiAyarla` → `durumDegisti` ile gelir; yuva görünürlüğü o sırada günceldir.
    private func gorunurlukDegisti() {
        guard let pencere else { return }
        let gorunur = gtk_widget_get_visible(pencere.anaSayfaYuvasi) != 0
        guard gorunur != gorunuyor else { return }
        gorunuyor = gorunur
        guard gorunur else { return }
        let basa = !kaydirmaKorunsun
        kaydirmaKorunsun = false
        // Önbellek ve ağaç, dışarıdan değişmiş notları da yakalasın (macOS icerikOnbelleginiIste).
        // Açılışta panel az önce taradıysa (1000 sayfada ~300 ms) tekrarlanmaz.
        Platform.anaIsParcaciginda { [weak self] in
            guard let panel = self?.panel, Date().timeIntervalSince(panel.sonYenileme) > 2 else { return }
            panel.yenile()
        }
        cizimiPlanla(basaDon: basa)
    }

    private func cizimiPlanla(basaDon: Bool = false) {
        basaDonulsun = basaDonulsun || basaDon
        guard !cizimPlanli else { return }
        cizimPlanli = true
        Platform.anaIsParcaciginda { [weak self] in
            guard let self else { return }
            self.cizimPlanli = false
            if self.gorunuyor { self.ciz() }
        }
    }

    private func ciz() {
        guard let panel else { return }
        let ayar = gtk_scrolled_window_get_vadjustment(OpaquePointer(kaydirma))!
        let konum = basaDonulsun ? 0 : gtk_adjustment_get_value(ayar)
        basaDonulsun = false
        let icerik = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14)!
        gtk_widget_set_margin_top(icerik, 28)
        gtk_widget_set_margin_bottom(icerik, 28)
        gtk_widget_set_margin_start(icerik, 24)
        gtk_widget_set_margin_end(icerik, 24)
        selamBolumu(icerik)
        let onbellek = panel.icerikOnbellek
        func kartlar(_ urller: [URL]) -> [(url: URL, tarih: Date?)] {
            urller.filter { onbellek[$0] != nil }.map { ($0, panel.sayfaBaglantilari.sonAcilmaTarihi($0)) }
        }
        kartBolumu(icerik, "Son açılanlar", kartlar(Array(panel.sayfaBaglantilari.sonAcilanlar.prefix(8))))
        yapilacakBolumu(icerik, bekleyenYapilacaklariBul(onbellek))
        eylemBolumu(icerik)
        gtk_scrolled_window_set_child(OpaquePointer(kaydirma), icerik)
        // Yeni içerik yerleşmeden değer sıkışır; kaydırma konumu bir sonraki döngüde geri verilir.
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, let ayar = gtk_scrolled_window_get_vadjustment(OpaquePointer(self.kaydirma)) else { return }
            gtk_adjustment_set_value(ayar, konum)
        }
    }

    // MARK: Bölümler

    private func ekle(_ kutu: Parca, _ parca: Parca) { gtk_box_append(nd_box(kutu), parca) }

    private func etiket(_ metin: String, sinif: String? = nil) -> Parca {
        let alan = gtk_label_new(metin)!
        gtk_label_set_xalign(nd_label(alan), 0)
        gtk_label_set_ellipsize(nd_label(alan), PANGO_ELLIPSIZE_END)
        gtk_widget_set_halign(alan, GTK_ALIGN_START)
        if let sinif { gtk_widget_add_css_class(alan, sinif) }
        return alan
    }

    private func bolumBasligi(_ kutu: Parca, _ ad: String) {
        let baslik = etiket(ad, sinif: "nd-ana-bolum")
        gtk_widget_set_margin_top(baslik, 8)
        ekle(kutu, baslik)
    }

    private func selamBolumu(_ kutu: Parca) {
        let saat = Calendar.current.component(.hour, from: Date())
        ekle(kutu, etiket(saat < 12 ? "Günaydın" : saat < 18 ? "İyi günler" : "İyi akşamlar", sinif: "nd-ana-selam"))
        let bicim = DateFormatter()
        bicim.locale = Locale(identifier: "tr_TR")
        bicim.dateFormat = "d MMMM yyyy, EEEE"
        ekle(kutu, etiket(bicim.string(from: Date()), sinif: "nd-ana-soluk"))
    }

    private func kartBolumu(_ kutu: Parca, _ ad: String, _ kartlar: [(url: URL, tarih: Date?)]) {
        bolumBasligi(kutu, ad)
        guard !kartlar.isEmpty else {
            ekle(kutu, etiket("Henüz açılmış sayfa yok.", sinif: "nd-ana-soluk"))
            return
        }
        let seritKaydirma = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_policy(OpaquePointer(seritKaydirma), GTK_POLICY_AUTOMATIC, GTK_POLICY_NEVER)
        let serit = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12)!
        for kart in kartlar {
            let dugme = gtk_button_new()!
            gtk_widget_add_css_class(dugme, "nd-ana-kart")
            gtk_widget_set_size_request(dugme, 176, 114)
            gtk_widget_set_overflow(dugme, GTK_OVERFLOW_HIDDEN)
            gtk_widget_set_focus_on_click(dugme, 0)
            gtk_widget_set_tooltip_text(dugme, sayfaBagYolu(kart.url))
            let ic = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
            let renkSeridi = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
            gtk_widget_add_css_class(renkSeridi, "nd-ana-kart-serit")
            ekle(ic, renkSeridi)
            let baslik = etiket(sayfaAdi(kart.url), sinif: "nd-ana-kart-baslik")
            let zaman = etiket(kart.tarih.map(Self.goreliZaman) ?? "Daha önce açıldı", sinif: "nd-ana-soluk")
            for alan in [baslik, zaman] {
                gtk_widget_set_margin_start(alan, 12)
                gtk_widget_set_margin_end(alan, 12)
            }
            gtk_widget_set_margin_top(baslik, 13)
            gtk_widget_set_margin_top(zaman, 11)
            ekle(ic, baslik)
            ekle(ic, zaman)
            let buton: UnsafeMutablePointer<GtkButton> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(dugme))
            gtk_button_set_child(buton, ic)
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked") { [weak self] in
                self?.ertele { self?.editor?.notuAc(kart.url) }
            }
            ekle(serit, dugme)
        }
        gtk_scrolled_window_set_child(OpaquePointer(seritKaydirma), serit)
        ekle(kutu, seritKaydirma)
    }

    private func yapilacakBolumu(_ kutu: Parca, _ yapilacaklar: [BekleyenYapilacak]) {
        bolumBasligi(kutu, "Bekleyen yapılacaklar")
        guard !yapilacaklar.isEmpty else {
            ekle(kutu, etiket("Bekleyen yapılacak yok.", sinif: "nd-ana-soluk"))
            return
        }
        var sonURL: URL?
        for gorev in yapilacaklar.prefix(20) {
            if sonURL != gorev.url {
                let grup = etiket(sayfaAdi(gorev.url), sinif: "nd-ana-kart-baslik")
                gtk_widget_set_tooltip_text(grup, sayfaBagYolu(gorev.url))
                ekle(kutu, grup)
                sonURL = gorev.url
            }
            let satir = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
            let kutucuk = gtk_check_button_new()!
            gtk_widget_set_tooltip_text(kutucuk, "Yapılacağı tamamla: \(gorev.metin)")
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(kutucuk), "toggled") { [weak self] in
                self?.ertele { self?.yapilacagiTamamla(gorev) }
            }
            let bag = gtk_button_new_with_label(gorev.metin.isEmpty ? "(Boş yapılacak)" : gorev.metin)!
            gtk_widget_add_css_class(bag, "flat")
            gtk_widget_set_focus_on_click(bag, 0)
            gtk_widget_set_hexpand(bag, 1)
            gtk_widget_set_tooltip_text(bag, gorev.metin)
            let buton: UnsafeMutablePointer<GtkButton> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(bag))
            if let yazi = gtk_button_get_child(buton) {
                gtk_label_set_xalign(nd_label(yazi), 0)
                gtk_label_set_ellipsize(nd_label(yazi), PANGO_ELLIPSIZE_END)
            }
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(bag), "clicked") { [weak self] in
                self?.ertele { self?.yapilacagaGit(gorev) }
            }
            ekle(satir, kutucuk)
            ekle(satir, bag)
            ekle(kutu, satir)
        }
        if yapilacaklar.count > 20 { ekle(kutu, etiket("+\(yapilacaklar.count - 20) daha", sinif: "nd-ana-soluk")) }
    }

    private func eylemBolumu(_ kutu: Parca) {
        bolumBasligi(kutu, "Hızlı eylemler")
        let eylemler: [(String, () -> Void)] = [
            ("Yeni sayfa", { [weak self] in self?.yeniSayfa() }),
            ("Günlük not", { [weak self] in self?.gunlukNotuAc() }),
            ("Şablondan…", { [weak self] in self?.sablondanSayfaOlustur() })
        ]
        for (ad, eylem) in eylemler {
            let dugme = gtk_button_new_with_label(ad)!
            gtk_widget_add_css_class(dugme, "flat")
            gtk_widget_set_halign(dugme, GTK_ALIGN_START)
            gtk_widget_set_focus_on_click(dugme, 0)
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(dugme), "clicked") { [weak self] in self?.ertele(eylem) }
            ekle(kutu, dugme)
        }
    }

    /// Foundation'ın RelativeDateTimeFormatter'ı Linux'ta güvenilir olmayabilir; Türkçe kısa biçim elle.
    private static func goreliZaman(_ tarih: Date) -> String {
        let saniye = max(0, Int(Date().timeIntervalSince(tarih)))
        switch saniye {
        case ..<60: return "az önce"
        case ..<3_600: return "\(saniye / 60) dakika önce"
        case ..<86_400: return "\(saniye / 3_600) saat önce"
        case ..<604_800: return "\(saniye / 86_400) gün önce"
        default:
            let bicim = DateFormatter()
            bicim.locale = Locale(identifier: "tr_TR")
            bicim.dateFormat = "d MMM yyyy"
            return bicim.string(from: tarih)
        }
    }

    // MARK: Eylemler

    /// Sinyalden çıkar; ana sayfa/not değiştiyse (nesil) eylem düşer ve sayfa yeniden çizilir.
    private func ertele(_ eylem: @escaping () -> Void) {
        let beklenen = editor?.nesil
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.editor?.nesil == beklenen else { self?.cizimiPlanla(); return }
            eylem()
        }
    }

    private func hata(_ baslik: String, _ neden: String) {
        guard let ust = pencere?.pencere else { return }
        LinuxDiyalog.bilgi(ust: ust, baslik: baslik, aciklama: neden, hata: true)
    }

    private func uyarSesi() { gdk_display_beep(ekran) }

    /// Disk yalnızca tıklanan hedef için okunur; eski konumla başka satır işaretlenmez.
    private func guncelYapilacakMetni(_ gorev: BekleyenYapilacak) -> String? {
        guard let editor, let panel else { return nil }
        let acik = editor.acikURL == gorev.url
        // Başarısız kayıtta editör kendi uyarısını gösterir; eski tampon sonradan ezmesin.
        if acik, case .hata = editor.simdiKaydetSonucu(bildir: true) { return nil }
        do {
            try notlarYolunuDogrula(gorev.url)
            let metin = try String(contentsOf: gorev.url, encoding: .utf8)
            let acikMetin = sonYazilan?.url == gorev.url ? sonYazilan?.metin : nil
            guard yapilacakGecerliMi(gorev, metin: metin, onbellekMetni: panel.icerikOnbellek[gorev.url]?.hamMarkdown,
                                     acikSayfaMi: acik, acikSayfaMetni: acikMetin) else {
                panel.notIceriginiGuncelle(gorev.url, metin: metin)
                if acik, acikMetin != metin { diskindenYenidenYukle(gorev.url) } else { cizimiPlanla() }
                uyarSesi()
                return nil
            }
            return metin
        } catch {
            hata("Yapılacak okunamadı", error.localizedDescription)
            return nil
        }
    }

    /// Açık sayfa dışarıdan değişmişse editör diskten yüklenir; ana sayfa kaydırma konumuyla geri gelir.
    private func diskindenYenidenYukle(_ url: URL) {
        editor?.notuAc(url, yenidenYukle: true) { [weak self] _ in
            self?.kaydirmaKorunsun = true
            self?.pencere?.icerigiGoster(anaSayfa: true)
        }
    }

    /// Kaynak satırındaki konum ile editörün görünen belgesindeki konum farklıdır (başlık, görsel, kod).
    private func editorKonumu(_ gorev: BekleyenYapilacak, metin: String) -> Int {
        let govde = sayfaUstbilgisiniAyir(metin).govde as NSString
        return markdowndenAttributedStringUret(govde.substring(to: gorev.govdeKonumu), taban: sayfaKlasoru(gorev.url)).length
    }

    private func yapilacagaGit(_ gorev: BekleyenYapilacak) {
        guard let metin = guncelYapilacakMetni(gorev) else { return }
        let konum = editorKonumu(gorev, metin: metin)
        editor?.notuAc(gorev.url) { [weak self] tamam in
            guard tamam else { return }
            // Yerleşim bir sonraki döngüde hazır olur; iter o zaman hesaplanır.
            Platform.anaIsParcaciginda { self?.imleciGoster(gorev.url, konum) }
        }
    }

    private func imleciGoster(_ url: URL, _ konum: Int) {
        guard let editor, editor.acikURL == url, editor.editorEtkin,
              konum <= editor.belgeyiOku({ $0.length }) else { return }
        var iter = LinuxMetinDonusumu.iter(editor.tampon, konum)
        gtk_text_buffer_place_cursor(editor.tampon, &iter)
        let gorunum: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(editor.metinGorunumu))
        gtk_text_view_scroll_to_iter(gorunum, &iter, 0.1, 0, 0, 0)
        gtk_widget_grab_focus(editor.metinGorunumu)
    }

    private func yapilacagiTamamla(_ gorev: BekleyenYapilacak) {
        guard let editor, let panel else { return }
        guard let metin = guncelYapilacakMetni(gorev) else { cizimiPlanla(); return }
        let sonuc: (markdown: String, satir: String)
        do { sonuc = try yapilacagiTamamlayanMetin(gorev, metin: metin) }
        catch {
            hata("Yapılacak tamamlanamadı", error.localizedDescription)
            cizimiPlanla()
            return
        }
        guard editor.acikURL == gorev.url else {
            do {
                try notlarYolunuDogrula(gorev.url)
                try sonuc.markdown.write(to: gorev.url, atomically: true, encoding: .utf8)
                panel.notIceriginiGuncelle(gorev.url, metin: sonuc.markdown)
            } catch { hata("Yapılacak kaydedilemedi", error.localizedDescription) }
            cizimiPlanla()
            return
        }
        // Açık sayfa: tampon ve disk birlikte güncellenir; yalnızca hedef paragraf değişir.
        // Belge kopyası uygulama anında üretilir; arada bağ yeniden yazımı gibi değişiklikler ezilmez.
        let konum = editorKonumu(gorev, metin: metin)
        let taban = sayfaKlasoru(gorev.url)
        let eskiSatir = markdowndenAttributedStringUret(gorev.satir, taban: taban).string.trimmingCharacters(in: .newlines)
        var hedefDegisti = false
        editor.acikBelgeyiGuncelle(gorev.url, uret: { guncel in
            let belge = NSMutableAttributedString(attributedString: guncel)
            guard konum < belge.length else { hedefDegisti = true; return nil }
            let paragraf = belge.mutableString.paragraphRange(for: NSRange(location: konum, length: 0))
            // Konum, tamponun artık başka bir satırına denk gelmiş olabilir; yalnızca hedef satır değiştirilir.
            let blok = MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: paragraf.location, effectiveRange: nil))
            guard paragraf.location == konum, blok?.tur == .yapilacak, blok?.tamamlandi == false,
                  belge.mutableString.substring(with: paragraf).trimmingCharacters(in: .newlines) == eskiSatir else {
                hedefDegisti = true
                return nil
            }
            belge.replaceCharacters(in: paragraf, with: markdowndenAttributedStringUret(sonuc.satir, taban: taban))
            return belge
        }) { [weak self] sonuc in
            // Kayıt hatasını editör kendi uyarısıyla bildirir; yalnızca "sayfa artık açık değil" burada gösterilir.
            if case .hata(let neden) = sonuc, self?.editor?.acikURL != gorev.url { self?.hata("Yapılacak tamamlanamadı", neden) }
            if hedefDegisti { self?.uyarSesi() }
            self?.cizimiPlanla()
        }
    }

    // MARK: Hızlı eylemler

    private func yeniSayfa() {
        sayfaOlustur(url: { [weak self] in
            benzersizSayfaURLSonucu(taban: "Yeni Sayfa", klasor: self?.panel?.hedefKlasor() ?? notlarKlasoru()).url
        }, metin: "", otomatikAd: true)
    }

    private func gunlukNotuAc() {
        let tarih = Date()
        do {
            let url = try gunlukNotURL(tarih)
            if dosyaYoluVarMi(url), let editor {
                editor.notuAc(url) { tamam in
                    if tamam, editor.editorEtkin { gtk_widget_grab_focus(editor.metinGorunumu) }
                }
            }
            else { sayfaOlustur(url: { url }, metin: SayfaSablonu.gunluk.markdown(tarih: tarih)) }
        } catch { hata("Günlük not açılamadı", error.localizedDescription) }
    }

    private func sablondanSayfaOlustur() {
        guard let ust = pencere?.pencere else { return }
        let sablonlar = SayfaSablonu.allCases
        // İlk düğme varsayılandır; "Vazgeç" başta durur, şablonlar 2'den başlar.
        LinuxDiyalog.mesaj(ust: ust, baslik: "Şablondan yeni sayfa", aciklama: "Bir şablon seçin.",
                           dugmeler: ["Vazgeç"] + sablonlar.map(\.rawValue), tur: GTK_MESSAGE_QUESTION) { [weak self] yanit in
            guard yanit >= 2, yanit - 2 < sablonlar.count else { return }
            let sablon = sablonlar[yanit - 2]
            self?.sayfaOlustur(url: { [weak self] in
                benzersizSayfaURLSonucu(taban: sablon.rawValue, klasor: self?.panel?.hedefKlasor() ?? notlarKlasoru()).url
            }, metin: sablon.markdown())
        }
    }

    /// Önce açık not kaydedilir (islemOncesi); dosya aynı klasörde yayımlanır, mevcut notun üzerine yazılmaz.
    /// `otomatikAd`: boş "Yeni Sayfa"nın adı ilk satırı izler (macOS yeniNotOlustur); şablon ve günlükte izlemez.
    private func sayfaOlustur(url olusturURL: @escaping () -> URL, metin: String, otomatikAd: Bool = false) {
        editor?.islemOncesi { [weak self] in
            guard let self, let editor = self.editor else { return }
            let url = olusturURL()
            do { try icerikleSayfaOlustur(url: url, metin: metin) }
            catch {
                self.hata("Sayfa oluşturulamadı", error.localizedDescription)
                return
            }
            self.panel?.yenile()
            if otomatikAd { editor.yeniSayfayiAc(url); return }
            editor.notuAc(url) { tamam in
                if tamam, editor.editorEtkin { gtk_widget_grab_focus(editor.metinGorunumu) }
            }
        }
    }
}
