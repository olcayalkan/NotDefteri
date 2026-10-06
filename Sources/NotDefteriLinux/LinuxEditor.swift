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
    guard let hedef = editor(veri), hedef.editorEtkin, let pano = gtk_widget_get_clipboard(hedef.metinGorunumu) else { return }
    if hedef.yapistirmaOncesi.contains(where: { $0(pano) }), let nesne {
        g_signal_stop_emission_by_name(nesne, "paste-clipboard")
    }
}

private let panoKesC: @convention(c) (gpointer?, gpointer?) -> Void = { nesne, veri in
    if let nesne, editor(veri)?.cerceveliSecimiSil(kes: true) == true {
        g_signal_stop_emission_by_name(nesne, "cut-clipboard")
    }
}

private let imlectenSilC: @convention(c) (gpointer?, GtkDeleteType, Int32, gpointer?) -> Void = { nesne, _, _, veri in
    if let nesne, editor(veri)?.cerceveliSecimiSil() == true {
        g_signal_stop_emission_by_name(nesne, "delete-from-cursor")
    }
}

private final class YapiEnterEylemi {
    let uygula: () -> Void
    init(_ uygula: @escaping () -> Void) { self.uygula = uygula }
}

private let kFontAnahtarlari = [kKalinAnahtari, kItalikAnahtari, kPuntoOlcegiAnahtari]

// MARK: - Editör

/// Kayıt denemesinin sonucu: neden bilgisi çağıran tarafa (geçmiş geri yükleme vb.) kalır.
enum KayitSonucu: Equatable {
    case yazildi
    /// Kaydedilecek değişiklik yok (içerik diskle aynı).
    case degisiklikYok
    case hata(String)
}

/// macOS NotMetinGorunumu + NotPenceresi kayıt akışının B1 dilimi: açma, yazma, satır başı
/// biçimleri, liste devamı, girinti, yapılacak kutusu, Ctrl+S/B/I/Z ve otomatik kayıt.
final class LinuxEditor {
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
    private var kaydiAtla = false
    private typealias BekleyenIslem = (devam: () -> Void, iptal: () -> Void, ust: LinuxDiyalog.Ust?)
    /// Diyalog açıkken gelen işlemler düşmez; diyalog kapanınca sırayla yeniden denenir.
    private var bekleyenIslemler: [BekleyenIslem] = []
    private var sonKayitHatasi: String?
    private var bekleyenKayitHatasi: (url: URL, neden: String)?
    var notSecimiBildir: ((URL?) -> Void)?
    var tusOncesi: [(_ keyval: UInt32, _ durum: UInt32) -> Bool] = []
    /// GdkClipboard, C köprüsünde opaque türdür. true = pano eklenti tarafından işlendi.
    var yapistirmaOncesi: [(OpaquePointer) -> Bool] = []
    var degisiklikSonrasi: [() -> Void] = []
    /// İkinci değer editörün diskte olduğuna inandığı metindir; kancalar diski yeniden okumasın (TOCTOU).
    var notAcildi: [(URL, String?) -> Void] = []
    var acikURL: URL? { mevcutURL }
    /// Kopya dışarıdan NSMutableAttributedString'e çevrilse de esas belge değişmez.
    var belge: NSAttributedString { NSAttributedString(attributedString: adaptor.belge) }
    /// Ana döngüde kopyasız okuma; belgeyi saklamayın veya mutable türe çevirmeyin.
    func belgeyiOku<T>(_ oku: (NSAttributedString) -> T) -> T { oku(adaptor.belge) }
    var sayfaUstbilgisi: SayfaUstbilgisi { ustbilgi }
    /// Kayıt başarısız olup kullanıcı "Kaydetmeden Devam" dediyse true kalır; disk sürümü eskidir.
    var kaydedilmemisDegisiklikVar: Bool { kaydedici.duzenlendiMi }
    private(set) var editorEtkin = false
    private(set) var nesil: UInt = 0
    var durumDegisti: [() -> Void] = []
    /// Tek geri alma geçmişi LinuxGorseller'dadır (metin, görsel ve üstbilgi adımları); tuş, menü ve düğmeler buradan geçer.
    var geriAlYolu: ((_ ileri: Bool) -> Void)?
    var kayitSonrasi: [(URL, String) -> Void] = []
    private var anaSayfaAcik = false
    private var kayitHatasiBildirildi = false
    private var diyalogAcik = false

    private var anlamsalBelge: NSMutableAttributedString { adaptor.belge }
    private var ns: NSMutableString { adaptor.belge.mutableString }
    private var secim: NSRange { LinuxMetinDonusumu.secim(tampon) }

    init(pencere: LinuxPencere) {
        self.pencere = pencere
        gorunum = UnsafeMutableRawPointer(metinGorunumu).assumingMemoryBound(to: GtkTextView.self)
        tampon = gtk_text_view_get_buffer(gorunum)!
        // Önbellek changed sinyalini aynalama/görünüm kancalarından önce işlemeli.
        GtkKoprusu.konumOnbelleginiKur(tampon)
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
        // Geçmiş LinuxGorseller'de; GTK'nin ikinci undo günlüğü tutulmaz.
        gtk_text_buffer_set_enable_undo(tampon, 0)
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
        cBagla(UnsafeMutableRawPointer(metinGorunumu), "cut-clipboard",
               unsafeBitCast(panoKesC, to: GCallback.self), self)
        cBagla(UnsafeMutableRawPointer(metinGorunumu), "delete-from-cursor",
               unsafeBitCast(imlectenSilC, to: GCallback.self), self)
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
        menuleriKaydet(pencere)
    }

