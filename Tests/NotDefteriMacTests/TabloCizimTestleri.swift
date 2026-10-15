import AppKit
import XCTest
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// #19: `/table` boyut penceresi, tablo vurgusunun çerçevede kalması ve kenar panel satırı.
final class TabloCizimTestleri: XCTestCase {

    // MARK: Boyut penceresi

    func testBoyutAlanlariTiklanabilirVeIlkOdakSatirda() throws {
        _ = NSApplication.shared
        let (uyari, satir, sutun) = tabloBoyutUyarisi()
        uyari.layout()
        let icerik = try XCTUnwrap(uyari.window.contentView)
        for alan in [satir, sutun] {
            XCTAssertGreaterThanOrEqual(alan.frame.width, 40)
            XCTAssertGreaterThan(alan.frame.height, 0)
            let merkez = alan.convert(NSPoint(x: alan.bounds.midX, y: alan.bounds.midY), to: icerik)
            let hedef = icerik.hitTest(icerik.superview?.convert(merkez, from: icerik) ?? merkez)
            XCTAssertTrue(hedef === alan || hedef?.isDescendant(of: alan) == true, "alan tıklanamıyor")
        }
        XCTAssertTrue(uyari.window.initialFirstResponder === satir)
        XCTAssertTrue(satir.nextKeyView === sutun)
    }

    func testBoyutGirdisiSinirlaraCekilirSayiOlmayanReddedilir() {
        let satir = kTabloEnAzSatir...kTabloEnCokSatir
        XCTAssertEqual(tabloBoyutu(" 5 ", satir), 5)
        XCTAssertEqual(tabloBoyutu("1", satir), kTabloEnAzSatir)
        XCTAssertEqual(tabloBoyutu("500", satir), kTabloEnCokSatir)
        XCTAssertNil(tabloBoyutu("beş", satir))
        XCTAssertNil(tabloBoyutu("", satir))
    }

    // MARK: Vurgu

    private struct Cizim {
        let gorunum: NotMetinGorunumu
        let pencere: NSWindow
        let baslik: NSRect    // başlık satırının glif sınırı, görünüm koordinatları
        let govde: NSRect     // ilk gövde satırının glif sınırı
        let tablo: NSRange
    }

