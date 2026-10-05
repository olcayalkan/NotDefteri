import AppKit
import NotDefteriCekirdek

/// Kopyalanan seçimi notun kendi biçiminde (Markdown + kaynak klasör)
/// taşıyan özel pano tipi.
///
/// NSTextView seçimi RTFD olarak panoya yazar, ama RTFD iki şeyi kaybediyor:
/// görsellerin `ResimEki` kimliği (dosya yolu + bağ) ve başlık düzeyi gibi
/// özel öznitelikler. Sonuçta başka sayfaya yapıştırılan görsel kaydedilirken
/// `![](...)` bağı üretilmiyor, görsel sessizce kayboluyordu. Bu yüzden
/// kopyalarken seçimi Markdown'a çevirip kaynak sayfanın klasörüyle birlikte
/// panoya koyuyoruz; yapıştırmada görsel dosyaları hedef sayfaya kopyalanıyor.
let kNotPanoTipi = NSPasteboard.PasteboardType("tr.notdefteri.icerik")

// MARK: - Görsel yapıştırma/sürükleme kabul eden metin görünümü

final class NotMetinGorunumu: NSTextView {

    /// Panodan gelen görseli diske yazıp ek üretmesi için pencereye sorar.
    /// İkinci parametre, görselin eklendiği bölümün başlığı (varsa).
    var gorselEklenecek: ((NSImage, String?) -> ResimEki?)?

    /// Kopyalanan Markdown'ı bu sayfaya uygun biçimde hazırlatır: içindeki
    /// görsellerin dosyaları hedef sayfanın klasörüne kopyalanır.
    /// Parametreler: Markdown metni ve kaynak sayfanın klasörü.
    var icerikEklenecek: ((String, URL?) -> NSAttributedString?)?

    /// Bu sayfanın kendi klasörü — kopyalanan görsel bağlarının çözüleceği taban.
    var sayfaTabanKlasoru: (() -> URL?)?

    /// Açıkken yapıştırılan içerik notun biçimine uydurulmaz, kaynağından
    /// geldiği gibi eklenir. ⇧⌘V bunu tek yapıştırma boyunca açar.
    var hamYapistirmaModu = false
    var blokDuzenleniyor = false
    var sayfaYukleniyor = false {
        didSet { if sayfaYukleniyor { kodDurumunuSifirla(); bekleyenBagBoyamasi = nil } }
    }
    var baglarGuncelleniyor = false
    let sayfaBulucusu = HizliBulucu()
    var bagTamamlamaAraligi: NSRange?
    var kapatilanBagKonumu: Int?
    let blokMenusu = BlokMenusu()
    let secimCubugu = SecimCubugu()
    var slashAraligi: NSRange?
    var kapatilanSlashKonumu: Int?
    var kucukYazi = false
    var yaziOlcegiUygulaniyor = false
    let kelimeMetni = NSMutableString(string: "")
    var kelimeSayisi = 0
    var altBilgiDegisti: (() -> Void)?
    weak var uyariEmojiAlani: NSTextField?
    var kodBekleyenAraliklar: [NSRange] = []
    var kodZamanlayicisi: Timer?
    var kodSurumu = 0
    /// Depo düzenlemesi bitince boyanacak sayfa bağı aralığı (bkz. didProcessEditing).
    var bekleyenBagBoyamasi: NSRange?
    private weak var izlenenKodDeposu: NSTextStorage?
    private weak var izlenenKaydirmaIcerigi: NSClipView?
    let kodAraclari = KodBloguAraclari()
    let katlama = KatlamaDurumu()
    let belgeAdaptoru = MacBelgeAdaptoru()

    /// Kod yazım özniteliklerini anlamsal yazar; görünüm her atamada adaptörden türetilir.
    override var typingAttributes: [NSAttributedString.Key: Any] {
        get { super.typingAttributes }
        set { super.typingAttributes = belgeAdaptoru.gorunumlu(newValue) }
    }

