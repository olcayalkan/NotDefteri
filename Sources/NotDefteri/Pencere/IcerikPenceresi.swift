import AppKit
import NotDefteriCekirdek

// MARK: - İçerik penceresi

/// Kenar panelde sayfaya üç kez tıklayınca açılan, yalnızca sayfa içeriğini gösteren pencere:
/// kenar panel, başlık çubuğu düğmeleri ve alt bilgi yoktur.
///
/// Salt okunurdur. Aynı sayfa ana pencerede de açıkken iki editörün aynı dosyaya yazması
/// birinin kaydını ezerdi. Ana penceredeki düzenleme kaydedildikten sonra bu pencere öne
/// gelince dosyadan yenilenir.
final class IcerikPenceresi: NSWindow {
    /// Pencereler kapanana kadar burada tutulur; aynı sayfa ikinci kez açılmaz, öne gelir.
    private static var acikPencereler: [IcerikPenceresi] = []

    let sayfaURL: URL
    let metinGorunumu = NotMetinGorunumu(frame: .zero)
    private let kaydirma = NSScrollView()
    private var sonOkunan: Date?

    static func ac(_ url: URL, yanindaki: NSWindow?) {
        if let acik = acikPencereler.first(where: { $0.sayfaURL == url }) {
            acik.makeKeyAndOrderFront(nil)
            return
        }
        let pencere = IcerikPenceresi(sayfaURL: url)
        acikPencereler.append(pencere)
        if let yanindaki {
            pencere.setFrameTopLeftPoint(NSPoint(x: yanindaki.frame.minX + 40, y: yanindaki.frame.maxY - 40))
        } else {
            pencere.center()
        }
        pencere.makeKeyAndOrderFront(nil)
    }

    private init(sayfaURL: URL) {
        self.sayfaURL = sayfaURL
        super.init(contentRect: NSRect(x: 0, y: 0, width: 760, height: 820),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        // Yalnızca içerik: başlık yazısı ve çubuk görünmez, pencere menüsünde ad yine durur.
        title = sayfaAdi(sayfaURL)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        minSize = NSSize(width: 360, height: 240)

        kaydirma.hasVerticalScroller = true
        kaydirma.kagitKaydiriciKullan()
        kaydirma.drawsBackground = false
        kaydirma.borderType = .noBorder
        kaydirma.autoresizingMask = [.width, .height]
        kaydirma.frame = contentView?.bounds ?? .zero
        contentView?.addSubview(kaydirma)

        metinGorunumu.frame = NSRect(origin: .zero, size: kaydirma.contentSize)
        metinGorunumu.autoresizingMask = [.width]
        metinGorunumu.minSize = NSSize(width: 0, height: kaydirma.contentSize.height)
        metinGorunumu.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        metinGorunumu.isVerticallyResizable = true
        metinGorunumu.isHorizontallyResizable = false
        metinGorunumu.textContainer?.widthTracksTextView = false
        metinGorunumu.isRichText = true
        metinGorunumu.isEditable = false
        metinGorunumu.isSelectable = true
        metinGorunumu.linkTextAttributes = bagOznitelikleri()
        kaydirma.documentView = metinGorunumu

        temayiUygula()
        icerigiYukle()
        NotificationCenter.default.addObserver(self, selector: #selector(boyutDegisti), name: NSWindow.didResizeNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(oneGeldi), name: NSWindow.didBecomeKeyNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(temaDegisti), name: .notDefteriTemaDegisti, object: nil)
    }

    override func close() {
        NotificationCenter.default.removeObserver(self)
        super.close()
        Self.acikPencereler.removeAll { $0 === self }
    }

    /// Ana penceredeki gibi okunur genişlikte (en çok 760 pt) ve ortada.
    @objc private func boyutDegisti() {
        guard let kap = metinGorunumu.textContainer else { return }
        let genislik = kaydirma.contentSize.width
        let kapGenisligi = max(1, min(760, genislik - 96))
        metinGorunumu.textContainerInset = NSSize(width: max(0, (genislik - kapGenisligi) / 2), height: 40)
        if kap.size.width != kapGenisligi {
            kap.size = NSSize(width: kapGenisligi, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    @objc private func oneGeldi() {
        if sonOkunan != degistirilmeTarihi(sayfaURL) { icerigiYukle() }
    }

    @objc private func temaDegisti() { temayiUygula() }

    private func temayiUygula() {
        backgroundColor = aktifTema.arkaplan
        metinGorunumu.backgroundColor = aktifTema.arkaplan
        metinGorunumu.linkTextAttributes = bagOznitelikleri()
        metinGorunumu.belgeGorunumunuYenile()
        metinGorunumu.sayfaBaglariniBoya()
    }

    private func icerigiYukle() {
        guard let icerik = try? String(contentsOf: sayfaURL, encoding: .utf8) else { return }
        let sayfa = sayfaUstbilgisiniAyir(icerik)
        metinGorunumu.sayfaYukleniyor = true
        metinGorunumu.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(sayfa.govde, taban: sayfaKlasoru(sayfaURL)))
        metinGorunumu.sayfaYukleniyor = false
        metinGorunumu.sayfaYaziOlceginiUygula(kucuk: sayfa.bilgi.yazi == "kucuk")
        sonOkunan = degistirilmeTarihi(sayfaURL)
        metinGorunumu.sayfaBaglariniBoya()
        boyutDegisti()
    }
}

extension Notification.Name {
    /// Tema seçilince ana pencere dışındaki pencereler (içerik penceresi) renklerini yeniler.
    static let notDefteriTemaDegisti = Notification.Name("NotDefteri.temaDegisti")
}
