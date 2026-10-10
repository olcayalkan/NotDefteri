import AppKit
import XCTest
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

final class GorunumBaglamMenusuTestleri: XCTestCase {
    func testTemaMenusuTumTemalariVeSecimiTasir() {
        _ = NSApplication.shared
        let eski = gTemaIndex
        defer { gTemaIndex = eski }
        gTemaIndex = 1
        let menu = gorunumBaglamMenusunuEkle(NSMenu(), hedef: nil)
        let temalar = menu.item(withTitle: "Görünüm")?.submenu?.item(withTitle: "Tema")?.submenu
        XCTAssertEqual(temalar?.items.map(\.title), temaListesi.map(\.ad))
        XCTAssertEqual(temalar?.items.filter { $0.state == .on }.map { $0.representedObject as? Int }, [1])
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
