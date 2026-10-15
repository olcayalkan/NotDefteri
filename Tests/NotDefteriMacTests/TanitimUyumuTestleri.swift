import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Tanıtımdaki görünüm: köşeli parantezsiz mavi sayfa bağı, "Sayfalar" başlığı ve klasör simgesi.
final class TanitimUyumuTestleri: XCTestCase {

    private func pencerede(_ md: String) -> (NotMetinGorunumu, NSWindow) {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        e.isEditable = true
        e.textStorage?.delegate = e
        let pencere = NSWindow(contentRect: e.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = e
        e.sayfaYukleniyor = true
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        e.sayfaYukleniyor = false
        e.textStorage?.addAttribute(kSayfaBagiAnahtari, value: "Q3 Report",
                                    range: (e.string as NSString).range(of: "[[Q3 Report]]"))
        return (e, pencere)
    }

    private func ozellik(_ e: NotMetinGorunumu, _ konum: Int) -> NSLayoutManager.GlyphProperty {
        let yerlesim = e.layoutManager!
        yerlesim.ensureLayout(for: e.textContainer!)
        return yerlesim.propertyForGlyph(at: yerlesim.glyphIndexForCharacter(at: konum))
    }

    /// Okurken sayfa emojisi ve adı görünür; imleç bağa girince "[[ ]]" yazımı geri gelir.
    func testSayfaBagiIsaretleriImlecDisindaGizlenir() throws {
        let (e, pencere) = pencerede("Details: [[Q3 Report]] tamam\n")
        defer { pencere.close() }
        let bag = (e.string as NSString).range(of: "[[Q3 Report]]")
        e.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertEqual(ozellik(e, bag.location), .controlCharacter, "emoji yeri")
        for konum in [bag.location + 1, NSMaxRange(bag) - 2, NSMaxRange(bag) - 1] {
            XCTAssertEqual(ozellik(e, konum), .null, "\(konum)")
        }
        XCTAssertNotEqual(ozellik(e, bag.location + 2), .null, "ad görünür")
        let yerlesim = try XCTUnwrap(e.layoutManager)
        let emojiYeri = yerlesim.boundingRect(forGlyphRange: NSRange(location: yerlesim.glyphIndexForCharacter(at: bag.location), length: 1),
                                              in: e.textContainer!)
        XCTAssertEqual(emojiYeri.width, e.bagSimgesiGenisligi(bag.location), accuracy: 0.5)
        e.setSelectedRange(NSRange(location: bag.location + 4, length: 0))
        XCTAssertNotEqual(ozellik(e, bag.location), .controlCharacter)
        XCTAssertNotEqual(ozellik(e, NSMaxRange(bag) - 1), .null)
        XCTAssertEqual(markdownMetniUret(e.textStorage!), "Details: [[Q3 Report]] tamam\n", "kaynak değişmez")
    }

    func testSayfaBagiBagRengiyleAltiCiziliBoyanir() throws {
        let (e, pencere) = pencerede("Details: [[Q3 Report]]\n")
        defer { pencere.close() }
        e.sayfaBaglariniBoya()
        let konum = (e.string as NSString).range(of: "Q3").location
        let gecici = try XCTUnwrap(e.layoutManager?.temporaryAttributes(atCharacterIndex: konum, effectiveRange: nil))
        XCTAssertEqual(gecici[.foregroundColor] as? NSColor, bagRengi())
        XCTAssertEqual(gecici[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
    }

    func testKenarPanelinKokundeSayfalarBasligiVar() {
        let panel = KenarPaneli(frame: .zero)
        let kok = FileManager.default.temporaryDirectory
        let yaprak = AgacDugumu(icerikURL: kok.appendingPathComponent("A/index.md"), klasorURL: kok.appendingPathComponent("A"))
        panel.kokDugumler = [yaprak]
        let kokteki = (0..<panel.outlineView(panel.tablo, numberOfChildrenOfItem: nil)).map {
            panel.outlineView(panel.tablo, child: $0, ofItem: nil)
        }
        let baslik = kokteki.first { $0 is SayfalarBasligi }
        XCTAssertNotNil(baslik)
        XCTAssertTrue(kokteki.last as AnyObject === yaprak, "başlık sayfalardan önce")
        XCTAssertFalse(panel.outlineView(panel.tablo, shouldSelectItem: baslik!))
        XCTAssertFalse(panel.outlineView(panel.tablo, isItemExpandable: baslik!))
        panel.kokDugumler = []
        XCTAssertFalse((0..<panel.outlineView(panel.tablo, numberOfChildrenOfItem: nil)).contains {
            panel.outlineView(panel.tablo, child: $0, ofItem: nil) is SayfalarBasligi
        }, "sayfa yoksa başlık da yok")
    }
}
