import AppKit

/// Notun başlıklarından üretilen, sağ ÜSTE sabit içindekiler paneli.
///
/// Daraltılmış hâlde seviyeye göre kısalan çizgiler gösterir; fare üzerine
/// gelince metinleri açar. Başlık sayısı sığmazsa panel kendi içinde kaydırılır.
final class IcindekilerPaneli: NSView {

    /// Bir başlık girdisi: metni, düzeyi ve metin içindeki konumu.
    struct Girdi {
        let metin: String
        let seviye: Int
        let konum: Int
    }

    /// Bir başlığa gidilmek istendiğinde tetiklenir (metin içi karakter konumu).
    var basligaGitIstendi: ((Int) -> Void)?

    private(set) var girdiler: [Girdi] = []
    private var etkinSira: Int?
    private(set) var acik = false
    private var izlemeAlani: NSTrackingArea?
    private var satirlar: [SatirGorunumu] = []

    private let kaydirma = NSScrollView()
    private let icerik = TersGorunum()

    // MARK: Ölçüler (Notion'a yakın: dar ve sık)
    static let daraltilmisGenislik: CGFloat = 22
    static let acikGenislik: CGFloat = 180
    /// Daraltılmışken satırlar sık; açılınca metin için yer açılır.
    private let daralikSatir: CGFloat = 11
    private let acikSatir: CGFloat = 22
    private let dikeyBosluk: CGFloat = 6
    /// Panelin üst kenarının başlık çubuğuna uzaklığı.
    private let ustBosluk: CGFloat = 10
    private let sagBosluk: CGFloat = 8

    private var satirYuksekligi: CGFloat { acik ? acikSatir : daralikSatir }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6

