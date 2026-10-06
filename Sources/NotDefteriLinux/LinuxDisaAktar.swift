import CGtk
import Foundation
import NotDefteriCekirdek

/// Dışa aktarma (macOS NotPenceresi+DisaAktar): HTML ve Markdown çekirdekten, PDF GtkPrintOperation ile.
/// Her zaman kaydedilmiş (diskteki) içerik kullanılır; hedefi FileChooserNative seçer (bloklamaz).
enum LinuxDisaAktar {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let islem = DisaAktarIslemi(pencere: pencere, editor: editor)
        let girisler: [(yol: [String], kisayol: String?, eylem: () -> Void)] = [
            (["Dosya", "Dışa aktar", "PDF"], "<Control><Shift>e", islem.pdf),
            (["Dosya", "Dışa aktar", "HTML"], nil, islem.html),
            (["Dosya", "Dışa aktar", "Markdown"], nil, islem.markdown),
            (["Düzen", "Markdown olarak kopyala"], nil, islem.kopyala)]
        for giris in girisler { pencere.menuEkle(giris.yol, kisayol: giris.kisayol, eylem: giris.eylem) }
        let durumuGuncelle = { [weak pencere, weak editor] in
            let etkin = editor?.editorEtkin == true && editor?.acikURL != nil
            for giris in girisler { pencere?.menuDurumu(giris.yol, etkin: etkin, isaretli: nil) }
        }
        editor.durumDegisti.append(durumuGuncelle)
        durumuGuncelle()
    }
}

private final class DisaAktarIslemi {
    private weak var pencere: LinuxPencere?
    private weak var editor: LinuxEditor?

    init(pencere: LinuxPencere, editor: LinuxEditor) {
        self.pencere = pencere
        self.editor = editor
    }

    /// Bekleyen düzenleme kaydedilir (başarısızsa "Kaydetmeden Devam" sorulur); çıktı diskten okunur.
    private func sayfayiAl(_ devam: @escaping (LinuxPencere, MarkdownAktarimSayfasi) -> Void) {
        guard let editor, editor.editorEtkin else { return }
        editor.islemOncesi { [weak self, weak editor] in
            guard let self, let pencere = self.pencere, let editor, editor.editorEtkin, let url = editor.acikURL else { return }
            do {
                let sayfa = try MarkdownDisaAktar.oku(url)
                // "Kaydetmeden Devam" seçildiyse çıktı eski disk sürümünden gelir; kullanıcı bir kez bilgilendirilir.
                guard editor.kaydedilmemisDegisiklikVar else { devam(pencere, sayfa); return }
                LinuxDiyalog.bilgi(ust: pencere.pencere, baslik: "Kaydedilmiş sürüm dışa aktarılacak",
                                   aciklama: "Son değişiklikler kaydedilemedi; dışa aktarma diskteki kayıtlı sürümü kullanır.") {
                    devam(pencere, sayfa)
                }
            } catch { self.bildir(error) }
        }
    }

    private func bildir(_ hata: Error) {
        guard let pencere else { return }
        LinuxDiyalog.bilgi(ust: pencere.pencere, baslik: "Sayfa dışa aktarılamadı",
                           aciklama: hata.localizedDescription, hata: true)
    }

    private func kaydet(uzanti: String, _ yaz: @escaping (MarkdownAktarimSayfasi, URL, LinuxPencere) throws -> Void) {
        sayfayiAl { [weak self] pencere, sayfa in
            LinuxDiyalog.dosyaKaydet(ust: pencere.pencere, baslik: "\(uzanti.uppercased()) olarak kaydet",
                                     onerilenAd: sayfaAdi(sayfa.url) + "." + uzanti) { secilen in
                guard let secilen else { return }
                // Uzantı türe göre zorlanır; GTK seçicisi yalnızca yazılan adın üzerine yazmayı sormuştur.
                let hedef = secilen.pathExtension.lowercased() == uzanti ? secilen : secilen.appendingPathExtension(uzanti)
                let calistir = { do { try yaz(sayfa, hedef, pencere) } catch { self?.bildir(error) } }
                guard hedef != secilen, FileManager.default.fileExists(atPath: hedef.path) else { calistir(); return }
                LinuxDiyalog.onay(ust: pencere.pencere, baslik: "\"\(hedef.lastPathComponent)\" üzerine yazılsın mı?",
                                  aciklama: "Bu adla bir dosya zaten var.", onay: "Üzerine yaz", iptal: "Vazgeç") { evet in
                    if evet { calistir() }
                }
            }
        }
    }