    private func tabloCiz() throws -> Cizim {
        _ = NSApplication.shared
        let kaynak = "Önce\n\n| Ad | Yaş | Şehir |\n| --- | --- | --- |\n| Ali | 30 | İzmir |\n| Ayşe | 25 | Ankara |\n\nSonra\n"
        let gorunum = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 520, height: 260))
        gorunum.textContainerInset = NSSize(width: 20, height: 20)
        gorunum.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(kaynak))
        let pencere = NSWindow(contentRect: gorunum.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = gorunum
        let yerlesim = try XCTUnwrap(gorunum.layoutManager)
        let kap = try XCTUnwrap(gorunum.textContainer)
        yerlesim.ensureLayout(for: kap)
        let ns = gorunum.string as NSString
        func satirKaresi(_ parca: String) -> NSRect {
            var satir = ns.lineRange(for: ns.range(of: parca))
            satir.length -= 1
            let glifler = yerlesim.glyphRange(forCharacterRange: satir, actualCharacterRange: nil)
            return yerlesim.boundingRect(forGlyphRange: glifler, in: kap)
                .offsetBy(dx: gorunum.textContainerOrigin.x, dy: gorunum.textContainerOrigin.y)
        }
        let bas = ns.range(of: "┌").location
        return Cizim(gorunum: gorunum, pencere: pencere, baslik: satirKaresi("│ Ad"), govde: satirKaresi("│ Ali"),
                     tablo: NSRange(location: bas, length: NSMaxRange(ns.range(of: "┘\n")) - bas))
    }

    private func renk(_ rep: NSBitmapImageRep, _ gorunum: NSView, _ nokta: NSPoint) -> NSColor? {
        let olcek = CGFloat(rep.pixelsWide) / gorunum.bounds.width
        return rep.colorAt(x: Int(nokta.x * olcek), y: Int(nokta.y * olcek))?.usingColorSpace(.sRGB)
    }

    private func ayni(_ a: NSColor?, _ b: NSColor?) -> Bool {
        guard let a, let b else { return false }
        return abs(a.redComponent - b.redComponent) < 0.02 && abs(a.greenComponent - b.greenComponent) < 0.02
            && abs(a.blueComponent - b.blueComponent) < 0.02
    }

    private func goruntu(_ gorunum: NSView) throws -> NSBitmapImageRep {
        let rep = try XCTUnwrap(gorunum.bitmapImageRepForCachingDisplay(in: gorunum.bounds))
        gorunum.cacheDisplay(in: gorunum.bounds, to: rep)
        return rep
    }

    /// Satır zemini satır sonundan sağ kenara ve önceki satırdan sol girintiye taşıyordu.
    func testSatirZeminiTabloCercevesindeKalir() throws {
        let c = try tabloCiz()
        defer { c.pencere.close() }
        XCTAssertNil(c.gorunum.textStorage?.attribute(.backgroundColor, at: c.tablo.location + 30, effectiveRange: nil))
        let rep = try goruntu(c.gorunum)
        let bos = renk(rep, c.gorunum, NSPoint(x: c.gorunum.bounds.maxX - 4, y: c.gorunum.bounds.maxY - 4))
        XCTAssertFalse(ayni(renk(rep, c.gorunum, NSPoint(x: c.baslik.midX, y: c.baslik.midY)), bos), "başlık bandı çizilmedi")
        XCTAssertTrue(ayni(renk(rep, c.gorunum, NSPoint(x: c.baslik.maxX + 12, y: c.baslik.midY)), bos), "sağa taştı")
        XCTAssertTrue(ayni(renk(rep, c.gorunum, NSPoint(x: c.govde.minX - 6, y: c.govde.midY)), bos), "sola taştı")
    }

    func testSecimVurgusuTabloCercevesindeKalir() throws {
        let c = try tabloCiz()
        defer { c.pencere.close() }
        c.gorunum.setSelectedRange(c.tablo)
        let rep = try goruntu(c.gorunum)
        let bos = renk(rep, c.gorunum, NSPoint(x: c.gorunum.bounds.maxX - 4, y: c.gorunum.bounds.maxY - 4))
        XCTAssertFalse(ayni(renk(rep, c.gorunum, NSPoint(x: c.govde.midX, y: c.govde.midY)), bos), "seçim çizilmedi")
        XCTAssertTrue(ayni(renk(rep, c.gorunum, NSPoint(x: c.baslik.maxX + 12, y: c.baslik.midY)), bos), "seçim sağa taştı")
        XCTAssertTrue(ayni(renk(rep, c.gorunum, NSPoint(x: c.govde.minX - 6, y: c.govde.midY)), bos), "seçim sola taştı")
    }

    // MARK: Kenar panel

    /// Satır görünür alandan genişken seçim kapsülü sağdan kırpılıyor, ad ortada durmuyordu.
    func testKenarPanelSatiriGorunurGenisligeSigar() {
        let panel = KenarPaneli(frame: NSRect(x: 0, y: 0, width: 190, height: 480))
        panel.layout()
        let gorunur = panel.kaydirmaGorunumu.contentSize.width
        XCTAssertGreaterThan(gorunur, 0)
        XCTAssertEqual(panel.tablo.frame.width, gorunur, accuracy: 0.5)
    }

    /// Açık sayfanın kısa yol vurgusu hücreden başlar ama seçim kapsülüyle aynı sağ kenarda biter.
    func testKisaYolVurgusuSecimleAyniSagKenardaBiter() throws {
        let satir = NotSatirGorunumu(frame: NSRect(x: 0, y: 0, width: 175, height: 26))
        let hucre = NSTableCellView(frame: NSRect(x: 38, y: 0, width: 121, height: 26))
        satir.addSubview(hucre)
        let vurgu = try XCTUnwrap(satir.subviews.first { !($0 is NSTableCellView) })
        satir.kisaYolVurgulu = true
        satir.layout()
        XCTAssertEqual(vurgu.alphaValue, 1)
        XCTAssertEqual(vurgu.frame.minX, 38)
        XCTAssertEqual(vurgu.frame.maxX, 171)
        satir.isSelected = true
        satir.layout()
        XCTAssertEqual(vurgu.frame.minX, 4)
        XCTAssertEqual(vurgu.frame.maxX, 171)
        satir.isSelected = false
        satir.kisaYolVurgulu = false
        XCTAssertEqual(vurgu.alphaValue, 0)
    }
}
