import CGtk
import Foundation
import NotDefteriCekirdek

// MARK: - C sinyal köprüsü (GtkKoprusu'nda olmayan imzalar)

/// Widget'lar pencereyle birlikte yok edilirken editör önce bırakılabilir; sinyal verisi zayıf tutar.
private final class ZayifEditor {
    weak var editor: LinuxEditor?
    init(_ editor: LinuxEditor) { self.editor = editor }
}

private func editor(_ veri: gpointer?) -> LinuxEditor? {
    veri.flatMap { Unmanaged<ZayifEditor>.fromOpaque($0).takeUnretainedValue().editor }
}

private func cBagla(_ nesne: UnsafeMutableRawPointer, _ ad: String, _ geri: GCallback, _ hedef: LinuxEditor) {
    let veri = Unmanaged.passRetained(ZayifEditor(hedef)).toOpaque()
    g_signal_connect_data(nesne, ad, geri, veri, { veri, _ in
        if let veri { Unmanaged<ZayifEditor>.fromOpaque(veri).release() }
    }, GConnectFlags(rawValue: 0))
}

private let metinEklenecekC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextIter>?, UnsafePointer<CChar>?, Int32, gpointer?) -> Void = {
    _, iter, metin, uzunluk, veri in
    guard let iter, let metin else { return }
    let yazi = uzunluk < 0 ? String(cString: metin)
        : String(decoding: UnsafeRawBufferPointer(start: metin, count: Int(uzunluk)), as: UTF8.self)
    editor(veri)?.metinEklenecek(iter.pointee, yazi)
}

private let metinSilinecekC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextIter>?, UnsafeMutablePointer<GtkTextIter>?, gpointer?) -> Void = {
    _, bas, son, veri in
    guard let bas, let son else { return }
    editor(veri)?.metinSilinecek(bas.pointee, son.pointee)
}

private let tusBasildiC: @convention(c) (gpointer?, guint, guint, GdkModifierType, gpointer?) -> gboolean = {
    _, tus, _, durum, veri in
    editor(veri)?.tusBasildi(tus, durum) == true ? 1 : 0
}

private let tiklandiC: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = {
    hareket, _, x, y, veri in
    if editor(veri)?.tiklandi(x, y) == true, let hareket { gtk_gesture_set_state(hareket, GTK_EVENT_SEQUENCE_CLAIMED) }
}

private let kapanisIstendiC: @convention(c) (gpointer?, gpointer?) -> gboolean = { _, veri in
    editor(veri)?.kapanisiEngelle() == true ? 1 : 0
}

private let panoYapistirC: @convention(c) (gpointer?, gpointer?) -> Void = { nesne, veri in
    guard let hedef = editor(veri), let pano = gtk_widget_get_clipboard(hedef.metinGorunumu) else { return }
    if hedef.yapistirmaOncesi.contains(where: { $0(pano) }), let nesne {
        g_signal_stop_emission_by_name(nesne, "paste-clipboard")
    }
}

private let kFontAnahtarlari = [kKalinAnahtari, kItalikAnahtari, kPuntoOlcegiAnahtari]

// MARK: - Editör

/// macOS NotMetinGorunumu + NotPenceresi kayıt akışının B1 dilimi: açma, yazma, satır başı
/// biçimleri, liste devamı, girinti, yapılacak kutusu, Ctrl+S/B/I/Z ve otomatik kayıt.
final class LinuxEditor: LinuxEditorProtokolu {
    private weak var pencere: LinuxPencere?
    private let kaydirma = gtk_scrolled_window_new()!
    let metinGorunumu = gtk_text_view_new()!
    private let gorunum: UnsafeMutablePointer<GtkTextView>
    let tampon: UnsafeMutablePointer<GtkTextBuffer>
    private let adaptor: LinuxBelgeAdaptoru
    private let kaydedici = NotKaydedici()
    private let stil = gtk_css_provider_new()!
    private var mevcutURL: URL?
    private var ustbilgi = SayfaUstbilgisi()
    /// Ctrl+B gibi seçimsiz biçim komutlarının sonraki yazıma etkisi (NSTextView typingAttributes).
    private var yazimOnceligi: Oznitelikler?
    private var imlecIzlenmiyor = false
    private var geriAliniyor = false
    /// GTK metni tutar; burada yalnızca değişen aralıkların anlamsal hâlleri saklanır.
    private enum GecmisTuru { case ekleme, geriSilme, ileriSilme, diger }
    private struct Duzenleme {
        var tur: GecmisTuru = .diger
        let konum: Int
        let eski: NSAttributedString
        let yeni: NSAttributedString
        var uzunluk: Int { eski.length + yeni.length }
    }
    private var anlikGoruntuler: [[Duzenleme]] = []
    private var bekleyenGecmis: [Duzenleme]?
    private var gecmisBirlesebilir = true
    private var ileriGoruntuler: [[Duzenleme]] = []
    private var geriAlmaUzunlugu = 0
    private var kaydiAtla = false
    private var sonKayitHatasi: String?
    private var bekleyenKayitHatasi: (url: URL, neden: String)?
    var notSecimiBildir: ((URL?) -> Void)?
    var tusOncesi: [(_ keyval: UInt32, _ durum: UInt32) -> Bool] = []
    /// GdkClipboard, C köprüsünde opaque türdür. true = pano eklenti tarafından işlendi.
    var yapistirmaOncesi: [(OpaquePointer) -> Bool] = []
    var degisiklikSonrasi: [() -> Void] = []
    var notAcildi: [(URL) -> Void] = []
    var acikURL: URL? { mevcutURL }
    /// Kopya dışarıdan NSMutableAttributedString'e çevrilse de esas belge değişmez.
    var belge: NSAttributedString { NSAttributedString(attributedString: adaptor.belge) }
    /// Ana döngüde kopyasız okuma; belgeyi saklamayın veya mutable türe çevirmeyin.
    func belgeyiOku<T>(_ oku: (NSAttributedString) -> T) -> T { oku(adaptor.belge) }
    var notKaydedildi: ((URL, String) -> Void)?
    private var kayitHatasiBildirildi = false
    private var diyalogAcik = false

    private var anlamsalBelge: NSMutableAttributedString { adaptor.belge }
    private var ns: NSMutableString { adaptor.belge.mutableString }
    private var secim: NSRange { LinuxMetinDonusumu.secim(tampon) }

    init(pencere: LinuxPencere) {
        self.pencere = pencere
        gorunum = UnsafeMutableRawPointer(metinGorunumu).assumingMemoryBound(to: GtkTextView.self)
        tampon = gtk_text_view_get_buffer(gorunum)!
        adaptor = LinuxBelgeAdaptoru(tampon: tampon)
        gorunumuKur(pencere)
        sinyalleriBagla(pencere)
    }

    deinit {
        if let ekran = gtk_widget_get_display(metinGorunumu) {
            gtk_style_context_remove_provider_for_display(ekran, nd_style_provider(stil))
        }
        g_object_unref(UnsafeMutableRawPointer(stil))
    }

