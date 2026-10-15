import AppKit
import XCTest
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

final class GorunumBaglamMenusuTestleri: XCTestCase {
    /// #18: Görünüm ara bir "Tema" adımı olmadan temaları doğrudan listeler.
    func testGorunumTemalariDogrudanListelerVeSecimiTasir() throws {
        _ = NSApplication.shared
        let eski = gTemaIndex
        defer { gTemaIndex = eski }
        gTemaIndex = 1
        let menu = gorunumBaglamMenusunuEkle(NSMenu(), hedef: nil)
        let gorunum = try XCTUnwrap(menu.item(withTitle: "Görünüm")?.submenu)
        XCTAssertNil(gorunum.item(withTitle: "Tema"))
        XCTAssertEqual(gorunum.items.prefix(temaListesi.count).map(\.title), temaListesi.map(\.ad))
        let temalar = gorunum.items.filter { $0.action == #selector(NotPenceresi.temaSecKomutu(_:)) }
        XCTAssertEqual(temalar.filter { $0.state == .on }.map { $0.representedObject as? Int }, [1])
        XCTAssertNotNil(gorunum.item(withTitle: "Küçük yazı"))
        XCTAssertNil(gorunum.item(withTitle: "Tam genişlik"), "Tam genişlik kaldırıldı")
    }

    func testMevcutMenuEylemleriKorunurVeGorunumTekKalir() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        _ = gorunumBaglamMenusunuEkle(menu, hedef: nil)
        _ = gorunumBaglamMenusunuEkle(menu, hedef: nil)
        XCTAssertNotNil(menu.item(withTitle: "Kopyala"))
        XCTAssertEqual(menu.items.filter { $0.title == "Görünüm" }.count, 1)
    }

    func testAnaSayfaninBelgesindeGorunumMenusuVar() throws {
        _ = NSApplication.shared
        let ana = AnaSayfa(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let olay = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        XCTAssertNotNil(ana.documentView?.menu(for: olay)?.item(withTitle: "Görünüm"))
    }
}
