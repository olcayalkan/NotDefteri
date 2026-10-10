import AppKit
import NotDefteriCekirdek

/// Yerel alan seçim, pano ve işaretli metni yönetir. Tamamlanan yazım hemen
/// anlamsal belgeye aktarılır; otomatik kayıt güncel hücreyi görür.
final class MacTabloYoneticisi: NSObject, NSTextFieldDelegate {
    private weak var gorunum: NotMetinGorunumu?
    private let alan = NSTextField(string: "")
    private var uygulaniyor = false
    private var ayarlaniyor = false
    private weak var alanEditoru: NSTextView?
    private var oncekiUndoIzni: Bool?
    private(set) var tasmaPenceresi: NSWindow?
    private var tasmaHucreleri: [NSTextField] = []
    private var tasmaKimligi: String?
    private var etkinAlan: NSTextField {
        guard let hucre = etkinHucre, let tablo = etkinTablo(), tasmaPenceresi != nil else { return alan }
        let indis = hucre.satir * tablo.model.sutunSayisi + hucre.sutun
        return tasmaHucreleri.indices.contains(indis) ? tasmaHucreleri[indis] : alan
    }
    private(set) var etkinHucre: (kimlik: String, satir: Int, sutun: Int)?

    init(gorunum: NotMetinGorunumu) {
        self.gorunum = gorunum
        super.init()
        alan.delegate = self
        alan.isBordered = false
        alan.focusRingType = .none
        alan.isHidden = true
        alan.usesSingleLineMode = true
        alan.lineBreakMode = .byClipping
    }

    private struct Tablo {
        let aralik: NSRange
        let kimlik: String
        var model: TabloModeli
    }

    private func tablolar() -> [Tablo] {
        guard let depo = gorunum?.textStorage else { return [] }
        var sonuc: [Tablo] = []
        depo.enumerateAttribute(kTabloGorselAnahtari, in: NSRange(location: 0, length: depo.length)) { deger, aralik, _ in
            guard let kimlik = deger as? String,
                  let model = TabloModeli(oznitelik: depo.attribute(kTabloModeliAnahtari, at: aralik.location, effectiveRange: nil)),
                  (depo.string as NSString).substring(with: aralik) == model.gorsel().metin else { return }
            sonuc.append(Tablo(aralik: aralik, kimlik: kimlik, model: model))
        }
        return sonuc
    }

    private func etkinTablo() -> Tablo? { tablolar().first { $0.kimlik == etkinHucre?.kimlik } }

    private func hucre(_ tablo: Tablo, konum: Int) -> (satir: Int, sutun: Int)? {
        let yer = konum - tablo.aralik.location
        let ns = tablo.model.gorsel().metin as NSString
        guard yer >= 0, yer < ns.length else { return nil }
        let satirAraligi = ns.lineRange(for: NSRange(location: yer, length: 0))
        for r in 0..<tablo.model.satirSayisi {
            for c in 0..<tablo.model.sutunSayisi {
                guard let alt = tablo.model.hucreAraligi(satir: r, sutun: c),
                      NSLocationInRange(alt.location, satirAraligi) else { continue }
                let son = tablo.model.hucreAraligi(satir: r, sutun: c + 1).map { $0.location - 2 }
                    ?? NSMaxRange(satirAraligi) - 2
                if yer >= alt.location - 1 && yer < son { return (r, c) }
            }
        }
        return nil
    }

    @discardableResult
    func hucreyiAc(konum: Int) -> Bool {
        guard gorunum?.isEditable == true,
              let tablo = tablolar().first(where: { NSLocationInRange(konum, $0.aralik) }) else {
            kapat()
            return false
        }
        guard let hucre = hucre(tablo, konum: konum) else { kapat(); return true }
        ac(tablo, satir: hucre.satir, sutun: hucre.sutun, sec: false)
        return true
    }