    private func gorunumuKur(_ pencere: LinuxPencere) {
        gtk_widget_add_css_class(metinGorunumu, "nd-metin")
        gtk_text_view_set_wrap_mode(gorunum, GTK_WRAP_WORD_CHAR)
        gtk_text_view_set_top_margin(gorunum, 12)
        gtk_text_view_set_bottom_margin(gorunum, 12)
        // Not açılana kadar yazılacak dosya yok.
        gtk_text_view_set_editable(gorunum, 0)
        gtk_text_view_set_cursor_visible(gorunum, 0)
        gtk_text_buffer_set_enable_undo(tampon, 1)
        gtk_text_buffer_set_max_undo_levels(tampon, 100)
        gtk_widget_action_set_enabled(metinGorunumu, "text.undo", 0)
        gtk_widget_action_set_enabled(metinGorunumu, "text.redo", 0)
        // Mac'teki 14 pt taban punto, mantıksal piksel olarak.
        gtk_css_provider_load_from_data(stil, "textview.nd-metin { font-size: \(Int(kTabanPunto))px; }", -1)
        gtk_style_context_add_provider_for_display(gtk_widget_get_display(metinGorunumu), nd_style_provider(stil),
                                                   guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
        let kaydirici = OpaquePointer(kaydirma)
        gtk_scrolled_window_set_policy(kaydirici, GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(kaydirici, metinGorunumu)
        gtk_widget_set_vexpand(kaydirma, 1)
        gtk_widget_set_hexpand(kaydirma, 1)
        gtk_box_append(nd_box(pencere.editorYuvasi), kaydirma)
    }

    private func sinyalleriBagla(_ pencere: LinuxPencere) {
        // GTK'nin Ctrl+V ve bağlam menüsü aynı action sinyalini kullanır.
        cBagla(UnsafeMutableRawPointer(metinGorunumu), "paste-clipboard",
               unsafeBitCast(panoYapistirC, to: GCallback.self), self)
        let tamponNesnesi = UnsafeMutableRawPointer(tampon)
        GtkKoprusu.aynalamaHatasiniIzle(tampon) { [weak self] neden in
            guard let self, let url = self.mevcutURL else { return }
            self.kaydedici.degisiklikIsaretle()
            self.sonKayitHatasi = neden
            Platform.anaIsParcaciginda { [weak self] in
                guard let self, self.mevcutURL == url, GtkKoprusu.aynalamaHatasi(self.tampon) != nil else { return }
                _ = self.kayitHatasi(neden, url: url, bildir: true)
            }
        }
        cBagla(tamponNesnesi, "insert-text", unsafeBitCast(metinEklenecekC, to: GCallback.self), self)
        cBagla(tamponNesnesi, "delete-range", unsafeBitCast(metinSilinecekC, to: GCallback.self), self)
        GtkKoprusu.sinyalBagla(tamponNesnesi, "changed") { [weak self] in self?.degisti() }
        GtkKoprusu.sinyalBagla(tamponNesnesi, "begin-user-action") { [weak self] in
            guard let self, !self.adaptor.programatik, !self.geriAliniyor else { return }
            self.bekleyenGecmis = []
        }
        GtkKoprusu.sinyalBagla(tamponNesnesi, "end-user-action") { [weak self] in
            guard let self, let adim = self.bekleyenGecmis else { return }
            self.bekleyenGecmis = nil
            self.gecmisGrubunuKaydet(adim)
        }
        // GtkTextView geçmiş değişince yerleşik eylemleri yeniden etkinleştirir.
        // Öznitelik günlüğümüzü atlayan menü yolu her bildirimde kapalı kalmalı.
        for ad in ["notify::can-undo", "notify::can-redo"] {
            GtkKoprusu.sinyalBagla(tamponNesnesi, ad) { [weak self] (_: gpointer?) in
                guard let self else { return }
                gtk_widget_action_set_enabled(self.metinGorunumu, "text.undo", 0)
                gtk_widget_action_set_enabled(self.metinGorunumu, "text.redo", 0)
            }
        }
        GtkKoprusu.sinyalBagla(tamponNesnesi, "notify::cursor-position") { [weak self] (_: gpointer?) in
            guard let self, !self.imlecIzlenmiyor else { return }
            self.yazimOnceligi = nil
        }
        let yatay = gtk_scrolled_window_get_hadjustment(OpaquePointer(kaydirma))!
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(yatay), "changed") { [weak self] in
            // Boyut dağıtımı sırasında kenar değiştirmek yeniden boyut kuyruğu uyarısı verir.
            Platform.anaIsParcaciginda { self?.kenarlariAyarla() }
        }

        let tuslar = gtk_event_controller_key_new()!
        gtk_event_controller_set_propagation_phase(tuslar, GTK_PHASE_CAPTURE)
        cBagla(UnsafeMutableRawPointer(tuslar), "key-pressed", unsafeBitCast(tusBasildiC, to: GCallback.self), self)
        gtk_widget_add_controller(metinGorunumu, tuslar)

        let tik = gtk_gesture_click_new()!
        gtk_gesture_single_set_button(tik, 1)
        gtk_event_controller_set_propagation_phase(tik, GTK_PHASE_CAPTURE)
        cBagla(UnsafeMutableRawPointer(tik), "pressed", unsafeBitCast(tiklandiC, to: GCallback.self), self)
        gtk_widget_add_controller(metinGorunumu, tik)

        cBagla(UnsafeMutableRawPointer(pencere.pencere), "close-request",
               unsafeBitCast(kapanisIstendiC, to: GCallback.self), self)
        pencere.kisayolEkle("<Control>s") { [weak self] in self?.kaydetKomutu() }
    }

    // MARK: Not açma

    func notuAc(_ url: URL) {
        defer { notSecimiBildir?(mevcutURL) }
        guard url != mevcutURL, !diyalogAcik else { return }
        if kaydiAtla || simdiKaydet() {
            ac(url)
        } else {
            kaydetmedenDevam { [weak self] in self?.ac(url) }
        }
    }

    @discardableResult
    private func ac(_ url: URL) -> Bool {
        defer { notSecimiBildir?(mevcutURL) }
        let icerik: String
        do { icerik = try String(contentsOf: url, encoding: .utf8) }
        catch {
            diyalog("Not açılamadı", error.localizedDescription, dugmeler: ["Tamam"]) { _ in }
            return false
        }
        let sayfa = sayfaUstbilgisiniAyir(icerik)
        ustbilgi = sayfa.bilgi
        imlecIzlenmiyor = true
        adaptor.yukle(markdowndenAttributedStringUret(sayfa.govde, taban: sayfaKlasoru(url)))
        var bas = GtkTextIter()
        gtk_text_buffer_get_start_iter(tampon, &bas)
        gtk_text_buffer_place_cursor(tampon, &bas)
        imlecIzlenmiyor = false
        yazimOnceligi = nil
        anlikGoruntuler.removeAll()
        bekleyenGecmis = nil
        gecmisBirlesebilir = true
        ileriGoruntuler.removeAll()
        mevcutURL = url
        kaydedici.sifirla(sonYazilan: icerik)
        kayitHatasiBildirildi = false
        bekleyenKayitHatasi = nil
        sonKayitHatasi = nil
        gtk_text_view_set_editable(gorunum, 1)
        gtk_text_view_set_cursor_visible(gorunum, 1)
        gtk_adjustment_set_value(gtk_scrolled_window_get_vadjustment(OpaquePointer(kaydirma)), 0)
        pencere?.basligiAyarla(sayfaYolu(url).map(sayfaAdi))
        kenarlariAyarla()
        for kanca in notAcildi { kanca(url) }
        return true
    }

    func simdiKaydet() -> Bool {
        kaydedici.bekleyeniIptalEt()
        guard kaydedici.duzenlendiMi, let url = mevcutURL else { return true }
        sonKayitHatasi = kaydet(url, bildir: false)
        return sonKayitHatasi == nil
    }

    /// GTK diyaloğu asenkrondur; yalnızca onaylanan işlem kayıt denetimini bir kez atlar.
    func kaydetmedenDevam(_ islem: @escaping () -> Void) {
        diyalog("Kaydetmeden devam edilsin mi?",
                "Son değişiklikler kaydedilemedi. Devam ederseniz kaybolabilir.\n\nNeden: \(sonKayitHatasi ?? "Kayıt başarısız")",
                dugmeler: ["Vazgeç", "Kaydetmeden Devam"]) { [weak self] secilen in
            guard let self else { return }
            if secilen == 2 {
                self.kaydiAtla = true
                islem()
                self.kaydiAtla = false
            }
            self.notSecimiBildir?(self.mevcutURL)
        }
    }

    func yolDegisti(eski: URL, yeni: URL) {
        guard mevcutURL == eski else { return }
        kaydedici.bekleyeniIptalEt()
        mevcutURL = yeni
        pencere?.basligiAyarla(sayfaYolu(yeni).map(sayfaAdi))
        notSecimiBildir?(yeni)
        for kanca in notAcildi { kanca(yeni) }
        if kaydedici.duzenlendiMi { icerikDegisti() }
    }

    func bosalt() {
        kaydedici.sifirla(sonYazilan: nil)
        mevcutURL = nil
        ustbilgi = SayfaUstbilgisi()
        yazimOnceligi = nil
        anlikGoruntuler.removeAll()
        bekleyenGecmis = nil
        gecmisBirlesebilir = true
        ileriGoruntuler.removeAll()
        kayitHatasiBildirildi = false
        sonKayitHatasi = nil
        bekleyenKayitHatasi = nil
        adaptor.yukle(NSAttributedString(string: ""))
        gtk_text_view_set_editable(gorunum, 0)
        gtk_text_view_set_cursor_visible(gorunum, 0)
        pencere?.basligiAyarla([])
        notSecimiBildir?(nil)
        degisiklikKancalariniBildir()
    }

    /// Okunur genişlik: Mac'teki gibi ~760 pt ortalanmış; sayfa "tam" ise tüm genişlik.
    private func kenarlariAyarla() {
        let genislik = Double(gtk_widget_get_width(kaydirma))
        guard genislik > 0 else { return }
        let yanPay = min(48, max(0, (genislik - 48) / 2))
        let kullanilabilir = max(1, genislik - yanPay * 2)
        let kap = ustbilgi.genislik == "tam" ? kullanilabilir : min(760, kullanilabilir)
        let kenar = Int32(max(0, (genislik - kap) / 2))
        guard kenar != gtk_text_view_get_left_margin(gorunum) else { return }
        gtk_text_view_set_left_margin(gorunum, kenar)
        gtk_text_view_set_right_margin(gorunum, kenar)
    }

    // MARK: Kayıt

    private func kaydetKomutu() {
        guard let url = mevcutURL else { return }
        kaydet(url, bildir: true)
    }

    /// Başarıda nil, başarısızlıkta neden döner. Sürüm geçmişi kayıttan sonra yazılır.
    @discardableResult
    private func kaydet(_ url: URL, bildir: Bool) -> String? {
        if let neden = adaptor.aynalamaHatasi() { return kayitHatasi(neden, url: url, bildir: bildir) }
        var klasorMu: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path),
              FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: &klasorMu),
              klasorMu.boolValue else {
            return kayitHatasi("Notun dosyası veya klasörü artık mevcut değil.", url: url, bildir: bildir)
        }
        let metin = sayfaMarkdownunuUret(anlamsalBelge, ustbilgi: ustbilgi)
        switch kaydedici.yaz(metin: metin, url: url, mevcutURL: mevcutURL) {
        case .gerekmedi:
            bekleyenKayitHatasi = nil
            kayitHatasiBildirildi = false
            return nil
        case .yazildi:
            kayitHatasiBildirildi = false
            bekleyenKayitHatasi = nil
            SayfaGecmisi.kaydet(metin: metin, icerikURL: url)
            notKaydedildi?(url, metin)
            return nil
        case .basarisiz(let neden):
            return kayitHatasi(neden, url: url, bildir: bildir)
        }
    }

    private func kayitHatasi(_ neden: String, url: URL, bildir: Bool) -> String {
        guard bildir, !kayitHatasiBildirildi else { return neden }
        if diyalogAcik {
            // Gösterilemeyen uyarı açık diyalog kapandıktan sonra sunulur.
            bekleyenKayitHatasi = (url, neden)
            return neden
        }
        kayitHatasiBildirildi = diyalog("Not kaydedilemedi",
                "\"\(sayfaAdi(url))\" diske yazılamadı. Yazdıklarınız pencerede duruyor; kapatmadan önce başka bir yere kopyalayın.\n\nNeden: \(neden)",
                dugmeler: ["Tamam"]) { _ in }
        return neden
    }

    private func icerikDegisti() {
        kaydedici.degisiklikIsaretle()
        if let neden = GtkKoprusu.aynalamaHatasi(tampon), let url = mevcutURL {
            sonKayitHatasi = neden
            _ = kayitHatasi(neden, url: url, bildir: true)
        }
        degisiklikKancalariniBildir()
        kaydedici.zamanlayiciKur { [weak self] in self?.otomatikKaydet() }
    }

    /// Mac didChangeText gibi: GTK işlem ve imleç güncellemesini bitirdikten sonra.
    private func degisiklikKancalariniBildir() {
        Platform.anaIsParcaciginda { [weak self] in
            guard let self else { return }
            for kanca in self.degisiklikSonrasi { kanca() }
        }
    }

    private func otomatikKaydet() {
        guard kaydedici.duzenlendiMi, let url = mevcutURL else { return }
        kaydet(url, bildir: true)
    }

    /// Kapanışta son kayıt; başarısızsa "Kaydetmeden Çık / Vazgeç" sorulur.
    fileprivate func kapanisiEngelle() -> Bool {
        guard kaydedici.duzenlendiMi, let url = mevcutURL else { return false }
        kaydedici.bekleyeniIptalEt()
        guard let neden = kaydet(url, bildir: false) else { return false }
        diyalog("Kaydetmeden çıkılsın mı?",
                "Not kaydedilemedi. Kaydetmeden çıkarsanız son değişiklikler kaybolacak.\n\nNeden: \(neden)",
                dugmeler: ["Vazgeç", "Kaydetmeden Çık"]) { [weak self] secilen in
            guard secilen == 2, let self, let pencere = self.pencere else { return }
            self.kaydedici.temizIsaretle()
            gtk_window_destroy(nd_window(pencere.pencere))
        }
        return true
    }

    /// GtkMessageDialog (4.6'da AlertDialog yok). Yanıt, düğmenin 1'den başlayan sırasıdır.
    @discardableResult
    private func diyalog(_ baslik: String, _ aciklama: String, dugmeler: [String], _ yanit: @escaping (Int) -> Void) -> Bool {
        guard !diyalogAcik, let pencere else { return false }
        diyalogAcik = true
        // gtk_message_dialog_new variadic olduğu için özellikler ayrı yazılır.
        let nesne = UnsafeMutableRawPointer(g_object_new_with_properties(gtk_message_dialog_get_type(), 0, nil, nil)!)
        gNesneOzelligi(nesne, "message-type", .sayim(gtk_message_type_get_type(), Int32(GTK_MESSAGE_WARNING.rawValue)))
        gNesneOzelligi(nesne, "text", .metin(baslik))
        gNesneOzelligi(nesne, "secondary-text", .metin(aciklama))
        let widget = nesne.assumingMemoryBound(to: GtkWidget.self)
        let pano = nesne.assumingMemoryBound(to: GtkDialog.self)
        gtk_window_set_transient_for(nd_window(widget), nd_window(pencere.pencere))
        gtk_window_set_modal(nd_window(widget), 1)
        for (sira, ad) in dugmeler.enumerated() { gtk_dialog_add_button(pano, ad, Int32(sira + 1)) }
        gtk_dialog_set_default_response(pano, 1)
        GtkKoprusu.sinyalBagla(nesne, "response") { [weak self] (secilen: guint) in
            self?.diyalogAcik = false
            // Sinyal closure'ı yanıt işlenirken serbest kalmasın diye yok etme sonraya bırakılır.
            Platform.anaIsParcaciginda { [weak self] in
                gtk_window_destroy(nd_window(widget))
                guard let self, let hata = self.bekleyenKayitHatasi else { return }
                self.bekleyenKayitHatasi = nil
                if self.mevcutURL == hata.url { _ = self.kayitHatasi(hata.neden, url: hata.url, bildir: true) }
            }
            yanit(Int(Int32(bitPattern: secilen)))
        }
        gtk_window_present(nd_window(widget))
        return true
    }

    // MARK: Tampon → belge

    fileprivate func metinEklenecek(_ iter: GtkTextIter, _ metin: String) {
        guard !adaptor.programatik else { return }
        if geriAliniyor { geriAlmaUzunlugu += (metin as NSString).length; return }
        let konum = LinuxMetinDonusumu.konum(iter)
        guard konum >= 0, konum <= anlamsalBelge.length, GtkKoprusu.aynalamaHatasi(tampon) == nil else {
            GtkKoprusu.aynalamaKaymasi(tampon, "Aynalama ekleme konumu geçersiz: \(konum)")
            return
        }
        let o = yazim(konum)
        anlikKaydet(NSRange(location: konum, length: 0), yeni: NSAttributedString(string: metin, attributes: o), tur: .ekleme)
        adaptor.eklendi(konum: konum, metin: metin, yazim: o)
    }

    fileprivate func metinSilinecek(_ bas: GtkTextIter, _ son: GtkTextIter) {
        guard !adaptor.programatik else { return }
        let aralik = LinuxMetinDonusumu.aralik(bas, son)
        if geriAliniyor { geriAlmaUzunlugu += aralik.length; return }
        let s = secim
        let tur: GecmisTuru = s.length > 0 ? .diger : s.location == NSMaxRange(aralik) ? .geriSilme :
            s.location == aralik.location ? .ileriSilme : .diger
        anlikKaydet(aralik, yeni: NSAttributedString(string: ""), tur: tur)
        adaptor.silindi(aralik)
    }

    private func degisti() {
        guard !adaptor.programatik, !geriAliniyor else { return }
        adaptor.bekleyeniUygula()
        icerikDegisti()
    }

    private func anlikKaydet(_ aralik: NSRange, yeni: NSAttributedString, tur: GecmisTuru = .diger) {
        guard aralik.location >= 0, aralik.length >= 0, aralik.location <= anlamsalBelge.length,
              aralik.length <= anlamsalBelge.length - aralik.location else {
            GtkKoprusu.aynalamaKaymasi(tampon, "Geçmiş aralığı belge dışında: \(aralik)")
            return
        }
        guard aralik.length + yeni.length > 0 else { return }
        let degisim = Duzenleme(tur: tur, konum: aralik.location,
                               eski: anlamsalBelge.attributedSubstring(from: aralik), yeni: NSAttributedString(attributedString: yeni))
        if var adim = bekleyenGecmis {
            if let son = adim.last, let birlesik = gecmisiBirlestir(son, degisim, grupIcinde: true) {
                adim[adim.count - 1] = birlesik
            } else { adim.append(degisim) }
            bekleyenGecmis = adim
        } else { gecmisGrubunuKaydet([degisim]) }
        ileriGoruntuler.removeAll()
    }

    /// GTK sınırı tuş/sinyal sayısı değil, birleşik kullanıcı adımı sayısıdır.
    private func gecmisGrubunuKaydet(_ adim: [Duzenleme]) {
        guard !adim.isEmpty else { return }
        if gecmisBirlesebilir, adim.count == 1, let onceki = anlikGoruntuler.last, onceki.count == 1,
           let birlesik = gecmisiBirlestir(onceki[0], adim[0], grupIcinde: false) {
            anlikGoruntuler[anlikGoruntuler.count - 1] = [birlesik]
        } else { anlikGoruntuler.append(adim) }
        gecmisBirlesebilir = true
        if anlikGoruntuler.count > 100 { anlikGoruntuler.removeFirst(anlikGoruntuler.count - 100) }
    }

    /// GTK 4.6 GtkTextHistory: bitişik yazım, Backspace ve Delete birleştirme sınırları.
    private func gecmisiBirlestir(_ eski: Duzenleme, _ yeni: Duzenleme, grupIcinde: Bool) -> Duzenleme? {
        guard eski.tur == yeni.tur, eski.tur != .diger else { return nil }
        let metin = NSMutableAttributedString(attributedString: eski.tur == .ekleme ? eski.yeni : eski.eski)
        let ek = eski.tur == .ekleme ? yeni.yeni : yeni.eski
        switch eski.tur {
        case .ekleme:
            guard eski.konum + eski.yeni.length == yeni.konum else { return nil }
            if !grupIcinde {
                let yazi = ek.string.unicodeScalars
                guard yazi.count <= 1000, !metin.string.contains("\n"), !ek.string.contains("\n") else { return nil }
                let bosluk = yazi.allSatisfy { $0.properties.isWhitespace } &&
                    (metin.string.unicodeScalars.last?.properties.isWhitespace ?? true)
                guard bosluk || (yazi.first?.properties.isWhitespace != true &&
                    !(yazi.count > 1 && yazi.contains { $0.properties.isWhitespace })) else { return nil }
            }
            metin.append(ek)
            return Duzenleme(tur: .ekleme, konum: eski.konum, eski: eski.eski, yeni: metin)
        case .geriSilme:
            guard yeni.konum + yeni.eski.length == eski.konum else { return nil }
            metin.insert(ek, at: 0)
        case .ileriSilme:
            guard eski.konum == yeni.konum,
                  !ek.string.unicodeScalars.contains(where: { $0.properties.isWhitespace }) ||
                  metin.string.unicodeScalars.allSatisfy({ $0.properties.isWhitespace }) else { return nil }
            metin.append(ek)
        case .diger: return nil
        }
        return Duzenleme(tur: eski.tur, konum: min(eski.konum, yeni.konum), eski: metin, yeni: eski.yeni)
    }

    private func geriAl(ileri: Bool) {
        guard (ileri ? gtk_text_buffer_get_can_redo(tampon) : gtk_text_buffer_get_can_undo(tampon)) != 0 else { return }
        guard GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
        gecmisBirlesebilir = false
        geriAliniyor = true
        defer { geriAliniyor = false }
        geriAlmaUzunlugu = 0
        if ileri { gtk_text_buffer_redo(tampon) } else { gtk_text_buffer_undo(tampon) }
        let adim = ileri ? ileriGoruntuler.last ?? [] : geriAlmaAdimi()
        guard !adim.isEmpty, adim.reduce(0, { $0 + $1.uzunluk }) == geriAlmaUzunlugu else {
            // Beklenmeyen GTK geçmişinde belgeyi bozma; tamponu eski hâline geri al.
            if ileri { gtk_text_buffer_undo(tampon) } else { gtk_text_buffer_redo(tampon) }
            FileHandle.standardError.write(Data("[NotDefteri] GTK/anlamsal geri alma adımı eşleşmedi.\n".utf8))
            diyalog("Geri alma uygulanamadı", "GTK geçmişi ile belge geçmişi eşleşmedi. İçerik korundu.", dugmeler: ["Tamam"]) { _ in }
            return
        }
        gecmisAdiminiUygula(adim, ileri: ileri)
        adaptor.gorunumuUygula(NSRange(location: 0, length: anlamsalBelge.length))
        yazimOnceligi = nil
        icerikDegisti()
    }

    /// GTK yazımı birleştirebilir. Sinyallerin gerçekten geri aldığı kadar aralık çıkarılır;
    /// metin eşitliğiyle anlık görüntü aranmaz, aynı metindeki biçim değişikliği de korunur.
    private func geriAlmaAdimi() -> [Duzenleme] {
        var toplam = 0, sayi = 0
        for adim in anlikGoruntuler.reversed() {
            toplam += adim.reduce(0) { $0 + $1.uzunluk }
            sayi += 1
            if toplam >= geriAlmaUzunlugu { break }
        }
        return toplam == geriAlmaUzunlugu ? anlikGoruntuler.suffix(sayi).flatMap { $0 } : []
    }

    private func gecmisAdiminiUygula(_ adim: [Duzenleme], ileri: Bool) {
        for degisim in ileri ? adim : adim.reversed() {
            let aralik = NSRange(location: degisim.konum, length: ileri ? degisim.eski.length : degisim.yeni.length)
            anlamsalBelge.replaceCharacters(in: aralik, with: ileri ? degisim.yeni : degisim.eski)
        }
        if ileri {
            ileriGoruntuler.removeLast()
            anlikGoruntuler.append(adim)
        } else {
            var kalan = adim.reduce(0) { $0 + $1.uzunluk }
            while kalan > 0, let son = anlikGoruntuler.popLast() {
                kalan -= son.reduce(0) { $0 + $1.uzunluk }
            }
            ileriGoruntuler.append(adim)
            // Sınırı GTK belirler: 100 birleşik adım, 100 tuş değil.
            if gtk_text_buffer_get_can_undo(tampon) == 0 { anlikGoruntuler.removeAll() }
        }
    }

    // MARK: Yazım öznitelikleri

    /// NSTextView gibi önceki karakterin öznitelikleri; ardından Mac'teki blokYaziminiGuncelle kuralları.
    private func yazim(_ konum: Int) -> Oznitelikler {
        var o = yazimOnceligi ?? (anlamsalBelge.length > 0
            ? anlamsalBelge.attributes(at: min(max(0, konum - 1), anlamsalBelge.length - 1), effectiveRange: nil) : [:])
        let oncekiBlok = MetinBlogu(oznitelik: o[kMetinBloguAnahtari])
        for anahtar in [kBlokIsaretiAnahtari, kBosKodSatiriAnahtari, kGorselAnahtari, kSayfaBagiAnahtari,
                        kKacisliKoseParantezAnahtari, kBaglantiAnahtari, kCiplakBagAnahtari] {
            o.removeValue(forKey: anahtar)
        }
        let aralik = ns.paragraphRange(for: NSRange(location: min(konum, ns.length), length: 0))
        let icinde = aralik.location < anlamsalBelge.length
        func deger(_ anahtar: NSAttributedString.Key) -> Any? {
            icinde ? anlamsalBelge.attribute(anahtar, at: aralik.location, effectiveRange: nil) : nil
        }
        if let blok = MetinBlogu(oznitelik: deger(kMetinBloguAnahtari)) {
            o.merge(blok.oznitelikler) { _, yeni in yeni }
        } else {
            for anahtar in [kMetinBloguAnahtari, kUyariKutusuAnahtari, kParagrafGeometrisiAnahtari] { o.removeValue(forKey: anahtar) }
            if oncekiBlok?.tur == .uyari { o.removeValue(forKey: kBlokKimligiAnahtari) }
        }
        if let baslik = deger(kBaslikSeviyesiAnahtari) as? Int {
            o[kBaslikSeviyesiAnahtari] = baslik
        } else if o[kBaslikSeviyesiAnahtari] != nil {
            // Başlıktan çıkan yazım düz gövdeye döner.
            o.removeValue(forKey: kBaslikSeviyesiAnahtari)
            for anahtar in kFontAnahtarlari { o.removeValue(forKey: anahtar) }
        }
        if let kod = deger(kKodBloguAnahtari) as? [String: String] {
            // Kod düz eş aralıklıdır; kalın/italik devralınmaz.
            o[kKodBloguAnahtari] = kod
            o[kKodBloguDiliAnahtari] = kodBloguDilEtiketi(kod)
            o[kBlokKimligiAnahtari] = kod["kimlik"] ?? ""
            o.removeValue(forKey: kKalinAnahtari)
            o.removeValue(forKey: kItalikAnahtari)
        } else if icinde, o[kKodBloguAnahtari] != nil {
            for anahtar in [kKodBloguAnahtari, kKodBloguDiliAnahtari, kBlokKimligiAnahtari] + kFontAnahtarlari {
                o.removeValue(forKey: anahtar)
            }
        }
        return o
    }

    // MARK: Klavye ve fare

    fileprivate func tusBasildi(_ tus: guint, _ durum: GdkModifierType) -> Bool {
        guard mevcutURL != nil else { return false }
        // Mac keyDown: önce bulucu/menü, ardından kısayollar ve otomatik blok biçimi.
        for kanca in tusOncesi where kanca(tus, durum.rawValue) { return true }
        guard GtkKoprusu.aynalamaHatasi(tampon) == nil else { return false }
        let ctrl = durum.rawValue & GDK_CONTROL_MASK.rawValue != 0
        let shift = durum.rawValue & GDK_SHIFT_MASK.rawValue != 0
        if ctrl {
            switch tus {
            case 0x62, 0x42: satirIciBicimiDegistir(kKalinAnahtari) // b
            case 0x69, 0x49: satirIciBicimiDegistir(kItalikAnahtari) // i
            case 0x7a, 0x5a: geriAl(ileri: shift) // z / CapsLock
            case 0x79, 0x59: geriAl(ileri: true) // y
            default: return false
            }
            return true
        }
        guard durum.rawValue & GDK_ALT_MASK.rawValue == 0 else { return false }
        switch tus {
        case 0xff0d, 0xff8d: // Return, KP_Enter
            guard !shift else { return false }
            imleciIsaretSonrasinaAl()
            return blokKisayolunuUygula("\n") || bloktaYeniSatir()
        case 0xff09: return !shift && blokGirintisiniDegistir(1) // Tab
        case 0xfe20: return blokGirintisiniDegistir(-1) // ISO_Left_Tab (Shift+Tab)
        case 0xff08: return satirBasindaBicimiKaldir() // BackSpace
        case 0x20:
            imleciIsaretSonrasinaAl()
            return blokKisayolunuUygula(" ")
        default:
            if gdk_keyval_to_unicode(tus) != 0 { imleciIsaretSonrasinaAl() }
            return false
        }
    }

    /// Yazım görünür/görünmez blok işaretinin önüne düşmesin (Mac: blokYaziminiGuncelle).
    private func imleciIsaretSonrasinaAl() {
        let s = secim
        guard s.length == 0 else { return }
        let paragraf = ns.paragraphRange(for: s)
        let isaret = blokIsaretiUzunlugu(anlamsalBelge, konum: paragraf.location)
        guard paragraf.length > 0, s.location < paragraf.location + isaret else { return }
        imlecIzlenmiyor = true
        LinuxMetinDonusumu.secimiAyarla(tampon, NSRange(location: paragraf.location + isaret, length: 0))
        imlecIzlenmiyor = false
    }

    fileprivate func tiklandi(_ x: Double, _ y: Double) -> Bool {
        guard mevcutURL != nil, GtkKoprusu.aynalamaHatasi(tampon) == nil else { return false }
        var bx: Int32 = 0, by: Int32 = 0
        gtk_text_view_window_to_buffer_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, Int32(x), Int32(y), &bx, &by)
        var iter = GtkTextIter()
        gtk_text_view_get_iter_at_location(gorunum, &iter, bx, by)
        let paragraf = ns.paragraphRange(for: NSRange(location: min(LinuxMetinDonusumu.konum(iter), ns.length), length: 0))
        guard var blok = blok(paragraf), blok.tur == .yapilacak else { return false }
        var kutu = LinuxMetinDonusumu.iter(tampon, paragraf.location)
        var kare = GdkRectangle()
        gtk_text_view_get_iter_location(gorunum, &kutu, &kare)
        guard bx >= kare.x - 3, bx <= kare.x + kare.width + 3, by >= kare.y - 2, by <= kare.y + kare.height + 2 else { return false }
        blok.tamamlandi.toggle()
        blok.kaynakOnEk = nil
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: paragraf))
        yeni.replaceCharacters(in: NSRange(location: 0, length: blokIsaretiUzunlugu(yeni)), with: blokIsaretiniUret(blok))
        blokBiciminiUygula(blok, metne: yeni, aralik: NSRange(location: 0, length: yeni.length))
        blokDuzenle(paragraf, yeni: yeni, secim: secim, yazim: yazimOnceligi)
        return true
    }

    // MARK: Biçim komutları (Mac: NotPenceresi+Bicimlendirme, NotMetinGorunumu+Bloklar)

    /// Aralık, anlamsal belge ve GTK metni mevcut düzenleme yolunda tek undo grubudur.
    func aralikDegistir(_ utf16: NSRange, ile yeni: NSAttributedString) {
        guard utf16.location >= 0, utf16.location <= anlamsalBelge.length else { return }
        blokDuzenle(utf16, yeni: yeni,
                    secim: NSRange(location: utf16.location + yeni.length, length: 0), yazim: yazimOnceligi, ayriAdim: true)
    }

    /// Değer nil ise biçim kaldırılır; boş seçimde yalnızca sonraki yazım etkilenir.
    func satirIciBicimUygula(_ anahtar: NSAttributedString.Key, deger: Any?) {
        guard mevcutURL != nil, GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
        let s = secim
        if s.length == 0 {
            var o = yazim(s.location)
            o[anahtar] = deger
            yazimOnceligi = o
            return
        }
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: s))
        yeni.enumerateAttributes(in: NSRange(location: 0, length: yeni.length)) { o, alt, _ in
            guard o[kBlokIsaretiAnahtari] as? Bool != true, o[kGorselAnahtari] == nil else { return }
            if let deger { yeni.addAttribute(anahtar, value: deger, range: alt) }
            else { yeni.removeAttribute(anahtar, range: alt) }
        }
        blokDuzenle(s, yeni: yeni, secim: s, yazim: yazimOnceligi)
    }

    /// Mac menuBlogunuUygula: paragraf kapsamı, eski işaretlerin temizliği, tek undo.
    func blokUygula(_ tur: MetinBlogu.Tur) {
        guard mevcutURL != nil, GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
        let paragraf = ns.paragraphRange(for: secim)
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: paragraf))
        var isaretler: [NSRange] = []
        yeni.enumerateAttribute(kBlokIsaretiAnahtari, in: NSRange(location: 0, length: yeni.length)) { deger, alt, _ in
            if deger as? Bool == true { isaretler.append(alt) }
        }
        for alt in isaretler.reversed() { yeni.deleteCharacters(in: alt) }
        blokBiciminiKaldir(yeni)
        let tumu = NSRange(location: 0, length: yeni.length)
        for anahtar in [kBaslikSeviyesiAnahtari, kKodBloguAnahtari, kKodBloguDiliAnahtari] + kFontAnahtarlari {
            yeni.removeAttribute(anahtar, range: tumu)
        }
        let blok = MetinBlogu(tur: tur, uyariKimligi: tur == .uyari ? UUID().uuidString : "")
        blokBiciminiUygula(blok, metne: yeni, aralik: tumu)
        let isaret = blokIsaretiniUret(blok)
        yeni.insert(isaret, at: 0)
        blokDuzenle(paragraf, yeni: yeni,
                    secim: NSRange(location: paragraf.location + isaret.length, length: 0),
                    yazim: tur == .ayirici ? [:] : blok.oznitelikler, numarala: blok.listeMi)
    }

    /// GtkTextView tampon koordinatı → widget → pencere; iter çağrı içinde kalır.
    func imlecKaresi() -> GdkRectangle {
        guard let pencere else { return GdkRectangle() }
        var iter = GtkTextIter(), kare = GdkRectangle()
        gtk_text_buffer_get_iter_at_mark(tampon, &iter, gtk_text_buffer_get_insert(tampon))
        gtk_text_view_get_iter_location(gorunum, &iter, &kare)
        var x: Int32 = 0, y: Int32 = 0
        gtk_text_view_buffer_to_window_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, kare.x, kare.y, &x, &y)
        var nokta = graphene_point_t(x: Float(x), y: Float(y)), hedef = graphene_point_t()
        guard gtk_widget_compute_point(metinGorunumu, pencere.pencere, &nokta, &hedef) != 0 else { return GdkRectangle() }
        kare.x = Int32(hedef.x)
        kare.y = Int32(hedef.y)
        return kare
    }

    private func satirIciBicimiDegistir(_ anahtar: NSAttributedString.Key) {
        func etkin(_ o: Oznitelikler) -> Bool {
            anahtar == kKalinAnahtari ? (o[kKalinAnahtari] as? Bool) ?? (o[kBaslikSeviyesiAnahtari] != nil) : o[anahtar] as? Bool == true
        }
        func degistir(_ eski: Oznitelikler, ac: Bool) -> Oznitelikler {
            var o = eski
            o[anahtar] = ac ? true : (anahtar == kKalinAnahtari && o[kBaslikSeviyesiAnahtari] != nil ? false : nil)
            return o
        }
        let s = secim
        if s.length == 0 {
            let mevcut = yazim(s.location)
            yazimOnceligi = degistir(mevcut, ac: !etkin(mevcut))
            return
        }
        var tumuEtkin = true
        anlamsalBelge.enumerateAttributes(in: s) { o, _, dur in
            if !etkin(o) { tumuEtkin = false; dur.pointee = true }
        }
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: s))
        yeni.enumerateAttributes(in: NSRange(location: 0, length: yeni.length)) { o, alt, _ in
            if o[kBlokIsaretiAnahtari] as? Bool != true, o[kGorselAnahtari] == nil {
                yeni.setAttributes(degistir(o, ac: !tumuEtkin), range: alt)
            }
        }
        blokDuzenle(s, yeni: yeni, secim: s, yazim: yazimOnceligi)
    }

    private func blok(_ aralik: NSRange) -> MetinBlogu? {
        guard aralik.location < anlamsalBelge.length else { return nil }
        return MetinBlogu(oznitelik: anlamsalBelge.attribute(kMetinBloguAnahtari, at: aralik.location, effectiveRange: nil))
    }

    /// Yalnızca yapısal değişimde komşu liste taranır; normal yazım bu yola girmez.
    private func listeAraliginiGenislet(_ aralik: NSRange) -> NSRange {
        var bas = aralik.location, son = NSMaxRange(aralik)
        while bas > 0 {
            let onceki = ns.paragraphRange(for: NSRange(location: bas - 1, length: 0))
            guard blok(onceki)?.listeMi == true else { break }
            bas = onceki.location
        }
        while son < ns.length {
            let sonraki = ns.paragraphRange(for: NSRange(location: son, length: 0))
            guard blok(sonraki)?.listeMi == true, sonraki.length > 0 else { break }
            son = NSMaxRange(sonraki)
        }
        return NSRange(location: bas, length: son - bas)
    }

    /// Metin, öznitelik ve seçim tek geri alma adımıdır; numaralar komşu listeyle yeniden sayılır.
    private func blokDuzenle(_ aralik: NSRange, yeni: NSAttributedString, secim hedef: NSRange,
                             yazim: Oznitelikler?, numarala: Bool = false, ayriAdim: Bool = false) {
        guard mevcutURL != nil, GtkKoprusu.aynalamaHatasi(tampon) == nil,
              aralik.location >= 0, aralik.length >= 0, aralik.location <= anlamsalBelge.length,
              aralik.length <= anlamsalBelge.length - aralik.location else { return }
        // GTK tek eklemeyi önceki yazıma birleştirir. Eklenti eklemesi dolu paragrafın
        // değiştirilmesiyle (silme + ekleme) kendi kullanıcı adımında kalır.
        let kapsam = numarala ? listeAraliginiGenislet(aralik) :
            ayriAdim && aralik.length == 0 && ns.length > 0
                ? ns.paragraphRange(for: NSRange(location: min(aralik.location, ns.length - 1), length: 0)) : aralik
        let eklenecek = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: kapsam))
        eklenecek.replaceCharacters(in: NSRange(location: aralik.location - kapsam.location, length: aralik.length), with: yeni)
        var yeniSecim = NSRange(location: hedef.location - kapsam.location, length: hedef.length)
        if numarala { blokNumaralariniGuncelle(eklenecek, secim: &yeniSecim) }
        yeniSecim.location += kapsam.location
        imlecIzlenmiyor = true
        gtk_text_buffer_begin_user_action(tampon)
        anlikKaydet(kapsam, yeni: eklenecek, tur: kapsam.length == 0 ? .ekleme : .diger)
        adaptor.degistir(kapsam, ile: eklenecek)
        gtk_text_buffer_end_user_action(tampon)
        LinuxMetinDonusumu.secimiAyarla(tampon, yeniSecim)
        imlecIzlenmiyor = false
        yazimOnceligi = yazim
        icerikDegisti()
    }

    /// Tamamlayıcı (boşluk/satır sonu) normal yazım olarak ayrı geri alma adımında kalır.
    private func tamamlayiciyiYaz(_ metin: String) {
        gtk_text_buffer_begin_user_action(tampon)
        gtk_text_buffer_insert_interactive_at_cursor(tampon, metin, -1, 1)
        gtk_text_buffer_end_user_action(tampon)
    }

    private func blokKisayolunuUygula(_ tamamlayici: String) -> Bool {
        let s = secim
        guard s.length == 0 else { return false }
        let paragraf = ns.paragraphRange(for: s)
        let mevcutYazim = yazim(s.location)
        guard blok(paragraf) == nil, mevcutYazim[kKodBloguAnahtari] == nil, mevcutYazim[kSatirIciKodAnahtari] == nil else { return false }
        let onEk = ns.substring(with: NSRange(location: paragraf.location, length: s.location - paragraf.location))
        let onEkUzunlugu = (onEk as NSString).length
        let seviye = ["#": 1, "##": 2, "###": 3][onEk]
        let cozum = metinBlogunuCozumle(onEk + (tamamlayici == " " ? " " : ""))
        if tamamlayici == "\n" {
            guard cozum?.blok.tur == .ayirici,
                  ns.substring(with: paragraf).trimmingCharacters(in: .newlines) == onEk else { return false }
        } else {
            guard seviye != nil || (cozum != nil && cozum!.uzunluk == onEkUzunlugu + 1 && cozum!.blok.tur != .ayirici) else { return false }
        }
        tamamlayiciyiYaz(tamamlayici)
        guard secim == NSRange(location: s.location + 1, length: 0) else { return true }
        if let seviye {
            baslikUygula(seviye, komutAraligi: NSRange(location: paragraf.location, length: onEkUzunlugu + 1))
            return true
        }
        let tamamlanmis = NSRange(location: paragraf.location, length: paragraf.length + 1)
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: tamamlanmis))
        yeni.deleteCharacters(in: NSRange(location: 0, length: onEkUzunlugu + (tamamlayici == " " ? 1 : 0)))
        var blok = cozum!.blok
        blok.kaynakOnEk = nil
        let isaret = blokIsaretiniUret(blok)
        blokBiciminiUygula(blok, metne: yeni, aralik: NSRange(location: 0, length: yeni.length))
        yeni.insert(isaret, at: 0)
        blokDuzenle(tamamlanmis, yeni: yeni,
                    secim: NSRange(location: paragraf.location + isaret.length + (tamamlayici == "\n" ? 1 : 0), length: 0),
                    yazim: blok.tur == .ayirici ? [:] : blok.oznitelikler, numarala: blok.listeMi)
        return true
    }

    private func baslikUygula(_ seviye: Int, komutAraligi: NSRange? = nil) {
        let paragraf = ns.paragraphRange(for: secim)
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: paragraf))
        var s = secim
        if let komutAraligi {
            yeni.deleteCharacters(in: NSRange(location: komutAraligi.location - paragraf.location, length: komutAraligi.length))
            s = NSRange(location: komutAraligi.location, length: 0)
        }
        var isaretler: [NSRange] = []
        yeni.enumerateAttribute(kBlokIsaretiAnahtari, in: NSRange(location: 0, length: yeni.length)) { deger, alt, _ in
            if deger as? Bool == true { isaretler.append(alt) }
        }
        for alt in isaretler.reversed() {
            yeni.deleteCharacters(in: alt)
            let bas = paragraf.location + alt.location, son = bas + alt.length
            func yeniKonum(_ k: Int) -> Int { k >= son ? k - alt.length : max(bas, k) }
            let yeniBas = s.location < bas ? s.location : yeniKonum(s.location)
            let yeniSon = NSMaxRange(s) < bas ? NSMaxRange(s) : yeniKonum(NSMaxRange(s))
            s = NSRange(location: yeniBas, length: yeniSon - yeniBas)
        }
        s.length = min(s.length, max(0, paragraf.location + yeni.length - s.location))
        blokBiciminiKaldir(yeni)
        let tumu = NSRange(location: 0, length: yeni.length)
        yeni.removeAttribute(kKodBloguAnahtari, range: tumu)
        yeni.removeAttribute(kKodBloguDiliAnahtari, range: tumu)
        // Başlık da düz metin de paragrafın tek fontunu alır: kalın/italik/punto düşer.
        for anahtar in kFontAnahtarlari { yeni.removeAttribute(anahtar, range: tumu) }
        var yazim: Oznitelikler = [:]
        if seviye > 0 {
            yazim[kBaslikSeviyesiAnahtari] = seviye
            if yeni.length == 0 {
                var isaret = yazim
                isaret[kBlokIsaretiAnahtari] = true
                yeni.append(NSAttributedString(string: "\u{200B}", attributes: isaret))
                s.location += 1
            }
            yeni.addAttributes(yazim, range: NSRange(location: 0, length: yeni.length))
        } else {
            yeni.removeAttribute(kBaslikSeviyesiAnahtari, range: tumu)
        }
        blokDuzenle(paragraf, yeni: yeni, secim: s, yazim: yazim, numarala: blok(paragraf)?.listeMi == true)
    }

    private func bloktaYeniSatir() -> Bool {
        let paragraf = ns.paragraphRange(for: secim)
        let s = secim
        let eski = anlamsalBelge.attributedSubstring(from: paragraf)
        let mevcutYazim = yazim(s.location)
        if mevcutYazim[kKodBloguAnahtari] != nil,
           eski.string.replacingOccurrences(of: "\u{200B}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blokDuzenle(paragraf, yeni: NSAttributedString(string: "\n"),
                        secim: NSRange(location: paragraf.location + 1, length: 0), yazim: [:])
            return true
        }
        let baslik = eski.length > 0 ? eski.attribute(kBaslikSeviyesiAnahtari, at: 0, effectiveRange: nil) as? Int : nil
        if baslik != nil || blok(paragraf)?.tur == .ayirici {
            let yeni = NSMutableAttributedString(attributedString: eski)
            let yerel = NSRange(location: s.location - paragraf.location, length: s.length)
            yeni.replaceCharacters(in: yerel, with: NSAttributedString(string: "\n", attributes: mevcutYazim))
            let alt = NSRange(location: yerel.location + 1, length: yeni.length - yerel.location - 1)
            for anahtar in [kBaslikSeviyesiAnahtari, kBlokIsaretiAnahtari, kMetinBloguAnahtari,
                            kUyariKutusuAnahtari, kParagrafGeometrisiAnahtari] + kFontAnahtarlari {
                yeni.removeAttribute(anahtar, range: alt)
            }
            blokDuzenle(paragraf, yeni: yeni, secim: NSRange(location: s.location + 1, length: 0), yazim: [:])
            return true
        }
        guard var blok = blok(paragraf) else { return false }
        let isaret = blokIsaretiUzunlugu(eski)
        let govde = (eski.string as NSString).substring(from: isaret).trimmingCharacters(in: .whitespacesAndNewlines)
        if govde.isEmpty {
            // Boş öğede Enter listeden çıkar.
            let yeni = NSMutableAttributedString(attributedString: eski)
            yeni.deleteCharacters(in: NSRange(location: 0, length: isaret))
            blokBiciminiKaldir(yeni)
            if blok.tur == .uyari, !yeni.string.hasSuffix("\n") { yeni.append(NSAttributedString(string: "\n")) }
            blokDuzenle(paragraf, yeni: yeni, secim: NSRange(location: paragraf.location, length: 0),
                        yazim: [:], numarala: blok.listeMi)
            return true
        }
        let yeni = NSMutableAttributedString(attributedString: eski)
        let bas = max(isaret, s.location - paragraf.location)
        let yerel = NSRange(location: bas, length: max(bas, NSMaxRange(s) - paragraf.location) - bas)
        yeni.replaceCharacters(in: yerel, with: NSAttributedString(string: "\n", attributes: mevcutYazim))
        blok.tamamlandi = false
        blok.kaynakOnEk = nil
        if blok.tur == .uyari { blok.devam = true }
        if blok.tur == .numarali { blok.numara = blok.numara == Int.max ? 1 : blok.numara + 1 }
        let yeniIsaret = blokIsaretiniUret(blok)
        let altBaslangic = yerel.location + 1
        yeni.insert(yeniIsaret, at: altBaslangic)
        blokBiciminiUygula(blok, metne: yeni, aralik: NSRange(location: altBaslangic, length: yeni.length - altBaslangic))
        var sonrakiYazim = mevcutYazim
        sonrakiYazim.merge(blok.oznitelikler) { _, yeni in yeni }
        blokDuzenle(paragraf, yeni: yeni,
                    secim: NSRange(location: paragraf.location + altBaslangic + yeniIsaret.length, length: 0),
                    yazim: sonrakiYazim, numarala: blok.listeMi)
        return true
    }

    private func blokGirintisiniDegistir(_ fark: Int) -> Bool {
        let paragraf = ns.paragraphRange(for: secim)
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: paragraf))
        var konum = 0, degisti = false, numarala = false
        var sonrakiYazim = yazim(secim.location)
        while konum < yeni.length {
            let alt = (yeni.string as NSString).paragraphRange(for: NSRange(location: konum, length: 0))
            if var blok = MetinBlogu(oznitelik: yeni.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil)),
               blok.tur != .ayirici, blok.tur != .uyari {
                blok.seviye = max(0, blok.seviye + fark)
                blok.kaynakOnEk = nil
                blokBiciminiUygula(blok, metne: yeni, aralik: alt)
                degisti = true
                numarala = numarala || blok.listeMi
                if konum == 0 { sonrakiYazim.merge(blok.oznitelikler) { _, yeni in yeni } }
            }
            konum = NSMaxRange(alt)
        }
        guard degisti else { return false }
        blokDuzenle(paragraf, yeni: yeni, secim: secim, yazim: sonrakiYazim, numarala: numarala)
        return true
    }

    private func satirBasindaBicimiKaldir() -> Bool {
        let s = secim
        guard s.length == 0 else { return false }
        let paragraf = ns.paragraphRange(for: s)
        let eski = anlamsalBelge.attributedSubstring(from: paragraf)
        guard s.location <= paragraf.location + blokIsaretiUzunlugu(eski) else { return false }
        if eski.length > 0, eski.attribute(kBaslikSeviyesiAnahtari, at: 0, effectiveRange: nil) != nil {
            baslikUygula(0)
            return true
        }
        guard let blok = blok(paragraf) else { return false }
        let yeni = NSMutableAttributedString(attributedString: eski)
        yeni.deleteCharacters(in: NSRange(location: 0, length: blokIsaretiUzunlugu(eski)))
        blokBiciminiKaldir(yeni)
        blokDuzenle(paragraf, yeni: yeni, secim: NSRange(location: paragraf.location, length: 0),
                    yazim: [:], numarala: blok.listeMi)
        return true
    }
}
