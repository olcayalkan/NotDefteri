import AppKit
import NotDefteriCekirdek

// MARK: - Görsel eki (tutamaçlarından çekilerek boyutlandırılabilir)

let kEnKucukResimEni: CGFloat = 48
let kEnKucukResimBoyu: CGFloat = 24
let kEnBuyukResimBoyutu: CGFloat = 10_000

func resimBoyutuGecerliMi(_ boyut: NSSize) -> Bool {
    boyut.width.isFinite && boyut.height.isFinite
        && boyut.width >= 1 && boyut.height >= 1
        && boyut.width <= kEnBuyukResimBoyutu && boyut.height <= kEnBuyukResimBoyutu
}

/// Görselin tutulduğu yer: kenarlar o yönde uzatır (sol/sağ eni, üst/alt boyu), köşeler
/// oranı koruyarak bütün görseli büyütür. `yatay`: -1 sol, 1 sağ; `dikey`: -1 üst, 1 alt
/// (metin görünümü ters çevrili, y aşağı doğru artar).
struct ResimTutamaci: Equatable {
    let yatay: CGFloat
    let dikey: CGFloat

    var koseMi: Bool { yatay != 0 && dikey != 0 }

    var imlec: NSCursor {
        if dikey == 0 { return .resizeLeftRight }
        if yatay == 0 { return .resizeUpDown }
        if #available(macOS 15.0, *) {
            let konum: NSCursor.FrameResizePosition = dikey < 0
                ? (yatay < 0 ? .topLeft : .topRight) : (yatay < 0 ? .bottomLeft : .bottomRight)
            return .frameResize(position: konum, directions: .all)
        }
        // macOS 12-14'te hazır çapraz imleç yok; yön oku sembolden çizilir.
        return yatay == dikey ? Self.solUstSagAlt : Self.sagUstSolAlt
    }

    private static let solUstSagAlt = caprazImlec("arrow.up.left.and.arrow.down.right")
    private static let sagUstSolAlt = caprazImlec("arrow.up.right.and.arrow.down.left")

    /// Beyaz kenarlı siyah çapraz ok; her zeminde seçilir, sıcak nokta ortada.
    private static func caprazImlec(_ sembol: String) -> NSCursor {
        let boyut = NSSize(width: 24, height: 24)
        let resim = NSImage(size: boyut, flipped: false) { alan in
            func simge(_ renk: NSColor) -> NSImage? {
                NSImage(systemSymbolName: sembol, accessibilityDescription: nil)?
                    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
                        .applying(NSImage.SymbolConfiguration(paletteColors: [renk])))
            }
            guard let beyaz = simge(.white), let siyah = simge(.black) else { return false }
            let kare = NSRect(x: (alan.width - beyaz.size.width) / 2, y: (alan.height - beyaz.size.height) / 2,
                              width: beyaz.size.width, height: beyaz.size.height)
            for (dx, dy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { beyaz.draw(in: kare.offsetBy(dx: dx, dy: dy)) }
            siyah.draw(in: kare)
            return true
        }
        return NSCursor(image: resim, hotSpot: NSPoint(x: boyut.width / 2, y: boyut.height / 2))
    }

    /// Başlangıç boyutuna, farenin başlangıçtan kayması (`fark`) uygulanır.
    func yeniBoyut(baslangic: NSSize, fark: NSPoint, enAz: NSSize, enFazla: NSSize) -> NSSize {
        func sinirla(_ deger: CGFloat, _ alt: CGFloat, _ ust: CGFloat) -> CGFloat { min(max(deger, alt), max(alt, ust)) }
        let dx = fark.x * yatay, dy = fark.y * dikey
        guard koseMi else {
            return NSSize(width: yatay == 0 ? baslangic.width : sinirla(baslangic.width + dx, enAz.width, enFazla.width).rounded(),
                          height: dikey == 0 ? baslangic.height : sinirla(baslangic.height + dy, enAz.height, enFazla.height).rounded())
        }
        // Köşe: farenin daha çok gittiği yön ölçeği belirler, görselin o anki oranı korunur.
        let oran = baslangic.width / max(1, baslangic.height)
        let olcek = abs(dx) >= abs(dy) * oran ? (baslangic.width + dx) / baslangic.width
                                               : (baslangic.height + dy) / baslangic.height
        let enAzOlcek = max(enAz.width / baslangic.width, enAz.height / baslangic.height)
        let enFazlaOlcek = min(enFazla.width / baslangic.width, enFazla.height / baslangic.height)
        let sinirli = sinirla(olcek, enAzOlcek, enFazlaOlcek)
        return NSSize(width: max(1, (baslangic.width * sinirli).rounded()), height: max(1, (baslangic.height * sinirli).rounded()))
    }
}