    private func ac(_ tablo: Tablo, satir: Int, sutun: Int, sec: Bool) {
        guard let gorunum, let metin = tablo.model.hucre(satir: satir, sutun: sutun) else { return }
        if tasmaPenceresi != nil || tasiyor(tablo) {
            tasmaAc(tablo, satir: satir, sutun: sutun, sec: sec)
            return
        }
        etkinHucre = (tablo.kimlik, satir, sutun)
        metniAyarla(metin)
        if alan.superview !== gorunum { gorunum.addSubview(alan) }
        alan.isHidden = false
        konumlandir()
        gorunum.yuzerGorunumleriGizle()
        gorunum.window?.makeFirstResponder(alan)
        if let editor = alan.currentEditor() {
            editor.selectedRange = NSRange(location: sec ? 0 : (metin as NSString).length,
                                            length: sec ? (metin as NSString).length : 0)
        }
    }

    private func metniAyarla(_ metin: String, alanda hedef: NSTextField? = nil) {
        let alan = hedef ?? etkinAlan
        ayarlaniyor = true
        alan.stringValue = metin
        if let editor = alan.currentEditor() {
            let secim = editor.selectedRange
            editor.string = metin
            let bas = min(secim.location, (metin as NSString).length)
            editor.selectedRange = NSRange(location: bas, length: min(secim.length, (metin as NSString).length - bas))
        }
        ayarlaniyor = false
    }

    func metniKaydet(_ metin: String) {
        guard !uygulaniyor, let gorunum, let hucre = etkinHucre, var tablo = etkinTablo() else { return }
        if etkinAlan.stringValue != metin { metniAyarla(metin) }
        let onceki = tablo.model.markdown()
        guard tablo.model.hucreyiGuncelle(satir: hucre.satir, sutun: hucre.sutun, metin: metin),
              tablo.model.markdown() != onceki else { return }
        let taban = gorunum.sayfaTabanKlasoru?() ?? notlarKlasoru()
        let yeni = NSMutableAttributedString(attributedString:
            gorunum.belgeAdaptoru.gorunumluBelge(markdowndenAttributedStringUret(tablo.model.markdown(), taban: taban)))
        let tumu = NSRange(location: 0, length: yeni.length)
        yeni.addAttribute(kTabloGorselAnahtari, value: tablo.kimlik, range: tumu)
        yeni.addAttribute(kTabloModeliAnahtari, value: tablo.model.oznitelikDegeri, range: tumu)
        let alt = tablo.model.hucreAraligi(satir: hucre.satir, sutun: hucre.sutun) ?? NSRange(location: 0, length: 0)
        uygulaniyor = true
        gorunum.blokDuzenle(tablo.aralik, yeni: yeni,
                            secim: NSRange(location: tablo.aralik.location + alt.location, length: 0),
                            yazim: [:])
        gorunum.undoManager?.setActionName("Tablo Hücresi")
        uygulaniyor = false
        konumlandir()
    }

    func gezin(_ yon: Int) {
        guard let hucre = etkinHucre, let tablo = etkinTablo() else { kapat(); return }
        let indis = hucre.satir * tablo.model.sutunSayisi + hucre.sutun + yon
        guard indis >= 0, indis < tablo.model.satirSayisi * tablo.model.sutunSayisi else { kapat(odakla: true); return }
        ac(tablo, satir: indis / tablo.model.sutunSayisi, sutun: indis % tablo.model.sutunSayisi, sec: true)
    }

    func kapat(kaydet: Bool = true, odakla: Bool = false) {
        if kaydet, etkinHucre != nil { metniKaydet(etkinAlan.stringValue) }
        etkinHucre = nil
        alan.isHidden = true
        let tasma = tasmaPenceresi
        tasmaPenceresi = nil
        tasmaHucreleri = []
        tasmaKimligi = nil
        if let tasma {
            tasma.sheetParent?.endSheet(tasma)
            tasma.orderOut(nil)
        }
        // AppKit alan editörünü kontroller arasında paylaşır; başka bir alan
        // düzenlenmeden önce önceki geri alma ayarını yerine koy.
        if let izin = oncekiUndoIzni { alanEditoru?.allowsUndo = izin }
        oncekiUndoIzni = nil
        let editor = alanEditoru
        alanEditoru = nil
        if let gorunum, odakla || (editor != nil && gorunum.window?.firstResponder === editor) {
            gorunum.window?.makeFirstResponder(gorunum)
        }
    }

