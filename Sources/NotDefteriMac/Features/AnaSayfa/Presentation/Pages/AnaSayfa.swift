import AppKit
import NotDefteriCekirdek

struct AnaSayfaKarti {
    let url: URL
    let tarih: Date?
}

/// Pencere genişliğine göre sütun sayısını seçen kart ızgarası.
enum KartIzgarasi {
    static let aralik: CGFloat = 12

    /// Sığan sütun sayısı (en az 1) ve kartların ortak genişliği.
    static func olc(genislik: CGFloat, enAzKart: CGFloat) -> (sutun: Int, kart: CGFloat) {
        let sutun = max(1, Int((genislik + aralik) / (enAzKart + aralik)))
        return (sutun, max(0, (genislik - aralik * CGFloat(sutun - 1)) / CGFloat(sutun)))
    }

    /// Kartların ızgaradaki çerçeveleri (üstten aşağı, y yukarıdan); toplam yükseklik ile.
    static func cerceveler(adet: Int, genislik: CGFloat, enAzKart: CGFloat, yukseklik: CGFloat)
        -> (cerceveler: [NSRect], yukseklik: CGFloat, sutun: Int) {
        let (sutun, kart) = olc(genislik: genislik, enAzKart: enAzKart)
        let cerceveler = (0..<adet).map { sira in
            NSRect(x: CGFloat(sira % sutun) * (kart + aralik), y: CGFloat(sira / sutun) * (yukseklik + aralik),
                   width: kart, height: yukseklik)
        }
        let satir = (adet + sutun - 1) / sutun
        return (cerceveler, satir == 0 ? 0 : CGFloat(satir) * yukseklik + CGFloat(satir - 1) * aralik, sutun)
    }
}

/// Selam, tarih ve canlı saat; altında son açılan sayfalar ve hızlı eylemler kart ızgarasında.
/// Pencere daralıp genişledikçe kartlar yeni sütun düzenine kayarak geçer.
final class AnaSayfa: NSScrollView {
    var sayfaAc: ((URL) -> Void)?
    var yeniSayfa: (() -> Void)?
    var gunlukNot: (() -> Void)?
    var sablonSec: (() -> Void)?

    private let belge = AnaSayfaBelgesi()
    private var sonlar: [AnaSayfaKarti] = []
    private let selam = NSTextField(labelWithString: "")
    private let tarih = NSTextField(labelWithString: "")
    private let saat = NSTextField(labelWithString: "")
    private lazy var selamSatiri = SelamSatiri(selam: selam, tarih: tarih, saat: saat)
    private var saatZamanlayicisi: Timer?

    private static let tarihBicimi: DateFormatter = {
        let bicim = DateFormatter()
        bicim.locale = Locale(identifier: "tr_TR")
        bicim.dateFormat = "d MMMM yyyy, EEEE"
        return bicim
    }()
    private static let saatBicimi: DateFormatter = {
        let bicim = DateFormatter()
        bicim.locale = Locale(identifier: "tr_TR")
        bicim.dateFormat = "HH:mm:ss"
        return bicim
    }()
    private static let goreliTarih: RelativeDateTimeFormatter = {
        let bicim = RelativeDateTimeFormatter()
        bicim.locale = Locale(identifier: "tr_TR")
        bicim.unitsStyle = .full
        return bicim
    }()

    private var metinRengi: NSColor {
        let renk = aktifTema.arkaplan.usingColorSpace(.genericRGB)
        let parlaklik = (renk?.redComponent ?? 1) * 0.2126 + (renk?.greenComponent ?? 1) * 0.7152 + (renk?.blueComponent ?? 1) * 0.0722
        return parlaklik < 0.45 ? .white : .black
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        hasVerticalScroller = true
        kagitKaydiriciKullan()
        drawsBackground = false
        borderType = .noBorder
        documentView = belge
        saat.font = .monospacedDigitSystemFont(ofSize: 40, weight: .light)
    }

    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    override func menu(for event: NSEvent) -> NSMenu? {
        gorunumBaglamMenusunuEkle(super.menu(for: event) ?? NSMenu(), hedef: window as? NotPenceresi)
    }

    func guncelle(sonlar: [AnaSayfaKarti]) {
        self.sonlar = sonlar
        temayiUygula()
    }

    func basaDon() {
        tile()
        belge.layoutSubtreeIfNeeded()
        contentView.scroll(to: .zero)
        reflectScrolledClipView(contentView)
    }