    func kopyala() {
        sayfayiAl { pencere, sayfa in
            guard let pano = gtk_widget_get_clipboard(pencere.pencere) else { return }
            gdk_clipboard_set_text(pano, sayfa.markdown)
        }
    }

    func html() {
        kaydet(uzanti: "html") { sayfa, hedef, _ in
            try MarkdownDisaAktar.gorselKaynaklariniDogrula(sayfa)
            let html = try htmlUret(markdown: sayfa.markdown, baslik: sayfaAdi(sayfa.url), taban: sayfaKlasoru(sayfa.url))
            try html.write(to: hedef, atomically: true, encoding: .utf8)
        }
    }

    func markdown() {
        kaydet(uzanti: "md") { sayfa, hedef, _ in
            try MarkdownDisaAktar.aktar(sayfa, hedef: hedef, gorselDogrula: gorselOkunabilirMi)
        }
    }

    func pdf() {
        kaydet(uzanti: "pdf") { sayfa, hedef, pencere in
            try MarkdownDisaAktar.gorselKaynaklariniDogrula(sayfa)
            PdfBaskisi(sayfa: sayfa, baslik: sayfaAdi(sayfa.url)).yaz(hedef: hedef, ust: pencere.pencere) { [weak self] hata in
                if let hata { self?.bildir(hata) }
            }
        }
    }
}

/// Yalnızca başlık okunur (biçim ve boyut); görsel belleğe çözülmez. Çözme sınırıyla aynı alan üst sınırı.
private func gorselOkunabilirMi(_ url: URL) -> Bool {
    guard url.isFileURL, (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return false }
    var en: gint = 0, boy: gint = 0
    guard gdk_pixbuf_get_file_info(url.path, &en, &boy) != nil else { return false }
    return en > 0 && boy > 0 && Int(en) * Int(boy) <= 64_000_000
}

// MARK: - PDF

private struct PdfHatasi: LocalizedError {
    let neden: String
    var errorDescription: String? { neden }
}

private let baskiBaslarC: @convention(c) (gpointer?, OpaquePointer?, gpointer?) -> Void = { islem, baglam, veri in
    guard let islem, let baglam, let veri else { return }
    let sayfaSayisi = Unmanaged<PdfBaskisi>.fromOpaque(veri).takeUnretainedValue().hazirla(baglam)
    gtk_print_operation_set_n_pages(islem.assumingMemoryBound(to: GtkPrintOperation.self), sayfaSayisi)
}

private let baskiSayfaC: @convention(c) (gpointer?, OpaquePointer?, Int32, gpointer?) -> Void = { _, baglam, sayfa, veri in
    guard let baglam, let veri else { return }
    Unmanaged<PdfBaskisi>.fromOpaque(veri).takeUnretainedValue().ciz(baglam, sayfa: Int(sayfa))
}

/// GtkTextView otomatik basılmaz: belge paragraf paragraf Pango yerleşimine çevrilir, satır
/// sınırlarında sayfalanır (begin-print) ve Cairo/Pango ile çizilir (draw-page). Görseller Cairo yüzeyidir.
/// ponytail: uyarı kutusu/alıntı çerçevesi çizilmez, yalnızca girinti; kod bloğu satır arka planıyla ayrışır.
private final class PdfBaskisi {
    private struct Oge {
        let yukseklik: Double
        let ciz: (OpaquePointer, Double) -> Void
    }

    private static let punto = 12.0
    private static let olcek = 1024.0 // PANGO_SCALE

