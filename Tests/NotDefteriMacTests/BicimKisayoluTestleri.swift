import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// `/red` kırmızı, `/info` yeşil uyarı kutusu açar; `/uyari` gibi boşlukla hemen uygulanır.
/// ⌘O satırı ortalar, ikinci kez basınca sola döndürür.
final class BicimKisayoluTestleri: XCTestCase {
    private var kok: URL!
    private var oncekiKok: String?

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        kok = FileManager.default.temporaryDirectory.appendingPathComponent("slash-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: kok, withIntermediateDirectories: true)
        oncekiKok = ProcessInfo.processInfo.environment["NOTDEFTERI_KOK"]
        setenv("NOTDEFTERI_KOK", kok.path, 1)
    }

    override func tearDown() {
        for pencere in NotPenceresi.icerikPencereleri { pencere.close() }
        if let oncekiKok { setenv("NOTDEFTERI_KOK", oncekiKok, 1) } else { unsetenv("NOTDEFTERI_KOK") }
        try? FileManager.default.removeItem(at: kok)
        super.tearDown()
    }

    private func pencereAc(_ icerik: String) throws -> NotPenceresi {
        let url = kok.appendingPathComponent("Sayfa").appendingPathComponent(kIcerikDosyaAdi)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try icerik.write(to: url, atomically: true, encoding: .utf8)
        return NotPenceresi.icerikPenceresiAc(url, yanindaki: nil)
    }

    private func yazilinca(_ metin: String) throws -> String {
        let editor = try pencereAc("").metinGorunumu
        for harf in metin { editor.insertText(String(harf), replacementRange: NSRange(location: NSNotFound, length: 0)) }
        return markdownMetniUret(editor.textStorage!)
    }

    func testRedKirmiziUyariAcar() throws {
        let md = try yazilinca("/red yaz")
        XCTAssertTrue(md.hasPrefix("> [!"), md)
        XCTAssertTrue(md.contains(" kırmızı] yaz"), md)
    }

    func testInfoYesilUyariAcar() throws {
        let md = try yazilinca("/info yaz")
        XCTAssertTrue(md.hasPrefix("> [!"), md)
        XCTAssertTrue(md.contains(" yeşil] yaz"), md)
    }

    // MARK: ⌘O ortala

    private func hiza(_ editor: NotMetinGorunumu, _ metin: String) -> NSTextAlignment? {
        let konum = (editor.string as NSString).range(of: metin).location
        return (editor.textStorage?.attribute(.paragraphStyle, at: konum, effectiveRange: nil) as? NSParagraphStyle)?.alignment
    }

    func testOrtalaAcarVeKapatir() throws {
        let pencere = try pencereAc("bir\niki\n")
        let editor = pencere.metinGorunumu
        editor.setSelectedRange(NSRange(location: 1, length: 0))
        pencere.ortalaKomutu(nil)
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "<center>bir</center>\niki\n")
        XCTAssertEqual(hiza(editor, "bir"), .center)
        XCTAssertNotEqual(hiza(editor, "iki"), .center)
        pencere.ortalaKomutu(nil)
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "bir\niki\n")
        XCTAssertNotEqual(hiza(editor, "bir"), .center)
    }

    /// Ortalı satırın sonunda Enter: yeni satır da ortalı yazılır (Word gibi).
    func testOrtaliSatirdanSonrakiSatirOrtaliDevamEder() throws {
        let pencere = try pencereAc("bir")
        let editor = pencere.metinGorunumu
        editor.setSelectedRange(NSRange(location: 3, length: 0))
        pencere.ortalaKomutu(nil)
        editor.insertNewline(nil)
        editor.insertText("iki", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "<center>bir</center>\n<center>iki</center>")
    }

    /// Kod bloğu bütün olarak ortalanır ({center} açılış çitinde); kodun içine etiket girmez.
    func testKodBloguOrtalanir() throws {
        let pencere = try pencereAc("bir\n```swift\nkod\nikinci\n```\n")
        let editor = pencere.metinGorunumu
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).range(of: "kod").location, length: 0))
        pencere.ortalaKomutu(nil)
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "bir\n```swift {center}\nkod\nikinci\n```\n")
        XCTAssertEqual(hiza(editor, "ikinci"), .center)
        // Ortalanan kodda yazmak bloğu ikiye bölmez.
        editor.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "bir\n```swift {center}\nxkod\nikinci\n```\n")
        pencere.ortalaKomutu(nil)
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "bir\n```swift\nxkod\nikinci\n```\n")
    }

    /// Kutu ve listede satır satır ortalanır; blok yapısı ve kutu korunur.
    func testKutuVeListeSatiriOrtalanir() throws {
        let pencere = try pencereAc("> [!💡 mavi] bir\n> iki\n\n- madde\n")
        let editor = pencere.metinGorunumu
        let ns = editor.string as NSString
        editor.setSelectedRange(NSUnionRange(ns.range(of: "iki"), ns.range(of: "madde")))
        pencere.ortalaKomutu(nil)
        let md = markdownMetniUret(editor.textStorage!)
        XCTAssertEqual(md, "> [!💡 mavi] bir\n> <center>iki</center>\n\n- <center>madde</center>\n")
        XCTAssertEqual(hiza(editor, "iki"), .center)
        XCTAssertNotEqual(hiza(editor, "bir"), .center)
        // Kapatıp açınca aynı kalır.
        let yeniden = MacBelgeAdaptoru.markdownuAc(md)
        XCTAssertEqual(markdownMetniUret(yeniden), md)
        XCTAssertEqual(yeniden.string, editor.string)
    }

    /// Sağ tık menüsünde simgeli Ortala / Sola yasla; Sola yasla aç/kapa değil, sola alır.
    func testSagTikHizalamaOgeleri() throws {
        let pencere = try pencereAc("> [!💡 mavi] bir iki\n")
        let editor = pencere.metinGorunumu
        let iki = (editor.string as NSString).range(of: "iki")
        editor.setSelectedRange(iki)
        pencere.layoutIfNeeded()
        let yerlesim = try XCTUnwrap(editor.layoutManager)
        let glif = yerlesim.glyphIndexForCharacter(at: iki.location + 1)
        var nokta = yerlesim.boundingRect(forGlyphRange: NSRange(location: glif, length: 1), in: editor.textContainer!).origin
        nokta.x += editor.textContainerOrigin.x + 1; nokta.y += editor.textContainerOrigin.y + 2
        let olay = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: editor.convert(nokta, to: nil),
            modifierFlags: [], timestamp: 0, windowNumber: pencere.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        let menu = try XCTUnwrap(editor.menu(for: olay))
        let ortala = try XCTUnwrap(menu.item(withTitle: "Ortala"))
        XCTAssertNotNil(ortala.image)
        XCTAssertNotNil(menu.item(withTitle: "Sola yasla")?.image)
        XCTAssertEqual(editor.selectedRange(), iki, "kutuda sağ tık seçimi korur")
        pencere.ortaliYapKomutu(nil)
        pencere.ortaliYapKomutu(nil)
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "> [!💡 mavi] <center>bir iki</center>\n")
        pencere.solaYaslaKomutu(nil)
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "> [!💡 mavi] bir iki\n")
    }

    func testOrtalaGeriAlinir() throws {
        let pencere = try pencereAc("bir\n")
        let editor = pencere.metinGorunumu
        editor.setSelectedRange(NSRange(location: 1, length: 0))
        let geri = try XCTUnwrap(editor.undoManager)
        geri.beginUndoGrouping()
        pencere.ortalaKomutu(nil)
        geri.endUndoGrouping()
        geri.undo()
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "bir\n")
    }
}
