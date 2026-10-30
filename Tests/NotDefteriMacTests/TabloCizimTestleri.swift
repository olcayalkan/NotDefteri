import AppKit
import XCTest
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// #19: `/table` boyut penceresi ve kenar panel satırı.
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