    func yenile() {
        guard !uygulaniyor, let hucre = etkinHucre else { return }
        guard let tablo = etkinTablo(), let metin = tablo.model.hucre(satir: hucre.satir, sutun: hucre.sutun) else { kapat(); return }
        if etkinAlan.stringValue.trimmingCharacters(in: .whitespaces) != metin { metniAyarla(metin) }
        if tasmaPenceresi != nil {
            for alan in tasmaHucreleri {
                let r = alan.tag / tablo.model.sutunSayisi, c = alan.tag % tablo.model.sutunSayisi
                if let deger = tablo.model.hucre(satir: r, sutun: c), alan !== etkinAlan, alan.stringValue != deger {
                    metniAyarla(deger, alanda: alan)
                }
            }
        }
        konumlandir()
    }

    /// Yerleşim koordinatları metin kabına aittir. Alan metin görünümünün
    /// çocuğu olduğundan kaydırmada tablosuyla birlikte hareket eder.
    func konumlandir() {
        guard let gorunum, let hucre = etkinHucre, let tablo = etkinTablo(),
              let alt = tablo.model.hucreAraligi(satir: hucre.satir, sutun: hucre.sutun),
              let yerlesim = gorunum.layoutManager, let kapsayici = gorunum.textContainer else { return }
        if tasmaPenceresi != nil { tasmaKonumlandir(tablo); return }
        if tasiyor(tablo) {
            tasmaAc(tablo, satir: hucre.satir, sutun: hucre.sutun, sec: false)
            return
        }
        yerlesim.ensureLayout(for: kapsayici)
        let ns = tablo.model.gorsel().metin as NSString
        let satir = ns.lineRange(for: NSRange(location: alt.location, length: 0))
        let son = tablo.model.hucreAraligi(satir: hucre.satir, sutun: hucre.sutun + 1).map { $0.location - 2 }
            ?? NSMaxRange(satir) - 2
        let karakterler = NSRange(location: tablo.aralik.location + alt.location, length: max(1, son - alt.location))
        let glifler = yerlesim.glyphRange(forCharacterRange: karakterler, actualCharacterRange: nil)
        var kare = yerlesim.boundingRect(forGlyphRange: glifler, in: kapsayici)
        kare = kare.offsetBy(dx: gorunum.textContainerOrigin.x, dy: gorunum.textContainerOrigin.y)
        alan.frame = NSRect(x: kare.minX - 2, y: kare.minY, width: max(40, kare.width + 4), height: max(18, kare.height))
        alan.font = gorunum.textStorage?.attribute(.font, at: karakterler.location, effectiveRange: nil) as? NSFont
        alan.textColor = kMetinRenk
        alan.backgroundColor = aktifTema.arkaplan
        alan.drawsBackground = true
    }

    /// Yerel hücreyi atlayan yazım komutlarından ızgarayı korur.
    /// Tablonun tamamı normal metin gibi silinebilir veya değiştirilebilir.
    func degisikligeIzinVer(_ aralik: NSRange, metin: String?) -> Bool {
        guard !uygulaniyor, let gorunum, !gorunum.blokDuzenleniyor,
              gorunum.undoManager?.isUndoing != true, gorunum.undoManager?.isRedoing != true else { return true }
        let tablolar = tablolar().filter {
            aralik.length == 0 ? NSLocationInRange(aralik.location, $0.aralik) : NSIntersectionRange(aralik, $0.aralik).length > 0
        }
        guard !tablolar.isEmpty else { return true }
        if aralik.length > 0, tablolar.allSatisfy({ aralik.location <= $0.aralik.location && NSMaxRange(aralik) >= NSMaxRange($0.aralik) }) {
            kapat()
            return true
        }
        guard tablolar.count == 1, let tablo = tablolar.first,
              let hucre = hucre(tablo, konum: aralik.location),
              let alt = tablo.model.hucreAraligi(satir: hucre.satir, sutun: hucre.sutun),
              aralik.location >= tablo.aralik.location + alt.location,
              NSMaxRange(aralik) <= tablo.aralik.location + NSMaxRange(alt),
              let eski = tablo.model.hucre(satir: hucre.satir, sutun: hucre.sutun),
              (eski as NSString).length == alt.length else { return false }
        let yerel = NSRange(location: aralik.location - tablo.aralik.location - alt.location, length: aralik.length)
        let yeni = (eski as NSString).replacingCharacters(in: yerel, with: metin ?? "")
        // shouldChangeText içindeki asıl düzenleme iptal edildikten sonra
        // depoyu değiştir. Beklerken sayfa/tablo değişmişse işlem uygulanmaz.
        let belge = gorunum.string
        DispatchQueue.main.async { [weak self, weak gorunum] in
            guard let self, let gorunum, !gorunum.sayfaYukleniyor, gorunum.string == belge,
                  let guncel = self.tablolar().first(where: { $0.kimlik == tablo.kimlik }) else { return }
            self.ac(guncel, satir: hucre.satir, sutun: hucre.sutun, sec: false)
            self.metniAyarla(yeni)
            self.metniKaydet(yeni)
            self.etkinAlan.currentEditor()?.selectedRange = NSRange(location: yerel.location + ((metin ?? "") as NSString).length, length: 0)
        }
        return false
    }