    /// macOS Menu.swift Dosya/Düzen/Biçim öğeleri. Ctrl+Z/Y/B/I tuş kancalarında işlenir (Ctrl+Z/Y: LinuxGorseller);
    /// bu yüzden yalnızca Ctrl+S gerçek kısayol olarak kaydedilir, diğerleri menüde görünür.
    private func menuleriKaydet(_ pencere: LinuxPencere) {
        pencere.menuEkle(["Dosya", "Kaydet"], kisayol: "<Control>s") { [weak self] in self?.kaydetKomutu() }
        pencere.menuEkle(["Düzen", "Geri Al"], kisayol: "<Control>z", kisayoluKaydet: false) { [weak self] in
            self?.geriAlIstendi(ileri: false)
        }
        pencere.menuEkle(["Düzen", "Yinele"], kisayol: "<Control>y", kisayoluKaydet: false) { [weak self] in
            self?.geriAlIstendi(ileri: true)
        }
        for (ad, tetik, anahtar) in [("Kalın", "<Control>b", kKalinAnahtari), ("İtalik", "<Control>i", kItalikAnahtari)] {
            pencere.menuEkle(["Biçim", ad], kisayol: tetik, kisayoluKaydet: false) { [weak self] in
                guard let self, self.editorEtkin, GtkKoprusu.aynalamaHatasi(self.tampon) == nil else { return }
                gtk_widget_grab_focus(self.metinGorunumu)
                self.satirIciBicimiDegistir(anahtar)
            }
        }
    }

    /// Başlık çubuğu düğmeleri ve menü: editör etkin değilse (ana sayfa) işlem yapılmaz.
    func geriAlIstendi(ileri: Bool) {
        guard editorEtkin else { return }
        gtk_widget_grab_focus(metinGorunumu)
        geriAlYolu?(ileri)
    }

    /// Mac baslikSeviyesiUygula: imlecin paragrafı başlığa çevrilir; 0 normal metne döndürür.
    func baslikSeviyesiUygula(_ seviye: Int) {
        guard editorEtkin, GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
        baslikUygula(seviye)
        gtk_widget_grab_focus(metinGorunumu)
    }