    /// Belge her zaman görünür genişliği doldurur; yüksekliği içeriğe göre uzar.
    override func tile() {
        super.tile()
        let genislik = contentView.bounds.width
        let boyut = NSSize(width: genislik, height: max(contentView.bounds.height, belge.icerikYuksekligi(genislik)))
        if belge.frame.size != boyut {
            belge.setFrameSize(boyut)
            belge.needsLayout = true
        }
    }

    // MARK: Saat

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        saatiAyarla()
    }

    override func viewDidHide() {
        super.viewDidHide()
        saatiAyarla()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        saatiAyarla()
    }

    /// Saat yalnızca Ana Sayfa görünürken saniyede bir ilerler.
    private func saatiAyarla() {
        let gorunur = window != nil && !isHiddenOrHasHiddenAncestor
        guard gorunur != (saatZamanlayicisi != nil) else { return }
        saatZamanlayicisi?.invalidate()
        saatZamanlayicisi = nil
        guard gorunur else { return }
        saatiYaz()
        let zamanlayici = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.saatiYaz() }
        zamanlayici.tolerance = 0.1
        RunLoop.main.add(zamanlayici, forMode: .common)
        saatZamanlayicisi = zamanlayici
    }

    private func saatiYaz() {
        let simdi = Date()
        saat.stringValue = Self.saatBicimi.string(from: simdi)
        selam.stringValue = Self.selam(simdi)
        tarih.stringValue = Self.tarihBicimi.string(from: simdi)
        // Selam saat dilimiyle değişir; elle dizilen satır yeni genişliği kendiliğinden görmez.
        selamSatiri.needsLayout = true
    }

    private static func selam(_ tarih: Date) -> String {
        let saat = Calendar.current.component(.hour, from: tarih)
        return saat < 12 ? "Günaydın" : saat < 18 ? "İyi günler" : "İyi akşamlar"
    }

    // MARK: İçerik

    func temayiUygula() {
        let kaydirmaKonumu = contentView.bounds.origin
        wantsLayer = true
        layer?.backgroundColor = aktifTema.arkaplan.cgColor
        let renk = metinRengi
        let zemin = aktifTema.kenarPanel

        selam.font = .systemFont(ofSize: 30, weight: .bold)
        selam.textColor = renk.withAlphaComponent(0.92)
        tarih.font = .systemFont(ofSize: 14)
        tarih.textColor = renk.withAlphaComponent(0.6)
        saat.textColor = renk.withAlphaComponent(0.85)
        saatiYaz()

        var satirlar: [AnaSayfaBelgesi.Satir] = [
            .tek(selamSatiri, yukseklik: SelamSatiri.yukseklik, ustBosluk: 0),
            .tek(bolumBasligi("Son açılanlar", renk: renk), yukseklik: 24, ustBosluk: 26)
        ]
        if sonlar.isEmpty {
            satirlar.append(.tek(etiket("Henüz açılmış sayfa yok.", boyut: 13, renk: renk.withAlphaComponent(0.6)),
                                 yukseklik: 20, ustBosluk: 10))
        } else {
            let kartlar = sonlar.map { veri in
                sayfaKarti(veri, renk: renk, zemin: zemin)
            }
            satirlar.append(.izgara(kartlar, enAzKart: 150, yukseklik: 92, ustBosluk: 12))
        }
        satirlar.append(.tek(bolumBasligi("Hızlı eylemler", renk: renk), yukseklik: 24, ustBosluk: 28))
        let eylemler: [(String, String, NSColor, () -> Void)] = [
            ("Yeni sayfa", "square.and.pencil", .systemBlue, { [weak self] in self?.yeniSayfa?() }),
            ("Günlük not", "calendar", .systemOrange, { [weak self] in self?.gunlukNot?() }),
            ("Şablondan…", "doc.on.doc", .systemPurple, { [weak self] in self?.sablonSec?() })
        ]
        satirlar.append(.izgara(eylemler.map { ad, sembol, vurgu, eylem in
            eylemKarti(ad, sembol: sembol, vurgu: vurgu, renk: renk, zemin: zemin, eylem: eylem)
        }, enAzKart: 170, yukseklik: 52, ustBosluk: 12))

        belge.satirlar = satirlar
        tile()
        belge.layoutSubtreeIfNeeded()
        contentView.scroll(to: kaydirmaKonumu)
        reflectScrolledClipView(contentView)
    }

    private func etiket(_ metin: String, boyut: CGFloat, kalin: Bool = false, renk: NSColor) -> NSTextField {
        let alan = NSTextField(labelWithString: metin)
        alan.font = .systemFont(ofSize: boyut, weight: kalin ? .semibold : .regular)
        alan.textColor = renk
        alan.lineBreakMode = .byTruncatingTail
        return alan
    }

    private func bolumBasligi(_ ad: String, renk: NSColor) -> NSTextField {
        etiket(ad, boyut: 17, kalin: true, renk: renk.withAlphaComponent(0.9))
    }

    private func sayfaKarti(_ veri: AnaSayfaKarti, renk: NSColor, zemin: NSColor) -> AnaSayfaKartGorunumu {
        let ad = sayfaAdi(veri.url)
        let yol = sayfaBagYolu(veri.url)
        let kart = AnaSayfaKartGorunumu(zemin: zemin, vurgu: Self.sayfaRengi(ad), renk: renk) { [weak self] in
            self?.sayfaAc?(veri.url)
        }
        kart.setAccessibilityLabel("Sayfayı aç: \(ad)")
        kart.toolTip = yol
        let zaman = veri.tarih.map { Self.goreliTarih.localizedString(for: $0, relativeTo: Date()) } ?? "Daha önce açıldı"
        let klasor = (yol as NSString).deletingLastPathComponent
        kart.icerikKur(sembol: "doc.text", baslik: ad, ust: zaman, alt: klasor.isEmpty ? "Notlar" : klasor)
        return kart
    }

    private func eylemKarti(_ ad: String, sembol: String, vurgu: NSColor, renk: NSColor, zemin: NSColor,
                            eylem: @escaping () -> Void) -> AnaSayfaKartGorunumu {
        let kart = AnaSayfaKartGorunumu(zemin: zemin, vurgu: vurgu, renk: renk, eylem: eylem)
        kart.setAccessibilityLabel(ad)
        kart.icerikKur(sembol: sembol, baslik: ad, ust: nil, alt: nil)
        return kart
    }

    /// Sayfa adından kararlı renk; aynı sayfa her açılışta aynı renkte görünür.
    static func sayfaRengi(_ ad: String) -> NSColor {
        let renkler: [NSColor] = [.systemBlue, .systemPurple, .systemPink, .systemOrange,
                                  .systemTeal, .systemGreen, .systemIndigo, .systemRed]
        let toplam = ad.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return renkler[toplam % renkler.count]
    }
}

