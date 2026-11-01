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

    /// Seçim kod bloğuna taşsa da yalnızca düz satırlar ortalanır; kod yapısı bozulmaz.
    func testKodSatiriOrtalanmaz() throws {
        let pencere = try pencereAc("bir\n```\nkod\n```\n")
        let editor = pencere.metinGorunumu
        editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
        pencere.ortalaKomutu(nil)
        XCTAssertEqual(markdownMetniUret(editor.textStorage!), "<center>bir</center>\n```\nkod\n```\n")
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
