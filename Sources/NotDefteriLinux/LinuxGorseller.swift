import CGtk
import Foundation
import NotDefteriCekirdek

private final class GorselSinyali<T> {
    let eylem: T
    init(_ eylem: T) { self.eylem = eylem }
}

private func gorselBagla<T>(_ nesne: UnsafeMutableRawPointer, _ ad: String,
                            _ callback: GCallback, _ eylem: T) {
    let veri = Unmanaged.passRetained(GorselSinyali(eylem)).toOpaque()
    g_signal_connect_data(nesne, ad, callback, veri, { veri, _ in
        if let veri { Unmanaged<AnyObject>.fromOpaque(veri).release() }
    }, GConnectFlags(rawValue: 0))
}

private let gorselHareketC: @convention(c) (gpointer?, Double, Double, gpointer?) -> Void = { _, x, y, veri in
    guard let veri else { return }
    Unmanaged<GorselSinyali<(Double, Double) -> Void>>.fromOpaque(veri).takeUnretainedValue().eylem(x, y)
}
private let gorselBirakC: @convention(c) (gpointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean = {
    _, deger, x, y, veri in
    guard let veri, let deger else { return 0 }
    return Unmanaged<GorselSinyali<(UnsafePointer<GValue>, Double, Double) -> Bool>>
        .fromOpaque(veri).takeUnretainedValue().eylem(deger, x, y) ? 1 : 0
}
private let gorselCizC: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = {
    _, cr, en, boy, veri in
    guard let cr, let veri else { return }
    Unmanaged<GorselSinyali<(OpaquePointer, Int32, Int32) -> Void>>
        .fromOpaque(veri).takeUnretainedValue().eylem(cr, en, boy)
}
private let gorselPanoC: @convention(c) (UnsafeMutablePointer<GObject>?, OpaquePointer?, gpointer?) -> Void = {
    kaynak, sonuc, veri in
    guard let veri else { return }
    let istek = Unmanaged<GorselSinyali<(UnsafeMutablePointer<GObject>?, OpaquePointer?) -> Void>>
        .fromOpaque(veri).takeRetainedValue()
    istek.eylem(kaynak, sonuc)
}

/// Anchor ekleme GTK'nın metin undo günlüğüne girmez. Görsel içeren düzenlemeler
/// için anlamsal aralık günlüğü kullanılır; geri alma da editor.aralikDegistir'den geçer.
/// Normal metin de bu günlüğe katılır ki görselin önündeki yazım konumu kaydırmasın.
enum LinuxGorseller {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor) {
        let yonetici = LinuxGorselYoneticisi(pencere: pencere, editor: editor)
        let nesne = UnsafeMutableRawPointer(editor.tampon).assumingMemoryBound(to: GObject.self)
        let veri = Unmanaged.passRetained(yonetici).toOpaque()
        g_object_set_data_full(nesne, "nd-gorseller", veri, { veri in
            if let veri { Unmanaged<LinuxGorselYoneticisi>.fromOpaque(veri).release() }
        })
        yonetici.kur()
    }

    private static func yonetici(_ tampon: UnsafeMutablePointer<GtkTextBuffer>) -> LinuxGorselYoneticisi? {
        guard let veri = g_object_get_data(UnsafeMutableRawPointer(tampon).assumingMemoryBound(to: GObject.self),
                                           "nd-gorseller") else { return nil }
        return Unmanaged<LinuxGorselYoneticisi>.fromOpaque(veri).takeUnretainedValue()
    }

    static func anchorEklendi(_ tampon: UnsafeMutablePointer<GtkTextBuffer>,
                             anchor: UnsafeMutablePointer<GtkTextChildAnchor>, gorsel: [String: Any]) {
        yonetici(tampon)?.anchorEklendi(anchor, gorsel: gorsel)
    }

    static func duzenleme(_ tampon: UnsafeMutablePointer<GtkTextBuffer>, aralik: NSRange,
                         eski: NSAttributedString, yeni: NSAttributedString) {
        yonetici(tampon)?.kaydet(aralik: aralik, eski: eski, yeni: yeni)
    }

    /// Sayfa seçenekleri metin adımlarıyla aynı geçmişe girer; sıra ve kırpma tek yerde kalır.
    static func ustbilgiDegisti(_ tampon: UnsafeMutablePointer<GtkTextBuffer>, eski: SayfaUstbilgisi, yeni: SayfaUstbilgisi) {
        yonetici(tampon)?.adimEkle(.ustbilgi(eski: eski, yeni: yeni))
    }

    /// Blok, biçim ve eklenti işlemleri tek harflik yazım zincirine eklenmez; açık grup da zinciri başlatmaz.
    static func birlesmeyiKes(_ tampon: UnsafeMutablePointer<GtkTextBuffer>) {
        yonetici(tampon)?.birlesmeyiKes()
    }
}