        kaydirma.drawsBackground = false
        kaydirma.borderType = .noBorder
        kaydirma.hasVerticalScroller = false      // Kaydırma var ama çubuk görünmesin.
        kaydirma.scrollerStyle = .overlay
        kaydirma.autohidesScrollers = true
        kaydirma.verticalScrollElasticity = .allowed
        kaydirma.documentView = icerik
        addSubview(kaydirma)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// Pencere yeniden boyutlanınca panel sağ üstte kalmalı ve azami
    /// yüksekliği yeniden hesaplanmalı; autoresizingMask bunu yapamıyor
    /// çünkü yükseklik pencere boyuna bağlı.
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        NotificationCenter.default.removeObserver(self)
        guard let ust = superview else { return }
        ust.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(ustBoyutDegisti),
                                                name: NSView.frameDidChangeNotification, object: ust)
    }

    @objc private func ustBoyutDegisti() {
        guard !girdiler.isEmpty else { return }
        frame = hedefKare()
    }

    // MARK: İçerik

    /// Metin deposundaki başlıkları tarayıp paneli yeniden kurar.
    func icerigiGuncelle(_ metinDeposu: NSTextStorage?) {
        girdiler = basliklariTopla(metinDeposu)
        satirlariKur()
        isHidden = girdiler.isEmpty       // Başlık yoksa panel hiç görünmesin.
        needsLayout = true
    }

    private func basliklariTopla(_ metinDeposu: NSTextStorage?) -> [Girdi] {
        guard let metinDeposu, metinDeposu.length > 0 else { return [] }
        let ns = metinDeposu.string as NSString
        var sonuc: [Girdi] = []

        metinDeposu.enumerateAttribute(kBaslikSeviyesiAnahtari,
                                        in: NSRange(location: 0, length: metinDeposu.length),
                                        options: []) { deger, aralik, _ in
            guard let seviye = deger as? Int, seviye >= 1, seviye <= 3 else { return }
            // Öznitelik aralığı birden çok paragrafa yayılmış olabilir; her birini ayrı al.
            var konum = aralik.location
            while konum < NSMaxRange(aralik) {
                let paragraf = ns.paragraphRange(for: NSRange(location: konum, length: 0))
                let metin = ns.substring(with: paragraf).trimmingCharacters(in: .whitespacesAndNewlines)
                if !metin.isEmpty, sonuc.last?.konum != paragraf.location {
                    sonuc.append(Girdi(metin: metin, seviye: seviye, konum: paragraf.location))
                }
                konum = max(NSMaxRange(paragraf), konum + 1)
            }
        }
        return sonuc
    }

    /// İmlecin bulunduğu başlığı vurgular ve gerekirse görünür alana kaydırır.
    func etkinBasligiGuncelle(imlecKonumu: Int) {
        let yeni = girdiler.lastIndex { $0.konum <= imlecKonumu }
        guard yeni != etkinSira else { return }
        etkinSira = yeni
        for (sira, satir) in satirlar.enumerated() { satir.etkin = (sira == yeni) }
        if acik, let yeni, satirlar.indices.contains(yeni) {
            icerik.scrollToVisible(satirlar[yeni].frame)
        }
    }

    private func satirlariKur() {
        satirlar.forEach { $0.removeFromSuperview() }
        satirlar = girdiler.enumerated().map { sira, girdi in
            let satir = SatirGorunumu(girdi: girdi)
            satir.tiklandi = { [weak self] in self?.basligaGitIstendi?(girdi.konum) }
            satir.etkin = (sira == etkinSira)
            satir.acikGoster(acik)
            icerik.addSubview(satir)
            return satir
        }
    }

    // MARK: Açılma / kapanma

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let izlemeAlani { removeTrackingArea(izlemeAlani) }
        let yeni = NSTrackingArea(rect: bounds,
                                   options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
                                   owner: self, userInfo: nil)
        addTrackingArea(yeni)
        izlemeAlani = yeni
    }

    override func mouseEntered(with event: NSEvent) { aciklikAyarla(true) }
    override func mouseExited(with event: NSEvent) { aciklikAyarla(false) }

    private func aciklikAyarla(_ yeniDurum: Bool) {
        guard acik != yeniDurum, !girdiler.isEmpty else { return }
        acik = yeniDurum

        NSAnimationContext.runAnimationGroup { baglam in
            baglam.duration = 0.15
            baglam.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().frame = hedefKare()
            layer?.backgroundColor = yeniDurum
                ? aktifTema.kenarPanel.withAlphaComponent(0.95).cgColor
                : NSColor.clear.cgColor
            for satir in satirlar { satir.acikGoster(yeniDurum) }
        }
        // Kapanınca başa dön; açılınca hep aynı yerden başlasın.
        if !yeniDurum { icerik.scroll(NSPoint(x: 0, y: 0)) }
        needsLayout = true
    }

    /// Sağ ÜSTE yaslı çerçeve. Yükseklik içeriğe göre; sığmazsa kırpılır
    /// ve panel kendi içinde kaydırılır.
    func hedefKare() -> NSRect {
        guard let ust = superview else { return frame }
        let genislik = acik ? Self.acikGenislik : Self.daraltilmisGenislik
        let istenen = CGFloat(girdiler.count) * satirYuksekligi + dikeyBosluk * 2
        let enFazla = ust.bounds.height - kBaslikYuksekligi - ustBosluk * 2
        let yukseklik = min(istenen, max(0, enFazla))
        return NSRect(x: ust.bounds.width - genislik - sagBosluk,
                      y: ust.bounds.height - kBaslikYuksekligi - ustBosluk - yukseklik,
                      width: genislik,
                      height: yukseklik)
    }

    override func layout() {
        super.layout()
        kaydirma.frame = bounds.insetBy(dx: 0, dy: dikeyBosluk)

        let icerikYuksekligi = CGFloat(satirlar.count) * satirYuksekligi
        icerik.frame = NSRect(x: 0, y: 0, width: kaydirma.contentSize.width,
                              height: max(icerikYuksekligi, kaydirma.contentSize.height))
        // Ters koordinatlı görünüm: ilk satır en üstte.
        for (sira, satir) in satirlar.enumerated() {
            satir.frame = NSRect(x: 0, y: CGFloat(sira) * satirYuksekligi,
                                  width: icerik.bounds.width, height: satirYuksekligi)
        }
    }

    func temayiUygula() {
        if acik { layer?.backgroundColor = aktifTema.kenarPanel.withAlphaComponent(0.95).cgColor }
        satirlar.forEach { $0.temayiUygula() }
    }
}

