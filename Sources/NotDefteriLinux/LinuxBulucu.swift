import CGtk
import Foundation
import NotDefteriCekirdek

private final class BulucuEylemi<Eylem> {
    let calistir: Eylem
    init(_ calistir: Eylem) { self.calistir = calistir }
}

private func bulucuSinyali<Eylem>(_ nesne: gpointer, _ ad: String, _ callback: GCallback, _ eylem: Eylem) {
    let veri = Unmanaged.passRetained(BulucuEylemi(eylem)).toOpaque()
    g_signal_connect_data(nesne, ad, callback, veri, { veri, _ in
        if let veri { Unmanaged<AnyObject>.fromOpaque(veri).release() }
    }, GConnectFlags(rawValue: 0))
}

private let bulucuTusuC: @convention(c) (gpointer?, guint, guint, GdkModifierType, gpointer?) -> gboolean = {
    _, tus, _, durum, veri in
    guard let veri else { return 0 }
    return Unmanaged<BulucuEylemi<(UInt32, UInt32) -> Bool>>.fromOpaque(veri)
        .takeUnretainedValue().calistir(tus, durum.rawValue) ? 1 : 0
}

private let bulucuTiklamasiC: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = {
    jest, adet, x, y, veri in
    guard let veri, adet == 1 else { return }
    if Unmanaged<BulucuEylemi<(Double, Double) -> Bool>>.fromOpaque(veri)
        .takeUnretainedValue().calistir(x, y), let jest {
        gtk_gesture_set_state(jest, GTK_EVENT_SEQUENCE_CLAIMED)
    }
}

private let bulucuYanitiC: @convention(c) (gpointer?, Int32, gpointer?) -> Void = { _, yanit, veri in
    guard let veri else { return }
    Unmanaged<BulucuEylemi<(Int32) -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir(yanit)
}

private let bagEklenecekC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextIter>?, UnsafePointer<CChar>?, Int32, gpointer?) -> Void = {
    _, iter, _, _, veri in
    guard let iter, let veri else { return }
    Unmanaged<BulucuEylemi<(GtkTextIter, GtkTextIter) -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir(iter.pointee, iter.pointee)
}

private let bagSilinecekC: @convention(c) (gpointer?, UnsafeMutablePointer<GtkTextIter>?, UnsafeMutablePointer<GtkTextIter>?, gpointer?) -> Void = {
    _, bas, son, veri in
    guard let bas, let son, let veri else { return }
    Unmanaged<BulucuEylemi<(GtkTextIter, GtkTextIter) -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir(bas.pointee, son.pointee)
}

enum LinuxBulucu {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let bulucu = SayfaBulucusu(pencere: pencere, editor: editor, baglantilar: panel.sayfaBaglantilari)
        // Editör kancaları bileşeni yaşatır; bileşenin editör/pencere bağı zayıftır.
        editor.tusOncesi.append { bulucu.tus($0, $1) }
        editor.degisiklikSonrasi.append { bulucu.degisti() }
        LinuxEklentiler.yasamDongusunuIzle(editor) { bulucu.durumDegisti() }
        panel.veriDegisti.append { [weak bulucu] in bulucu?.veriDegisti() }
        pencere.menuEkle(["Not", "Hızlı Sayfa Bulucu"], kisayol: "<Control>p") { [weak bulucu] in bulucu?.merkezdeAc() }
    }
}