/// Solda selam ve altında tarih; saat, sol bloğun bitişiyle sağ kenar arasının tam ortasında.
/// Yer daraldıkça saat sağ kenara yaslanır, selam ve tarih kısalır; saat hep tam görünür.
/// Tarih saatin altına kaymasın diye üçü aynı görünümde dizilir.
/// Auto Layout (NSStackView) elle dizilen belgenin içinde çözülmediği için yerleşim elle yapılır.
private final class SelamSatiri: NSView {
    private let selam: NSTextField
    private let tarih: NSTextField
    private let saat: NSTextField
    private static let aralik: CGFloat = 16
    /// Saat, selamın üst kenarından bu kadar aşağıda başlar; iki satırlık sol sütunla dengeli durur.
    private static let saatUstPayi: CGFloat = 15
    private static let selamYuksekligi: CGFloat = 50
    private static let tarihYuksekligi: CGFloat = 20
    static let yukseklik: CGFloat = selamYuksekligi + 2 + tarihYuksekligi

    init(selam: NSTextField, tarih: NSTextField, saat: NSTextField) {
        self.selam = selam
        self.tarih = tarih
        self.saat = saat
        super.init(frame: .zero)
        selam.lineBreakMode = .byTruncatingTail
        tarih.lineBreakMode = .byTruncatingTail
        addSubview(selam)
        addSubview(tarih)
        addSubview(saat)
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }

