import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// `/red` kırmızı, `/info` yeşil uyarı kutusu açar; `/uyari` gibi boşlukla hemen uygulanır.
final class SlashUyariKisayoluTestleri: XCTestCase {
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

    private func yazilinca(_ metin: String) throws -> String {
        let url = kok.appendingPathComponent("Sayfa").appendingPathComponent(kIcerikDosyaAdi)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "".write(to: url, atomically: true, encoding: .utf8)
        let pencere = NotPenceresi.icerikPenceresiAc(url, yanindaki: nil)
        let editor = pencere.metinGorunumu
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
}
