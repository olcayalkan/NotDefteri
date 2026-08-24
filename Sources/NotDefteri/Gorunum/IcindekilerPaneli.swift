import AppKit

/// Notun başlıklarından üretilen, sağ kenarda duran içindekiler paneli.
///
/// Daraltılmış hâlde yalnızca seviyeye göre kısalan çizgiler gösterir; fare
/// üzerine gelince metinleri açar (Notion'daki gibi). Bir satıra tıklamak
/// metni o başlığa kaydırır.
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
    /// Metinde o an görünen/imlecin bulunduğu başlığın sırası.
    private var etkinSira: Int?
    private var acik = false
    private var izlemeAlani: NSTrackingArea?
    private var satirlar: [SatirGorunumu] = []

    static let daraltilmisGenislik: CGFloat = 26
    static let acikGenislik: CGFloat = 190
    private let satirYuksekligi: CGFloat = 22

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

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

    /// İmlecin bulunduğu başlığı vurgular.
    func etkinBasligiGuncelle(imlecKonumu: Int) {
        let yeni = girdiler.lastIndex { $0.konum <= imlecKonumu }
        guard yeni != etkinSira else { return }
        etkinSira = yeni
        for (sira, satir) in satirlar.enumerated() {
            satir.etkin = (sira == yeni)
        }
    }

    // MARK: Satırlar

    private func satirlariKur() {
        satirlar.forEach { $0.removeFromSuperview() }
        satirlar = girdiler.enumerated().map { sira, girdi in
            let satir = SatirGorunumu(girdi: girdi)
            satir.tiklandi = { [weak self] in
                self?.basligaGitIstendi?(girdi.konum)
            }
            satir.etkin = (sira == etkinSira)
            addSubview(satir)
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
            baglam.duration = 0.16
            baglam.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().frame = hedefKare()
            layer?.backgroundColor = yeniDurum
                ? aktifTema.kenarPanel.withAlphaComponent(0.92).cgColor
                : NSColor.clear.cgColor
            for satir in satirlar { satir.acikGoster(yeniDurum) }
        }
        needsLayout = true
    }

    /// Panelin o anki hâline göre olması gereken çerçevesi.
    /// Sağ kenara yaslıdır; açılırken sola doğru büyür.
    func hedefKare() -> NSRect {
        guard let ust = superview else { return frame }
        let genislik = acik ? Self.acikGenislik : Self.daraltilmisGenislik
        let yukseklik = min(CGFloat(max(girdiler.count, 1)) * satirYuksekligi + 12,
                            ust.bounds.height - kBaslikYuksekligi - 24)
        return NSRect(x: ust.bounds.width - genislik - 6,
                      y: (ust.bounds.height - kBaslikYuksekligi - yukseklik) / 2,
                      width: genislik,
                      height: yukseklik)
    }

    override func layout() {
        super.layout()
        for (sira, satir) in satirlar.enumerated() {
            satir.frame = NSRect(x: 0,
                                  y: bounds.height - 6 - CGFloat(sira + 1) * satirYuksekligi,
                                  width: bounds.width,
                                  height: satirYuksekligi)
        }
    }

    func temayiUygula() {
        if acik { layer?.backgroundColor = aktifTema.kenarPanel.withAlphaComponent(0.92).cgColor }
        satirlar.forEach { $0.temayiUygula() }
    }
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
        case 1: return 14
        case 2: return 10
        default: return 6
        }
    }

    /// Metin girintisi de düzeye göre artar.
    private var girinti: CGFloat {
        CGFloat(girdi.seviye - 1) * 10
    }

    init(girdi: IcindekilerPaneli.Girdi) {
        self.girdi = girdi
        super.init(frame: .zero)
        wantsLayer = true

        cizgi.wantsLayer = true
        cizgi.layer?.cornerRadius = 1
        addSubview(cizgi)

        etiket.stringValue = girdi.metin
        etiket.font = NSFont.systemFont(ofSize: girdi.seviye == 1 ? 11.5 : 11,
                                         weight: girdi.seviye == 1 ? .medium : .regular)
        etiket.lineBreakMode = .byTruncatingTail
        etiket.alphaValue = 0
        addSubview(etiket)

        gorunumuTazele()
    }

    required init?(coder: NSCoder) { fatalError() }

    func acikGoster(_ acikMi: Bool) {
        acik = acikMi
        etiket.animator().alphaValue = acikMi ? 1 : 0
        cizgi.animator().alphaValue = acikMi ? 0 : 1
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let y = (bounds.height - 2) / 2
        cizgi.frame = NSRect(x: bounds.width - cizgiUzunlugu - 8, y: y, width: cizgiUzunlugu, height: 2)
        etiket.frame = NSRect(x: 10 + girinti, y: (bounds.height - 15) / 2,
                              width: max(0, bounds.width - 18 - girinti), height: 15)
    }

    private func gorunumuTazele() {
        let koyuluk: CGFloat = etkin ? 0.85 : (farePanelde ? 0.6 : 0.35)
        cizgi.layer?.backgroundColor = NSColor.black.withAlphaComponent(koyuluk).cgColor
        etiket.textColor = NSColor.black.withAlphaComponent(etkin ? 0.9 : 0.6)
        layer?.backgroundColor = farePanelde && acik
            ? NSColor.black.withAlphaComponent(0.06).cgColor
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

    override func mouseEntered(with event: NSEvent) {
        farePanelde = true
        gorunumuTazele()
    }

    override func mouseExited(with event: NSEvent) {
        farePanelde = false
        gorunumuTazele()
    }

    override func mouseDown(with event: NSEvent) { tiklandi?() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
