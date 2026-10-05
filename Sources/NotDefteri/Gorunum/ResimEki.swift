import AppKit
import NotDefteriCekirdek

// MARK: - Görsel eki (tutamaçlarından çekilerek boyutlandırılabilir)

let kEnKucukResimEni: CGFloat = 48
let kEnBuyukResimBoyutu: CGFloat = 10_000

func resimBoyutuGecerliMi(_ boyut: NSSize) -> Bool {
    boyut.width.isFinite && boyut.height.isFinite
        && boyut.width >= 1 && boyut.height >= 1
        && boyut.width <= kEnBuyukResimBoyutu && boyut.height <= kEnBuyukResimBoyutu
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
    /// Görselin kendi en/boy oranı; boyutlandırırken korunur.
    var enBoyOrani: CGFloat = 4.0 / 3.0
    var tutamaclarGorunur = false
    private(set) var cizimCercevesi: NSRect = .zero
    private var boyutlandiriliyor = false

    override func cellSize() -> NSSize { gosterimBoyutu }

    /// Görsel, satırda kalan yere sığmıyorsa oranı korunarak sığdırılır.
    /// Saklanan boyut değişmez; pencere genişleyince görsel eski boyutuna döner.
    override func cellFrame(for textContainer: NSTextContainer, proposedLineFragment lineFrag: NSRect,
                            glyphPosition position: NSPoint, characterIndex charIndex: Int) -> NSRect {
        var boyut = gosterimBoyutu
        let sigacakEn = max(kEnKucukResimEni, lineFrag.width - position.x)
        if boyut.width > sigacakEn {
            boyut = NSSize(width: sigacakEn.rounded(),
                           height: min(kEnBuyukResimBoyutu, max(1, (sigacakEn / enBoyOrani).rounded())))
        }
        return NSRect(x: 0, y: cellBaselineOffset().y, width: boyut.width, height: boyut.height)
    }

    /// Görseli satırın taban çizgisine oturtur.
    override func cellBaselineOffset() -> NSPoint { NSPoint(x: 0, y: -3) }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        if controlView is NotMetinGorunumu { cizimCercevesi = cellFrame }
        image?.draw(in: cellFrame, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        if tutamaclarGorunur || boyutlandiriliyor { tutamaclariCiz(cellFrame) }
    }

    private func tutamaclariCiz(_ cerceve: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.7).setStroke()
        let kenar = NSBezierPath(rect: cerceve.insetBy(dx: 0.5, dy: 0.5))
        kenar.lineWidth = 1
        kenar.stroke()
        for alan in tutamaclar(cerceve) {
            NSColor.white.withAlphaComponent(0.95).setFill()
            let yol = NSBezierPath(rect: alan)
            yol.fill()
            yol.lineWidth = 1
            yol.stroke()
        }
    }

    /// Çizim ve tıklama aynı alanları kullanır.
    private func tutamaclar(_ cerceve: NSRect) -> [NSRect] {
        let kare = min(8, cerceve.width, cerceve.height)
        let cubukEni = min(4, cerceve.width)
        let cubukBoyu = min(24, cerceve.height)
        return [
            NSRect(x: cerceve.minX, y: cerceve.minY, width: kare, height: kare),
            NSRect(x: cerceve.minX, y: cerceve.maxY - kare, width: kare, height: kare),
            NSRect(x: cerceve.maxX - kare, y: cerceve.minY, width: kare, height: kare),
            NSRect(x: cerceve.maxX - kare, y: cerceve.maxY - kare, width: kare, height: kare),
            NSRect(x: cerceve.minX, y: cerceve.midY - cubukBoyu / 2, width: cubukEni, height: cubukBoyu),
            NSRect(x: cerceve.maxX - cubukEni, y: cerceve.midY - cubukBoyu / 2, width: cubukEni, height: cubukBoyu)
        ]
    }

    func tutamacYonu(noktada nokta: NSPoint, cerceve: NSRect) -> CGFloat? {
        guard cerceve.contains(nokta),
              tutamaclar(cerceve).contains(where: { $0.insetBy(dx: -3, dy: -3).contains(nokta) }) else { return nil }
        // Dar görsellerde tıklama alanları çakışsa da sağ/sol yönü değişmesin.
        return nokta.x < cerceve.midX ? -1 : 1
    }

    override func wantsToTrackMouse() -> Bool { true }

    override func trackMouse(with theEvent: NSEvent, in cellFrame: NSRect, of controlView: NSView?, untilMouseUp flag: Bool) -> Bool {
        guard let metinGorunumu = controlView as? NSTextView, metinGorunumu.isEditable,
              let pencere = metinGorunumu.window else { return false }
        let baslangicNoktasi = metinGorunumu.convert(theEvent.locationInWindow, from: nil)
        // Tutamacın dışına basıldıysa olağan davranış (seçme/sürükleme) sürsün.
        guard let yon = tutamacYonu(noktada: baslangicNoktasi, cerceve: cellFrame) else { return false }
        guard let metinDeposu = metinGorunumu.textStorage,
              let ekIndeksi = ekinIndeksi(metinDeposu) else { return false }

        let baslangicBoyutu = gosterimBoyutu
        let baslangicAnlamsali = metinDeposu.attribute(kGorselAnahtari, at: ekIndeksi, effectiveRange: nil) as? [String: Any]
        // Satıra sığdırılan görsel, ilk harekette saklanan büyük boyutuna sıçramasın.
        let baslangicEni = cellFrame.width
        let enFazlaEn = min(maksimumEn(metinGorunumu), kEnBuyukResimBoyutu,
                           kEnBuyukResimBoyutu * enBoyOrani).rounded(.down)
        let enAzGecerliEn = max(1, enBoyOrani).rounded(.up)
        let enAzEn = min(enFazlaEn, max(kEnKucukResimEni, enAzGecerliEn))
        boyutlandiriliyor = true
        pencere.makeFirstResponder(metinGorunumu)
        NSCursor.resizeLeftRight.set()
        defer {
            boyutlandiriliyor = false
            metinGorunumu.needsDisplay = true
        }
        metinGorunumu.breakUndoCoalescing()

        while let olay = pencere.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if olay.type == .leftMouseUp { break }
            // Oranı koruyan hiçbir geçerli boyut sığmıyorsa tutamaç yine seçimi engeller.
            guard enAzGecerliEn <= enFazlaEn else { continue }
            let nokta = metinGorunumu.convert(olay.locationInWindow, from: nil)
            let yatayFark = (nokta.x - baslangicNoktasi.x) * yon
            let yeniEn = min(max(baslangicEni + yatayFark, enAzEn), enFazlaEn)
            let yeniBoyut = yatayFark == 0 ? baslangicBoyutu
                : NSSize(width: max(1, yeniEn.rounded()), height: max(1, (yeniEn / enBoyOrani).rounded()))
            guard resimBoyutuGecerliMi(yeniBoyut), yeniBoyut != gosterimBoyutu else { continue }
            gosterimBoyutu = yeniBoyut
            yerlesimiTazele(metinGorunumu, ekIndeksi: ekIndeksi)
            metinGorunumu.displayIfNeeded()
            NSCursor.resizeLeftRight.set()
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