private final class LinuxGorselYoneticisi {
    private weak var editor: LinuxEditor?
    private weak var pencere: LinuxPencere?
    private var hucreler: [LinuxGorselHucresi] = []
    private var bekleyen: ZamanlayiciIptal?
    private var nesil = 0
    private var gecmisURL: URL?
    private var surum = 0
    fileprivate enum Adim {
        /// `imlecBasta`: silme, imleç silinen aralığın başındayken (Delete) yapıldı; geri almada imleç oraya döner.
        case aralik(konum: Int, eski: NSAttributedString, yeni: NSAttributedString, imlecBasta: Bool = false)
        case ustbilgi(eski: SayfaUstbilgisi, yeni: SayfaUstbilgisi)
    }
    private var geri: [[Adim]] = [], ileri: [[Adim]] = []
    private var grup: [Adim]?
    private var geriAliniyor = false
    /// `geri.last` tek harflik yazım/silme zinciriyse son düzenleme anı (systemUptime).
    private var birlesen: Double?
    private var kesik = false
    /// Yapıştırma/kesme sinyali geldi; sıradaki tek harflik adım zincire girmez.
    private var zincirDisi = false
    /// Tek zincirde birleşen yazı/silme uzunluğu (UTF-16) bu sınıra varınca yeni adım açılır.
    private static let zincirSiniri = 100

    init(pencere: LinuxPencere, editor: LinuxEditor) { self.pencere = pencere; self.editor = editor }
    deinit { bekleyen?() }