    /// Pencere boyutu değişince saat yeni ortaya taşınır; elle yerleşimde bu kendiliğinden olmaz.
    override func setFrameSize(_ yeniBoyut: NSSize) {
        super.setFrameSize(yeniBoyut)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        // intrinsicContentSize hizalama dikdörtgenidir; etiketin kenar payı eklenmezse metin "…" ile kesilir.
        func boyut(_ etiket: NSTextField) -> NSSize {
            etiket.frame(forAlignmentRect: NSRect(origin: .zero, size: etiket.intrinsicContentSize)).size
        }
        let saatBoyutu = boyut(saat)
        let solGenislik = max(0, bounds.width - saatBoyutu.width - Self.aralik)
        let selamBoyutu = boyut(selam)
        let selamGenisligi = min(selamBoyutu.width, solGenislik)
        let tarihGenisligi = min(boyut(tarih).width, solGenislik)
        // Saat, sol bloğun bitişiyle sağ kenar arasının ortasında; en az `aralik` kadar uzak durur.
        let solBitis = max(selamGenisligi, tarihGenisligi)
        let saatX = solBitis + max(Self.aralik, (bounds.width - solBitis - saatBoyutu.width) / 2)
        saat.frame = NSRect(x: saatX, y: Self.saatUstPayi, width: saatBoyutu.width, height: saatBoyutu.height)
        // Selam, saatin eski (üst paysız) yerindeki taban çizgisinde kalır.
        let taban = saat.firstBaselineOffsetFromTop - selam.firstBaselineOffsetFromTop
        selam.frame = NSRect(x: 0, y: taban, width: selamGenisligi, height: selamBoyutu.height)
        tarih.frame = NSRect(x: 0, y: Self.selamYuksekligi + 2, width: tarihGenisligi, height: Self.tarihYuksekligi)
    }
}

/// Ana Sayfa içeriğini elle dizer: tek satırlar tam genişlikte, ızgaralar sütunlara bölünür.
private final class AnaSayfaBelgesi: NSView {
    enum Satir {
        case tek(NSView, yukseklik: CGFloat, ustBosluk: CGFloat)
        case izgara([NSView], enAzKart: CGFloat, yukseklik: CGFloat, ustBosluk: CGFloat)
    }

    static let yanPay: CGFloat = 28
    static let ustPay: CGFloat = 28

    var satirlar: [Satir] = [] {
        didSet {
            subviews.forEach { $0.removeFromSuperview() }
            for satir in satirlar {
                switch satir {
                case .tek(let gorunum, _, _): addSubview(gorunum)
                case .izgara(let kartlar, _, _, _): kartlar.forEach(addSubview)
                }
            }
            needsLayout = true
        }
    }
    /// Son yerleşimdeki sütun sayıları; değişince kartlar kayarak yer değiştirir.
    private var sutunlar: [Int] = []

    override var isFlipped: Bool { true }
    override func menu(for event: NSEvent) -> NSMenu? {
        gorunumBaglamMenusunuEkle(super.menu(for: event) ?? NSMenu(), hedef: window as? NotPenceresi)
    }

    func icerikYuksekligi(_ genislik: CGFloat) -> CGFloat { yerlesim(genislik).yukseklik }

    private func yerlesim(_ genislik: CGFloat) -> (cerceveler: [(NSView, NSRect)], yukseklik: CGFloat, sutunlar: [Int]) {
        let icGenislik = max(0, genislik - Self.yanPay * 2)
        var y = Self.ustPay
        var cerceveler: [(NSView, NSRect)] = []
        var sutunlar: [Int] = []
        for satir in satirlar {
            switch satir {
            case .tek(let gorunum, let yukseklik, let ustBosluk):
                y += ustBosluk
                cerceveler.append((gorunum, NSRect(x: Self.yanPay, y: y, width: icGenislik, height: yukseklik)))
                y += yukseklik
            case .izgara(let kartlar, let enAz, let yukseklik, let ustBosluk):
                y += ustBosluk
                let izgara = KartIzgarasi.cerceveler(adet: kartlar.count, genislik: icGenislik, enAzKart: enAz, yukseklik: yukseklik)
                for (kart, cerceve) in zip(kartlar, izgara.cerceveler) {
                    cerceveler.append((kart, cerceve.offsetBy(dx: Self.yanPay, dy: y)))
                }
                sutunlar.append(izgara.sutun)
                y += izgara.yukseklik
            }
        }
        return (cerceveler, y + Self.ustPay, sutunlar)
    }

    override func layout() {
        super.layout()
        let sonuc = yerlesim(bounds.width)
        // Sütun düzeni değişince kartlar yeni yerlerine kayar; aynı düzende genişlik
        // değişimi pencereyi gecikmesiz izler. Sıfır süre süren animasyonları da keser.
        let animasyonlu = !sutunlar.isEmpty && sutunlar != sonuc.sutunlar && window != nil
        sutunlar = sonuc.sutunlar
        NSAnimationContext.runAnimationGroup { baglam in
            baglam.duration = animasyonlu ? 0.3 : 0
            baglam.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for (gorunum, cerceve) in sonuc.cerceveler where gorunum.frame != cerceve {
                if gorunum.frame == .zero { gorunum.frame = cerceve } else { gorunum.animator().frame = cerceve }
            }
        }
    }
}

