import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// AppKit kaydırma için görünür alanın üstünü ve altını önceden çizer. Kutu, kod ve alıntı
/// çizimi görünür alanla kırpıldığında o bölgelerde yalnızca metin kalıyor, kaydırınca uzun
/// blokların üst/alt parçaları kopuk görünüyordu.
final class KutuCizimTestleri: XCTestCase {

    /// Uygulamadaki gibi: kaydırıcının içinde, içerikle uzayan metin görünümü.
    private func kaydirilmisEditor(_ md: String) -> (NotMetinGorunumu, NSWindow) {
        _ = NSApplication.shared
        let kaydirici = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 200))
        let e = NotMetinGorunumu(frame: NSRect(origin: .zero, size: kaydirici.contentSize))
        e.autoresizingMask = [.width]
        e.minSize = NSSize(width: 0, height: kaydirici.contentSize.height)
        e.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        e.isRichText = true
        e.isVerticallyResizable = true
        e.textContainerInset = NSSize(width: 14, height: 12)
        e.textContainer?.widthTracksTextView = false
        e.textContainer?.size = NSSize(width: kaydirici.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        kaydirici.documentView = e
        let pencere = NSWindow(contentRect: kaydirici.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = kaydirici
        e.layoutManager?.ensureLayout(for: e.textContainer!)
        e.sizeToFit()
        return (e, pencere)
    }

    /// Bloğun ortası görünür alanda kalacak biçimde kaydırır; tüm görünüm çizilir
    /// (görünür alan dışı, AppKit'in önceden çizdiği bölgeye karşılık gelir).
    private func ciz(_ e: NotMetinGorunumu, blok: NSRect) -> NSBitmapImageRep {
        e.scroll(NSPoint(x: 0, y: blok.midY - 100))
        XCTAssertGreaterThan(e.visibleRect.minY, blok.minY + 20, "bloğun üstü görünür alanın dışında olmalı")
        XCTAssertLessThan(e.visibleRect.maxY, blok.maxY - 20, "bloğun altı görünür alanın dışında olmalı")
        let rep = e.bitmapImageRepForCachingDisplay(in: e.bounds)!
        e.cacheDisplay(in: e.bounds, to: rep)
        return rep
    }

    /// `x` çevresindeki birkaç piksel içinde arka plandan ayrışan (çizgi/dolgu) piksel var mı?
    private func cizgiVar(_ rep: NSBitmapImageRep, _ e: NSView, x: CGFloat, y: CGFloat) -> Bool {
        let olcek = CGFloat(rep.pixelsWide) / e.bounds.width
        guard let zemin = rep.colorAt(x: 1, y: Int(y * olcek))?.usingColorSpace(.sRGB) else { return false }
        return (Int((x - 2) * olcek)...Int((x + 2) * olcek)).contains { px in
            guard let r = rep.colorAt(x: px, y: Int(y * olcek))?.usingColorSpace(.sRGB) else { return false }
            return abs(r.redComponent - zemin.redComponent) + abs(r.greenComponent - zemin.greenComponent)
                + abs(r.blueComponent - zemin.blueComponent) > 0.04
        }
    }

    private func blokKenarlariCizilir(_ md: String, anahtar: NSAttributedString.Key, dosya: StaticString = #filePath, satir: UInt = #line) throws {
        let (e, pencere) = kaydirilmisEditor(md)
        defer { pencere.close() }
        let depo = try XCTUnwrap(e.textStorage)
        let konum = (e.string as NSString).range(of: "s20").location
        var aralik = NSRange()
        XCTAssertNotNil(depo.attribute(anahtar, at: konum, longestEffectiveRange: &aralik,
                                       in: NSRange(location: 0, length: depo.length)), file: dosya, line: satir)
        let kare = try XCTUnwrap(e.blokCerceveKaresi(aralik, anahtar: anahtar))
        let rep = ciz(e, blok: kare)
        XCTAssertTrue(cizgiVar(rep, e, x: kare.minX + 0.5, y: kare.minY + 30), "üst parça (görünür alanın üstü) çizilmedi",
                      file: dosya, line: satir)
        XCTAssertTrue(cizgiVar(rep, e, x: kare.minX + 0.5, y: kare.maxY - 30), "alt parça (görünür alanın altı) çizilmedi",
                      file: dosya, line: satir)
    }

    private let satirlar = (1...40).map { "s\($0)" }

    func testUzunUyariKutusuGorunurAlanDisindaDaCizilir() throws {
        try blokKenarlariCizilir("önce\n> [!💡 mavi] baş\n" + satirlar.map { "> \($0)\n" }.joined() + "sonra\n",
                                 anahtar: kUyariKutusuAnahtari)
    }

    func testUzunKodBloguGorunurAlanDisindaDaCizilir() throws {
        try blokKenarlariCizilir("önce\n```\n" + satirlar.map { "\($0)\n" }.joined() + "```\nsonra\n",
                                 anahtar: kKodBloguAnahtari)
    }

    /// Alıntı çizgisi de aynı kırpmaya takılıyordu.
    func testUzunAlintiCizgisiGorunurAlanDisindaDaCizilir() throws {
        let (e, pencere) = kaydirilmisEditor("önce\n" + satirlar.map { "> \($0)\n" }.joined() + "sonra\n")
        defer { pencere.close() }
        let ns = e.string as NSString
        let ilk = try XCTUnwrap(e.guvenliKare(karakter: ns.range(of: "s1\n")))
        let son = try XCTUnwrap(e.guvenliKare(karakter: ns.range(of: "s40")))
        let blok = NSUnionRect(ilk, son).offsetBy(dx: e.textContainerOrigin.x, dy: e.textContainerOrigin.y)
        let rep = ciz(e, blok: blok)
        let x = e.textContainerOrigin.x + (e.textContainer?.lineFragmentPadding ?? 0) + 8
        XCTAssertTrue(cizgiVar(rep, e, x: x, y: blok.minY + 30), "alıntı çizgisinin üstü çizilmedi")
        XCTAssertTrue(cizgiVar(rep, e, x: x, y: blok.maxY - 30), "alıntı çizgisinin altı çizilmedi")
    }
    /// AppKit düzenlemede yalnızca değişen satırları kirletir. Kutunun yalnızca bir parçası
    /// kirliyken çizim yapılırsa kalan parça eski pikselleriyle kalıyordu: ekranda kutunun
    /// üst yarısı yok, alt yarısı çerçeveliydi. Parça çizimi kalanı da kirletmeli.
    func testKutununParcasiCizilinceKalaniDaKirlenir() throws {
        let (e, pencere) = kaydirilmisEditor("önce\n> [!💡 mavi] baş\n" + satirlar.map { "> \($0)\n" }.joined() + "sonra\n")
        defer { pencere.close() }
        let depo = try XCTUnwrap(e.textStorage)
        var aralik = NSRange()
        XCTAssertNotNil(depo.attribute(kUyariKutusuAnahtari, at: (e.string as NSString).range(of: "s20").location,
                                       longestEffectiveRange: &aralik, in: NSRange(location: 0, length: depo.length)))
        let kare = try XCTUnwrap(e.blokCerceveKaresi(aralik, anahtar: kUyariKutusuAnahtari))
        e.scroll(NSPoint(x: 0, y: kare.midY - 100))
        let parca = NSRect(x: kare.minX, y: kare.midY, width: kare.width, height: 20)
        let rep = try XCTUnwrap(e.bitmapImageRepForCachingDisplay(in: e.bounds))
        let baglam = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        e.displayIgnoringOpacity(parca, in: baglam)
        XCTAssertTrue(e.needsDisplay, "kutunun kalan parçası kirletilmedi")
    }
}