    /// Mac yaziBoyutunuDegistir: seçimde her parçanın puntosu `fark` kadar değişir; seçim yoksa yalnızca
    /// sonraki yazım etkilenir. Başlık puntosu başlık düzeyinden gelir (Linux'ta geçici başlık puntosu yok).
    func puntoDegistir(fark: CGFloat) {
        guard editorEtkin, GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
        func yaz(_ o: inout Oznitelikler) -> Bool {
            guard o[kBaslikSeviyesiAnahtari] == nil || o[kKodBloguAnahtari] != nil else { return false }
            let eski = kTabanPunto * CGFloat((o[kPuntoOlcegiAnahtari] as? Double) ?? 1)
            let yeni = boyutSinirla(eski + fark)
            guard yeni != eski else { return false }
            o[kPuntoOlcegiAnahtari] = yeni == kTabanPunto ? nil : Double(yeni / kTabanPunto)
            return true
        }
        gtk_widget_grab_focus(metinGorunumu)
        let s = secim
        if s.length == 0 {
            var o = yazim(s.location)
            if yaz(&o) { yazimOnceligi = o }
            return
        }
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: s))
        var degisti = false
        yeni.enumerateAttributes(in: NSRange(location: 0, length: yeni.length)) { o, alt, _ in
            guard o[kBlokIsaretiAnahtari] as? Bool != true, o[kGorselAnahtari] == nil else { return }
            var yeniO = o
            if yaz(&yeniO) { yeni.setAttributes(yeniO, range: alt); degisti = true }
        }
        if degisti { blokDuzenle(s, yeni: yeni, secim: s, yazim: yazimOnceligi) }
    }

    /// Mac mevcutPunto: seçimin başındaki ya da (seçim yoksa) sonraki yazının puntosu.
    var imlecPuntosu: CGFloat {
        let s = secim
        let o: Oznitelikler = s.length > 0 && s.location < anlamsalBelge.length
            ? anlamsalBelge.attributes(at: s.location, effectiveRange: nil) : yazim(s.location)
        if let seviye = o[kBaslikSeviyesiAnahtari] as? Int, o[kKodBloguAnahtari] == nil {
            return (kTabanPunto * (seviye == 1 ? 1.75 : seviye == 2 ? 1.40 : 1.15)).rounded()
        }
        return kTabanPunto * CGFloat((o[kPuntoOlcegiAnahtari] as? Double) ?? 1)
    }

    // MARK: Not açma

    func notuAc(_ url: URL, yenidenYukle: Bool = false) { notuAc(url, yenidenYukle: yenidenYukle) { _ in } }

    /// `yenidenYukle`: aynı not açıkken de diskten okunur (Mac notuAc(yenidenYukle: true)); örneğin
    /// ana sayfadan yapılacak tamamlanınca dosya değiştiğinde. Önce tampon kaydedilir.
    func notuAc(_ url: URL, yenidenYukle: Bool = false, tamam: @escaping (Bool) -> Void) {
        guard !diyalogAcik else { notSecimiBildir?(mevcutURL); tamam(false); return }
        if url == mevcutURL, editorEtkin, !yenidenYukle { notSecimiBildir?(url); tamam(true); return }
        islemOncesi({ [weak self] in
            guard let self else { tamam(false); return }
            if url == self.mevcutURL, !yenidenYukle {
                self.pencere?.icerigiGoster(anaSayfa: false)
                self.notSecimiBildir?(url)
                tamam(true)
                return
            }
            tamam(self.ac(url))
        }, iptal: { [weak self] in
            self?.notSecimiBildir?(self?.mevcutURL)
            tamam(false)
        })
    }

    /// İşlem ve tampon değişiklikleri her zaman sinyal dönüşünden sonra başlar.
    /// `ust`: kayıt uyarısının bağlanacağı pencere (işlemi başlatan modal pencere); yoksa ana pencere.
    func islemOncesi(ust: LinuxDiyalog.Ust? = nil, _ devam: @escaping () -> Void) { islemOncesi(devam, iptal: {}, ust: ust) }

    private func islemOncesi(_ devam: @escaping () -> Void, iptal: @escaping () -> Void, ust: LinuxDiyalog.Ust? = nil) {
        let beklenen = nesil, kaydiAtla = kaydiAtla
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.nesil == beklenen else { iptal(); return }
            guard !self.diyalogAcik else { self.bekleyenIslemler.append((devam, iptal, ust)); return }
            if kaydiAtla || self.simdiKaydet() { devam() }
            else { self.kaydetmedenDevam(devam, iptal: iptal, ust: ust) }
        }
    }

    private func bekleyenIslemleriSurdur() {
        guard !diyalogAcik, !bekleyenIslemler.isEmpty else { return }
        let islemler = bekleyenIslemler
        bekleyenIslemler = []
        for islem in islemler { islemOncesi(islem.devam, iptal: islem.iptal, ust: islem.ust) }
    }

    @discardableResult
    private func ac(_ url: URL) -> Bool {
        defer { notSecimiBildir?(mevcutURL) }
        let icerik: String
        do {
            try notlarYolunuDogrula(url)
            icerik = try String(contentsOf: url, encoding: .utf8)
        }
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
        mevcutURL = url
        kaydedici.sifirla(sonYazilan: icerik)
        kayitHatasiBildirildi = false
        bekleyenKayitHatasi = nil
        sonKayitHatasi = nil
        nesil &+= 1
        editorEtkin = !anaSayfaAcik
        pencere?.icerigiGoster(anaSayfa: false)
        gtk_text_view_set_editable(gorunum, editorEtkin ? 1 : 0)
        gtk_text_view_set_cursor_visible(gorunum, editorEtkin ? 1 : 0)
        gtk_adjustment_set_value(gtk_scrolled_window_get_vadjustment(OpaquePointer(kaydirma)), 0)
        pencere?.basligiAyarla(sayfaYolu(url))
        kenarlariAyarla()
        for kanca in notAcildi { kanca(url, icerik) }
        durumuBildir()
        return true
    }

    func simdiKaydet() -> Bool {
        if case .hata = simdiKaydetSonucu() { return false }
        return true
    }

    /// Bekleyen değişikliği hemen yazar ve nedenini bildirir; diyalog göstermez (çağıran karar verir).
    func simdiKaydetSonucu(bildir: Bool = false) -> KayitSonucu {
        kaydedici.bekleyeniIptalEt()
        guard kaydedici.duzenlendiMi, let url = mevcutURL else { return .degisiklikYok }
        let sonuc = kaydetSonucu(url, bildir: bildir)
        if case .hata(let neden) = sonuc { sonKayitHatasi = neden } else { sonKayitHatasi = nil }
        return sonuc
    }

    /// GTK diyaloğu asenkrondur; yalnızca onaylanan işlem kayıt denetimini bir kez atlar.
    func kaydetmedenDevam(_ islem: @escaping () -> Void) { kaydetmedenDevam(islem, iptal: {}) }

    private func kaydetmedenDevam(_ islem: @escaping () -> Void, iptal: @escaping () -> Void, ust: LinuxDiyalog.Ust? = nil) {
        let beklenen = nesil
        let gosterildi = diyalog("Kaydetmeden devam edilsin mi?",
                "Son değişiklikler kaydedilemedi. Devam ederseniz kaybolabilir.\n\nNeden: \(sonKayitHatasi ?? "Kayıt başarısız")",
                dugmeler: ["İptal", "Kaydetmeden Devam"], ust: ust) { [weak self] secilen in
            guard let self, self.nesil == beklenen, secilen == 2 else { iptal(); return }
            self.kaydiAtla = true
            islem()
            self.kaydiAtla = false
            self.notSecimiBildir?(self.mevcutURL)
        }
        if !gosterildi { iptal() }
    }

    func etkinligiAyarla(anaSayfa: Bool) {
        guard anaSayfaAcik != anaSayfa else { return }
        anaSayfaAcik = anaSayfa
        editorEtkin = mevcutURL != nil && !anaSayfa
        nesil &+= 1
        yazimOnceligi = nil
        if anaSayfa { kaydedici.bekleyeniIptalEt() }
        gtk_text_view_set_editable(gorunum, editorEtkin ? 1 : 0)
        gtk_text_view_set_cursor_visible(gorunum, editorEtkin ? 1 : 0)
        durumuBildir()
        if editorEtkin, kaydedici.duzenlendiMi { kaydedici.zamanlayiciKur { [weak self] in self?.otomatikKaydet() } }
    }

    private func durumuBildir() { for kanca in durumDegisti { kanca() } }

    /// macOS gibi geri alınabilir tek adım ("Sayfa seçenekleri"); adım LinuxGorseller geçmişine girer.
    func ustbilgiyiDegistir(_ yeni: SayfaUstbilgisi) {
        guard editorEtkin, yeni != ustbilgi else { return }
        LinuxGorseller.ustbilgiDegisti(tampon, eski: ustbilgi, yeni: yeni)
        ustbilgiyiUygula(yeni)
    }

    /// Geçmiş kaydı yapmaz; geri alma/yineleme de buradan uygular.
    func ustbilgiyiUygula(_ bilgi: SayfaUstbilgisi) {
        ustbilgi = bilgi
        kenarlariAyarla()
        icerikDegisti()
        durumuBildir()
    }

    /// Gizli tampon da güncellenir; kullanıcının seçim/undo ve kaydedilmemiş gövdesi korunur.
    func baglariYenidenYaz(_ hedefler: [String: String]) {
        guard mevcutURL != nil, !hedefler.isEmpty else { return }
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.mevcutURL != nil else { return }
            // Bekleyen aralık yoktur; dönüşüm o andaki açık/gizli belgeden yeniden hesaplanır.
            self.bagYaziminiUygula(hedefler)
        }
    }

    /// Ana sayfa açıkken (editör gizli) açık sayfanın belgesini değiştirir: tampon ve disk birlikte
    /// güncellenir, böylece eski tampon sonradan diske geri yazılmaz. `metin` tüm yeni belgedir
    /// (genelde `belge` kopyasının değiştirilmişi). Tampon değişimi sinyal dönüşünden sonra yapılır;
    /// `tamam` ana iş parçacığında kayıt sonucuyla çağrılır. Başka sayfa açıksa `.hata` döner.
    func acikBelgeyiGuncelle(_ url: URL, metin: NSAttributedString, kayitBildir: Bool = true,
                             tamam: ((KayitSonucu) -> Void)? = nil) {
        acikBelgeyiGuncelle(url, kayitBildir: kayitBildir, uret: { _ in metin }, tamam: tamam)
    }

    /// `uret`, uygulama anındaki güncel belgeyle çağrılır (sıçramadan önce alınan kopya arada değişen
    /// tamponu ezmesin); nil dönerse belge değişmez ve `tamam` `.degisiklikYok` ile çağrılır.
    /// `kayitBildir` false ise kayıt hatasını editör diyaloğa çevirmez; çağıran tek diyaloğu kendisi gösterir.
    func acikBelgeyiGuncelle(_ url: URL, kayitBildir: Bool = true, uret: @escaping (NSAttributedString) -> NSAttributedString?,
                             tamam: ((KayitSonucu) -> Void)? = nil) {
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.mevcutURL == url else { tamam?(.hata("Sayfa artık açık değil.")); return }
            guard GtkKoprusu.aynalamaHatasi(self.tampon) == nil else {
                tamam?(.hata("Editör tamponu belgeyle uyumsuz.")); return
            }
            guard let metin = uret(NSAttributedString(attributedString: self.anlamsalBelge)) else {
                tamam?(.degisiklikYok); return
            }
            let secilen = NSRange(location: min(self.secim.location, metin.length), length: 0)
            self.blokDuzenle(NSRange(location: 0, length: self.anlamsalBelge.length), yeni: metin,
                             secim: secilen, yazim: nil, ayriAdim: true, gizliyken: true)
            let sonuc = self.simdiKaydetSonucu(bildir: kayitBildir)
            self.durumuBildir()
            tamam?(sonuc)
        }
    }

    private func bagYaziminiUygula(_ hedefler: [String: String]) {
        var degisimler: [(NSRange, String)] = []
        for bag in sayfaBaglariniBul(anlamsalBelge.string) {
            guard let hedef = hedefler[bag.hedef.trimmingCharacters(in: .whitespaces)] else { continue }
            var engelli = false
            anlamsalBelge.enumerateAttributes(in: bag.aralik) { oznitelikler, _, dur in
                if [kKodBloguAnahtari, kSatirIciKodAnahtari, kBaglantiAnahtari, kKacisliKoseParantezAnahtari]
                    .contains(where: { oznitelikler[$0] != nil }) { engelli = true; dur.pointee = true }
            }
            if !engelli { degisimler.append((bag.aralik, hedef)) }
        }
        guard !degisimler.isEmpty else { return }
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge)
        var secilen = secim
        for (aralik, hedef) in degisimler.reversed() {
            let metin = "[[\(hedef)]]", uzunluk = (metin as NSString).length
            if secilen.location >= NSMaxRange(aralik) { secilen.location += uzunluk - aralik.length }
            else if NSMaxRange(secilen) > aralik.location { secilen = NSRange(location: aralik.location + uzunluk, length: 0) }
            var oznitelikler = yeni.attributes(at: aralik.location, effectiveRange: nil)
            oznitelikler[kSayfaBagiAnahtari] = hedef
            oznitelikler.removeValue(forKey: kMarkdownKaynakAnahtari)
            yeni.replaceCharacters(in: aralik, with: NSAttributedString(string: metin, attributes: oznitelikler))
        }
        blokDuzenle(NSRange(location: 0, length: anlamsalBelge.length), yeni: yeni,
                    secim: secilen, yazim: nil, ayriAdim: true, gizliyken: true)
        if let url = mevcutURL { sonKayitHatasi = kaydet(url, bildir: true) }
        durumuBildir()
    }

    func yolDegisti(eski: URL, yeni: URL) {
        guard mevcutURL == eski else { return }
        kaydedici.bekleyeniIptalEt()
        mevcutURL = yeni
        nesil &+= 1
        pencere?.basligiAyarla(sayfaYolu(yeni))
        notSecimiBildir?(yeni)
        for kanca in notAcildi { kanca(yeni, kaydedici.sonYazilanIcerik) }
        durumuBildir()
        if kaydedici.duzenlendiMi { icerikDegisti() }
    }

    /// Not silindi: kaydedilecek dosya yok, bu yüzden kayıt denemesi ve "Kaydetmeden devam?" sorusu yoktur.
    /// Tampon değişimi sinyal dönüşünden sonra yapılır; arada başka not açıldıysa dokunulmaz.
    func bosalt(silinen: URL) {
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.mevcutURL == silinen else { return }
            self.tamponuBosalt()
        }
    }

    private func tamponuBosalt() {
        kaydedici.sifirla(sonYazilan: nil)
        mevcutURL = nil
        editorEtkin = false
        nesil &+= 1
        ustbilgi = SayfaUstbilgisi()
        yazimOnceligi = nil
        kayitHatasiBildirildi = false
        sonKayitHatasi = nil
        bekleyenKayitHatasi = nil
        adaptor.yukle(NSAttributedString(string: ""))
        gtk_text_view_set_editable(gorunum, 0)
        gtk_text_view_set_cursor_visible(gorunum, 0)
        pencere?.basligiAyarla([])
        notSecimiBildir?(nil)
        durumuBildir()
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

    /// Başarıda nil, başarısızlıkta neden döner.
    @discardableResult
    private func kaydet(_ url: URL, bildir: Bool) -> String? {
        if case .hata(let neden) = kaydetSonucu(url, bildir: bildir) { return neden }
        return nil
    }

    /// Sürüm geçmişi kayıttan sonra yazılır.
    private func kaydetSonucu(_ url: URL, bildir: Bool) -> KayitSonucu {
        if let neden = adaptor.aynalamaHatasi() { return .hata(kayitHatasi(neden, url: url, bildir: bildir)) }
        do { try notlarYolunuDogrula(url) }
        catch { return .hata(kayitHatasi(error.localizedDescription, url: url, bildir: bildir)) }
        var klasorMu: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path),
              FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: &klasorMu),
              klasorMu.boolValue else {
            return .hata(kayitHatasi("Notun dosyası veya klasörü artık mevcut değil.", url: url, bildir: bildir))
        }
        let metin = sayfaMarkdownunuUret(anlamsalBelge, ustbilgi: ustbilgi)
        switch kaydedici.yaz(metin: metin, url: url, mevcutURL: mevcutURL) {
        case .gerekmedi:
            bekleyenKayitHatasi = nil
            kayitHatasiBildirildi = false
            return .degisiklikYok
        case .yazildi:
            kayitHatasiBildirildi = false
            bekleyenKayitHatasi = nil
            SayfaGecmisi.kaydet(metin: metin, icerikURL: url)
            for kanca in kayitSonrasi { kanca(url, metin) }
            durumuBildir()
            return .yazildi
        case .basarisiz(let neden):
            return .hata(kayitHatasi(neden, url: url, bildir: bildir))
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
        nesil &+= 1
        kaydedici.degisiklikIsaretle()
        if let neden = GtkKoprusu.aynalamaHatasi(tampon), let url = mevcutURL {
            sonKayitHatasi = neden
            _ = kayitHatasi(neden, url: url, bildir: true)
        }
        degisiklikKancalariniBildir()
        if editorEtkin { kaydedici.zamanlayiciKur { [weak self] in self?.otomatikKaydet() } }
    }

    /// Mac didChangeText gibi: GTK işlem ve imleç güncellemesini bitirdikten sonra.
    private func degisiklikKancalariniBildir() {
        let beklenen = nesil
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.nesil == beklenen else { return }
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

    /// Tek diyalog kuralı: biri açıkken ikincisi gösterilmez (false). Yanıt, düğmenin 1'den başlayan sırasıdır.
    @discardableResult
    private func diyalog(_ baslik: String, _ aciklama: String, dugmeler: [String], ust: LinuxDiyalog.Ust? = nil,
                         _ yanit: @escaping (Int) -> Void) -> Bool {
        guard !diyalogAcik, let pencere else { return false }
        diyalogAcik = true
        LinuxDiyalog.mesaj(ust: ust ?? pencere.pencere, baslik: baslik, aciklama: aciklama, dugmeler: dugmeler,
                           kapandi: { [weak self] in self?.diyalogAcik = false }) { [weak self] secilen in
            yanit(secilen)
            guard let self else { return }
            if let hata = self.bekleyenKayitHatasi {
                self.bekleyenKayitHatasi = nil
                if self.mevcutURL == hata.url { _ = self.kayitHatasi(hata.neden, url: hata.url, bildir: true) }
            }
            self.bekleyenIslemleriSurdur()
        }
        return true
    }

    // MARK: Tampon → belge

    fileprivate func metinEklenecek(_ iter: GtkTextIter, _ metin: String) {
        guard !adaptor.programatik else { return }
        let konum = LinuxMetinDonusumu.konum(iter)
        guard konum >= 0, konum <= anlamsalBelge.length, GtkKoprusu.aynalamaHatasi(tampon) == nil else {
            GtkKoprusu.aynalamaKaymasi(tampon, "Aynalama ekleme konumu geçersiz: \(konum)")
            return
        }
        let o = yazim(konum)
        adaptor.eklendi(konum: konum, metin: metin, yazim: o)
    }

    fileprivate func metinSilinecek(_ bas: GtkTextIter, _ son: GtkTextIter) {
        guard !adaptor.programatik else { return }
        adaptor.silindi(LinuxMetinDonusumu.aralik(bas, son))
    }

    private func degisti() {
        guard !adaptor.programatik else { return }
        adaptor.bekleyeniUygula()
        icerikDegisti()
    }

    // MARK: Yazım öznitelikleri

    /// Yer tutucu ve blok işareti öznitelikleri gerçek yazıya taşınamaz.
    static func yapisalYazimIsaretleriniTemizle(_ oznitelikler: Oznitelikler) -> Oznitelikler {
        var sonuc = oznitelikler
        for anahtar in [kBlokIsaretiAnahtari, kBosKodSatiriAnahtari] { sonuc.removeValue(forKey: anahtar) }
        return sonuc
    }

    /// NSTextView gibi önceki karakterin öznitelikleri; ardından Mac'teki blokYaziminiGuncelle kuralları.
    private func yazim(_ konum: Int) -> Oznitelikler {
        var o = yazimOnceligi ?? (anlamsalBelge.length > 0
            ? anlamsalBelge.attributes(at: min(max(0, konum - 1), anlamsalBelge.length - 1), effectiveRange: nil) : [:])
        o = Self.yapisalYazimIsaretleriniTemizle(o)
        let oncekiBlok = MetinBlogu(oznitelik: o[kMetinBloguAnahtari])
        for anahtar in [kGorselAnahtari, kSayfaBagiAnahtari,
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
        guard editorEtkin else { return false }
        // Mac keyDown: önce bulucu/menü, ardından kısayollar ve otomatik blok biçimi.
        for kanca in tusOncesi where kanca(tus, durum.rawValue) { return true }
        guard GtkKoprusu.aynalamaHatasi(tampon) == nil else { return false }
        let ctrl = durum.rawValue & GDK_CONTROL_MASK.rawValue != 0
        let shift = durum.rawValue & GDK_SHIFT_MASK.rawValue != 0
        if ctrl {
            switch tus {
            case 0x62, 0x42: satirIciBicimiDegistir(kKalinAnahtari) // b
            case 0x69, 0x49: satirIciBicimiDegistir(kItalikAnahtari) // i
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
        case 0xff08: return cerceveliSecimiSil() || blokDevamindaGeriSil() || cerceveliBloktaGeriSil() || satirBasindaBicimiKaldir() // BackSpace
        case 0xffff: return !shift && cerceveliSecimiSil() // Delete; Shift+Delete GTK'nin Kes eylemidir.
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
        guard editorEtkin, GtkKoprusu.aynalamaHatasi(tampon) == nil else { return false }
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
    func aralikDegistir(_ utf16: NSRange, ile yeni: NSAttributedString,
                       secim hedef: NSRange? = nil, yazim: Oznitelikler? = nil) {
        guard editorEtkin, utf16.location >= 0, utf16.location <= anlamsalBelge.length else { return }
        blokDuzenle(utf16, yeni: yeni,
                    secim: hedef ?? NSRange(location: utf16.location + yeni.length, length: 0),
                    yazim: yazim ?? yazimOnceligi, ayriAdim: true)
    }

    /// Değer nil ise biçim kaldırılır; boş seçimde yalnızca sonraki yazım etkilenir.
    func satirIciBicimUygula(_ anahtar: NSAttributedString.Key, deger: Any?) {
        guard editorEtkin, GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
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
        guard editorEtkin, GtkKoprusu.aynalamaHatasi(tampon) == nil else { return }
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
                             yazim: Oznitelikler?, numarala: Bool = false, ayriAdim: Bool = false, gizliyken: Bool = false) {
        guard (editorEtkin || gizliyken && mevcutURL != nil), GtkKoprusu.aynalamaHatasi(tampon) == nil,
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
        LinuxGorseller.birlesmeyiKes(tampon)
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
        LinuxGorseller.birlesmeyiKes(tampon)
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
        guard let degisim = yapiEnterKurali(anlamsalBelge, imlec: secim) else { return false }
        yapiDegisiminiPlanla(degisim)
        return true
    }

    private func blokDevamindaGeriSil() -> Bool {
        guard let degisim = yapiDevamindaGeriSil(anlamsalBelge, imlec: secim) else { return false }
        yapiDegisiminiPlanla(degisim)
        return true
    }

    private func yapiDegisiminiPlanla(_ degisim: YapiEnterDegisimi) {
        let url = mevcutURL, secilen = secim, beklenen = nesil
        let eski = anlamsalBelge.attributedSubstring(from: degisim.aralik)
        // Sinyal bitince, bir sonraki tuştan önce uygula. Varsayılan idle önceliği
        // hızlı Enter/Backspace + yazımda kararı daha sonraki belgeye taşıyabilir.
        let veri = Unmanaged.passRetained(YapiEnterEylemi { [weak self] in
            guard let self, self.nesil == beklenen, self.editorEtkin, self.mevcutURL == url, self.secim == secilen,
                  NSMaxRange(degisim.aralik) <= self.anlamsalBelge.length,
                  self.anlamsalBelge.attributedSubstring(from: degisim.aralik).isEqual(to: eski),
                  gtk_text_view_get_editable(self.gorunum) != 0,
                  GtkKoprusu.aynalamaHatasi(self.tampon) == nil else { return }
            self.aralikDegistir(degisim.aralik, ile: degisim.metin,
                                secim: NSRange(location: degisim.imlec, length: 0), yazim: degisim.yazim)
        }).toOpaque()
        g_idle_add_full(G_PRIORITY_HIGH, { veri in
            if let veri { Unmanaged<YapiEnterEylemi>.fromOpaque(veri).takeUnretainedValue().uygula() }
            return 0
        }, veri, { veri in
            if let veri { Unmanaged<YapiEnterEylemi>.fromOpaque(veri).release() }
        })
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

    /// Tam kutuda kalan işaretler temizlenir; başlangıcı silinen kısmi uyarıda
    /// kalan ilk paragraf aynı silme ve geri alma kapsamına alınır.
    fileprivate func cerceveliSecimiSil(kes: Bool = false) -> Bool {
        let s = secim
        guard mevcutURL != nil, gtk_text_view_get_editable(gorunum) != 0,
              GtkKoprusu.aynalamaHatasi(tampon) == nil,
              s.length > 0, NSMaxRange(s) <= anlamsalBelge.length else { return false }
        var kapsam = s, imlec = s.location, duzeltmeVar = false
        var islemler: [(NSRange, NSAttributedString)] = [(s, NSAttributedString(string: ""))]
        anlamsalBelge.enumerateAttribute(kBlokKimligiAnahtari, in: s) { deger, alt, _ in
            guard deger != nil,
                  anlamsalBelge.attribute(kUyariKutusuAnahtari, at: alt.location, effectiveRange: nil) != nil ||
                    anlamsalBelge.attribute(kKodBloguAnahtari, at: alt.location, effectiveRange: nil) != nil else { return }
            var blok = NSRange()
            _ = anlamsalBelge.attribute(kBlokKimligiAnahtari, at: alt.location, longestEffectiveRange: &blok,
                                       in: NSRange(location: 0, length: anlamsalBelge.length))
            let secilen = NSIntersectionRange(s, blok)
            let kalanlar = [NSRange(location: blok.location, length: secilen.location - blok.location),
                            NSRange(location: NSMaxRange(secilen), length: NSMaxRange(blok) - NSMaxRange(secilen))]
                .map { ($0, kodBloguGovdesi(anlamsalBelge.attributedSubstring(from: $0))) }
            guard kalanlar.map(\.1).joined().trimmingCharacters(in: .newlines).isEmpty else {
                if kalanlar[0].1.isEmpty, NSMaxRange(secilen) < NSMaxRange(blok),
                   let kimlik = deger as? String,
                   let onarim = uyariBaslangiciniOnar(NSMaxRange(secilen), kimlik: kimlik) {
                    duzeltmeVar = true
                    kapsam = NSUnionRange(kapsam, onarim.aralik)
                    islemler.append((onarim.aralik, onarim.metin))
                }
                return
            }
            duzeltmeVar = true; kapsam = NSUnionRange(kapsam, blok)
            for (aralik, metin) in kalanlar where aralik.length > 0 {
                islemler.append((aralik, NSAttributedString(string: metin)))
                if NSMaxRange(aralik) <= s.location { imlec -= aralik.length - (metin as NSString).length }
            }
        }
        guard duzeltmeVar else { return false }
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: kapsam))
        for (aralik, metin) in islemler.sorted(by: { $0.0.location > $1.0.location }) {
            yeni.replaceCharacters(in: NSRange(location: aralik.location - kapsam.location, length: aralik.length), with: metin)
        }
        if kes {
            guard let pano = gtk_widget_get_clipboard(metinGorunumu) else { return false }
            gtk_text_buffer_copy_clipboard(tampon, pano)
        }
        geriSilmeDegisiminiPlanla(kapsam, yeni: yeni, imlec: imlec)
        return true
    }

    private func cerceveliBloktaGeriSil() -> Bool {
        let s = secim
        guard s.length == 0, anlamsalBelge.length > 0 else { return false }
        let paragraf = ns.paragraphRange(for: s)
        guard paragraf.length > 0 else { return false }
        let eski = anlamsalBelge.attributedSubstring(from: paragraf)
        let isaret = blokIsaretiUzunlugu(eski)
        let uyari = blok(paragraf)
        let kod = eski.attribute(kKodBloguAnahtari, at: 0, effectiveRange: nil) != nil
        guard uyari?.tur == .uyari || kod, s.location <= paragraf.location + isaret else { return false }
        var kodAraligi = NSRange()
        if kod {
            _ = anlamsalBelge.attribute(kKodBloguAnahtari, at: paragraf.location, longestEffectiveRange: &kodAraligi,
                                       in: NSRange(location: 0, length: anlamsalBelge.length))
            let kodGovdesi = kodBloguGovdesi(anlamsalBelge.attributedSubstring(from: kodAraligi))
            if kodGovdesi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                geriSilmeDegisiminiPlanla(kodAraligi, yeni: NSAttributedString(string: kodGovdesi), imlec: kodAraligi.location)
                return true
            }
        }
        let govde = kodBloguGovdesi(eski)
        if let uyari, uyari.tur == .uyari, govde.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bosUyariParagrafiniKaldir(paragraf, blok: uyari, govde: govde)
            return true
        }
        if let uyari, uyari.tur == .uyari {
            uyariDevaminiGeriBirlestir(paragraf, blok: uyari, isaret: isaret)
            return true
        }
        // Kodun ilk görünmez işareti korunur; devam satırında doğal birleştirme sürer.
        return s.location <= kodAraligi.location + blokIsaretiUzunlugu(anlamsalBelge, konum: kodAraligi.location)
    }

    /// Boş paragraf kutuyu böldüğünde kalan kısmın Markdown başlığı da yenilenir;
    /// normalleştirme ve komşu onarımı aynı geri alma adımında tutulur.
    private func bosUyariParagrafiniKaldir(_ paragraf: NSRange, blok: MetinBlogu, govde: String) {
        var kapsam = paragraf
        let yeni = NSMutableAttributedString(string: govde)
        if let onarim = uyariBaslangiciniOnar(NSMaxRange(paragraf), kimlik: blok.uyariKimligi) {
            kapsam = NSUnionRange(paragraf, onarim.aralik)
            yeni.append(onarim.metin)
        }
        geriSilmeDegisiminiPlanla(kapsam, yeni: yeni, imlec: paragraf.location)
    }

    private func uyariBaslangiciniOnar(_ konum: Int, kimlik: String) -> (aralik: NSRange, metin: NSAttributedString)? {
        guard konum < anlamsalBelge.length,
              var blok = self.blok(NSRange(location: konum, length: 0)),
              blok.tur == .uyari, blok.uyariKimligi == kimlik else { return nil }
        let paragraf = ns.paragraphRange(for: NSRange(location: konum, length: 0))
        // Seçim paragrafın ortasında bitebilir; yalnızca kalan parça onarılır.
        let aralik = NSRange(location: konum, length: NSMaxRange(paragraf) - konum)
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: aralik))
        blok.devam = false
        blok.kaynakOnEk = nil
        blokBiciminiUygula(blok, metne: yeni, aralik: NSRange(location: 0, length: yeni.length))
        return (aralik, yeni)
    }

    private func uyariDevaminiGeriBirlestir(_ paragraf: NSRange, blok mevcut: MetinBlogu, isaret: Int) {
        guard paragraf.location > 0,
              anlamsalBelge.attribute(kUyariKutusuAnahtari, at: paragraf.location - 1, effectiveRange: nil) as? String == mevcut.uyariKimligi else { return }
        let onceki = ns.paragraphRange(for: NSRange(location: paragraf.location - 1, length: 0))
        guard let oncekiBlok = blok(onceki) else { return }
        let kapsam = NSUnionRange(onceki, paragraf)
        let yeni = NSMutableAttributedString(attributedString: anlamsalBelge.attributedSubstring(from: kapsam))
        let oncekiSon = (ns.substring(with: onceki).trimmingCharacters(in: .newlines) as NSString).length
        yeni.deleteCharacters(in: NSRange(location: oncekiSon, length: onceki.length - oncekiSon + isaret))
        blokBiciminiUygula(oncekiBlok, metne: yeni, aralik: NSRange(location: 0, length: yeni.length))
        geriSilmeDegisiminiPlanla(kapsam, yeni: yeni, imlec: onceki.location + oncekiSon)
    }

    /// key-pressed sinyalinden çıkmadan tampon değişmez. Bekleyen işlem not,
    /// seçim veya içerik değişmişse iptal edilir; aralikDegistir tek undo açar.
    private func geriSilmeDegisiminiPlanla(_ aralik: NSRange, yeni: NSAttributedString, imlec: Int) {
        let url = mevcutURL, secilen = secim, beklenen = nesil
        let eski = anlamsalBelge.attributedSubstring(from: aralik)
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, self.nesil == beklenen, self.editorEtkin, self.mevcutURL == url, self.secim == secilen,
                  gtk_text_view_get_editable(self.gorunum) != 0, NSMaxRange(aralik) <= self.anlamsalBelge.length,
                  self.anlamsalBelge.attributedSubstring(from: aralik).isEqual(to: eski) else { return }
            self.aralikDegistir(aralik, ile: yeni)
            self.imlecIzlenmiyor = true
            LinuxMetinDonusumu.secimiAyarla(self.tampon, NSRange(location: imlec, length: 0))
            self.imlecIzlenmiyor = false
            self.yazimOnceligi = nil
        }
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