/// Metnin içine gömülen görsel. Dosya yolunu ve gösterim boyutunu taşır.
final class ResimEki: NSTextAttachment {
    var dosyaURL: URL?
    /// Boyutsuz Markdown'a geri dönüldüğünde diskten yeniden çözmeden kullanılır.
    var dogalGosterimBoyutu = NSSize(width: 200, height: 150)
    /// Notta yazılı olan bağ yolu ("Görseller/Başlık1.png"). Eski notların
    /// "ekler/..." bağlarını olduğu gibi korumak için saklanır.
    var bagYolu: String?

    var gosterimBoyutu: NSSize {
        get { (attachmentCell as? ResimEkiHucresi)?.gosterimBoyutu ?? .zero }
        set { (attachmentCell as? ResimEkiHucresi)?.gosterimBoyutu = newValue }
    }
}

/// Görseli çizen ve tutamaçlarından boyutlandırmayı yöneten hücre.
final class ResimEkiHucresi: NSTextAttachmentCell {

    var gosterimBoyutu: NSSize = NSSize(width: 200, height: 150) {
        didSet {
            if !resimBoyutuGecerliMi(gosterimBoyutu) { gosterimBoyutu = oldValue }
        }
    }
    /// Görselin kendi en/boy oranı; kenardan uzatılmamış görselin ilk boyutu bundan hesaplanır.
    var enBoyOrani: CGFloat = 4.0 / 3.0
    var tutamaclarGorunur = false
    private(set) var cizimCercevesi: NSRect = .zero
    private var boyutlandiriliyor = false

    override func cellSize() -> NSSize { gosterimBoyutu }

    /// Görsel, satırda kalan yere sığmıyorsa gösterilen oranı korunarak sığdırılır (kenardan
    /// uzatılmış görsel de uzatılmış hâliyle küçülür). Saklanan boyut değişmez; pencere
    /// genişleyince görsel eski boyutuna döner.
    override func cellFrame(for textContainer: NSTextContainer, proposedLineFragment lineFrag: NSRect,
                            glyphPosition position: NSPoint, characterIndex charIndex: Int) -> NSRect {
        var boyut = gosterimBoyutu
        let sigacakEn = max(kEnKucukResimEni, lineFrag.width - position.x)
        if boyut.width > sigacakEn {
            let oran = boyut.width / max(1, boyut.height)
            boyut = NSSize(width: sigacakEn.rounded(),
                           height: min(kEnBuyukResimBoyutu, max(1, (sigacakEn / oran).rounded())))
        }
        return NSRect(x: 0, y: cellBaselineOffset().y, width: boyut.width, height: boyut.height)
    }

    /// Görseli satırın taban çizgisine oturtur.
    override func cellBaselineOffset() -> NSPoint { NSPoint(x: 0, y: -3) }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        if controlView is NotMetinGorunumu { cizimCercevesi = cellFrame }
        // Görsel, köşeleri yuvarlak ve hafif gölgeli bir kart olarak çizilir. Gölge hücrenin
        // içinde kalır: dışına taşan gölge, yalnızca komşu satır yeniden çizilince siliniyordu.
        let kart = cellFrame.insetBy(dx: 4, dy: 4)
        let yol = NSBezierPath(roundedRect: kart, xRadius: 8, yRadius: 8)
        NSGraphicsContext.saveGraphicsState()
        let golge = NSShadow()
        golge.shadowColor = NSColor.black.withAlphaComponent(0.22)
        golge.shadowBlurRadius = 4
        golge.shadowOffset = NSSize(width: 0, height: -1.5)   // Gölge ekran uzayında: aşağı.
        golge.set()
        aktifTema.arkaplan.setFill()
        yol.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        yol.addClip()
        image?.draw(in: kart, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
        if tutamaclarGorunur || boyutlandiriliyor { tutamaclariCiz(cellFrame) }
    }