// MARK: - Ters koordinatlı kapsayıcı (ilk satır üstte)

private final class TersGorunum: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Tek başlık satırı

/// Daraltılmışken çizgi, açıkken metin gösteren satır.
private final class SatirGorunumu: NSView {

    var tiklandi: (() -> Void)?
    var etkin = false { didSet { gorunumuTazele() } }

    private let cizgi = NSView()
    private let etiket = NSTextField(labelWithString: "")
    private let girdi: IcindekilerPaneli.Girdi
    private var acik = false
    private var izlemeAlani: NSTrackingArea?
    private var farePanelde = false

    /// Çizgi uzunluğu başlık düzeyini gösterir: /1 en uzun.
    private var cizgiUzunlugu: CGFloat {
        switch girdi.seviye {
        case 1: return 11
        case 2: return 8
        default: return 5
        }
    }

    /// Metin girintisi de düzeye göre artar.
    private var girinti: CGFloat { CGFloat(girdi.seviye - 1) * 9 }

    init(girdi: IcindekilerPaneli.Girdi) {
        self.girdi = girdi
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 3

        cizgi.wantsLayer = true
        cizgi.layer?.cornerRadius = 0.75
        addSubview(cizgi)

        etiket.stringValue = girdi.metin
        etiket.font = NSFont.systemFont(ofSize: girdi.seviye == 1 ? 11 : 10.5,
                                         weight: girdi.seviye == 1 ? .medium : .regular)
        etiket.lineBreakMode = .byTruncatingTail
        etiket.alphaValue = 0
        addSubview(etiket)

        gorunumuTazele()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    func acikGoster(_ acikMi: Bool) {
        acik = acikMi
        etiket.animator().alphaValue = acikMi ? 1 : 0
        cizgi.animator().alphaValue = acikMi ? 0 : 1
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let y = (bounds.height - 1.5) / 2
        cizgi.frame = NSRect(x: bounds.width - cizgiUzunlugu - 6, y: y, width: cizgiUzunlugu, height: 1.5)
        etiket.frame = NSRect(x: 8 + girinti, y: (bounds.height - 14) / 2,
                              width: max(0, bounds.width - 14 - girinti), height: 14)
    }

    private func gorunumuTazele() {
        let koyuluk: CGFloat = etkin ? 0.8 : 0.3
        cizgi.layer?.backgroundColor = NSColor.black.withAlphaComponent(koyuluk).cgColor
        etiket.textColor = NSColor.black.withAlphaComponent(etkin ? 0.9 : 0.58)
        layer?.backgroundColor = (farePanelde && acik)
            ? NSColor.black.withAlphaComponent(0.07).cgColor
            : NSColor.clear.cgColor
    }

    func temayiUygula() { gorunumuTazele() }

    // MARK: Fare

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let izlemeAlani { removeTrackingArea(izlemeAlani) }
        let yeni = NSTrackingArea(rect: bounds,
                                   options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
                                   owner: self, userInfo: nil)
        addTrackingArea(yeni)
        izlemeAlani = yeni
    }

    override func mouseEntered(with event: NSEvent) { farePanelde = true; gorunumuTazele() }
    override func mouseExited(with event: NSEvent) { farePanelde = false; gorunumuTazele() }
    override func mouseDown(with event: NSEvent) { tiklandi?() }

    override func resetCursorRects() {
        if acik { addCursorRect(bounds, cursor: .pointingHand) }
    }
}