/// Tıklanabilir kart: simge, başlık, isteğe bağlı üst ve alt satır; üzerine gelince belirginleşir.
private final class AnaSayfaKartGorunumu: NSButton {
    private let eylem: () -> Void
    private let zemin: NSColor
    private let vurgu: NSColor
    private let renk: NSColor
    private let icerik = KartIcerigi()
    private var uzerinde = false { didSet { gorunumuGuncelle() } }

    init(zemin: NSColor, vurgu: NSColor, renk: NSColor, eylem: @escaping () -> Void) {
        self.eylem = eylem
        self.zemin = zemin
        self.vurgu = vurgu
        self.renk = renk
        super.init(frame: .zero)
        title = ""
        isBordered = false
        target = self
        action = #selector(tiklandi)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 6
        icerik.frame = bounds
        icerik.autoresizingMask = [.width, .height]
        addSubview(icerik)
        gorunumuGuncelle()
    }

    required init?(coder: NSCoder) { fatalError() }

    func icerikKur(sembol: String, baslik: String, ust: String?, alt: String?) {
        icerik.kur(sembol: sembol, baslik: baslik, ust: ust, alt: alt, vurgu: vurgu, renk: renk)
        if ust == nil, alt == nil { toolTip = toolTip ?? baslik }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { uzerinde = true }
    override func mouseExited(with event: NSEvent) { uzerinde = false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    private func gorunumuGuncelle() {
        NSAnimationContext.runAnimationGroup { baglam in
            baglam.duration = 0.15
            baglam.allowsImplicitAnimation = true
            layer?.backgroundColor = (uzerinde ? zemin.blended(withFraction: 0.06, of: renk) ?? zemin : zemin).cgColor
            layer?.borderColor = vurgu.withAlphaComponent(uzerinde ? 0.7 : 0.18).cgColor
            layer?.shadowOpacity = uzerinde ? 0.16 : 0.05
        }
    }

    @objc private func tiklandi() { eylem() }
}

/// Kartın içi; üstten aşağı dizilir.
private final class KartIcerigi: NSView {
    private let simgeZemini = NSView()
    private let simge = NSImageView()
    private let baslik = NSTextField(labelWithString: "")
    private let ust = NSTextField(labelWithString: "")
    private let alt = NSTextField(labelWithString: "")
    private var buyuk = false

    override var isFlipped: Bool { true }

    func kur(sembol: String, baslik metin: String, ust ustMetin: String?, alt altMetin: String?, vurgu: NSColor, renk: NSColor) {
        buyuk = ustMetin != nil || altMetin != nil
        simgeZemini.wantsLayer = true
        simgeZemini.layer?.cornerRadius = 8
        simgeZemini.layer?.backgroundColor = vurgu.withAlphaComponent(0.16).cgColor
        simge.image = NSImage(systemSymbolName: sembol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .semibold))
        simge.contentTintColor = vurgu
        baslik.stringValue = metin
        baslik.font = .systemFont(ofSize: 13, weight: .semibold)
        baslik.textColor = renk.withAlphaComponent(0.92)
        for (alan, deger) in [(ust, ustMetin), (alt, altMetin)] {
            alan.stringValue = deger ?? ""
            alan.isHidden = deger == nil
            alan.font = .systemFont(ofSize: 11)
            alan.textColor = renk.withAlphaComponent(0.55)
        }
        for alan in [baslik, ust, alt] { alan.lineBreakMode = .byTruncatingTail }
        alt.lineBreakMode = .byTruncatingMiddle
        [simgeZemini, simge, baslik, ust, alt].forEach { if $0.superview == nil { addSubview($0) } }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let pay: CGFloat = 12
        let w = max(0, bounds.width - pay * 2)
        if buyuk {
            simgeZemini.frame = NSRect(x: pay, y: 12, width: 26, height: 26)
            ust.frame = NSRect(x: pay + 34, y: 17, width: max(0, w - 34), height: 16)
            baslik.frame = NSRect(x: pay, y: 46, width: w, height: 20)
            alt.frame = NSRect(x: pay, y: 68, width: w, height: 16)
        } else {
            simgeZemini.frame = NSRect(x: 12, y: (bounds.height - 30) / 2, width: 30, height: 30)
            baslik.frame = NSRect(x: 52, y: (bounds.height - 18) / 2, width: max(0, bounds.width - 64), height: 18)
        }
        simge.frame = simgeZemini.frame.insetBy(dx: 6, dy: 6)
    }
}