    /// Yalnızca tutamaçlar çizilir: köşelerde daire, kenar ortalarında çubuk. Beyaz dolgu,
    /// vurgu rengi kenar ve gölge, açık ya da koyu her görselin üstünde seçilir.
    private func tutamaclariCiz(_ cerceve: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let golge = NSShadow()
        golge.shadowColor = NSColor.black.withAlphaComponent(0.35)
        golge.shadowBlurRadius = 2
        golge.shadowOffset = NSSize(width: 0, height: -1)
        golge.set()
        NSColor.white.setFill()
        let yollar = tutamaclar(cerceve)
        yollar.forEach { $0.fill() }
        NSGraphicsContext.restoreGraphicsState()
        NSColor.controlAccentColor.setStroke()
        for yol in yollar {
            yol.lineWidth = 1.5
            yol.stroke()
        }
    }

    /// Tutamaç şekilleri; gölgeleriyle birlikte hücrenin içinde kalır (dışına taşan çizim
    /// yalnızca komşu satır yeniden çizilince silinir).
    private func tutamaclar(_ cerceve: NSRect) -> [NSBezierPath] {
        let kose = cerceve.insetBy(dx: 9, dy: 9), kart = cerceve.insetBy(dx: 6, dy: 6)
        let cap = min(12, cerceve.width / 4, cerceve.height / 4)
        let kalin: CGFloat = 6
        let dikeyBoy = min(28, kart.height / 3), yatayBoy = min(28, kart.width / 3)
        let koseler = [NSPoint(x: kose.minX, y: kose.minY), NSPoint(x: kose.maxX, y: kose.minY),
                       NSPoint(x: kose.minX, y: kose.maxY), NSPoint(x: kose.maxX, y: kose.maxY)]
        let daireler = koseler.map {
            NSBezierPath(ovalIn: NSRect(x: $0.x - cap / 2, y: $0.y - cap / 2, width: cap, height: cap))
        }
        let cubuklar = [
            NSRect(x: kart.minX - kalin / 2, y: kart.midY - dikeyBoy / 2, width: kalin, height: dikeyBoy),
            NSRect(x: kart.maxX - kalin / 2, y: kart.midY - dikeyBoy / 2, width: kalin, height: dikeyBoy),
            NSRect(x: kart.midX - yatayBoy / 2, y: kart.minY - kalin / 2, width: yatayBoy, height: kalin),
            NSRect(x: kart.midX - yatayBoy / 2, y: kart.maxY - kalin / 2, width: yatayBoy, height: kalin)
        ].map { NSBezierPath(roundedRect: $0, xRadius: kalin / 2, yRadius: kalin / 2) }
        return daireler + cubuklar
    }

    /// Kenar boyunca her yer tutulabilir (yalnız ortadaki çubuk değil); köşeler önceliklidir.
    /// Alanlar görünen tutamaçlardan geniştir: fare tam üstüne gelmeden de yakalar.
    func tutamac(noktada nokta: NSPoint, cerceve: NSRect) -> ResimTutamaci? {
        guard cerceve.contains(nokta) else { return nil }
        let kenar = min(12, cerceve.width / 3, cerceve.height / 3)
        let kose = min(18, cerceve.width / 3, cerceve.height / 3)
        func yon(_ deger: CGFloat, _ alt: CGFloat, _ ust: CGFloat, _ pay: CGFloat) -> CGFloat {
            deger < alt + pay ? -1 : (deger >= ust - pay ? 1 : 0)
        }
        let koseYatay = yon(nokta.x, cerceve.minX, cerceve.maxX, kose)
        let koseDikey = yon(nokta.y, cerceve.minY, cerceve.maxY, kose)
        if koseYatay != 0, koseDikey != 0 { return ResimTutamaci(yatay: koseYatay, dikey: koseDikey) }
        let yatay = yon(nokta.x, cerceve.minX, cerceve.maxX, kenar)
        if yatay != 0 { return ResimTutamaci(yatay: yatay, dikey: 0) }
        let dikey = yon(nokta.y, cerceve.minY, cerceve.maxY, kenar)
        if dikey != 0 { return ResimTutamaci(yatay: 0, dikey: dikey) }
        return nil
    }