    private let sayfa: MarkdownAktarimSayfasi
    private let baslik: String
    private var baglam: OpaquePointer?
    private var genislik = 0.0
    private var yukseklik = 0.0
    private var yerlesimler: [OpaquePointer] = []
    private var sayfalar: [[(y: Double, oge: Oge)]] = []

    init(sayfa: MarkdownAktarimSayfasi, baslik: String) {
        self.sayfa = sayfa
        self.baslik = baslik
    }

    deinit { for yerlesim in yerlesimler { g_object_unref(UnsafeMutableRawPointer(yerlesim)) } }

    /// A4, 40 pt kenar boşluğu (Mac ile aynı); işlem EXPORT olduğu için yazıcı iletişim kutusu açılmaz.
    /// İşlem eşzamansızdır (iç içe ana döngü yok): `bitti`, "done" sinyalinden sonra ana döngüde çağrılır.
    /// `self` ve GtkPrintOperation o ana dek tutulur.
    func yaz(hedef: URL, ust: UnsafeMutablePointer<GtkWidget>, bitti: @escaping (Error?) -> Void) {
        let islem = gtk_print_operation_new()!
        let kurulum = gtk_page_setup_new()!
        defer { g_object_unref(UnsafeMutableRawPointer(kurulum)) }
        let kagit = gtk_paper_size_new(GTK_PAPER_NAME_A4)!
        gtk_page_setup_set_paper_size(kurulum, kagit)
        gtk_paper_size_free(kagit)
        gtk_page_setup_set_top_margin(kurulum, 40, GTK_UNIT_POINTS)
        gtk_page_setup_set_bottom_margin(kurulum, 40, GTK_UNIT_POINTS)
        gtk_page_setup_set_left_margin(kurulum, 40, GTK_UNIT_POINTS)
        gtk_page_setup_set_right_margin(kurulum, 40, GTK_UNIT_POINTS)
        gtk_print_operation_set_default_page_setup(islem, kurulum)
        gtk_print_operation_set_unit(islem, GTK_UNIT_POINTS)
        gtk_print_operation_set_export_filename(islem, hedef.path)
        gtk_print_operation_set_job_name(islem, baslik)
        gtk_print_operation_set_allow_async(islem, 1)
        let veri = Unmanaged.passRetained(self).toOpaque()
        let nesne = UnsafeMutableRawPointer(islem)
        g_signal_connect_data(nesne, "begin-print", unsafeBitCast(baskiBaslarC, to: GCallback.self), veri, nil, GConnectFlags(rawValue: 0))
        g_signal_connect_data(nesne, "draw-page", unsafeBitCast(baskiSayfaC, to: GCallback.self), veri, nil, GConnectFlags(rawValue: 0))
        // "done" ve run dönüşü aynı sonucu bildirebilir; yalnızca ilki geçerlidir.
        var bitirildi = false
        let bitir: (Error?) -> Void = { hata in
            guard !bitirildi else { return }
            bitirildi = true
            // Sinyal içinden nesne bırakılmaz; sonraki döngüde.
            Platform.anaIsParcaciginda {
                Unmanaged<PdfBaskisi>.fromOpaque(veri).release()
                g_object_unref(nesne)
                bitti(hata)
            }
        }
        GtkKoprusu.sinyalBagla(nesne, "done") { (sonuc: gint) in
            if sonuc == GTK_PRINT_OPERATION_RESULT_APPLY.rawValue { bitir(nil); return }
            var gerr: UnsafeMutablePointer<GError>?
            gtk_print_operation_get_error(islem, &gerr)
            let neden = gerr.map { String(cString: $0.pointee.message) } ?? "PDF yazılamadı."
            if let gerr { g_error_free(gerr) }
            bitir(PdfHatasi(neden: neden))
        }
        var hata: UnsafeMutablePointer<GError>?
        let sonuc = gtk_print_operation_run(islem, GTK_PRINT_OPERATION_ACTION_EXPORT, nd_window(ust), &hata)
        if let hata {
            let neden = String(cString: hata.pointee.message)
            g_error_free(hata)
            bitir(PdfHatasi(neden: neden))
        } else if sonuc == GTK_PRINT_OPERATION_RESULT_APPLY {
            bitir(nil)
        } else if sonuc != GTK_PRINT_OPERATION_RESULT_IN_PROGRESS {
            bitir(PdfHatasi(neden: "PDF yazılamadı."))
        }
    }

