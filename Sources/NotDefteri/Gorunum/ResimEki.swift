import AppKit

// MARK: - Görsel eki (köşesinden çekilerek boyutlandırılabilir)

let kEnKucukResimEni: CGFloat = 48

/// Metnin içine gömülen görsel. Dosya yolunu ve gösterim boyutunu taşır.
final class ResimEki: NSTextAttachment {
    var dosyaURL: URL?
    /// Notta yazılı olan bağ yolu ("Görseller/Başlık1.png"). Eski notların
    /// "ekler/..." bağlarını olduğu gibi korumak için saklanır.
    var bagYolu: String?

    var gosterimBoyutu: NSSize {
        get { (attachmentCell as? ResimEkiHucresi)?.gosterimBoyutu ?? .zero }
        set { (attachmentCell as? ResimEkiHucresi)?.gosterimBoyutu = newValue }
    }
}

/// Görseli çizen ve sağ alt köşesindeki tutamaçtan boyutlandırmayı yöneten hücre.
final class ResimEkiHucresi: NSTextAttachmentCell {

    var gosterimBoyutu: NSSize = NSSize(width: 200, height: 150)
    /// Görselin kendi en/boy oranı; boyutlandırırken korunur.
    var enBoyOrani: CGFloat = 4.0 / 3.0
    private let tutamacBoyutu: CGFloat = 14

    override func cellSize() -> NSSize { gosterimBoyutu }

    /// Görsel, satırda kalan yere sığmıyorsa oranı korunarak sığdırılır.
    /// Saklanan boyut değişmez; pencere genişleyince görsel eski boyutuna döner.
    override func cellFrame(for textContainer: NSTextContainer, proposedLineFragment lineFrag: NSRect,
                            glyphPosition position: NSPoint, characterIndex charIndex: Int) -> NSRect {
        var boyut = gosterimBoyutu
        let sigacakEn = max(kEnKucukResimEni, lineFrag.width - position.x)
        if boyut.width > sigacakEn {
            boyut = NSSize(width: sigacakEn.rounded(), height: (sigacakEn / enBoyOrani).rounded())
        }
        return NSRect(x: 0, y: cellBaselineOffset().y, width: boyut.width, height: boyut.height)
    }

    /// Görseli satırın taban çizgisine oturtur.
    override func cellBaselineOffset() -> NSPoint { NSPoint(x: 0, y: -3) }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        image?.draw(in: cellFrame, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        tutamaciCiz(cellFrame)
    }

    private func tutamaciCiz(_ cellFrame: NSRect) {
        let kare = tutamacKaresi(cellFrame).insetBy(dx: 3, dy: 3)
        NSColor.white.withAlphaComponent(0.9).setFill()
        let yol = NSBezierPath(roundedRect: kare, xRadius: 2, yRadius: 2)
        yol.fill()
        NSColor.black.withAlphaComponent(0.55).setStroke()
        yol.lineWidth = 1
        yol.stroke()
    }

    /// Tutamaç, görselin sağ alt köşesinde (metin görünümü ters çevrilmiş koordinatta).
    private func tutamacKaresi(_ cellFrame: NSRect) -> NSRect {
        NSRect(x: cellFrame.maxX - tutamacBoyutu, y: cellFrame.maxY - tutamacBoyutu,
               width: tutamacBoyutu, height: tutamacBoyutu)
    }

    override func wantsToTrackMouse() -> Bool { true }

    override func trackMouse(with theEvent: NSEvent, in cellFrame: NSRect, of controlView: NSView?, untilMouseUp flag: Bool) -> Bool {
        guard let metinGorunumu = controlView as? NSTextView, let pencere = metinGorunumu.window else { return false }
        let baslangicNoktasi = metinGorunumu.convert(theEvent.locationInWindow, from: nil)
        // Tutamacın dışına basıldıysa olağan davranış (seçme/sürükleme) sürsün.
        guard tutamacKaresi(cellFrame).contains(baslangicNoktasi) else { return false }

        let baslangicBoyutu = gosterimBoyutu
        let enFazlaEn = maksimumEn(metinGorunumu)

        while let olay = pencere.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if olay.type == .leftMouseUp { break }
            let nokta = metinGorunumu.convert(olay.locationInWindow, from: nil)
            // Çapraz çekme: yatay ve dikey hareketin ortalaması, oran korunarak.
            let yatayFark = nokta.x - baslangicNoktasi.x
            let dikeyFark = (nokta.y - baslangicNoktasi.y) * enBoyOrani
            let yeniEn = min(max(baslangicBoyutu.width + (yatayFark + dikeyFark) / 2, kEnKucukResimEni), enFazlaEn)
            gosterimBoyutu = NSSize(width: yeniEn.rounded(), height: (yeniEn / enBoyOrani).rounded())
            yerlesimiTazele(metinGorunumu)
        }
        yerlesimiTazele(metinGorunumu)
        // Boyut değişikliği not içeriğinin bir parçası; kaydı tetikle.
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: metinGorunumu)
        return true
    }

    /// Görselin sığabileceği en fazla genişlik (metin alanı eksi kenar boşlukları).
    private func maksimumEn(_ metinGorunumu: NSTextView) -> CGFloat {
        let kapsayiciEni = metinGorunumu.textContainer?.size.width ?? metinGorunumu.bounds.width
        return max(kEnKucukResimEni, kapsayiciEni - metinGorunumu.textContainerInset.width * 2 - 8)
    }

    /// Hücre boyutu değişince satır yerleşimi yeniden hesaplanmalı.
    private func yerlesimiTazele(_ metinGorunumu: NSTextView) {
        guard let metinDeposu = metinGorunumu.textStorage,
              let ekIndeksi = ekinIndeksi(metinDeposu) else { return }
        metinDeposu.edited(.editedAttributes, range: NSRange(location: ekIndeksi, length: 1), changeInLength: 0)
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
    hucre.enBoyOrani = oran > 0 ? oran : 1

    if let istenen = gosterimBoyutu, istenen.width >= kEnKucukResimEni {
        hucre.gosterimBoyutu = istenen
    } else {
        // Yeni eklenen görsel çok büyükse makul bir başlangıç genişliğine indirilir.
        let baslangicEni = min(gercekBoyut.width, 360)
        hucre.gosterimBoyutu = NSSize(width: baslangicEni.rounded(), height: (baslangicEni / hucre.enBoyOrani).rounded())
    }

    ek.attachmentCell = hucre
    ek.dosyaURL = dosyaURL
    ek.bagYolu = bagYolu ?? "\(kGorsellerKlasorAdi)/\(dosyaURL.lastPathComponent)"
    return ek
}