    override func wantsToTrackMouse() -> Bool { true }

    override func trackMouse(with theEvent: NSEvent, in cellFrame: NSRect, of controlView: NSView?, untilMouseUp flag: Bool) -> Bool {
        guard let metinGorunumu = controlView as? NSTextView, metinGorunumu.isEditable,
              let pencere = metinGorunumu.window else { return false }
        let baslangicNoktasi = metinGorunumu.convert(theEvent.locationInWindow, from: nil)
        // Tutamacın dışına basıldıysa olağan davranış (seçme/sürükleme) sürsün.
        guard let tutulan = tutamac(noktada: baslangicNoktasi, cerceve: cellFrame) else { return false }
        guard let metinDeposu = metinGorunumu.textStorage,
              let ekIndeksi = ekinIndeksi(metinDeposu) else { return false }

        let baslangicBoyutu = gosterimBoyutu
        let baslangicAnlamsali = metinDeposu.attribute(kGorselAnahtari, at: ekIndeksi, effectiveRange: nil) as? [String: Any]
        // Satıra sığdırılan görsel, ilk harekette saklanan büyük boyutuna sıçramasın.
        let baslangicCercevesi = NSSize(width: max(1, cellFrame.width), height: max(1, cellFrame.height))
        let enFazla = NSSize(width: min(maksimumEn(metinGorunumu), kEnBuyukResimBoyutu).rounded(.down),
                             height: kEnBuyukResimBoyutu)
        let enAz = NSSize(width: min(enFazla.width, kEnKucukResimEni), height: kEnKucukResimBoyu)
        boyutlandiriliyor = true
        pencere.makeFirstResponder(metinGorunumu)
        tutulan.imlec.set()
        defer {
            boyutlandiriliyor = false
            metinGorunumu.needsDisplay = true
        }
        metinGorunumu.breakUndoCoalescing()

        while let olay = pencere.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if olay.type == .leftMouseUp { break }
            let nokta = metinGorunumu.convert(olay.locationInWindow, from: nil)
            let fark = NSPoint(x: nokta.x - baslangicNoktasi.x, y: nokta.y - baslangicNoktasi.y)
            let yeniBoyut = fark == .zero ? baslangicBoyutu
                : tutulan.yeniBoyut(baslangic: baslangicCercevesi, fark: fark, enAz: enAz, enFazla: enFazla)
            guard resimBoyutuGecerliMi(yeniBoyut), yeniBoyut != gosterimBoyutu else { continue }
            gosterimBoyutu = yeniBoyut
            yerlesimiTazele(metinGorunumu, ekIndeksi: ekIndeksi)
            metinGorunumu.displayIfNeeded()
            tutulan.imlec.set()
        }
        if gosterimBoyutu != baslangicBoyutu {
            geriAlmayiKaydet(boyut: baslangicBoyutu, anlamsal: baslangicAnlamsali, metinGorunumu: metinGorunumu)
            metinGorunumu.didChangeText()
        } else if let baslangicAnlamsali {
            // Sürükleyip başladığı yere dönmek boyutsuz kaynağa boyut eklememeli.
            yerlesimiTazele(metinGorunumu, ekIndeksi: ekIndeksi, anlamsal: baslangicAnlamsali)
        }
        return true
    }

    private func geriAlmayiKaydet(boyut: NSSize, anlamsal: [String: Any]?, metinGorunumu: NSTextView) {
        metinGorunumu.undoManager?.registerUndo(withTarget: self) { [weak metinGorunumu] hucre in
            guard let metinGorunumu, let depo = metinGorunumu.textStorage,
                  let indeks = hucre.ekinIndeksi(depo) else { return }
            let mevcut = depo.attribute(kGorselAnahtari, at: indeks, effectiveRange: nil) as? [String: Any]
            hucre.geriAlmayiKaydet(boyut: hucre.gosterimBoyutu, anlamsal: mevcut, metinGorunumu: metinGorunumu)
            hucre.gosterimBoyutu = boyut
            hucre.yerlesimiTazele(metinGorunumu, ekIndeksi: indeks, anlamsal: anlamsal)
            metinGorunumu.didChangeText()
        }
        metinGorunumu.undoManager?.setActionName("Görsel Boyutlandırma")
    }

    /// Görselin sığabileceği en fazla genişlik (metin alanı eksi kenar boşlukları).
    private func maksimumEn(_ metinGorunumu: NSTextView) -> CGFloat {
        guard let kapsayici = metinGorunumu.textContainer else {
            return max(1, metinGorunumu.bounds.width - metinGorunumu.textContainerInset.width * 2)
        }
        return max(1, kapsayici.size.width - kapsayici.lineFragmentPadding * 2)
    }

    /// Kayıt boyutu yalnızca anlamsal görselden okur; öznitelik düzenlemesi yerleşimi de yeniler.
    private func yerlesimiTazele(_ metinGorunumu: NSTextView, ekIndeksi: Int, anlamsal: [String: Any]? = nil) {
        guard let metinDeposu = metinGorunumu.textStorage else { return }
        let aralik = NSRange(location: ekIndeksi, length: 1)
        if let ek = metinDeposu.attribute(.attachment, at: ekIndeksi, effectiveRange: nil) as? ResimEki,
           let gorsel = anlamsal ?? MacBelgeAdaptoru.gorselAnlamsali(ek) {
            metinDeposu.addAttribute(kGorselAnahtari, value: gorsel, range: aralik)
        } else {
            metinDeposu.edited(.editedAttributes, range: aralik, changeInLength: 0)
        }
        metinGorunumu.needsDisplay = true
    }

    private func ekinIndeksi(_ metinDeposu: NSTextStorage) -> Int? {
        var bulunan: Int?
        metinDeposu.enumerateAttribute(.attachment, in: NSRange(location: 0, length: metinDeposu.length), options: []) { deger, aralik, durdur in
            if let ek = deger as? NSTextAttachment, ek.attachmentCell === self {
                bulunan = aralik.location
                durdur.pointee = true
            }
        }
        return bulunan
    }
}