    /// begin-print: tüm belge sayfalanır; dönen değer sayfa sayısıdır.
    fileprivate func hazirla(_ baglam: OpaquePointer) -> Int32 {
        self.baglam = baglam
        genislik = gtk_print_context_get_width(baglam)
        yukseklik = gtk_print_context_get_height(baglam)
        let belge = markdowndenAttributedStringUret(sayfaUstbilgisiniAyir(sayfa.markdown).govde, taban: sayfaKlasoru(sayfa.url))
        var ogeler = metinOgeleri("<span weight=\"bold\" size=\"\(26 * 1024)\">\(htmlKacir(baslik))</span>",
                                  sol: 0, indent: 0, sekme: nil, bosluk: 12)
        let ns = belge.string as NSString
        var konum = 0
        while konum < ns.length {
            let aralik = ns.paragraphRange(for: NSRange(location: konum, length: 0))
            ogeler += paragraf(belge, aralik)
            konum = NSMaxRange(aralik)
        }
        sayfalar = [[]]
        var y = 0.0
        for oge in ogeler {
            if y > 0, y + oge.yukseklik > yukseklik { sayfalar.append([]); y = 0 }
            sayfalar[sayfalar.count - 1].append((y, oge))
            y += oge.yukseklik
        }
        return Int32(sayfalar.count)
    }

    fileprivate func ciz(_ baglam: OpaquePointer, sayfa: Int) {
        guard sayfalar.indices.contains(sayfa), let cr = gtk_print_context_get_cairo_context(baglam) else { return }
        cairo_set_source_rgb(cr, 0, 0, 0)
        for (y, oge) in sayfalar[sayfa] { oge.ciz(cr, y) }
    }

    // MARK: Belge → öğeler

    private func paragraf(_ belge: NSAttributedString, _ aralik: NSRange) -> [Oge] {
        let o = belge.attributes(at: aralik.location, effectiveRange: nil)
        let blok = MetinBlogu(oznitelik: o[kMetinBloguAnahtari])
        if blok?.tur == .ayirici { return [ayirici()] }
        let geometri = o[kParagrafGeometrisiAnahtari] as? [String: Any] ?? [:]
        func olcu(_ ad: String) -> Double { geometri[ad] as? Double ?? 0 }
        let ilk = olcu("ilkSatirGirintisi"), govde = olcu("govdeGirintisi"), sol = min(ilk, govde)
        let ns = belge.string as NSString
        var ogeler: [Oge] = []
        var markup = ""
        func metniBosalt() {
            guard !markup.isEmpty else { return }
            ogeler += metinOgeleri(markup, sol: sol, indent: ilk - govde, sekme: govde > ilk ? govde - ilk : nil,
                                   bosluk: olcu("paragrafBoslugu"))
            markup = ""
        }
        belge.enumerateAttributes(in: aralik) { oz, alt, _ in
            if let gorsel = oz[kGorselAnahtari] as? [String: Any] {
                metniBosalt()
                for _ in 0..<alt.length { if let oge = gorselOgesi(gorsel, sol: sol) { ogeler.append(oge) } }
                return
            }
            // Liste imi (•, ☐) basılır; kod çiti/başlık işareti gibi görünmez işaretler basılmaz.
            let gizli = (oz[kBlokIsaretiAnahtari] as? Bool == true && blok?.listeMi != true)
                || oz[kBosKodSatiriAnahtari] as? Bool == true
            let yazi = Self.temizle(ns.substring(with: alt))
            if !gizli, !yazi.isEmpty { markup += Self.parca(yazi, oz, blok: blok) }
        }
        metniBosalt()
        // Boş satır da dikey boşluk taşır.
        if ogeler.isEmpty { ogeler = metinOgeleri("", sol: sol, indent: 0, sekme: nil, bosluk: 0) }
        return ogeler
    }