    func kur() {
        guard let editor else { return }
        // GTK anchor günlüğü eksik olduğundan metin ve görseller aynı aralık geçmişini kullanır.
        editor.geriAlYolu = { [weak self] ileri in self?.geriAl(ileri: ileri) }
        editor.tusOncesi.insert({ [weak self] tus, durum in self?.tus(tus, durum: durum) ?? false }, at: 0)
        editor.yapistirmaOncesi.append { [weak self] pano in self?.panodanEkle(pano) ?? false }
        LinuxEklentiler.yasamDongusunuIzle(editor) { [weak self] in self?.sifirla() }
        editor.degisiklikSonrasi.append { [weak self] in self?.degisti() }
        // Yapıştırma sinyali panoYapistirC tarafından durdurulabilir; yapıştırma bayrağı panodanEkle'de kurulur.
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.metinGorunumu), "cut-clipboard") { [weak self] in self?.zincirDisi = true }
        let nesne = UnsafeMutableRawPointer(editor.tampon)
        GtkKoprusu.sinyalBagla(nesne, "begin-user-action") { [weak self] in
            guard let self, !self.geriAliniyor else { return }
            self.grup = []
        }
        GtkKoprusu.sinyalBagla(nesne, "end-user-action") { [weak self] in
            guard let self, let grup = self.grup else { return }
            self.grup = nil
            self.grubuKaydet(grup)
        }
        for ad in ["notify::width", "notify::left-margin", "notify::right-margin"] {
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.metinGorunumu), ad) { [weak self] (_: gpointer?) in
                Platform.anaIsParcaciginda { [weak self] in self?.genisligiGuncelle() }
            }
        }
        let birak = gtk_drop_target_new(gdk_file_list_get_type(), GDK_ACTION_COPY)!
        var turler = [gdk_file_list_get_type(), gdk_texture_get_type()]
        gtk_drop_target_set_gtypes(birak, &turler, UInt(turler.count))
        gorselBagla(UnsafeMutableRawPointer(birak), "drop", unsafeBitCast(gorselBirakC, to: GCallback.self)) {
            [weak self] (deger: UnsafePointer<GValue>, x: Double, y: Double) -> Bool in
            self?.birak(deger, x: x, y: y) ?? false
        }
        gtk_widget_add_controller(editor.metinGorunumu, birak)
        sifirla()
    }

    private func sifirla() {
        nesil += 1
        birlesen = nil
        bekleyen?(); bekleyen = nil
        if gecmisURL != editor?.acikURL {
            geri.removeAll(); ileri.removeAll(); grup = nil
            gecmisURL = editor?.acikURL
        }
        hucreler.removeAll { gtk_text_child_anchor_get_deleted($0.anchor) != 0 }
        genisligiGuncelle()
    }

    func anchorEklendi(_ anchor: UnsafeMutablePointer<GtkTextChildAnchor>, gorsel: [String: Any]) {
        guard let editor else { return }
        let hucre = LinuxGorselHucresi(anchor: anchor, gorsel: gorsel, editor: editor)
        hucreler.append(hucre)
        hucre.genisligiGuncelle()
    }

    private func degisti() {
        surum += 1
        guard editor?.editorEtkin == true else { sifirla(); return }
        bekleyen?()
        let tarih = nesil
        bekleyen = Platform.zamanlayici(0.08) { [weak self] in
            guard let self, self.nesil == tarih else { return }
            self.bekleyen = nil
            self.hucreler.removeAll { gtk_text_child_anchor_get_deleted($0.anchor) != 0 }
        }
    }

    private func genisligiGuncelle() { for hucre in hucreler { hucre.genisligiGuncelle() } }

    func kaydet(aralik: NSRange, eski: NSAttributedString, yeni: NSAttributedString) {
        // Silme sinyali tampon değişmeden gelir; imleç hâlâ özgün konumdadır.
        var imlecBasta = false
        if let tampon = editor?.tampon, eski.length > 0, yeni.length == 0 {
            let imlec = LinuxMetinDonusumu.secim(tampon)
            imlecBasta = imlec.length == 0 && imlec.location == aralik.location
        }
        adimEkle(.aralik(konum: aralik.location, eski: NSAttributedString(attributedString: eski),
                         yeni: NSAttributedString(attributedString: yeni), imlecBasta: imlecBasta))
    }

    /// Geri alma/yineleme sırasında uygulanan adımlar kaydedilmez; `ileri` yalnızca yeni adımla temizlenir.
    fileprivate func adimEkle(_ adim: Adim) {
        guard !geriAliniyor else { return }
        if grup != nil { grup?.append(adim) } else { grubuKaydet([adim]) }
    }

    func birlesmeyiKes() {
        birlesen = nil
        if grup != nil { kesik = true }
    }

    /// Ardışık tek harflik yazım ya da silmeler (NSTextView gibi) son grupta birleşir; kesme koşulları `birlestir`dedir.
    private func grubuKaydet(_ adimlar: [Adim]) {
        guard !adimlar.isEmpty, !geriAliniyor else { return }
        defer { kesik = false; zincirDisi = false }
        if adimlar.count == 1, !kesik, !zincirDisi, Self.tekHarfMi(adimlar[0]) {
            let simdi = ProcessInfo.processInfo.systemUptime
            if let onceki = birlesen, simdi - onceki < 1, geri.last?.count == 1,
               let toplam = Self.birlestir(geri[geri.count - 1][0], adimlar[0]) {
                geri[geri.count - 1] = [toplam]; ileri.removeAll(); birlesen = simdi
                return
            }
            birlesen = simdi
        } else {
            birlesen = nil
        }
        geri.append(adimlar); ileri.removeAll()
        if geri.count > 200 { geri.removeFirst() }
    }

    private static func tekHarfMi(_ adim: Adim) -> Bool {
        guard case let .aralik(_, eski, yeni, _) = adim else { return false }
        return eski.length == 0 ? yeni.string.count == 1 : yeni.length == 0 && eski.string.count == 1
    }

    /// Yazma: bitişik ekleme. Silme: Backspace (öncesi) ya da Delete (aynı konum). Boşluktan sonra yeni kelime
    /// başlayınca, satır sonu gelince, zincir `zincirSiniri`na varınca ya da yazma/silme değişince nil döner.
    private static func birlestir(_ a: Adim, _ b: Adim) -> Adim? {
        guard case let .aralik(k1, e1, y1, bas1) = a, case let .aralik(k2, e2, y2, _) = b,
              max(e1.length, y1.length) < zincirSiniri,
              !e2.string.contains("\n"), !y2.string.contains("\n") else { return nil }
        func bosluk(_ s: NSAttributedString, sondaki: Bool) -> Bool {
            (sondaki ? s.string.last : s.string.first)?.isWhitespace == true
        }
        let toplam = NSMutableAttributedString(string: "")
        if e1.length == 0, e2.length == 0, k2 == k1 + y1.length {
            guard !bosluk(y1, sondaki: true) || bosluk(y2, sondaki: false) else { return nil }
            toplam.append(y1); toplam.append(y2)
            return .aralik(konum: k1, eski: e1, yeni: toplam)
        }
        guard y1.length == 0, y2.length == 0, e1.length > 0, e2.length > 0 else { return nil }
        if k2 + e2.length == k1 {
            guard !bosluk(e1, sondaki: false) || bosluk(e2, sondaki: false) else { return nil }
            toplam.append(e2); toplam.append(e1)
            return .aralik(konum: k2, eski: toplam, yeni: y1)
        }
        guard k2 == k1, !bosluk(e1, sondaki: true) || bosluk(e2, sondaki: false) else { return nil }
        toplam.append(e1); toplam.append(e2)
        return .aralik(konum: k1, eski: toplam, yeni: y1, imlecBasta: bas1)
    }

    /// Ctrl+Z/Y, Düzen menüsü ve başlık çubuğu düğmeleri tek yoldan geçer; adım türüne göre uygulanır.
    func geriAl(ileri ileriMi: Bool) {
        guard let editor, editor.editorEtkin,
              gtk_text_view_get_editable(gorunum(editor)) != 0,
              GtkKoprusu.aynalamaHatasi(editor.tampon) == nil,
              let adimlar = ileriMi ? ileri.popLast() : geri.popLast() else { return }
        geriAliniyor = true
        birlesen = nil
        defer { geriAliniyor = false }
        for adim in ileriMi ? adimlar : adimlar.reversed() {
            switch adim {
            case let .aralik(konum, eski, yeni, imlecBasta):
                editor.aralikDegistir(NSRange(location: konum, length: ileriMi ? eski.length : yeni.length),
                                      ile: ileriMi ? yeni : eski,
                                      secim: !ileriMi && imlecBasta ? NSRange(location: konum, length: 0) : nil)
            case let .ustbilgi(eski, yeni):
                editor.ustbilgiyiUygula(ileriMi ? yeni : eski)
            }
        }
        if ileriMi { geri.append(adimlar) } else { ileri.append(adimlar) }
    }

    private func tus(_ tus: UInt32, durum: UInt32) -> Bool {
        guard let editor, gtk_widget_has_focus(editor.metinGorunumu) != 0,
              gtk_text_view_get_editable(gorunum(editor)) != 0 else { return false }
        let ctrl = durum & GDK_CONTROL_MASK.rawValue != 0
        let shift = durum & GDK_SHIFT_MASK.rawValue != 0
        guard ctrl, durum & GDK_ALT_MASK.rawValue == 0 else { return false }
        if [0x7a, 0x5a, 0x79, 0x59].contains(tus) {
            geriAl(ileri: shift || tus == 0x79 || tus == 0x59)
            return true
        }
        return false
    }

    private func panodanEkle(_ pano: OpaquePointer) -> Bool {
        birlesen = nil
        zincirDisi = true
        guard let editor, editor.acikURL != nil, gtk_text_view_get_editable(gorunum(editor)) != 0,
              let bicimler = gdk_clipboard_get_formats(pano) else { return false }
        let tur = gdk_content_formats_contain_gtype(bicimler, gdk_file_list_get_type()) != 0
            ? gdk_file_list_get_type() : gdk_texture_get_type()
        guard gdk_content_formats_contain_gtype(bicimler, tur) != 0 else { return false }
        let aralik = LinuxMetinDonusumu.secim(editor.tampon), tarih = nesil, onceki = surum
        let istek = GorselSinyali { [weak self] (kaynak: UnsafeMutablePointer<GObject>?, sonuc: OpaquePointer?) in
            guard let kaynak, let sonuc else { return }
            var hata: UnsafeMutablePointer<GError>?
            let pano = OpaquePointer(kaynak)
            let deger = gdk_clipboard_read_value_finish(pano, sonuc, &hata)
            defer { if let hata { g_error_free(hata) } }
            guard let self, self.nesil == tarih, self.surum == onceki else { return }
            guard let deger else { self.hata("Panodaki görsel okunamadı."); return }
            _ = self.ekle(deger, aralik: aralik)
        }
        gdk_clipboard_read_value_async(pano, tur, 0, nil, gorselPanoC, Unmanaged.passRetained(istek).toOpaque())
        return true
    }

    private func birak(_ deger: UnsafePointer<GValue>, x: Double, y: Double) -> Bool {
        guard let editor, gtk_text_view_get_editable(gorunum(editor)) != 0 else { return false }
        var bx: Int32 = 0, by: Int32 = 0, iter = GtkTextIter()
        gtk_text_view_window_to_buffer_coords(gorunum(editor), GTK_TEXT_WINDOW_WIDGET, Int32(x), Int32(y), &bx, &by)
        gtk_text_view_get_iter_at_location(gorunum(editor), &iter, bx, by)
        return ekle(deger, aralik: NSRange(location: LinuxMetinDonusumu.konum(iter), length: 0))
    }

    private func ekle(_ deger: UnsafePointer<GValue>, aralik: NSRange) -> Bool {
        guard let editor, let url = editor.acikURL, gtk_text_view_get_editable(gorunum(editor)) != 0 else { return false }
        do {
            let klasor = try hedefKlasor(url)
            let kaynaklar = try kaynaklar(deger)
            guard !kaynaklar.isEmpty else { throw GorselHatasi.metin("Yerel bir görsel dosyası seçin.") }
            let yeni = NSMutableAttributedString(string: "")
            let sinirlar = editor.belgeyiOku { belge -> (Bool, Bool) in
                let ns = belge.string as NSString
                return (aralik.location == 0 || ns.character(at: aralik.location - 1) == 10,
                        NSMaxRange(aralik) >= ns.length || ns.character(at: NSMaxRange(aralik)) == 10)
            }
            if !sinirlar.0 { yeni.append(NSAttributedString(string: "\n")) }
            for (sira, kaynak) in kaynaklar.enumerated() {
                defer { if kaynak.gecici { try? FileManager.default.removeItem(at: kaynak.url) } }
                guard let texture = gorselOku(kaynak.url) else { throw GorselHatasi.metin("Görsel okunamadı: \(kaynak.url.lastPathComponent)") }
                defer { g_object_unref(UnsafeMutableRawPointer(texture)) }
                guard let hedef = gorselDosyasiniKopyala(kaynak.url, hedefKlasor: klasor, taban: bolumBasligi(aralik.location)) else {
                    throw GorselHatasi.metin("Görsel sayfanın Görseller klasörüne kopyalanamadı.")
                }
                let oran = Double(gdk_texture_get_width(texture)) / Double(gdk_texture_get_height(texture))
                let en = min(360, Double(gdk_texture_get_width(texture)), 10_000 * oran).rounded(.down)
                let gorsel: [String: Any] = ["yol": "\(kGorsellerKlasorAdi)/\(hedef.lastPathComponent)",
                    "dosyaURL": hedef, "genislik": max(1, en), "yukseklik": max(1, (en / oran).rounded())]
                if sira > 0 { yeni.append(NSAttributedString(string: "\n")) }
                yeni.append(NSAttributedString(string: "\u{FFFC}", attributes: [kGorselAnahtari: gorsel]))
            }
            let imlec = aralik.location + yeni.length
            if !sinirlar.1 { yeni.append(NSAttributedString(string: "\n")) }
            editor.aralikDegistir(aralik, ile: yeni)
            LinuxMetinDonusumu.secimiAyarla(editor.tampon, NSRange(location: imlec, length: 0))
            return true
        } catch { hata(error.localizedDescription); return false }
    }

    private func bolumBasligi(_ konum: Int) -> String? {
        editor?.belgeyiOku { belge in
            var baslik: String?
            belge.enumerateAttribute(kBaslikSeviyesiAnahtari, in: NSRange(location: 0, length: min(konum, belge.length))) { deger, alt, _ in
                if deger != nil { baslik = (belge.string as NSString).substring(with: alt).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            return baslik
        }
    }

    private func hedefKlasor(_ url: URL) throws -> URL {
        let sayfa = sayfaKlasoru(url).resolvingSymlinksInPath().standardizedFileURL
        let kok = notlarKlasoru().resolvingSymlinksInPath().standardizedFileURL
        let klasor = sayfa.appendingPathComponent(kGorsellerKlasorAdi, isDirectory: true)
        let cozulmus = klasor.resolvingSymlinksInPath().standardizedFileURL
        guard sayfa.pathComponents.starts(with: kok.pathComponents), sayfa != kok,
              cozulmus.deletingLastPathComponent() == sayfa, cozulmus.lastPathComponent == kGorsellerKlasorAdi else {
            throw GorselHatasi.metin("Görsel klasörü sayfanın izinli yolunun dışında.")
        }
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        return klasor
    }

    private func kaynaklar(_ deger: UnsafePointer<GValue>) throws -> [(url: URL, gecici: Bool)] {
        if deger.pointee.g_type == gdk_file_list_get_type(), let kutu = g_value_get_boxed(deger) {
            var sonuc: [(URL, Bool)] = [], liste = gdk_file_list_get_files(OpaquePointer(kutu))
            while let oge = liste {
                guard let dosya = oge.pointee.data, let yol = g_file_get_path(OpaquePointer(dosya)) else {
                    throw GorselHatasi.metin("Yalnızca yerel dosya yolları destekleniyor.")
                }
                sonuc.append((URL(fileURLWithPath: String(cString: yol)), false)); g_free(yol)
                liste = oge.pointee.next
            }
            return sonuc
        }
        guard deger.pointee.g_type == gdk_texture_get_type(), let nesne = g_value_get_object(deger) else { return [] }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NotDefteri-\(UUID().uuidString).png")
        guard gdk_texture_save_to_png(OpaquePointer(nesne), url.path) != 0 else { throw GorselHatasi.metin("Panodaki görsel PNG olarak yazılamadı.") }
        return [(url, true)]
    }

    private func hata(_ aciklama: String) {
        guard let pencere else { return }
        let nesne = UnsafeMutableRawPointer(g_object_new_with_properties(gtk_message_dialog_get_type(), 0, nil, nil)!)
        gNesneOzelligi(nesne, "text", .metin("Görsel eklenemedi"))
        gNesneOzelligi(nesne, "secondary-text", .metin(aciklama))
        let widget = nesne.assumingMemoryBound(to: GtkWidget.self)
        gtk_window_set_transient_for(nd_window(widget), nd_window(pencere.pencere))
        gtk_window_set_modal(nd_window(widget), 1)
        gtk_dialog_add_button(nesne.assumingMemoryBound(to: GtkDialog.self), "Tamam", 1)
        GtkKoprusu.sinyalBagla(nesne, "response") { (_: guint) in
            Platform.anaIsParcaciginda { gtk_window_destroy(nd_window(widget)) }
        }
        gtk_window_present(nd_window(widget))
    }
}

private enum GorselHatasi: LocalizedError {
    case metin(String)
    var errorDescription: String? { if case .metin(let metin) = self { return metin }; return nil }
}

private func gorunum(_ editor: LinuxEditor) -> UnsafeMutablePointer<GtkTextView> {
    UnsafeMutableRawPointer(editor.metinGorunumu).assumingMemoryBound(to: GtkTextView.self)
}

private func gorselOku(_ url: URL) -> OpaquePointer? {
    guard url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost",
          (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
    var hata: UnsafeMutablePointer<GError>?
    let resim = gdk_texture_new_from_filename(url.path, &hata)
    if let hata { g_error_free(hata) }
    return resim
}

private final class LinuxGorselHucresi {
    let anchor: UnsafeMutablePointer<GtkTextChildAnchor>
    private weak var editor: LinuxEditor?
    private let widget: UnsafeMutablePointer<GtkWidget>
    private let cizim = gtk_drawing_area_new()!
    private let oran: Double
    private let gorsel: [String: Any]
    private let kayitEni: Double
    private var uzerinde = false
    private var surukleme: (yon: Double, en: Double)?
    private var onizlemeEni: Double?
    private let gorselVar: Bool

    init(anchor: UnsafeMutablePointer<GtkTextChildAnchor>, gorsel: [String: Any], editor: LinuxEditor) {
        self.anchor = anchor; self.gorsel = gorsel; self.editor = editor
        g_object_ref(UnsafeMutableRawPointer(anchor))
        let texture = (gorsel["dosyaURL"] as? URL).flatMap(gorselOku)
        gorselVar = texture != nil
        g_object_ref_sink(UnsafeMutableRawPointer(cizim))
        if let texture {
            oran = min(10_000, max(0.0001, Double(gdk_texture_get_width(texture)) / Double(gdk_texture_get_height(texture))))
            let dogal = min(360, Double(gdk_texture_get_width(texture)), 10_000 * oran)
            let en = gorsel["genislik"] as? Double, boy = gorsel["yukseklik"] as? Double
            kayitEni = en.flatMap { en in boy.flatMap { anlamsalGorselBoyutuGecerliMi(en: en, boy: $0) ? en : nil } } ?? dogal
            widget = gtk_overlay_new()!
            let picture = gtk_picture_new_for_paintable(texture)!
            gtk_picture_set_keep_aspect_ratio(OpaquePointer(picture), 1)
            gtk_picture_set_can_shrink(OpaquePointer(picture), 1)
            gtk_picture_set_alternative_text(OpaquePointer(picture), gorsel["yol"] as? String ?? "Görsel")
            gtk_overlay_set_child(OpaquePointer(widget), gtk_box_new(GTK_ORIENTATION_VERTICAL, 0))
            // Picture doğal piksel boyutuyla anchor ölçüsünü büyütmesin.
            gtk_overlay_add_overlay(OpaquePointer(widget), picture)
            gtk_overlay_add_overlay(OpaquePointer(widget), cizim)
            gtk_widget_set_can_target(cizim, 0)
            gtk_widget_set_hexpand(cizim, 1); gtk_widget_set_vexpand(cizim, 1)
            g_object_unref(UnsafeMutableRawPointer(texture))
        } else {
            oran = 1; kayitEni = 200
            widget = gtk_label_new("▧ \(gorsel["yol"] as? String ?? "Görsel") (okunamadı)")!
            gtk_label_set_wrap(nd_label(widget), 1)
            gtk_widget_set_tooltip_text(widget, "Dosya eksik veya bozuk. Görsel yolu ve kayıt boyutu korunuyor.")
        }
        g_object_ref_sink(UnsafeMutableRawPointer(widget))
        gtk_text_view_add_child_at_anchor(gorunum(editor), widget, anchor)
        if texture != nil { tutamaclariKur() }
    }

    deinit {
        g_object_unref(UnsafeMutableRawPointer(cizim))
        g_object_unref(UnsafeMutableRawPointer(anchor))
        g_object_unref(UnsafeMutableRawPointer(widget))
    }

    private func tutamaclariKur() {
        let veri = Unmanaged.passRetained(GorselSinyali { [weak self] (cr: OpaquePointer, en: Int32, boy: Int32) -> Void in
            self?.ciz(cr, en: Double(en), boy: Double(boy))
        }).toOpaque()
        gtk_drawing_area_set_draw_func(UnsafeMutableRawPointer(cizim).assumingMemoryBound(to: GtkDrawingArea.self), gorselCizC, veri, { veri in
            if let veri { Unmanaged<AnyObject>.fromOpaque(veri).release() }
        })
        let hareket = gtk_event_controller_motion_new()!
        gorselBagla(UnsafeMutableRawPointer(hareket), "motion", unsafeBitCast(gorselHareketC, to: GCallback.self)) {
            [weak self] (x: Double, y: Double) -> Void in
            guard let self else { return }
            self.uzerinde = true
            gtk_widget_set_cursor_from_name(self.widget, self.tutamacYonu(x, y) == nil ? "default" : "ew-resize")
            gtk_widget_queue_draw(self.cizim)
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(hareket), "leave") { [weak self] in
            guard let self else { return }
            self.uzerinde = false; gtk_widget_queue_draw(self.cizim)
        }
        gtk_widget_add_controller(widget, hareket)
        let surukle = gtk_gesture_drag_new()!
        gtk_gesture_single_set_button(surukle, 1)
        gtk_event_controller_set_propagation_phase(surukle, GTK_PHASE_CAPTURE)
        for (ad, eylem) in [
            ("drag-begin", { [weak self] (x: Double, y: Double) -> Void in self?.basla(surukle, x: x, y: y) }),
            ("drag-update", { [weak self] (x: Double, y: Double) -> Void in self?.surukle(x) }),
            ("drag-end", { [weak self] (x: Double, y: Double) -> Void in self?.bitir(x) })
        ] {
            gorselBagla(UnsafeMutableRawPointer(surukle), ad, unsafeBitCast(gorselHareketC, to: GCallback.self), eylem)
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(surukle), "cancel") { [weak self] (_: gpointer?) in
            self?.surukleme = nil; self?.onizlemeEni = nil; self?.genisligiGuncelle()
        }
        gtk_widget_add_controller(widget, surukle)
    }

    private func tutamaclar(_ en: Double, _ boy: Double) -> [(Double, Double, Double, Double)] {
        let kare = min(8, en, boy), cubuk = min(24, boy), ince = min(4, en)
        return [(0, 0, kare, kare), (0, boy - kare, kare, kare),
                (en - kare, 0, kare, kare), (en - kare, boy - kare, kare, kare),
                (0, (boy - cubuk) / 2, ince, cubuk), (en - ince, (boy - cubuk) / 2, ince, cubuk)]
    }

    private func tutamacYonu(_ x: Double, _ y: Double) -> Double? {
        let en = Double(gtk_widget_get_width(widget)), boy = Double(gtk_widget_get_height(widget))
        guard x >= 0, x <= en, y >= 0, y <= boy,
              tutamaclar(en, boy).contains(where: { bx, by, w, h in
                  x >= bx - 3 && x <= bx + w + 3 && y >= by - 3 && y <= by + h + 3
              }) else { return nil }
        return x < en / 2 ? -1 : 1
    }

    private func ciz(_ cr: OpaquePointer, en: Double, boy: Double) {
        guard uzerinde || surukleme != nil else { return }
        cairo_set_source_rgba(cr, 0.16, 0.44, 0.86, 0.8)
        cairo_set_line_width(cr, 1)
        cairo_rectangle(cr, 0.5, 0.5, max(0, en - 1), max(0, boy - 1)); cairo_stroke(cr)
        for (x, y, w, h) in tutamaclar(en, boy) {
            cairo_rectangle(cr, x + 0.5, y + 0.5, max(0, w - 1), max(0, h - 1))
            cairo_set_source_rgba(cr, 1, 1, 1, 0.95); cairo_fill_preserve(cr)
            cairo_set_source_rgba(cr, 0.16, 0.44, 0.86, 0.8); cairo_stroke(cr)
        }
    }

    private func basla(_ hareket: OpaquePointer, x: Double, y: Double) {
        guard let editor, gtk_text_view_get_editable(gorunum(editor)) != 0,
              gtk_text_child_anchor_get_deleted(anchor) == 0, let yon = tutamacYonu(x, y) else {
            gtk_gesture_set_state(hareket, GTK_EVENT_SEQUENCE_DENIED); return
        }
        surukleme = (yon, Double(gtk_widget_get_width(widget)))
        gtk_gesture_set_state(hareket, GTK_EVENT_SEQUENCE_CLAIMED)
        gtk_widget_grab_focus(editor.metinGorunumu)
    }

    private func surukle(_ fark: Double) {
        guard let surukleme else { return }
        let enFazla = min(maksimumEn(), 10_000, 10_000 * oran).rounded(.down)
        let enAz = min(enFazla, max(48, oran.rounded(.up)))
        guard enFazla >= max(1, oran) else { return }
        onizlemeEni = fark == 0 ? nil : min(enFazla, max(enAz, surukleme.en + fark * surukleme.yon)).rounded()
        genisligiGuncelle()
    }

    private func bitir(_ fark: Double) {
        guard surukleme != nil else { return }
        surukle(fark)
        let en = onizlemeEni
        surukleme = nil; onizlemeEni = nil
        guard let en, en != kayitEni, let editor, gtk_text_child_anchor_get_deleted(anchor) == 0,
              gtk_text_view_get_editable(gorunum(editor)) != 0 else { genisligiGuncelle(); return }
        var iter = GtkTextIter()
        gtk_text_buffer_get_iter_at_child_anchor(editor.tampon, &iter, anchor)
        let konum = LinuxMetinDonusumu.konum(iter)
        let yeni = editor.belgeyiOku { belge -> NSMutableAttributedString? in
            guard konum < belge.length, belge.attribute(kGorselAnahtari, at: konum, effectiveRange: nil) != nil else { return nil }
            return NSMutableAttributedString(attributedString: belge.attributedSubstring(from: NSRange(location: konum, length: 1)))
        }
        guard let yeni else { return }
        var anlamsal = gorsel
        anlamsal["genislik"] = en; anlamsal["yukseklik"] = max(1, (en / oran).rounded())
        yeni.addAttribute(kGorselAnahtari, value: anlamsal, range: NSRange(location: 0, length: 1))
        editor.aralikDegistir(NSRange(location: konum, length: 1), ile: yeni)
    }

    private func maksimumEn() -> Double {
        guard let editor else { return 1 }
        return max(1, Double(gtk_widget_get_width(editor.metinGorunumu)
            - gtk_text_view_get_left_margin(gorunum(editor)) - gtk_text_view_get_right_margin(gorunum(editor))))
    }

    func genisligiGuncelle() {
        guard gtk_text_child_anchor_get_deleted(anchor) == 0 else { return }
        let en = max(1, min(onizlemeEni ?? kayitEni, maksimumEn(), 10_000, 10_000 * oran).rounded(.down))
        gtk_widget_set_size_request(widget, Int32(en), gorselVar ? Int32(max(1, (en / oran).rounded())) : -1)
        gtk_widget_queue_draw(cizim)
    }
}