/// Görsel verisinden, verilen gösterim boyutuyla bir ek üretir.
func resimEkiUret(gorsel: NSImage, dosyaURL: URL, bagYolu: String? = nil, gosterimBoyutu: NSSize? = nil) -> ResimEki {
    let ek = ResimEki()
    let hucre = ResimEkiHucresi()
    hucre.image = gorsel

    let gercekBoyut = gorsel.size
    let oran = gercekBoyut.height > 0 ? gercekBoyut.width / gercekBoyut.height : 1
    hucre.enBoyOrani = oran.isFinite && oran > 0 ? min(max(oran, 1 / kEnBuyukResimBoyutu), kEnBuyukResimBoyutu) : 1

    // Yeni eklenen görsel çok büyükse makul bir başlangıç genişliğine indirilir.
    let baslangicEni = gercekBoyut.width.isFinite && gercekBoyut.width > 0 ? min(gercekBoyut.width, 360) : 200
    ek.dogalGosterimBoyutu = NSSize(width: max(1, baslangicEni.rounded()),
        height: min(kEnBuyukResimBoyutu, max(1, (baslangicEni / hucre.enBoyOrani).rounded())))
    hucre.gosterimBoyutu = gosterimBoyutu.flatMap {
        resimBoyutuGecerliMi($0) && $0.width >= kEnKucukResimEni ? $0 : nil
    } ?? ek.dogalGosterimBoyutu

    ek.attachmentCell = hucre
    ek.dosyaURL = dosyaURL
    ek.bagYolu = bagYolu ?? "\(kGorsellerKlasorAdi)/\(dosyaURL.lastPathComponent)"
    return ek
}