    private func ayirici() -> Oge {
        let genislik = genislik
        return Oge(yukseklik: 14) { cr, y in
            cairo_set_source_rgb(cr, 0.6, 0.6, 0.6)
            cairo_set_line_width(cr, 1)
            cairo_move_to(cr, 0, y + 7)
            cairo_line_to(cr, genislik, y + 7)
            cairo_stroke(cr)
            cairo_set_source_rgb(cr, 0, 0, 0)
        }
    }

    /// Her Pango satırı ayrı öğedir; böylece sayfa sınırı paragrafın ortasından geçebilir.
    private func metinOgeleri(_ markup: String, sol: Double, indent: Double, sekme: Double?, bosluk: Double) -> [Oge] {
        guard let baglam else { return [] }
        let yerlesim = gtk_print_context_create_pango_layout(baglam)!
        yerlesimler.append(yerlesim)
        let yazitipi = pango_font_description_from_string("Sans \(Self.punto)")
        pango_layout_set_font_description(yerlesim, yazitipi)
        pango_font_description_free(yazitipi)
        pango_layout_set_width(yerlesim, Int32(max(1, genislik - sol) * Self.olcek))
        pango_layout_set_wrap(yerlesim, PANGO_WRAP_WORD_CHAR)
        pango_layout_set_indent(yerlesim, Int32(indent * Self.olcek))
        if let sekme {
            let sekmeler = pango_tab_array_new(1, 1)!
            pango_tab_array_set_tab(sekmeler, 0, PANGO_TAB_LEFT, Int32(sekme))
            pango_layout_set_tabs(yerlesim, sekmeler)
            pango_tab_array_free(sekmeler)
        }
        pango_layout_set_markup(yerlesim, markup, -1)
        var ogeler: [Oge] = []
        let satirlar = pango_layout_get_iter(yerlesim)!
        defer { pango_layout_iter_free(satirlar) }
        repeat {
            var mantik = PangoRectangle()
            pango_layout_iter_get_line_extents(satirlar, nil, &mantik)
            let taban = Double(pango_layout_iter_get_baseline(satirlar) - mantik.y) / Self.olcek
            let x = sol + Double(mantik.x) / Self.olcek
            let satir = pango_layout_iter_get_line_readonly(satirlar)
            ogeler.append(Oge(yukseklik: Double(mantik.height) / Self.olcek) { cr, y in
                cairo_move_to(cr, x, y + taban)
                pango_cairo_show_layout_line(cr, satir)
            })
        } while pango_layout_iter_next_line(satirlar) != 0
        if let son = ogeler.popLast() { ogeler.append(Oge(yukseklik: son.yukseklik + bosluk, ciz: son.ciz)) }
        return ogeler
    }

    private func gorselOgesi(_ gorsel: [String: Any], sol: Double) -> Oge? {
        guard let url = gorsel["dosyaURL"] as? URL, let resim = BaskiGorseli(url) else { return nil }
        var en = min(360, resim.en), boy = en * resim.boy / resim.en
        if let e = gorsel["genislik"] as? Double, let b = gorsel["yukseklik"] as? Double,
           anlamsalGorselBoyutuGecerliMi(en: e, boy: b) { en = e; boy = b }
        let oran = min(1, (genislik - sol) / en, 600 / boy, yukseklik / boy)
        return Oge(yukseklik: boy * oran + 4) { cr, y in
            cairo_save(cr)
            cairo_translate(cr, sol, y)
            cairo_scale(cr, en * oran / resim.en, boy * oran / resim.boy)
            cairo_set_source_surface(cr, resim.yuzey, 0, 0)
            cairo_paint(cr)
            cairo_restore(cr)
        }
    }

    // MARK: Pango markup