    private func kendiAlani(_ alan: NSTextField) -> Bool {
        alan === self.alan || tasmaHucreleri.contains { $0 === alan }
    }

    private func hedefiSec(_ alan: NSTextField) {
        guard alan !== self.alan, let kimlik = tasmaKimligi,
              let tablo = tablolar().first(where: { $0.kimlik == kimlik }), tasmaHucreleri.contains(where: { $0 === alan }) else { return }
        etkinHucre = (kimlik, alan.tag / tablo.model.sutunSayisi, alan.tag % tablo.model.sutunSayisi)
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let alan = obj.object as? NSTextField, kendiAlani(alan) else { return }
        hedefiSec(alan)
        // Hücre düzenlemeleri belgenin tek geri alma geçmişine yazılır.
        if let editor = alan.currentEditor() as? NSTextView {
            if alanEditoru !== editor {
                // Ana pencere ve tablo sayfası farklı alan editörlerini paylaşır.
                if let izin = oncekiUndoIzni { alanEditoru?.allowsUndo = izin }
                alanEditoru = editor
                oncekiUndoIzni = editor.allowsUndo
            }
            editor.allowsUndo = false
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard !ayarlaniyor, let alan = obj.object as? NSTextField, kendiAlani(alan),
              (alan.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
        hedefiSec(alan)
        metniKaydet(alan.stringValue)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard etkinHucre != nil, let alan = obj.object as? NSTextField, kendiAlani(alan) else { return }
        hedefiSec(alan)
        metniKaydet(alan.stringValue)
        if tasmaPenceresi == nil { kapat() }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard !textView.hasMarkedText(), let alan = control as? NSTextField, kendiAlani(alan) else { return false }
        hedefiSec(alan)
        switch NSStringFromSelector(commandSelector) {
        case "insertTab:": metniKaydet(alan.stringValue); gezin(1)
        case "insertBacktab:": metniKaydet(alan.stringValue); gezin(-1)
        case "insertNewline:": metniKaydet(alan.stringValue); gezin(etkinTablo()?.model.sutunSayisi ?? 1)
        case "cancelOperation:": metniKaydet(alan.stringValue); kapat(odakla: true)
        case "undo:": gorunum?.undoManager?.undo(); yenile()
        case "redo:": gorunum?.undoManager?.redo(); yenile()
        default: return false
        }
        return true
    }

    /// Geniş tablolar notun paragraf düzenini değiştirmeden yerel bir sayfada
    /// düzenlenir; yatay kaydırmayla bütün sütunlara erişilir.
    private func tasiyor(_ tablo: Tablo) -> Bool {
        guard let gorunum, gorunum.window != nil, let kap = gorunum.textContainer else { return false }
        let font = gorunum.textStorage?.attribute(.font, at: tablo.aralik.location, effectiveRange: nil) as? NSFont ?? varsayilanFont()
        let genislik = tablo.model.gorsel().metin.components(separatedBy: "\n").map {
            ($0 as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return genislik + 14 + kap.lineFragmentPadding * 2 > kap.size.width
    }

    private func tasmaAc(_ tablo: Tablo, satir: Int, sutun: Int, sec: Bool) {
        guard let gorunum, let pencere = gorunum.window else { return }
        if tasmaKimligi != nil, tasmaKimligi != tablo.kimlik { kapat() }
        etkinHucre = (tablo.kimlik, satir, sutun)
        if tasmaPenceresi == nil {
            let boyut = NSRect(x: 0, y: 0, width: min(900, max(460, pencere.frame.width)), height: 420)
            let sayfa = NSWindow(contentRect: boyut, styleMask: [.titled], backing: .buffered, defer: false)
            sayfa.title = "Tablo Düzenle"
            sayfa.isReleasedWhenClosed = false
            let kaydirici = NSScrollView(frame: NSRect(x: 16, y: 58, width: boyut.width - 32, height: boyut.height - 74))
            kaydirici.hasHorizontalScroller = true
            kaydirici.hasVerticalScroller = true
            kaydirici.borderType = .noBorder
            kaydirici.documentView = MacTabloSayfasi(frame: .zero)
            sayfa.contentView?.addSubview(kaydirici)
            let tamam = NSButton(title: "Bitti", target: self, action: #selector(tasmaKapat))
            tamam.frame = NSRect(x: boyut.width - 100, y: 14, width: 84, height: 30)
            tamam.bezelStyle = .rounded
            sayfa.contentView?.addSubview(tamam)
            tasmaPenceresi = sayfa
            tasmaKimligi = tablo.kimlik
            for r in 0..<tablo.model.satirSayisi {
                for c in 0..<tablo.model.sutunSayisi {
                    let hucre = NSTextField(string: tablo.model.hucre(satir: r, sutun: c) ?? "")
                    hucre.tag = r * tablo.model.sutunSayisi + c
                    hucre.delegate = self
                    hucre.usesSingleLineMode = true
                    hucre.lineBreakMode = .byClipping
                    hucre.focusRingType = .none
                    kaydirici.documentView?.addSubview(hucre)
                    tasmaHucreleri.append(hucre)
                }
            }
            alan.isHidden = true
            gorunum.yuzerGorunumleriGizle()
            tasmaKonumlandir(tablo)
            pencere.beginSheet(sayfa) { [weak self, weak sayfa] _ in
                guard let self, let sayfa, self.tasmaPenceresi === sayfa else { return }
                self.kapat(kaydet: false)
            }
        }
        guard let sayfa = tasmaPenceresi else { return }
        let alan = etkinAlan
        sayfa.makeFirstResponder(alan)
        if let editor = alan.currentEditor() {
            let uzunluk = (alan.stringValue as NSString).length
            editor.selectedRange = NSRange(location: sec ? 0 : uzunluk, length: sec ? uzunluk : 0)
        }
        alan.scrollToVisible(alan.bounds)
    }

    private func tasmaKonumlandir(_ tablo: Tablo) {
        guard let sayfa = tasmaPenceresi,
              let kaydirici = sayfa.contentView?.subviews.compactMap({ $0 as? NSScrollView }).first,
              let belge = kaydirici.documentView else { return }
        let font = gorunum?.textStorage?.attribute(.font, at: tablo.aralik.location, effectiveRange: nil) as? NSFont ?? varsayilanFont()
        let genislikler = (0..<tablo.model.sutunSayisi).map { sutun in
            max(100, (0..<tablo.model.satirSayisi).map { satir in
                ((tablo.model.hucre(satir: satir, sutun: sutun) ?? "") as NSString).size(withAttributes: [.font: font]).width + 20
            }.max() ?? 100)
        }
        for hucre in tasmaHucreleri {
            let r = hucre.tag / tablo.model.sutunSayisi, c = hucre.tag % tablo.model.sutunSayisi
            hucre.frame = NSRect(x: genislikler.prefix(c).reduce(0, +), y: CGFloat(r) * 30,
                                 width: genislikler[c], height: 28)
            hucre.font = font
            hucre.textColor = kMetinRenk
            hucre.backgroundColor = aktifTema.arkaplan
        }
        belge.frame.size = NSSize(width: genislikler.reduce(0, +), height: CGFloat(tablo.model.satirSayisi) * 30)
        sayfa.backgroundColor = aktifTema.arkaplan
        kaydirici.backgroundColor = aktifTema.arkaplan
    }

    @objc private func tasmaKapat() { kapat(odakla: true) }
}

private final class MacTabloSayfasi: NSView {
    override var isFlipped: Bool { true }
}
