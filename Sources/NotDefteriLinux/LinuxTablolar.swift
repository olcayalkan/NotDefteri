import CGtk
import Foundation
import NotDefteriCekirdek

private final class TabloTusHedefi {
    weak var hedef: LinuxTabloHucreEditoru?
    init(_ hedef: LinuxTabloHucreEditoru) { self.hedef = hedef }
}
private let tabloTusC: @convention(c) (gpointer?, guint, guint, GdkModifierType, gpointer?) -> gboolean = {
    _, tus, _, durum, veri in
    guard let veri else { return 0 }
    return Unmanaged<TabloTusHedefi>.fromOpaque(veri).takeUnretainedValue().hedef?.tusIsle(tus, durum: durum.rawValue) == true ? 1 : 0
}

/// Native editing owns selection, preedit and clipboard; every completed edit is mirrored immediately.
final class LinuxTabloHucreEditoru {
    let widget = gtk_entry_new()!
    var gezin: ((Int) -> Void)?
    var sonrakiSatir: (() -> Void)?
    var kapat: (() -> Void)?
    var geriAl: ((Bool) -> Void)?
    private var ayarlaniyor = false
    private let degisti: (String) -> Void

    init(metin: String, degisti: @escaping (String) -> Void) {
        self.degisti = degisti
        g_object_ref_sink(UnsafeMutableRawPointer(widget))
        metniAyarla(metin)
        gtk_widget_add_css_class(widget, "nd-tablo-hucresi")
        let stil = gtk_css_provider_new()!
        gtk_css_provider_load_from_data(stil, "entry.nd-tablo-hucresi { min-height: 0; min-width: 0; padding: 0 2px; font-family: monospace; font-size: \(Int(kTabanPunto))px; } entry.nd-tablo-hucresi text { min-height: 0; padding: 0; }", -1)
        gtk_style_context_add_provider(gtk_widget_get_style_context(widget), nd_style_provider(stil), guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
        g_object_unref(UnsafeMutableRawPointer(stil))
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(widget), "notify::text") { [weak self] (_: gpointer?) in
            guard let self, !self.ayarlaniyor else { return }
            self.degisti(String(cString: gtk_editable_get_text(OpaquePointer(self.widget))))
        }
        let tuslar = gtk_event_controller_key_new()!
        gtk_event_controller_set_propagation_phase(tuslar, GTK_PHASE_CAPTURE)
        let veri = Unmanaged.passRetained(TabloTusHedefi(self)).toOpaque()
        g_signal_connect_data(UnsafeMutableRawPointer(tuslar), "key-pressed", unsafeBitCast(tabloTusC, to: GCallback.self), veri,
                              { veri, _ in if let veri { Unmanaged<TabloTusHedefi>.fromOpaque(veri).release() } }, GConnectFlags(rawValue: 0))
        gtk_widget_add_controller(widget, tuslar)
    }
    deinit { g_object_unref(UnsafeMutableRawPointer(widget)) }
    func metniAyarla(_ metin: String) {
        ayarlaniyor = true
        gtk_editable_set_text(OpaquePointer(widget), metin)
        ayarlaniyor = false
    }
    func tusIsle(_ tus: UInt32, durum: UInt32) -> Bool {
        let shift = durum & GDK_SHIFT_MASK.rawValue != 0
        if durum & GDK_CONTROL_MASK.rawValue != 0 {
            if [0x7a, 0x5a, 0x79, 0x59].contains(tus) { geriAl?(shift || tus == 0x79 || tus == 0x59); return true }
            return false
        }
        switch tus {
        case 0xff09: gezin?(shift ? -1 : 1); return true
        case 0xfe20: gezin?(-1); return true
        case 0xff0d, 0xff8d: sonrakiSatir?(); return true
        case 0xff1b: kapat?(); return true
        default: return false
        }
    }
}

enum LinuxTablolar {
    static func kur(editor: LinuxEditor) {
        let yonetici = LinuxTabloYoneticisi(editor: editor)
        yonetici.kur()
    }
}