    /// Pango markup'ı geçersiz denetim karakterlerini reddeder; satır sonları paragraf düzeyinde zaten ayrılmıştır.
    private static func temizle(_ yazi: String) -> String {
        String(String.UnicodeScalarView(yazi.unicodeScalars.filter {
            ($0.value >= 0x20 || $0.value == 9) && $0.value != 0x7F && $0.value != 0x200B
                && $0.value != 0xFFFC && !(0xFFFE...0xFFFF).contains($0.value)
        }))
    }

    /// Anlamsal öznitelikler → tek `span`; adaptörün ekrandaki etiketleriyle aynı eşleme.
    private static func parca(_ yazi: String, _ o: Oznitelikler, blok: MetinBlogu?) -> String {
        let kod = o[kKodBloguAnahtari] != nil
        let satirIciKod = o[kSatirIciKodAnahtari] as? Bool == true
        var puan = punto
        if let seviye = o[kBaslikSeviyesiAnahtari] as? Int, !kod { puan *= [1.75, 1.4, 1.15][min(max(seviye, 1), 3) - 1] }
        else if let oran = o[kPuntoOlcegiAnahtari] as? Double, oran.isFinite, oran > 0 { puan *= oran }
        let tamamlandi = blok?.tur == .yapilacak && blok?.tamamlandi == true && o[kBlokIsaretiAnahtari] as? Bool != true
        var oz = ["size=\"\(Int(max(1, puan) * olcek))\""]
        if (o[kKalinAnahtari] as? Bool) ?? (o[kBaslikSeviyesiAnahtari] != nil && !kod) { oz.append("weight=\"bold\"") }
        if o[kItalikAnahtari] as? Bool == true { oz.append("style=\"italic\"") }
        if tamamlandi || o[kUstuCiziliAnahtari] as? Bool == true { oz.append("strikethrough=\"true\"") }
        if kod || satirIciKod { oz.append("font_family=\"monospace\"") }
        var onPlan: String?, arkaPlan: String?
        if tamamlandi { onPlan = "#808080" }
        if kod || satirIciKod { arkaPlan = "#f0f0f0" }
        if o[kVurguAnahtari] as? Bool == true { arkaPlan = "#ffe68a" }
        if o[kBaglantiAnahtari] != nil || o[kSayfaBagiAnahtari] != nil { onPlan = "#1464b4"; oz.append("underline=\"single\"") }
        if let onPlan { oz.append("foreground=\"\(onPlan)\"") }
        if let arkaPlan { oz.append("background=\"\(arkaPlan)\"") }
        return "<span \(oz.joined(separator: " "))>\(htmlKacir(yazi))</span>"
    }
}

/// Görsel, editörle aynı codec'le (GdkTexture) okunur; Cairo yüzeyi baskı bitene dek yaşar.
private final class BaskiGorseli {
    let yuzey: OpaquePointer
    let en: Double
    let boy: Double
    private let veri: UnsafeMutablePointer<UInt8>

    init?(_ url: URL) {
        guard url.isFileURL, (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
        var hata: UnsafeMutablePointer<GError>?
        guard let doku = gdk_texture_new_from_filename(url.path, &hata) else {
            if let hata { g_error_free(hata) }
            return nil
        }
        defer { g_object_unref(UnsafeMutableRawPointer(doku)) }
        let e = Int(gdk_texture_get_width(doku)), b = Int(gdk_texture_get_height(doku))
        guard e > 0, b > 0, e * b <= 64_000_000 else { return nil }
        let tampon = UnsafeMutablePointer<UInt8>.allocate(capacity: e * b * 4)
        gdk_texture_download(doku, tampon, gsize(e * 4)) // Cairo ARGB32 (önceden çarpılmış) düzeni.
        guard let yuzey = cairo_image_surface_create_for_data(tampon, CAIRO_FORMAT_ARGB32, Int32(e), Int32(b), Int32(e * 4)),
              cairo_surface_status(yuzey) == CAIRO_STATUS_SUCCESS else {
            tampon.deallocate()
            return nil
        }
        veri = tampon
        self.yuzey = yuzey
        en = Double(e)
        boy = Double(b)
    }

    deinit {
        cairo_surface_destroy(yuzey)
        veri.deallocate()
    }
}
