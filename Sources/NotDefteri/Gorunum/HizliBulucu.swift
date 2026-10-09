import AppKit
import NotDefteriCekirdek

/// Aynı sonuç listesi ⌘P aramasında ve [[ tamamlamasında kullanılır.
final class HizliBulucu: NSView, NSTextFieldDelegate {
    var ara: ((String) -> [SayfaSecenegi])?
    var secildi: ((SayfaSecenegi) -> Void)?
    private let aramaAlani = NSTextField()
    private let kaydirma = NSScrollView()
    private let liste = BulucuListesi()
    private let bosEtiketi = NSTextField(labelWithString: "Sonuç yok")
    private var sonuclar: [SayfaSecenegi] = []
    private var dugmeler: [NSButton] = []
    private var secili = 0
    private var satirIci = false
    private var aramaZamanlayicisi: Timer?
    private var bekleyenSorgu: String?
    private var sonSorgu: String?
    private var satirIciKare: NSRect?
    private weak var anaPencere: NSWindow?
    private weak var oncekiOdak: NSResponder?
    private lazy var panel = YuzerPanel(gorunum: self)
    var gorunur: Bool { satirIci ? panel.isVisible : superview != nil }
    override var isFlipped: Bool { true }

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 180))
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        aramaAlani.delegate = self
        aramaAlani.placeholderString = "Sayfa bul…"
        aramaAlani.font = .systemFont(ofSize: 18)
        aramaAlani.isBezeled = false
        aramaAlani.drawsBackground = false
        aramaAlani.focusRingType = .none
        aramaAlani.usesSingleLineMode = true
        aramaAlani.setAccessibilityLabel("Hızlı sayfa bulucu")
        addSubview(aramaAlani)
        kaydirma.drawsBackground = false
        kaydirma.hasVerticalScroller = true
        kaydirma.autohidesScrollers = true
        kaydirma.documentView = liste
        addSubview(kaydirma)
        bosEtiketi.textColor = kMetinRenk.withAlphaComponent(0.6)
        addSubview(bosEtiketi)
    }
    required init?(coder: NSCoder) { fatalError() }

    func filtrele(_ sorgu: String) {
        layer?.backgroundColor = aktifTema.kenarPanel.cgColor
        aramaAlani.textColor = kMetinRenk
        bosEtiketi.textColor = kMetinRenk.withAlphaComponent(0.6)
        sonSorgu = sorgu
        sonuclar = ara?(sorgu) ?? []
        secili = 0
        dugmeler.forEach { $0.removeFromSuperview() }
        dugmeler = sonuclar.enumerated().map { sira, sayfa in
            let dugme = NSButton(title: "", target: self, action: #selector(tiklandi(_:)))
            let ad = NSMutableAttributedString(string: "📄  \(sayfa.ad)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: kMetinRenk])
            ad.append(NSAttributedString(string: "     \(sayfa.ustYol.isEmpty ? "Ana sayfalar" : sayfa.ustYol)", attributes: [
                .font: NSFont.systemFont(ofSize: 10), .foregroundColor: kMetinRenk.withAlphaComponent(0.55)]))
            dugme.attributedTitle = ad
            dugme.tag = sira
            dugme.isBordered = false
            dugme.alignment = .left
            dugme.cell?.wraps = true
            dugme.cell?.isScrollable = false
            dugme.cell?.usesSingleLineMode = false
            dugme.lineBreakMode = .byTruncatingTail
            dugme.refusesFirstResponder = true
            dugme.toolTip = sayfa.yol
            dugme.setAccessibilityLabel("\(sayfa.ad), \(sayfa.ustYol)")
            liste.addSubview(dugme)
            return dugme
        }
        bosEtiketi.isHidden = !sonuclar.isEmpty
        let yukseklik = min(CGFloat(max(1, sonuclar.count)) * 44, satirIci ? 220 : 308) + (satirIci ? 12 : 58)
        setFrameSize(NSSize(width: satirIci ? 300 : 420, height: yukseklik))
        yerlesiminiGuncelle()
        needsLayout = true
        vurguyuGuncelle()
        liste.scroll(.zero)
    }

    func gosterMerkezde(_ pencere: NSWindow, sorgu: String = "") {
        gizle()
        satirIci = false
        anaPencere = pencere
        oncekiOdak = pencere.firstResponder
        aramaAlani.isHidden = false
        aramaAlani.stringValue = sorgu
        filtrele(sorgu)
        pencere.contentView?.addSubview(self)
        yerlesiminiGuncelle()
        pencere.makeFirstResponder(aramaAlani)
    }

    func gosterSatirIci(_ kare: NSRect, pencere: NSWindow, sorgu: String) {
        let zatenGorunur = gorunur
        satirIci = true
        anaPencere = pencere
        satirIciKare = kare
        aramaAlani.isHidden = true
        if zatenGorunur { filtrelemeyiPlanla(sorgu) } else { filtrele(sorgu) }
        panel.goster(kare, ustunde: false, pencere: pencere)
    }

    private func filtrelemeyiPlanla(_ sorgu: String) {
        guard sorgu != bekleyenSorgu, sorgu != sonSorgu || bekleyenSorgu != nil else { return }
        aramaZamanlayicisi?.invalidate()
        bekleyenSorgu = sorgu
        let zamanlayici = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in self?.bekleyeniUygula() }
        aramaZamanlayicisi = zamanlayici
        RunLoop.main.add(zamanlayici, forMode: .common)
    }

    private func bekleyeniUygula() {
        guard let sorgu = bekleyenSorgu else { return }
        aramaZamanlayicisi?.invalidate()
        aramaZamanlayicisi = nil
        bekleyenSorgu = nil
        filtrele(sorgu)
        if satirIci, let kare = satirIciKare, let anaPencere {
            panel.goster(kare, ustunde: false, pencere: anaPencere)
        }
    }

    func yerlesiminiGuncelle() {
        guard !satirIci, let alan = anaPencere?.contentView?.bounds else { return }
        let boyut = NSSize(width: min(420, max(0, alan.width - 32)), height: min(frame.height, max(0, alan.height - 48)))
        frame = NSRect(x: alan.midX - boyut.width / 2, y: alan.midY - boyut.height / 2,
                       width: boyut.width, height: boyut.height)
        layer?.backgroundColor = aktifTema.kenarPanel.cgColor
    }

    override func layout() {
        super.layout()
        let ust: CGFloat = satirIci ? 6 : 52
        aramaAlani.frame = NSRect(x: 16, y: 12, width: max(0, bounds.width - 32), height: 28)
        kaydirma.frame = NSRect(x: 6, y: ust, width: max(0, bounds.width - 12), height: max(0, bounds.height - ust - 6))
        liste.frame = NSRect(x: 0, y: 0, width: kaydirma.contentSize.width, height: max(CGFloat(dugmeler.count) * 44, kaydirma.contentSize.height))
        for (sira, dugme) in dugmeler.enumerated() {
            dugme.frame = NSRect(x: 2, y: CGFloat(sira) * 44, width: max(0, liste.bounds.width - 4), height: 44)
        }
        bosEtiketi.frame = NSRect(x: 16, y: ust + 12, width: max(0, bounds.width - 32), height: 20)
    }

    func gezin(_ yon: Int) {
        bekleyeniUygula()
        guard !sonuclar.isEmpty else { return }
        secili = (secili + yon + sonuclar.count) % sonuclar.count
        vurguyuGuncelle()
        liste.scrollToVisible(dugmeler[secili].frame)
    }
    func sec() {
        bekleyeniUygula()
        guard sonuclar.indices.contains(secili) else { return }
        let sayfa = sonuclar[secili]
        gizle()
        secildi?(sayfa)
    }
    @objc private func tiklandi(_ gonderen: NSButton) {
        guard sonuclar.indices.contains(gonderen.tag) else { return }
        let sayfa = sonuclar[gonderen.tag]
        gizle()
        secildi?(sayfa)
    }
    private func vurguyuGuncelle() {
        for (sira, dugme) in dugmeler.enumerated() {
            dugme.wantsLayer = true
            dugme.layer?.cornerRadius = 5
            dugme.layer?.backgroundColor = (sira == secili ? secimVurguRengi() : .clear).cgColor
        }
    }
    func gizle() {
        aramaZamanlayicisi?.invalidate()
        aramaZamanlayicisi = nil
        bekleyenSorgu = nil
        sonSorgu = nil
        satirIciKare = nil
        if satirIci { panel.gizle() }
        else {
            removeFromSuperview()
            if let anaPencere, let oncekiOdak { anaPencere.makeFirstResponder(oncekiOdak) }
            anaPencere = nil
            oncekiOdak = nil
        }
    }
    func controlTextDidChange(_ bildirim: Notification) { filtrelemeyiPlanla(aramaAlani.stringValue) }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy komut: Selector) -> Bool {
        switch komut {
        case #selector(NSResponder.moveUp(_:)): gezin(-1)
        case #selector(NSResponder.moveDown(_:)): gezin(1)
        case #selector(NSResponder.insertNewline(_:)): sec()
        case #selector(NSResponder.cancelOperation(_:)): gizle()
        default: return false
        }
        return true
    }
}

private final class BulucuListesi: NSView {
    override var isFlipped: Bool { true }
}