/// Ctrl+P ve [[ tamamlaması aynı çekirdek indeksi ve sonuç listesini kullanır.
private final class SayfaBulucusu {
    private weak var pencere: LinuxPencere?
    private weak var editor: LinuxEditor?
    private let baglantilar: SayfaBaglantilari
    private let panel = gtk_popover_new()!
    private let arama = gtk_search_entry_new()!
    private let liste = gtk_list_box_new()!
    private let kaydirma = gtk_scrolled_window_new()!
    private var popover: UnsafeMutablePointer<GtkPopover> { GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(panel)) }
    private var listeKutusu: OpaquePointer { OpaquePointer(liste) }
    private var sonuclar: [SayfaSecenegi] = []
    private var secili = 0
    private var satirIci = false
    private var acik = false
    private var aralik: NSRange?
    private var tamamlamaURL: URL?
    private var kapatilanBagKonumu: Int?
    private var oncekiOdak: UnsafeMutablePointer<GtkWidget>?
    private var aramaIptal: ZamanlayiciIptal?
    private var bekleyenSorgu: String?
    private var sonSorgu: String?
    private var imlecBekliyor = false
    private var kapandi = false
    private var diyalog: UnsafeMutablePointer<GtkWidget>?
    private let bagEtiketi: UnsafeMutablePointer<GtkTextTag>
    private let solukBagEtiketi: UnsafeMutablePointer<GtkTextTag>
    private var boyaIptal: ZamanlayiciIptal?
    private var boyaNesli = 0
    private var degisenBas: UnsafeMutablePointer<GtkTextMark>?
    private var degisenSon: UnsafeMutablePointer<GtkTextMark>?
    private var indeksNesli = 0
    private var sayfaOnbellegi: [URL: SayfaSecenegi] = [:]

    init(pencere: LinuxPencere, editor: LinuxEditor, baglantilar: SayfaBaglantilari) {
        self.pencere = pencere
        self.editor = editor
        self.baglantilar = baglantilar
        bagEtiketi = Self.bagEtiketi(editor.tampon, ad: "nd-sayfa-bagi", renk: "#2a6fdb")
        solukBagEtiketi = Self.bagEtiketi(editor.tampon, ad: "nd-olmayan-sayfa-bagi", renk: "rgba(42,111,219,0.35)")
        g_object_ref_sink(UnsafeMutableRawPointer(panel)) // Gizlenince parent'tan ayrı da yaşar.
        arayuzuKur()
        sinyalleriKur(pencere, editor)
        indeksiYenile()
        baglariBoya()
    }

    deinit {
        aramaIptal?()
        boyaIptal?()
        if let oncekiOdak { g_object_unref(UnsafeMutableRawPointer(oncekiOdak)) }
        g_object_unref(UnsafeMutableRawPointer(panel))
    }

    private func arayuzuKur() {
        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8)!
        for yon in [gtk_widget_set_margin_top, gtk_widget_set_margin_bottom,
                    gtk_widget_set_margin_start, gtk_widget_set_margin_end] { yon(kutu, 8) }
        gtk_widget_set_tooltip_text(arama, "Hızlı sayfa bulucu (Ctrl+P)")
        gNesneOzelligi(UnsafeMutableRawPointer(arama), "placeholder-text", .metin("Sayfa bul…"))
        gtk_box_append(nd_box(kutu), arama)
        gtk_list_box_set_selection_mode(listeKutusu, GTK_SELECTION_SINGLE)
        gtk_list_box_set_activate_on_single_click(listeKutusu, 1)
        gtk_widget_set_focusable(liste, 0)
        let bos = gtk_label_new("Sonuç yok")!
        gtk_widget_set_margin_top(bos, 12)
        gtk_widget_set_margin_bottom(bos, 12)
        gtk_list_box_set_placeholder(listeKutusu, bos)
        gtk_scrolled_window_set_policy(OpaquePointer(kaydirma), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(OpaquePointer(kaydirma), liste)
        gtk_box_append(nd_box(kutu), kaydirma)
        gtk_popover_set_child(popover, kutu)
        gtk_popover_set_has_arrow(popover, 0)
        gtk_popover_set_position(popover, GTK_POS_BOTTOM)
    }

    private func sinyalleriKur(_ pencere: LinuxPencere, _ editor: LinuxEditor) {
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(arama), "changed") { [weak self] in
            guard let self, self.acik, !self.satirIci else { return }
            self.filtrelemeyiPlanla(self.aramaMetni)
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(liste), "row-activated") { [weak self] (satir: gpointer?) in
            guard let self, let satir else { return }
            self.sec(Int(gtk_list_box_row_get_index(GtkKoprusu.gtkIsaretci(satir))))
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(panel), "closed") { [weak self] in
            guard let self, self.acik else { return }
            self.kapatilanBagKonumu = self.aralik?.location
            self.gizle()
        }
        let tuslar = gtk_event_controller_key_new()!
        gtk_event_controller_set_propagation_phase(tuslar, GTK_PHASE_CAPTURE)
        bulucuSinyali(UnsafeMutableRawPointer(tuslar), "key-pressed", unsafeBitCast(bulucuTusuC, to: GCallback.self),
                     { [weak self] (tus: UInt32, durum: UInt32) in self?.tus(tus, durum) ?? false })
        gtk_widget_add_controller(panel, tuslar)
        let tik = gtk_gesture_click_new()!
        gtk_gesture_single_set_button(tik, 1)
        gtk_event_controller_set_propagation_phase(tik, GTK_PHASE_CAPTURE)
        bulucuSinyali(UnsafeMutableRawPointer(tik), "pressed", unsafeBitCast(bulucuTiklamasiC, to: GCallback.self),
                     { [weak self] (x: Double, y: Double) in self?.bagTiklandi(x, y) ?? false })
        gtk_widget_add_controller(editor.metinGorunumu, tik)
        for ad in ["notify::cursor-position", "notify::has-selection"] {
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(editor.tampon), ad) { [weak self] (_: gpointer?) in self?.imleciPlanla() }
        }
        let odak = gtk_event_controller_focus_new()!
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(odak), "leave") { [weak self] in
            if self?.satirIci == true { self?.gizle() }
        }
        gtk_widget_add_controller(editor.metinGorunumu, odak)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(pencere.pencere), "destroy") { [weak self] in
            self?.kapat()
        }
        for (ad, callback) in [("insert-text", unsafeBitCast(bagEklenecekC, to: GCallback.self)),
                               ("delete-range", unsafeBitCast(bagSilinecekC, to: GCallback.self))] {
            bulucuSinyali(UnsafeMutableRawPointer(editor.tampon), ad, callback,
                         { [weak self] (bas: GtkTextIter, son: GtkTextIter) -> Void in self?.degisenParagraflariIsaretle(bas, son) })
        }
        // Adjustment değişimleri kaydırmayı ve boyut dağıtımını birlikte kapsar.
        for ayar in [gtk_scrollable_get_hadjustment(OpaquePointer(editor.metinGorunumu)),
                     gtk_scrollable_get_vadjustment(OpaquePointer(editor.metinGorunumu))].compactMap({ $0 }) {
            for ad in ["changed", "value-changed"] {
                GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(ayar), ad) { [weak self] in self?.imleciPlanla() }
            }
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(pencere.pencere), "notify::is-active") { [weak self, weak pencere] (_: gpointer?) in
            guard let pencere else { return }
            if gtk_window_is_active(nd_window(pencere.pencere)) == 0, self?.satirIci == true { self?.gizle() }
        }
    }

    private var aramaMetni: String {
        gtk_editable_get_text(OpaquePointer(arama)).map { String(cString: $0) } ?? ""
    }

    private func indeksiYenile(sonra: (() -> Void)? = nil) {
        indeksNesli += 1
        let nesil = indeksNesli, eski = sayfaOnbellegi
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            func secenekler(_ dugumler: [AgacDugumu]) -> [SayfaSecenegi] {
                dugumler.flatMap { ($0.icerikURL.map { [eski[$0] ?? SayfaSecenegi(url: $0)] } ?? []) + secenekler($0.cocuklar) }
            }
            let sayfalar = secenekler(agaciYukle())
            let onbellek = Dictionary(sayfalar.map { ($0.url, $0) }, uniquingKeysWith: { ilk, _ in ilk })
            Platform.anaIsParcaciginda { [weak self] in
                guard let self, !self.kapandi, self.indeksNesli == nesil else { return }
                defer { sonra?() }
                guard self.baglantilar.sayfalar != sayfalar else { return }
                self.sayfaOnbellegi = onbellek
                self.baglantilar.guncelle(sayfalar)
                self.baglantilar.olmayanSonAcilanlariDusur()
                self.baglariBoya()
                if self.acik { self.filtrele(self.bekleyenSorgu ?? self.sonSorgu ?? "") }
            }
        }
    }

    func merkezdeAc(sorgu: String = "") {
        guard !kapandi, diyalog == nil, let pencere else { return }
        gizle()
        indeksiYenile()
        satirIci = false
        if let odak = gtk_window_get_focus(nd_window(pencere.pencere)) {
            g_object_ref(UnsafeMutableRawPointer(odak))
            oncekiOdak = odak
        }
        gtk_widget_set_visible(arama, 1)
        gtk_popover_set_autohide(popover, 1)
        gtk_editable_set_text(OpaquePointer(arama), sorgu)
        paneliBagla()
        filtrele(sorgu)
        gtk_popover_popup(popover)
        gtk_widget_grab_focus(arama)
    }

    private func paneliBagla() {
        guard let pencere else { return }
        // Arama alanının tuşları editörün capture controller'ından geçmemeli.
        // Konum/dağıtım aşağıda present ile, kapanışta sahiplik unparent ile yönetilir.
        if gtk_widget_get_parent(panel) == nil { gtk_widget_set_parent(panel, pencere.pencere) }
        acik = true
    }

    private func filtrelemeyiPlanla(_ sorgu: String) {
        guard sorgu != bekleyenSorgu, sorgu != sonSorgu || bekleyenSorgu != nil else { return }
        aramaIptal?()
        bekleyenSorgu = sorgu
        aramaIptal = Platform.zamanlayici(0.15) { [weak self] in self?.bekleyeniUygula() }
    }

    private func bekleyeniUygula() {
        guard acik, let sorgu = bekleyenSorgu else { return }
        aramaIptal?()
        aramaIptal = nil
        bekleyenSorgu = nil
        filtrele(sorgu)
    }

    private func filtrele(_ sorgu: String) {
        sonSorgu = sorgu
        sonuclar = baglantilar.ara(sorgu)
        secili = 0
        while let cocuk = gtk_widget_get_first_child(liste) { gtk_list_box_remove(listeKutusu, cocuk) }
        for sayfa in sonuclar {
            let satir = gtk_list_box_row_new()!
            // Emoji (📄) yerine simge temasından simge: emoji yazı tipi olmayan sistemlerde kutu görünüyordu.
            let metin = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
            let simge = gtk_image_new_from_icon_name("text-x-generic-symbolic")!
            gtk_widget_set_valign(simge, GTK_ALIGN_START)
            let yazi = gtk_label_new("\(sayfa.ad)\n\(sayfa.ustYol.isEmpty ? "Ana sayfalar" : sayfa.ustYol)")!
            gtk_label_set_xalign(nd_label(yazi), 0)
            gtk_label_set_ellipsize(nd_label(yazi), PANGO_ELLIPSIZE_END)
            gtk_box_append(nd_box(metin), simge)
            gtk_box_append(nd_box(metin), yazi)
            gtk_widget_set_margin_start(metin, 8)
            gtk_widget_set_margin_end(metin, 8)
            gtk_widget_set_size_request(satir, -1, 44)
            gtk_widget_set_focusable(satir, 0)
            gtk_widget_set_tooltip_text(satir, sayfa.yol)
            gtk_list_box_row_set_child(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(satir)), metin)
            gtk_list_box_append(listeKutusu, satir)
        }
        let yukseklik = Int32(min(max(1, sonuclar.count) * 44, satirIci ? 220 : 308))
        gtk_widget_set_size_request(kaydirma, satirIci ? 284 : 404, yukseklik)
        gtk_list_box_select_row(listeKutusu, gtk_list_box_get_row_at_index(listeKutusu, 0))
        gtk_adjustment_set_value(gtk_scrolled_window_get_vadjustment(OpaquePointer(kaydirma)), 0)
        konumlandir()
    }

    private func konumlandir() {
        guard acik, let editor, let pencere, !editor.yokEdildi else { return }
        // Parent pencere: pointing_to pencere koordinatındadır; TextView overlay'i değildir.
        var kare = satirIci ? editor.imlecKaresi() : GdkRectangle(
            x: gtk_widget_get_width(pencere.pencere) / 2,
            y: gtk_widget_get_height(pencere.pencere) / 2, width: 1, height: 1)
        if satirIci {
            var nokta = graphene_point_t(x: Float(kare.x), y: Float(kare.y)), hedef = graphene_point_t()
            guard gtk_widget_compute_point(pencere.pencere, editor.metinGorunumu, &nokta, &hedef) != 0 else { return }
            if hedef.y < 0 || hedef.y >= Float(gtk_widget_get_height(editor.metinGorunumu)) { gizle(); return }
        }
        var boy: Int32 = 0
        gtk_widget_measure(panel, GTK_ORIENTATION_VERTICAL, -1, nil, &boy, nil, nil)
        gtk_popover_set_offset(popover, 0, satirIci ? 0 : -boy / 2)
        gtk_popover_set_pointing_to(popover, &kare)
        gtk_popover_present(popover)
    }

    func tus(_ tus: UInt32, _ durum: UInt32) -> Bool {
        guard !kapandi, durum & (GDK_CONTROL_MASK.rawValue | GDK_ALT_MASK.rawValue | GDK_SUPER_MASK.rawValue) == 0 else { return false }
        if tus == 0x5d, (!acik || satirIci), elleYazilanBagiBitir() { return true }
        guard acik else { return false }
        if satirIci {
            tamamlamayiGuncelle()
            guard acik else { return false }
        }
        switch tus {
        case 0xff52, 0xff54: // Up / Down
            bekleyeniUygula()
            guard !sonuclar.isEmpty else { return true }
            secili = (secili + (tus == 0xff52 ? -1 : 1) + sonuclar.count) % sonuclar.count
            gtk_list_box_select_row(listeKutusu, gtk_list_box_get_row_at_index(listeKutusu, Int32(secili)))
            secimiGoster()
        case 0xff0d, 0xff8d:
            bekleyeniUygula()
            guard !satirIci || !sonuclar.isEmpty else { gizle(); return false }
            sec(secili)
        case 0xff1b:
            kapatilanBagKonumu = aralik?.location
            gizle()
        default: return false
        }
        return true
    }

    private func secimiGoster() {
        // GTK 4.6'da scroll_to yok; seçilen satırı mevcut adjustment ile görünür tut.
        guard let satir = gtk_list_box_get_row_at_index(listeKutusu, Int32(secili)) else { return }
        var kare = GtkAllocation()
        gtk_widget_get_allocation(UnsafeMutableRawPointer(satir).assumingMemoryBound(to: GtkWidget.self), &kare)
        let ayar = gtk_scrolled_window_get_vadjustment(OpaquePointer(kaydirma))!
        let bas = gtk_adjustment_get_value(ayar), boy = gtk_adjustment_get_page_size(ayar)
        if Double(kare.y) < bas { gtk_adjustment_set_value(ayar, Double(kare.y)) }
        else if Double(kare.y + kare.height) > bas + boy { gtk_adjustment_set_value(ayar, Double(kare.y + kare.height) - boy) }
    }

    private func sec(_ sira: Int) {
        guard acik, sonuclar.indices.contains(sira), let editor else { return }
        let sayfa = sonuclar[sira]
        let tamamlama = satirIci ? tamamlamaKapsami() : nil
        let tamamlaniyor = satirIci
        let kaynakURL = tamamlamaURL
        gizle()
        if tamamlaniyor {
            guard let (kapsam, _) = tamamlama, kaynakURL == editor.acikURL else { return }
            let yeni = editor.belgeyiOku { self.tamamlamaMetni(sayfa, belge: $0, kapsam: kapsam) }
            kapatilanBagKonumu = yeni.0.location
            editor.aralikDegistir(yeni.0, ile: yeni.1)
            gtk_widget_grab_focus(editor.metinGorunumu)
        } else {
            editor.notuAc(sayfa.url)
            gtk_widget_grab_focus(editor.metinGorunumu)
        }
    }

    private func tamamlamaMetni(_ sayfa: SayfaSecenegi, belge: NSAttributedString, kapsam: NSRange) -> (NSRange, NSAttributedString) {
        var kapsam = kapsam
        let ns = belge.string as NSString
        if NSMaxRange(kapsam) + 2 <= ns.length,
           ns.substring(with: NSRange(location: NSMaxRange(kapsam), length: 2)) == "]]" { kapsam.length += 2 }
        let hedef = baglantilar.bagMetni(sayfa.url)
        var oznitelikler = belge.attributes(at: kapsam.location, effectiveRange: nil)
        for anahtar in [kKacisliKoseParantezAnahtari, kBaglantiAnahtari, kCiplakBagAnahtari,
                        kBlokIsaretiAnahtari, kGorselAnahtari] { oznitelikler.removeValue(forKey: anahtar) }
        oznitelikler[kSayfaBagiAnahtari] = hedef
        return (kapsam, NSAttributedString(string: "[[\(hedef)]]", attributes: oznitelikler))
    }

    private func elleYazilanBagiBitir() -> Bool {
        guard let editor, let (kapsam, sorgu) = tamamlamaKapsami(kapanis: true), sorgu.hasSuffix("]"),
              let bag = sayfaBaglariniBul("[[" + sorgu + "]").first else { return false }
        // Son ] ve bağlantı özniteliği aynı undo adımıdır; kayıt [[...]]'yi kaçırmaz.
        let yeni = editor.belgeyiOku { belge in
            let yeni = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: kapsam))
            yeni.append(NSAttributedString(string: "]", attributes: belge.attributes(at: NSMaxRange(kapsam) - 1, effectiveRange: nil)))
            return yeni
        }
        yeni.addAttribute(kSayfaBagiAnahtari, value: bag.hedef, range: NSRange(location: 0, length: yeni.length))
        gizle()
        kapatilanBagKonumu = kapsam.location
        editor.aralikDegistir(kapsam, ile: yeni)
        return true
    }

    private func tamamlamaKapsami(kapanis: Bool = false) -> (NSRange, String)? {
        guard let editor, gtk_text_buffer_get_has_selection(editor.tampon) == 0 else { return nil }
        var imlec = GtkTextIter()
        gtk_text_buffer_get_iter_at_mark(editor.tampon, &imlec, gtk_text_buffer_get_insert(editor.tampon))
        var satirBasi = imlec
        gtk_text_iter_set_line_offset(&satirBasi, 0)
        let ns = GtkKoprusu.dilim(editor.tampon, bas: satirBasi, son: imlec) as NSString
        let bas = ns.range(of: "[[", options: .backwards)
        guard bas.location != NSNotFound else { return nil }
        guard let pencere, gtk_window_is_active(nd_window(pencere.pencere)) != 0,
              editor.acikURL != nil, gtk_widget_has_focus(editor.metinGorunumu) != 0,
              gtk_text_view_get_editable(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(editor.metinGorunumu))) != 0,
              GtkKoprusu.aynalamaHatasi(editor.tampon) == nil else { return nil }
        var kacis = bas.location
        while kacis > 0, ns.character(at: kacis - 1) == 92 { kacis -= 1 }
        let sorgu = ns.substring(from: NSMaxRange(bas)), aday = "[[" + sorgu + "]"
        let kapanabilir = kapanis && sayfaBaglariniBul(aday).first?.aralik.length == (aday as NSString).length
        guard (bas.location - kacis) % 2 == 0, !sorgu.contains("["), !sorgu.contains("]") || kapanabilir else { return nil }
        let konum = GtkKoprusu.utf16(imlec)
        let kapsam = NSRange(location: konum - ns.length + bas.location, length: ns.length - bas.location)
        return editor.belgeyiOku { belge in
            guard konum <= belge.length,
                  !kapsamEngelli(belge, NSRange(location: kapsam.location, length: 2)) else { return nil }
            return (kapsam, sorgu)
        }
    }

    private func kapsamEngelli(_ belge: NSAttributedString, _ kapsam: NSRange) -> Bool {
        var engelli = false
        belge.enumerateAttributes(in: kapsam) { o, _, dur in
            if [kKodBloguAnahtari, kSatirIciKodAnahtari, kBaglantiAnahtari, kKacisliKoseParantezAnahtari].contains(where: { o[$0] != nil }) {
                engelli = true
                dur.pointee = true
            }
        }
        return engelli
    }

    private func imleciPlanla() {
        guard !kapandi, !imlecBekliyor else { return }
        imlecBekliyor = true
        Platform.anaIsParcaciginda { [weak self] in
            guard let self, !self.kapandi else { return }
            self.imlecBekliyor = false
            self.tamamlamayiGuncelle()
        }
    }

    private func tamamlamayiGuncelle() {
        guard !kapandi, diyalog == nil, !acik || satirIci else { konumlandir(); return }
        guard let (kapsam, sorgu) = tamamlamaKapsami() else {
            if satirIci { gizle() }
            kapatilanBagKonumu = nil
            return
        }
        guard kapsam.location != kapatilanBagKonumu else { return }
        kapatilanBagKonumu = nil
        let zatenAcik = acik
        if !zatenAcik { indeksiYenile() }
        satirIci = true
        aralik = kapsam
        tamamlamaURL = editor?.acikURL
        gtk_widget_set_visible(arama, 0)
        gtk_popover_set_autohide(popover, 0) // Odak editörde kalır; tuşlar 048 kancasından gelir.
        paneliBagla()
        if zatenAcik { filtrelemeyiPlanla(sorgu) } else { filtrele(sorgu) }
        konumlandir()
        if acik { gtk_popover_popup(popover) }
    }

    func degisti() {
        guard !kapandi else { return }
        if editor?.editorEtkin != true { gizle(odagiGeriVer: false); diyaloguKapat() }
        boyamayiPlanla()
        tamamlamayiGuncelle()
    }

    func durumDegisti() {
        gizle(odagiGeriVer: false)
        diyaloguKapat()
        kapatilanBagKonumu = nil
        boyamayiSifirla()
        indeksiYenile()
        baglariBoya()
    }

    func veriDegisti() {
        guard !kapandi else { return }
        indeksNesli += 1
        let yollarDegisti = Set(sayfaOnbellegi.keys) != Set(baglantilar.sayfalar.map(\.url))
        sayfaOnbellegi = Dictionary(baglantilar.sayfalar.map { ($0.url, $0) }, uniquingKeysWith: { ilk, _ in ilk })
        if yollarDegisti { baglariBoya() } else { boyamayiPlanla() }
        if acik { filtrele(bekleyenSorgu ?? sonSorgu ?? "") }
    }

    private func gizle(odagiGeriVer: Bool = true) {
        acik = false
        aramaIptal?()
        aramaIptal = nil
        bekleyenSorgu = nil
        sonSorgu = nil
        aralik = nil
        tamamlamaURL = nil
        // Önce durumu temizle: popdown/unparent closed sinyalini yeniden çağırabilir.
        if gtk_widget_get_parent(panel) != nil {
            gtk_popover_popdown(popover)
            gtk_widget_unparent(panel)
        }
        if let odak = oncekiOdak {
            oncekiOdak = nil
            defer { g_object_unref(UnsafeMutableRawPointer(odak)) }
            if odagiGeriVer, gtk_widget_get_root(odak) != nil { gtk_widget_grab_focus(odak) }
        }
    }

    private static func bagEtiketi(_ tampon: UnsafeMutablePointer<GtkTextBuffer>, ad: String, renk: String) -> UnsafeMutablePointer<GtkTextTag> {
        let etiket = gtk_text_tag_new(ad)!
        gNesneOzelligi(UnsafeMutableRawPointer(etiket), "foreground", .metin(renk))
        gNesneOzelligi(UnsafeMutableRawPointer(etiket), "underline", .sayim(pango_underline_get_type(), Int32(PANGO_UNDERLINE_SINGLE.rawValue)))
        gtk_text_tag_table_add(gtk_text_buffer_get_tag_table(tampon), etiket)
        g_object_unref(UnsafeMutableRawPointer(etiket))
        return etiket
    }

    private func baglar(_ belge: NSAttributedString) -> [SayfaBagi] {
        sayfaBaglariniBul(belge.string).filter { !kapsamEngelli(belge, $0.aralik) }
    }

    private func baglariBoya() {
        guard let editor else { return }
        boyamayiSifirla()
        var bas = GtkTextIter(), son = GtkTextIter()
        gtk_text_buffer_get_bounds(editor.tampon, &bas, &son)
        editor.belgeyiOku { belge in
            baglariBoya(belge, kapsam: NSRange(location: 0, length: belge.length), bas: bas, son: son)
        }
    }

    private func baglariBoya(_ belge: NSAttributedString, kapsam: NSRange, bas: GtkTextIter, son: GtkTextIter) {
        guard let editor, kapsam.length > 0 else { return }
        var bas = bas, son = son
        for etiket in [bagEtiketi, solukBagEtiketi] { gtk_text_buffer_remove_tag(editor.tampon, etiket, &bas, &son) }
        // Tüm belge boyanırken kopya alınmaz (büyük notta corelibs kopyası yüzlerce ms).
        let paragraf = kapsam == NSRange(location: 0, length: belge.length) ? belge : belge.attributedSubstring(from: kapsam)
        let ns = paragraf.string as NSString
        // Bağlar sıralı gelir; iter bir öncekinden ilerletilir. Her bağ için kapsam başından
        // saymak 2000 bağlı notta açılışı 1,6 sn donduruyordu (karesel).
        var iter = bas, konum = 0
        for bag in baglar(paragraf) where bag.aralik.location >= konum {
            gtk_text_iter_forward_chars(&iter, Int32(LinuxMetinDonusumu.karakterSayisi(
                ns, NSRange(location: konum, length: bag.aralik.location - konum))))
            var sonu = iter
            gtk_text_iter_forward_chars(&sonu, Int32(LinuxMetinDonusumu.karakterSayisi(ns, bag.aralik)))
            let etiket = baglantilar.coz(bag.hedef) == nil ? solukBagEtiketi : bagEtiketi
            gtk_text_buffer_apply_tag(editor.tampon, etiket, &iter, &sonu)
            iter = sonu
            konum = NSMaxRange(bag.aralik)
        }
    }

    /// Iter saklanmaz; yerçekimleri ekleme/silme sırasında kirli kapsamı korur.
    private func degisenParagraflariIsaretle(_ ilk: GtkTextIter, _ son: GtkTextIter) {
        guard !kapandi, let editor else { return }
        var bas = ilk, bitis = son
        gtk_text_iter_set_line_offset(&bas, 0)
        if gtk_text_iter_ends_line(&bitis) == 0 { gtk_text_iter_forward_to_line_end(&bitis) }
        if let degisenBas, let degisenSon {
            var eskiBas = GtkTextIter(), eskiSon = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &eskiBas, degisenBas)
            gtk_text_buffer_get_iter_at_mark(editor.tampon, &eskiSon, degisenSon)
            if gtk_text_iter_compare(&bas, &eskiBas) < 0 { gtk_text_buffer_move_mark(editor.tampon, degisenBas, &bas) }
            if gtk_text_iter_compare(&bitis, &eskiSon) > 0 { gtk_text_buffer_move_mark(editor.tampon, degisenSon, &bitis) }
        } else {
            degisenBas = gtk_text_buffer_create_mark(editor.tampon, nil, &bas, 1)
            degisenSon = gtk_text_buffer_create_mark(editor.tampon, nil, &bitis, 0)
        }
        // Ana döngüdeki gecikmiş changed kancası gelmeden eski boya işi geçersizdir.
        boyaNesli += 1
        boyaIptal?()
        boyaIptal = nil
    }

    private func boyamayiPlanla() {
        boyaNesli += 1
        boyaIptal?()
        guard degisenBas != nil, editor?.acikURL != nil else { return }
        let nesil = boyaNesli, url = editor?.acikURL
        boyaIptal = Platform.zamanlayici(0.15) { [weak self] in
            guard let self, !self.kapandi, self.boyaNesli == nesil, self.editor?.acikURL == url else { return }
            self.degisenBaglariBoya()
        }
    }

    private func degisenBaglariBoya() {
        guard let editor, let degisenBas, let degisenSon else { return }
        var bas = GtkTextIter(), son = GtkTextIter()
        gtk_text_buffer_get_iter_at_mark(editor.tampon, &bas, degisenBas)
        gtk_text_buffer_get_iter_at_mark(editor.tampon, &son, degisenSon)
        gtk_text_iter_set_line_offset(&bas, 0)
        if gtk_text_iter_ends_line(&son) == 0 { gtk_text_iter_forward_to_line_end(&son) }
        gtk_text_iter_forward_char(&son) // Paragraf sonu öznitelikleri de boyanır.
        let konum = GtkKoprusu.utf16(bas)
        let kapsam = NSRange(location: konum, length: GtkKoprusu.utf16(son) - konum)
        editor.belgeyiOku { belge in
            guard NSMaxRange(kapsam) <= belge.length else { return }
            baglariBoya(belge, kapsam: kapsam, bas: bas, son: son)
        }
        boyamayiSifirla()
    }

    private func boyamayiSifirla() {
        boyaNesli += 1
        boyaIptal?()
        boyaIptal = nil
        if let editor {
            for isaret in [degisenBas, degisenSon].compactMap({ $0 }) { gtk_text_buffer_delete_mark(editor.tampon, isaret) }
        }
        degisenBas = nil
        degisenSon = nil
    }

    private func bagTiklandi(_ x: Double, _ y: Double) -> Bool {
        guard !kapandi, diyalog == nil, let editor, editor.acikURL != nil,
              GtkKoprusu.aynalamaHatasi(editor.tampon) == nil else { return false }
        let gorunum: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(editor.metinGorunumu))
        var bx: Int32 = 0, by: Int32 = 0, iter = GtkTextIter()
        gtk_text_view_window_to_buffer_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, Int32(x), Int32(y), &bx, &by)
        guard gtk_text_view_get_iter_at_position(gorunum, &iter, nil, bx, by) != 0 else { return false }
        let konum = LinuxMetinDonusumu.konum(iter)
        let bag = editor.belgeyiOku { belge -> SayfaBagi? in
            let kapsam = (belge.string as NSString).paragraphRange(for: NSRange(location: konum, length: 0))
            return baglar(belge.attributedSubstring(from: kapsam)).first { NSLocationInRange(konum - kapsam.location, $0.aralik) }
        }
        guard let bag else { return false }
        gizle()
        let url = editor.acikURL
        indeksiYenile { [weak self] in
            guard let self, self.editor?.acikURL == url else { return }
            self.bagAc(bag.hedef.trimmingCharacters(in: .whitespaces))
        }
        return true
    }

    private func bagAc(_ hedef: String) {
        if let url = baglantilar.coz(hedef) { editor?.notuAc(url); return }
        if baglantilar.belirsizMi(hedef) { merkezdeAc(sorgu: hedef); return }
        let yol = hedef.hasPrefix("./") ? String(hedef.dropFirst(2)) : hedef
        let parcalar = yol.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parcalar.allSatisfy(sayfaAdiGecerliMi) else {
            diyalogGoster("Bu bağlantının sayfa adı kullanılamaz", mesaj: hedef, onay: nil) { _ in }
            return
        }
        diyalogGoster("\"\(hedef)\" sayfası oluşturulsun mu?", mesaj: "Yeni sayfa notlar klasörüne eklenecek.", onay: "Oluştur") { [weak self] yanit in
            if yanit == 1 { self?.sayfaOlustur(parcalar) }
        }
    }

    private func sayfaOlustur(_ parcalar: [String], kaydiAtla: Bool = false) {
        guard let editor else { return }
        if !kaydiAtla {
            editor.islemOncesi { [weak self] in self?.sayfaOlustur(parcalar, kaydiAtla: true) }
            return
        }
        let kok = notlarKlasoru().resolvingSymlinksInPath().standardizedFileURL
        let klasor = parcalar.reduce(kok) { $0.appendingPathComponent($1, isDirectory: true) }
        let url = klasor.appendingPathComponent(kIcerikDosyaAdi)
        guard url.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(kok.path + "/") else {
            diyalogGoster("Sayfa oluşturulamadı", mesaj: "Bağlantı notlar klasörünün dışına çıkıyor.", onay: nil) { _ in }
            return
        }
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
                try "".write(to: url, atomically: true, encoding: .utf8)
            }
            (pencere?.kenarPaneli as? LinuxKenarPaneli)?.yenile()
            indeksiYenile()
            editor.notuAc(url)
            gtk_widget_grab_focus(editor.metinGorunumu)
        } catch {
            diyalogGoster("Sayfa oluşturulamadı", mesaj: error.localizedDescription, onay: nil) { _ in }
        }
    }

    private func diyalogGoster(_ baslik: String, mesaj: String, onay: String?, yanit: @escaping (Int32) -> Void) {
        guard diyalog == nil, let pencere else { return }
        let nesne = UnsafeMutableRawPointer(g_object_new_with_properties(gtk_message_dialog_get_type(), 0, nil, nil)!)
        gNesneOzelligi(nesne, "text", .metin(baslik))
        gNesneOzelligi(nesne, "secondary-text", .metin(mesaj))
        gNesneOzelligi(nesne, "message-type", .sayim(gtk_message_type_get_type(), Int32(GTK_MESSAGE_QUESTION.rawValue)))
        let widget = nesne.assumingMemoryBound(to: GtkWidget.self)
        let dialog = nesne.assumingMemoryBound(to: GtkDialog.self)
        gtk_window_set_transient_for(nd_window(widget), nd_window(pencere.pencere))
        gtk_window_set_destroy_with_parent(nd_window(widget), 1)
        gtk_window_set_modal(nd_window(widget), 1)
        gtk_dialog_add_button(dialog, onay == nil ? "Tamam" : "Vazgeç", 0)
        if let onay { gtk_dialog_add_button(dialog, onay, 1) }
        gtk_dialog_set_default_response(dialog, 0)
        diyalog = widget
        let kaynakURL = editor?.acikURL
        bulucuSinyali(nesne, "response", unsafeBitCast(bulucuYanitiC, to: GCallback.self), { [weak self] (secilen: Int32) -> Void in
            guard let self, self.diyalog == widget else { return }
            self.diyalog = nil
            // Callback'in destroy_data'sı yanıt işlenirken bırakılmasın.
            g_object_ref(nesne)
            Platform.anaIsParcaciginda {
                gtk_window_destroy(nd_window(widget))
                g_object_unref(nesne)
            }
            if !self.kapandi, self.editor?.acikURL == kaynakURL { yanit(secilen) }
        })
        gtk_window_present(nd_window(widget))
    }

    private func diyaloguKapat() {
        guard let widget = diyalog else { return }
        diyalog = nil
        gtk_window_destroy(nd_window(widget))
    }

    private func kapat() {
        kapandi = true
        indeksNesli += 1
        boyamayiSifirla()
        gizle(odagiGeriVer: false)
        diyaloguKapat()
    }
}