private final class LinuxTabloYoneticisi {
    private weak var editor: LinuxEditor?
    private var giris: LinuxTabloHucreEditoru?
    /// TextView overlay çocukları bu GTK sürümünde sökülüp yeniden eklenince
    /// bayat çizim kaydı bırakabiliyor. Tek giriş alanı yeniden konumlandırılır.
    private var girisOnbellek: LinuxTabloHucreEditoru?
    private var kimlik: String?
    private var satir = 0
    private var sutun = 0
    private var uygulaniyor = false
    private var kendiBelgesi: String?
    private var etkilesim: UInt = 0
    private var gorunum: UnsafeMutablePointer<GtkTextView>? {
        editor.map { UnsafeMutableRawPointer($0.metinGorunumu).assumingMemoryBound(to: GtkTextView.self) }
    }
    init(editor: LinuxEditor) { self.editor = editor }
    func kur() {
        guard let editor else { return }
        // The editor retains the manager through these callbacks; manager references editor weakly.
        editor.tiklamaOncesi.append { [self] x, y in tiklandi(x, y) }
        editor.metinEklemeOncesi.append { [self] konum, metin in ekle(konum, metin) }
        editor.metinSilmeOncesi.append { [self] aralik in sil(aralik) }
        editor.degisiklikSonrasi.append { [self] in if !uygulaniyor { yenile() } }
        editor.boyutDegisti.append { [self] in konumlandir() }
        editor.notKapanmadanOnce.append { [self] in kapat() }
        editor.notAcildi.append { [self] _, _ in kapat() }
    }
    private struct Tablo {
        let aralik: NSRange
        let kimlik: String
        var model: TabloModeli
    }
    private func tablolar() -> [Tablo] {
        guard let editor else { return [] }
        return editor.belgeyiOku { belge in
            var sonuc: [Tablo] = []
            belge.enumerateAttribute(kTabloGorselAnahtari, in: NSRange(location: 0, length: belge.length)) { deger, alt, _ in
                guard let id = deger as? String,
                      let model = TabloModeli(oznitelik: belge.attribute(kTabloModeliAnahtari, at: alt.location, effectiveRange: nil)),
                      (belge.string as NSString).substring(with: alt) == model.gorsel().metin else { return }
                sonuc.append(Tablo(aralik: alt, kimlik: id, model: model))
            }
            return sonuc
        }
    }
    private func etkin() -> Tablo? { tablolar().first { $0.kimlik == kimlik } }
    private func hucre(_ tablo: Tablo, konum: Int) -> (Int, Int)? {
        let yer = konum - tablo.aralik.location
        let ns = tablo.model.gorsel().metin as NSString
        guard yer >= 0, yer < ns.length else { return nil }
        let paragraf = ns.lineRange(for: NSRange(location: yer, length: 0))
        guard ns.substring(with: paragraf).hasPrefix("│") else { return nil }
        // Row ranges come from the model: literal │ in a cell is content, not a separator.
        for r in 0..<tablo.model.satirSayisi {
            for c in 0..<tablo.model.sutunSayisi {
                guard let alt = tablo.model.hucreAraligi(satir: r, sutun: c), NSLocationInRange(alt.location, paragraf) else { continue }
                let son = c + 1 < tablo.model.sutunSayisi
                    ? (tablo.model.hucreAraligi(satir: r, sutun: c + 1)?.location ?? NSMaxRange(paragraf)) - 2
                    : NSMaxRange(paragraf) - 2
                if yer >= alt.location - 1, yer < son { return (r, c) }
            }
        }
        return nil
    }
    private func tiklandi(_ x: Double, _ y: Double) -> Bool {
        guard let editor, let gorunum, editor.editorEtkin else { return false }
        var bx: Int32 = 0, by: Int32 = 0, iter = GtkTextIter()
        gtk_text_view_window_to_buffer_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, Int32(x), Int32(y), &bx, &by)
        gtk_text_view_get_iter_at_location(gorunum, &iter, bx, by)
        let konum = LinuxMetinDonusumu.konum(iter)
        guard let tablo = tablolar().first(where: { NSLocationInRange(konum, $0.aralik) }) else { kapat(); return false }
        guard let (r, c) = hucre(tablo, konum: konum) else { kapat(); return true }
        // TextView capture aşamasında olduğundan açık yerel girişe tıklama önce
        // buraya ulaşır. Aynı hücrede yeniden kurmak imleci sona taşır ve eski
        // overlay çocuğunu ebeveyninden koparır; olayı GtkEntry'ye bırak.
        guard giris == nil || tablo.kimlik != kimlik || r != satir || c != sutun else { return false }
        ac(tablo, satir: r, sutun: c, tumunuSec: false)
        return true
    }
    private func ac(_ tablo: Tablo, satir: Int, sutun: Int, tumunuSec: Bool) {
        guard let gorunum else { return }
        kapat()
        self.kimlik = tablo.kimlik; self.satir = satir; self.sutun = sutun
        let metin = tablo.model.hucre(satir: satir, sutun: sutun) ?? ""
        let giris: LinuxTabloHucreEditoru
        if let onbellek = girisOnbellek {
            giris = onbellek
            giris.metniAyarla(metin)
        } else {
            giris = LinuxTabloHucreEditoru(metin: metin) { [weak self] in self?.kaydet($0) }
            giris.gezin = { [weak self] in self?.gezin($0) }
            giris.sonrakiSatir = { [weak self] in
                guard let self, let tablo = self.etkin() else { return }
                let r = self.satir + 1
                if r < tablo.model.satirSayisi { self.ac(tablo, satir: r, sutun: self.sutun, tumunuSec: true) } else { self.kapat() }
            }
            giris.kapat = { [weak self] in self?.kapat(odakla: true) }
            giris.geriAl = { [weak self] ileri in
                guard let self else { return }
                let konum = self.giris.map { gtk_editable_get_position(OpaquePointer($0.widget)) } ?? 0
                self.editor?.geriAlIstendi(ileri: ileri)
                self.yenile()
                if let giris = self.giris {
                    gtk_widget_grab_focus(giris.widget)
                    gtk_editable_set_position(OpaquePointer(giris.widget), konum)
                }
            }
            girisOnbellek = giris
            gtk_text_view_add_overlay(gorunum, giris.widget, 0, 0)
        }
        self.giris = giris
        gtk_widget_set_visible(giris.widget, 1)
        konumlandir()
        gtk_widget_grab_focus(giris.widget)
        if tumunuSec { gtk_editable_select_region(OpaquePointer(giris.widget), 0, -1) }
        else { gtk_editable_set_position(OpaquePointer(giris.widget), -1) }
    }
    private func kaydet(_ metin: String, hedef: Tablo? = nil, hedefSatir: Int? = nil, hedefSutun: Int? = nil) {
        let satir = hedefSatir ?? self.satir, sutun = hedefSutun ?? self.sutun
        guard let editor, var tablo = hedef ?? etkin(), !uygulaniyor else { return }
        let oncekiMarkdown = tablo.model.markdown()
        guard tablo.model.hucreyiGuncelle(satir: satir, sutun: sutun, metin: metin) else { return }
        if tablo.model.markdown() == oncekiMarkdown {
            kendiBelgesi = editor.belge.string
            return
        }
        let yeni = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret(tablo.model.markdown(), taban: editor.acikURL.map(sayfaKlasoru) ?? notlarKlasoru()))
        let tumu = NSRange(location: 0, length: yeni.length)
        yeni.addAttribute(kTabloGorselAnahtari, value: tablo.kimlik, range: tumu)
        yeni.addAttribute(kTabloModeliAnahtari, value: tablo.model.oznitelikDegeri, range: tumu)
        let alt = tablo.model.hucreAraligi(satir: satir, sutun: sutun) ?? NSRange(location: 0, length: 0)
        uygulaniyor = true
        editor.aralikDegistir(tablo.aralik, ile: yeni, secim: NSRange(location: tablo.aralik.location + alt.location, length: 0))
        kendiBelgesi = editor.belge.string
        uygulaniyor = false
        konumlandir()
    }
    private func gezin(_ yon: Int) {
        guard let tablo = etkin() else { kapat(); return }
        let indeks = satir * tablo.model.sutunSayisi + sutun + yon
        guard indeks >= 0, indeks < tablo.model.satirSayisi * tablo.model.sutunSayisi else { kapat(odakla: true); return }
        ac(tablo, satir: indeks / tablo.model.sutunSayisi, sutun: indeks % tablo.model.sutunSayisi, tumunuSec: true)
    }
    private func konumlandir() {
        guard let editor, let gorunum, let giris, let tablo = etkin(),
              let alt = tablo.model.hucreAraligi(satir: satir, sutun: sutun) else { return }
        var bas = LinuxMetinDonusumu.iter(editor.tampon, tablo.aralik.location + alt.location)
        let ns = tablo.model.gorsel().metin as NSString
        let satirAraligi = ns.lineRange(for: NSRange(location: alt.location, length: 0))
        let sag = tablo.model.hucreAraligi(satir: satir, sutun: sutun + 1).map { $0.location - 2 }
            ?? (NSMaxRange(satirAraligi) - 2)
        var son = LinuxMetinDonusumu.iter(editor.tampon, tablo.aralik.location + sag)
        var a = GdkRectangle(), b = GdkRectangle()
        gtk_text_view_get_iter_location(gorunum, &bas, &a)
        gtk_text_view_get_iter_location(gorunum, &son, &b)
        gtk_widget_set_size_request(giris.widget, max(60, b.x - a.x + 8), max(18, a.height))
        gtk_text_view_move_overlay(gorunum, giris.widget, a.x - 2, a.y)
    }
    private func yenile() {
        guard let giris else { return }
        if editor?.belge.string == kendiBelgesi { konumlandir(); return }
        guard let tablo = etkin(), let metin = tablo.model.hucre(satir: satir, sutun: sutun) else { kapat(); return }
        if String(cString: gtk_editable_get_text(OpaquePointer(giris.widget))) != metin {
            giris.metniAyarla(metin)
        }
        konumlandir()
    }
    private func kapat(odakla: Bool = false) {
        etkilesim &+= 1
        if let giris { gtk_widget_set_visible(giris.widget, 0) }
        giris = nil; kimlik = nil; kendiBelgesi = nil
        if odakla, let editor, !editor.yokEdildi { gtk_widget_grab_focus(editor.metinGorunumu) }
    }
    private struct BekleyenHucre {
        let kimlik: String
        let satir: Int
        let sutun: Int
        var metin: String
        var eklemeYeri: Int?
        let belge: String
    }
    private var bekleyen: BekleyenHucre?
    private func planla(_ islem: BekleyenHucre) {
        let zatenPlanli = bekleyen != nil
        bekleyen = islem
        guard !zatenPlanli, let editor else { return }
        let url = editor.acikURL, nesil = editor.nesil, odakNesli = etkilesim
        Platform.anaIsParcaciginda { [weak self, weak editor] in
            guard let self else { return }
            let islem = self.bekleyen
            self.bekleyen = nil
            guard let islem, let editor, !editor.yokEdildi, editor.editorEtkin,
                  editor.acikURL == url, editor.nesil == nesil, editor.belge.string == islem.belge,
                  let tablo = self.tablolar().first(where: { $0.kimlik == islem.kimlik }) else { return }
            if self.etkilesim == odakNesli {
                self.ac(tablo, satir: islem.satir, sutun: islem.sutun, tumunuSec: false)
                self.giris?.metniAyarla(islem.metin)
                self.kaydet(islem.metin)
                if let giris = self.giris { gtk_editable_set_position(OpaquePointer(giris.widget), -1) }
            } else {
                self.kaydet(islem.metin, hedef: tablo, hedefSatir: islem.satir, hedefSutun: islem.sutun)
            }
        }
    }
    private func ekle(_ konum: Int, _ metin: String) -> Bool {
        guard let editor,
              let tablo = tablolar().first(where: { NSLocationInRange(konum, $0.aralik) }) else { return false }
        // A selection replacement emits delete then insert before GTK returns to its loop.
        // Both signals contribute to one model transaction while the buffer remains untouched.
        if var islem = bekleyen, islem.kimlik == tablo.kimlik,
           islem.belge == editor.belge.string, let yer = islem.eklemeYeri {
            let ns = islem.metin as NSString
            let bas = min(yer, ns.length)
            islem.metin = ns.replacingCharacters(in: NSRange(location: bas, length: 0), with: metin)
            islem.eklemeYeri = bas + (metin as NSString).length
            planla(islem)
            return true
        }
        guard let (r, c) = hucre(tablo, konum: konum),
              let alt = tablo.model.hucreAraligi(satir: r, sutun: c), let eski = tablo.model.hucre(satir: r, sutun: c) else { return true }
        let ns = eski as NSString
        let yer = min(max(0, konum - tablo.aralik.location - alt.location), ns.length)
        let yeni = ns.replacingCharacters(in: NSRange(location: yer, length: 0), with: metin)
        planla(BekleyenHucre(kimlik: tablo.kimlik, satir: r, sutun: c, metin: yeni,
                            eklemeYeri: yer + (metin as NSString).length, belge: editor.belge.string))
        return true
    }
    private func sil(_ aralik: NSRange) -> Bool {
        let kesisen = tablolar().filter { NSIntersectionRange($0.aralik, aralik).length > 0 }
        guard !kesisen.isEmpty else { return false }
        if kesisen.allSatisfy({ aralik.location <= $0.aralik.location && NSMaxRange(aralik) >= NSMaxRange($0.aralik) }) { kapat(); return false }
        guard let editor, kesisen.count == 1, let tablo = kesisen.first,
              let (r, c) = hucre(tablo, konum: aralik.location), let alt = tablo.model.hucreAraligi(satir: r, sutun: c),
              aralik.location >= tablo.aralik.location + alt.location,
              NSMaxRange(aralik) <= tablo.aralik.location + NSMaxRange(alt),
              let eski = tablo.model.hucre(satir: r, sutun: c), (eski as NSString).length == alt.length else { return true }
        let yer = aralik.location - tablo.aralik.location - alt.location
        let yeni = (eski as NSString).replacingCharacters(in: NSRange(location: yer, length: aralik.length), with: "")
        planla(BekleyenHucre(kimlik: tablo.kimlik, satir: r, sutun: c, metin: yeni,
                            eklemeYeri: yer, belge: editor.belge.string))
        return true
    }
}