    override func changeFont(_ sender: Any?) {
        guard isEditable, let yonetici = sender as? NSFontManager, let depo = textStorage else { return }
        let secim = selectedRange()
        if secim.length == 0 {
            typingAttributes = belgeAdaptoru.fontuDegistir(yonetici, oznitelikler: typingAttributes)
            return
        }
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: secim))
        yeni.enumerateAttributes(in: NSRange(location: 0, length: yeni.length)) { o, alt, _ in
            yeni.setAttributes(belgeAdaptoru.fontuDegistir(yonetici, oznitelikler: o), range: alt)
        }
        blokDuzenle(secim, yeni: yeni, secim: secim, yazim: typingAttributes)
    }

    override var backgroundColor: NSColor {
        didSet {
            guard backgroundColor != oldValue else { return }
            needsDisplay = true
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let eski = izlenenKaydirmaIcerigi {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: eski)
        }
        izlenenKaydirmaIcerigi = window == nil ? nil : enclosingScrollView?.contentView
        if let icerik = izlenenKaydirmaIcerigi {
            icerik.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(kodVeResimAraclariniGuncelle(_:)),
                                                   name: NSView.boundsDidChangeNotification, object: icerik)
        }
        guard let depo = textStorage, izlenenKodDeposu !== depo else { return }
        if let eski = izlenenKodDeposu {
            NotificationCenter.default.removeObserver(self, name: NSTextStorage.didProcessEditingNotification, object: eski)
        }
        izlenenKodDeposu = depo
        layoutManager?.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(kodDeposuDegisti(_:)),
                                               name: NSTextStorage.didProcessEditingNotification, object: depo)
        NotificationCenter.default.addObserver(self, selector: #selector(katlamaDeposuDegisti(_:)),
                                               name: NSTextStorage.didProcessEditingNotification, object: depo)
        kodBekleyenAraliklar = [NSRange(location: 0, length: depo.length)]
        kodRenklendirmeyiPlanla()
        addSubview(kodAraclari)
        kodAraclari.isHidden = true
        kodAraclari.kopyala = { [weak self] in self?.kodBlogunuKopyala() }
    }

    deinit {
        kodZamanlayicisi?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func keyDown(with event: NSEvent) {
        if window?.firstResponder === self, katlamaKisayolunuUygula(event) { return }
        secimCubugu.gizle()
        if sayfaBulucusu.gorunur, !hasMarkedText(), event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            switch event.keyCode {
            case 126: sayfaBulucusu.gezin(-1); return
            case 125: sayfaBulucusu.gezin(1); return
            case 36, 76: sayfaBulucusu.sec(); return
            case 53:
                kapatilanBagKonumu = bagTamamlamaAraligi?.location
                bagTamamlamaAraligi = nil
                sayfaBulucusu.gizle()
                return
            default: break
            }
        }
        if blokMenusu.gorunur, !hasMarkedText(),
           event.modifierFlags.intersection(blokMenusu.dilSecimi ? [.command, .control, .option] : [.command, .control, .option, .shift]).isEmpty {
            switch event.keyCode {
            case 126: blokMenusu.gezin(-1); return
            case 125: blokMenusu.gezin(1); return
            case 36, 76: blokMenusu.sec(); return
            case 53:
                kapatilanSlashKonumu = slashAraligi?.location
                slashAraligi = nil
                blokMenusu.gizle()
                return
            default:
                if blokMenusu.dilSecimi {
                    blokMenusu.dilSorgusunuYaz(event.characters, sil: event.keyCode == 51)
                    return
                }
            }
        }
        super.keyDown(with: event)
        sayfaBulucusunuGuncelle()
        if !sayfaBulucusu.gorunur { blokMenusunuGuncelle() }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        (window?.firstResponder === self && katlamaKisayolunuUygula(event)) || super.performKeyEquivalent(with: event)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(katlamaKomutu(_:)) {
            return isEditable && !katlama.basliklar.isEmpty
        }
        return super.validateMenuItem(menuItem)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        for range in ranges { katliAraligiAc(range.rangeValue) }
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag)
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        katliAraligiAc(range)
        super.scrollRangeToVisible(range)
    }

    override func didChangeText() {
        blokMenusu.gizle()
        secimCubugu.gizle()
        yazimOlceginiGuncelle()
        super.didChangeText()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.kodVeResimAraclariniGuncelle()
            self.sayfaBulucusunuGuncelle()
            if !self.sayfaBulucusu.gorunur { self.blokMenusunuGuncelle() }
        }
    }

    override func resignFirstResponder() -> Bool {
        yuzerGorunumleriGizle()
        return super.resignFirstResponder()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        yuzerGorunumleriGizle()
        super.viewWillMove(toWindow: newWindow)
    }

    func blokTamamlayicisiniYaz(_ metin: String) {
        blokYaziminiGuncelle()
        super.insertText(metin, replacementRange: selectedRange())
        breakUndoCoalescing()
        // Tamamlayıcı normal yazım geçmişinde kalsın; dönüşüm ayrı bir undo olsun.
        if let yonetici = undoManager, yonetici.groupsByEvent, yonetici.groupingLevel == 1 {
            yonetici.endUndoGrouping()
        }
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        secimCubugu.gizle()
        sayfaBagYaziminiTemizle()
        if let metin = insertString as? String, metin.contains("[") { kapatilanBagKonumu = nil }
        if let metin = insertString as? String, metin.contains("/") { kapatilanSlashKonumu = nil }
        if !hasMarkedText(), let metin = insertString as? String, metin == " ",
           (replacementRange.location == NSNotFound || replacementRange == selectedRange()),
           blokKisayolunuUygula(metin) { return }
        blokYaziminiGuncelle()
        super.insertText(insertString, replacementRange: replacementRange)
    }

    override func insertNewline(_ sender: Any?) {
        katlamaYeniSatirOncesi()
        blokYaziminiGuncelle()
        if !hasMarkedText(), blokKisayolunuUygula("\n") || bloktaYeniSatir() { return }
        super.insertNewline(sender)
    }

    override func insertTab(_ sender: Any?) {
        if hasMarkedText() || !blokGirintisiniDegistir(1) { super.insertTab(sender) }
    }

    override func insertBacktab(_ sender: Any?) {
        if hasMarkedText() || !blokGirintisiniDegistir(-1) { super.insertBacktab(sender) }
    }

    override func deleteBackward(_ sender: Any?) {
        if hasMarkedText() || !satirBasindaBicimiKaldir() { super.deleteBackward(sender) }
    }

    private var resimIzlemeAlani: NSTrackingArea?
    private weak var uzerindekiResimHucresi: ResimEkiHucresi?
    private var resimTutamacinda = false

    // MARK: Görsel tutamaçları

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let resimIzlemeAlani { removeTrackingArea(resimIzlemeAlani) }
        let alan = NSTrackingArea(rect: .zero,
                                 options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate,
                                           .activeInKeyWindow, .inVisibleRect],
                                 owner: self, userInfo: nil)
        addTrackingArea(alan)
        resimIzlemeAlani = alan
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        katlamaFaresiniGuncelle(convert(event.locationInWindow, from: nil))
        resimImleciniGuncelle(noktada: convert(event.locationInWindow, from: nil), olay: event)
        kodAraclariniGuncelle(noktada: convert(event.locationInWindow, from: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let nokta = convert(event.locationInWindow, from: nil)
        katlamaFaresiniGuncelle(nokta)
        kodAraclariniGuncelle(noktada: nokta)
        resimTutamaclariniGuncelle(resimHucresiniBul(noktada: nokta)?.hucre)
        resimImleciniGuncelle(noktada: nokta, olay: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        let tutamactaydi = resimTutamacinda
        resimImleciniGuncelle(noktada: convert(event.locationInWindow, from: nil), olay: event)
        if !resimTutamacinda && !tutamactaydi {
            super.cursorUpdate(with: event)
        }
    }

    override func mouseExited(with event: NSEvent) {
        katlamaFaresiniGuncelle(nil)
        kodAraclari.isHidden = true
        resimTutamaclariniGuncelle(nil)
        resimTutamacinda = false
        super.mouseExited(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        blokCizgileriniCiz(dirtyRect)
        katlamaIsaretleriniCiz(dirtyRect)
    }

    @objc private func kodVeResimAraclariniGuncelle(_ bildirim: Notification? = nil) {
        // Kaydırma ve yeniden dizilimde yalnızca önbellekteki hücreyi denetle.
        let nokta = window.flatMap { $0.isKeyWindow ? convert($0.mouseLocationOutsideOfEventStream, from: nil) : nil }
        kodAraclariniGuncelle(noktada: nokta)
        if nokta.flatMap({ resimHucresi(noktada: $0) }) == nil {
            resimTutamaclariniGuncelle(nil)
        }
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        uyariKutulariniCiz(rect)
    }

    override func mouseDown(with event: NSEvent) {
        let nokta = convert(event.locationInWindow, from: nil)
        if katlamaIsaretiniTikla(nokta) { return }
        if uyariEmojisiniTikla(noktada: nokta) { return }
        if yapilacakKutusunuDegistir(noktada: nokta) { return }
        if let resim = resimHucresi(noktada: nokta),
           resim.hucre.tutamacYonu(noktada: nokta, cerceve: resim.cerceve) != nil,
           resim.hucre.trackMouse(with: event, in: resim.cerceve, of: self, untilMouseUp: true) {
            // Tutamaç tıklaması NSTextView'ın seçim/sürükleme yoluna girmesin.
            if let pencere = window {
                resimImleciniGuncelle(noktada: convert(pencere.mouseLocationOutsideOfEventStream, from: nil),
                                     olay: NSApp.currentEvent ?? event)
            }
            return
        }
        sayfaBulucusu.gizle()
        if sayfaBaginiTikla(noktada: nokta) { return }
        blokMenusu.gizle()
        if event.modifierFlags.contains(.command), let depo = textStorage {
            let konum = characterIndexForInsertion(at: nokta)
            if konum < depo.length, let bag = depo.attribute(kBaglantiAnahtari, at: konum, effectiveRange: nil),
               let url = (bag as? URL) ?? URL(string: String(describing: bag)) {
                if disBaglantiGecerliMi(url) { NSWorkspace.shared.open(url) }
                return
            }
        }
        super.mouseDown(with: event)
        secimCubugunuGuncelle()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let nokta = convert(event.locationInWindow, from: nil)
        let konum = characterIndexForInsertion(at: nokta)
        if let depo = textStorage, konum < depo.length,
           MetinBlogu(oznitelik: depo.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil))?.tur == .uyari {
            setSelectedRange(NSRange(location: konum, length: 0))
            return uyariRenkMenusu()
        }
        return super.menu(for: event)
    }

    private func resimImleciniGuncelle(noktada nokta: NSPoint, olay: NSEvent) {
        let resim = resimHucresi(noktada: nokta)
        let tutamacta = resim.map { $0.hucre.tutamacYonu(noktada: nokta, cerceve: $0.cerceve) != nil } ?? false
        guard tutamacta != resimTutamacinda else { return }
        resimTutamacinda = tutamacta
        if tutamacta {
            // macOS 12'de köşeler için hazır çapraz imleç yok.
            NSCursor.resizeLeftRight.set()
        } else {
            super.cursorUpdate(with: olay)
        }
    }

    func resimTutamaclariniGuncelle(_ hucre: ResimEkiHucresi?) {
        guard uzerindekiResimHucresi !== hucre else { return }
        if let onceki = uzerindekiResimHucresi {
            onceki.tutamaclarGorunur = false
            setNeedsDisplay(onceki.cizimCercevesi)
        }
        uzerindekiResimHucresi = hucre
        if let hucre {
            hucre.tutamaclarGorunur = true
            setNeedsDisplay(hucre.cizimCercevesi)
        }
    }

    private func resimHucresi(noktada nokta: NSPoint) -> (hucre: ResimEkiHucresi, cerceve: NSRect)? {
        guard isEditable, visibleRect.contains(nokta), let hucre = uzerindekiResimHucresi,
              hucre.cizimCercevesi.contains(nokta) else { return nil }
        return (hucre, hucre.cizimCercevesi)
    }

    private func resimHucresiniBul(noktada nokta: NSPoint) -> (hucre: ResimEkiHucresi, cerceve: NSRect)? {
        guard isEditable, visibleRect.contains(nokta), let depo = textStorage,
              let yerlesim = layoutManager, let kapsayici = textContainer else { return nil }
        let gorunen = visibleRect.offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let glifler = yerlesim.glyphRange(forBoundingRect: gorunen, in: kapsayici)
        let karakterler = yerlesim.characterRange(forGlyphRange: glifler, actualGlyphRange: nil)
        var bulunan: (hucre: ResimEkiHucresi, cerceve: NSRect)?
        depo.enumerateAttribute(.attachment, in: karakterler, options: []) { deger, aralik, durdur in
            guard !self.katlama.gizliMi(aralik.location), let ek = deger as? ResimEki, let hucre = ek.attachmentCell as? ResimEkiHucresi,
                  !hucre.cizimCercevesi.isEmpty, hucre.cizimCercevesi.contains(nokta) else { return }
            bulunan = (hucre, hucre.cizimCercevesi)
            durdur.pointee = true
        }
        return bulunan
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        blokYaziminiGuncelle()
        if typingAttributes[kKodBloguAnahtari] != nil || typingAttributes[kSatirIciKodAnahtari] != nil {
            // Kodda pano işaretlemesi yorumlanmaz; hedef bloğun kimliği korunur.
            guard let metin = pboard.string(forType: .string) else { NSSound.beep(); return true }
            icerigiEkle(NSAttributedString(string: metin, attributes: typingAttributes))
            return true
        }
        // ⇧⌘V: kullanıcı bilerek kaynak biçimini istedi.
        if hamYapistirmaModu {
            if let zengin = panodanZenginMetin(pboard) {
                if let icerik = disGorselleriSayfayaAl(zengin) {
                    icerigiEkle(MacBelgeAdaptoru.disIcerigiAnlamsalaCevir(icerik, kaynakBicimi: true), kaynakBiciminiKoru: true)
                }
                return true
            }
            return super.readSelection(from: pboard, type: type)
        }
        // Önce kendi tipimiz: görseller ve başlıklar eksiksiz taşınsın.
        if let bilgi = pboard.propertyList(forType: kNotPanoTipi) as? [String: Any], bilgi["markdown"] is String {
            if let icerik = kopyalananIcerik(pboard) { icerigiEkle(icerik) }
            // Hazırlama başarısızsa diğer pano tiplerine geçip bozuk ek yapıştırma.
            return true
        }
        if let zengin = panodanZenginMetin(pboard) {
            // Ekler önce sayfaya yazılır; anlamsal dönüşüm görseli dosya yoluyla taşır.
            if let icerik = disGorselleriSayfayaAl(zengin) {
                icerigiEkle(disIcerigiNotBicimineCevir(MacBelgeAdaptoru.disIcerigiAnlamsalaCevir(icerik)))
            }
            return true
        }
        if let gorsel = panodanGorsel(pboard) {
            guard let ek = gorselEklenecek?(gorsel, bulunanBolumBasligi()) else {
                gorselYapistirmaHatasiniBildir()
                return true
            }
            ekiEkle(ek)
            return true
        }
        // Başka bir uygulamadan gelen içerik: notun kendi yazım biçimine uydurulur.
        if let icerik = disPanoIcerigi(pboard) {
            icerigiEkle(icerik)
            return true
        }
        return super.readSelection(from: pboard, type: type)
    }

    /// Panodaki içeriği notun biçimine uydurmadan, kaynağındaki hâliyle yapıştırır.
    func hamYapistir() {
        hamYapistirmaModu = true
        defer { hamYapistirmaModu = false }
        pasteAsRichText(nil)
    }

    // MARK: Dış içerik

    /// Panodaki düz metni Markdown olarak yorumlayıp notun biçimine çevirir.
    private func disPanoIcerigi(_ pano: NSPasteboard) -> NSAttributedString? {
        guard let metin = pano.string(forType: .string), !metin.isEmpty else { return nil }
        let taban = sayfaTabanKlasoru?() ?? notlarKlasoru()
        let icerik = MacBelgeAdaptoru.belgeyiAc(disMetniNotBicimineCevir(metin, taban: taban), taban: taban)
        return icerik.length > 0 ? icerik : nil
    }

    private func panodanZenginMetin(_ pano: NSPasteboard) -> NSAttributedString? {
        if let veri = pano.data(forType: .rtfd),
           let icerik = NSAttributedString(rtfd: veri, documentAttributes: nil) { return icerik }
        if let veri = pano.data(forType: .rtf),
           let icerik = NSAttributedString(rtf: veri, documentAttributes: nil) { return icerik }
        if let veri = pano.data(forType: .html),
           let icerik = try? NSAttributedString(
               data: veri,
               options: [.documentType: NSAttributedString.DocumentType.html,
                         .characterEncoding: String.Encoding.utf8.rawValue],
               documentAttributes: nil) { return icerik }
        return nil
    }

    /// Dış içerikteki görselleri diske yazıp `ResimEki`ye çevirir.
    ///
    /// Yapıştırılan RTFD/HTML görselleri yalnızca bellekte duruyordu: not
    /// kaydedilince `![](...)` bağı üretilmediği için sessizce kayboluyorlardı.
    func disGorselleriSayfayaAl(_ icerik: NSAttributedString) -> NSAttributedString? {
        let sonuc = NSMutableAttributedString(attributedString: icerik)
        // Ekler önce hazırlanır; başarısızlıkta içeriğin tamamı iptal edilir.
        var yenilenecekler: [(NSRange, ResimEki)] = []
        var basarisiz = false
        sonuc.enumerateAttribute(.attachment, in: NSRange(location: 0, length: sonuc.length), options: []) { deger, aralik, durdur in
            guard let ek = deger as? NSTextAttachment, !(ek is ResimEki) else { return }
            guard let gorsel = ekinGorseli(ek),
                  let yeni = gorselEklenecek?(gorsel, bulunanBolumBasligi()) else {
                basarisiz = true
                durdur.pointee = true
                return
            }
            yenilenecekler.append((aralik, yeni))
        }
        guard !basarisiz else {
            gorselYapistirmaHatasiniBildir()
            return nil
        }
        for (aralik, ek) in yenilenecekler.reversed() {
            sonuc.addAttribute(.attachment, value: ek, range: aralik)
        }
        return sonuc
    }

    private func gorselYapistirmaHatasiniBildir() {
        let uyari = NSAlert()
        uyari.alertStyle = .critical
        uyari.messageText = "Görsel yapıştırılamadı"
        uyari.informativeText = "Görsel okunamadı veya bu sayfanın görsel klasörüne kaydedilemedi. Yapıştırma iptal edildi."
        uyari.addButton(withTitle: "Tamam")
        uyari.runModal()
    }

    private func ekinGorseli(_ ek: NSTextAttachment) -> NSImage? {
        if let gorsel = ek.image, gorsel.size.width > 0 { return gorsel }
        if let hucre = ek.attachmentCell as? NSTextAttachmentCell,
           let gorsel = hucre.image, gorsel.size.width > 0 { return gorsel }
        if let veri = ek.fileWrapper?.regularFileContents,
           let gorsel = NSImage(data: veri), gorsel.size.width > 0 { return gorsel }
        return nil
    }

    // MARK: Kopyalama

    override func copy(_ sender: Any?) {
        super.copy(sender)
        secimiPanoyaEkle()
    }

    override func cut(_ sender: Any?) {
        // Seçim silinmeden önce okunmalı.
        let markdown = secimiMarkdownaCevir()
        super.cut(sender)
        panoyaYaz(markdown)
    }

    /// Seçimi, notun kendi Markdown biçimiyle panoya ekler (RTFD'ye ek olarak).
    private func secimiPanoyaEkle() { panoyaYaz(secimiMarkdownaCevir()) }

    private func secimiMarkdownaCevir() -> String? {
        guard let metinDeposu = textStorage else { return nil }
        let aralik = selectedRange()
        guard aralik.length > 0, NSMaxRange(aralik) <= metinDeposu.length else { return nil }
        let markdown = markdownMetniUret(metinDeposu.attributedSubstring(from: aralik))
        return markdown.isEmpty ? nil : markdown
    }

    private func panoyaYaz(_ markdown: String?) {
        guard let markdown else { return }
        var bilgi: [String: Any] = ["markdown": markdown]
        if let taban = sayfaTabanKlasoru?() { bilgi["taban"] = taban.path }
        let pano = NSPasteboard.general
        pano.addTypes([kNotPanoTipi], owner: nil)
        pano.setPropertyList(bilgi, forType: kNotPanoTipi)
    }

    /// Panoda kendi tipimiz varsa görselleri bu sayfaya kopyalanmış içeriği döner.
    private func kopyalananIcerik(_ pano: NSPasteboard) -> NSAttributedString? {
        guard let bilgi = pano.propertyList(forType: kNotPanoTipi) as? [String: Any],
              let markdown = bilgi["markdown"] as? String else { return nil }
        let taban = (bilgi["taban"] as? String).map { URL(fileURLWithPath: $0) }
        return icerikEklenecek?(markdown, taban)
    }

    func icerigiEkle(_ icerik: NSAttributedString, kaynakBiciminiKoru: Bool = false) {
        let kodda = typingAttributes[kKodBloguAnahtari] != nil || typingAttributes[kSatirIciKodAnahtari] != nil
        let icerik = kodda ? NSMutableAttributedString(string: icerik.string, attributes: typingAttributes)
            : NSMutableAttributedString(attributedString: icerik)
        if !kodda { ciplakBaglariIsaretle(icerik, aralik: NSRange(location: 0, length: icerik.length)) }
        let aralik = selectedRange()
        if !kodda, icerik.length > 0, let depo = textStorage {
            let ns = depo.mutableString
            if icerik.attribute(kKodBloguAnahtari, at: 0, effectiveRange: nil) != nil,
               aralik.location > 0, ns.character(at: aralik.location - 1) != 10 {
                icerik.insert(NSAttributedString(string: "\n"), at: 0)
            }
            if NSMaxRange(aralik) < ns.length, ns.character(at: NSMaxRange(aralik)) != 10 {
                var sonBlok = NSRange()
                if var sinirlar = icerik.attribute(kKodBloguAnahtari, at: icerik.length - 1,
                       longestEffectiveRange: &sonBlok, in: NSRange(location: 0, length: icerik.length)) as? [String: String] {
                    // Yapıştırılan çit, arkasındaki gövde metnini kodun içine almamalı.
                    if (sinirlar["kapanis"] ?? "").isEmpty {
                        sinirlar["kapanis"] = String((sinirlar["acilis"] ?? "```").prefix { $0 == "`" })
                    }
                    if sinirlar["kapanis"]?.hasSuffix("\n") != true { sinirlar["kapanis", default: "```"] += "\n" }
                    icerik.addAttribute(kKodBloguAnahtari, value: sinirlar, range: sonBlok)
                    if !icerik.string.hasSuffix("\n") {
                        icerik.append(NSAttributedString(string: "\n", attributes: kodBloguOznitelikleri(sinirlar)))
                    }
                }
            }
        }
        guard shouldChangeText(in: aralik, replacementString: icerik.string) else { return }
        textStorage?.beginEditing()
        textStorage?.replaceCharacters(in: aralik, with: icerik)
        textStorage?.endEditing()
        didChangeText()
        setSelectedRange(NSRange(location: aralik.location + icerik.length, length: 0))
        if !kaynakBiciminiKoru, !kodda { typingAttributes = [:] }
    }

    /// İmlecin bulunduğu yerden yukarı doğru en yakın başlık satırının metni.
    /// Görsel dosyasını o bölümün adıyla kaydetmek için kullanılır.
    private func bulunanBolumBasligi() -> String? {
        guard let metinDeposu = textStorage, metinDeposu.length > 0 else { return nil }
        let ns = metinDeposu.string as NSString
        var aralik = ns.paragraphRange(for: NSRange(location: min(selectedRange().location, ns.length - 1), length: 0))
        while true {
            if aralik.length > 0,
               metinDeposu.attribute(kBaslikSeviyesiAnahtari, at: aralik.location, effectiveRange: nil) != nil {
                let baslik = ns.substring(with: aralik).trimmingCharacters(in: .whitespacesAndNewlines)
                if !baslik.isEmpty { return baslik }
            }
            guard aralik.location > 0 else { return nil }
            aralik = ns.paragraphRange(for: NSRange(location: aralik.location - 1, length: 0))
        }
    }

    private func panodanGorsel(_ pano: NSPasteboard) -> NSImage? {
        // Ekran görüntüleri ve kopyalanan görseller doğrudan pano verisi olarak gelir.
        if let gorsel = NSImage(pasteboard: pano), gorsel.size.width > 0 { return gorsel }
        // Finder'dan sürüklenen dosyalar.
        if let urller = pano.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let ilk = urller.first,
           ["png", "jpg", "jpeg", "gif", "heic", "tiff"].contains(ilk.pathExtension.lowercased()) {
            return NSImage(contentsOf: ilk)
        }
        return nil
    }

    func ekiEkle(_ ek: ResimEki) {
        let aralik = selectedRange()
        let ns = (textStorage?.string ?? "") as NSString

        // Görsel kendi satırında (blok) dursun: aynı satırı yazıyla paylaşınca
        // satır yüksekliği görsel kadar olur ve yanında kocaman boşluk oluşur.
        let satirBasindaMi = aralik.location == 0 || ns.character(at: aralik.location - 1) == 10  // "\n"
        let satirSonundaMi = NSMaxRange(aralik) >= ns.length || ns.character(at: NSMaxRange(aralik)) == 10

        // Görsel ve çevresindeki satır sonları normal metin biçiminde olsun (başlık değil).
        let eklenecek = NSMutableAttributedString()
        if !satirBasindaMi { eklenecek.append(NSAttributedString(string: "\n")) }
        let gorselAralikBasi = eklenecek.length
        var gorselOznitelikleri: [NSAttributedString.Key: Any] = [.attachment: ek]
        gorselOznitelikleri[kGorselAnahtari] = MacBelgeAdaptoru.gorselAnlamsali(ek)
        eklenecek.append(NSAttributedString(string: "\u{FFFC}", attributes: gorselOznitelikleri))
        if !satirSonundaMi { eklenecek.append(NSAttributedString(string: "\n")) }

        guard shouldChangeText(in: aralik, replacementString: eklenecek.string) else { return }
        textStorage?.beginEditing()
        textStorage?.replaceCharacters(in: aralik, with: eklenecek)
        textStorage?.endEditing()
        didChangeText()
        // İmleci görselden hemen sonraya al ve yazımın normal biçimde sürmesini sağla.
        setSelectedRange(NSRange(location: aralik.location + gorselAralikBasi + 1, length: 0))
        typingAttributes = [:]
    }
}
