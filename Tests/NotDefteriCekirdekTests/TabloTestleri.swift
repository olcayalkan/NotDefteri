import XCTest
@testable import NotDefteriCekirdek

final class TabloTestleri: XCTestCase {
    func testTabloUretirVeIlkBasligiSecer() throws {
        let metin = try XCTUnwrap(tabloMarkdownUret(satir: 3, sutun: 2))
        XCTAssertEqual(metin, "| Başlık 1 | Başlık 2 |\n| --- | --- |\n| Hücre | Hücre |\n| Hücre | Hücre |\n")
        let secim = tabloIlkHucreAraligi(sutun: 2)
        XCTAssertGreaterThan(secim.location, 2)
        XCTAssertEqual(secim.length, 8)
    }

    func testGecersizBoyutTabloUretmez() {
        XCTAssertNil(tabloMarkdownUret(satir: 1, sutun: 2))
        XCTAssertNil(tabloMarkdownUret(satir: 2, sutun: 1))
        XCTAssertNil(tabloMarkdownUret(satir: 31, sutun: 2))
    }

    func testMarkdownTablosuGorunumOzniteligiAlirVeAynenKaydolur() throws {
        let metin = "| Ad | Değer |\n| :--- | ---: |\n| Bir | 1 |\n"
        let belge = markdowndenAttributedStringUret(metin)
        let ns = belge.string as NSString
        XCTAssertTrue(belge.string.hasPrefix("┌"))
        let baslik = ns.range(of: "Ad")
        XCTAssertNotEqual(baslik.location, NSNotFound)
        XCTAssertEqual(belge.attribute(kTabloSatiriAnahtari, at: baslik.location, effectiveRange: nil) as? String, "baslik")
        XCTAssertNotNil(belge.attribute(kTabloGorselAnahtari, at: 0, effectiveRange: nil))
        XCTAssertEqual(markdownMetniUret(belge), metin)
    }

    func testSiradanBoruMetniTabloDegildir() {
        let belge = markdowndenAttributedStringUret("a | b\n")
        XCTAssertNil(belge.attribute(kTabloSatiriAnahtari, at: 0, effectiveRange: nil))
    }

    func testKutuluTablodaHucreDuzenleninceMarkdownaGeriDoner() {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret(
            "| Ad | Değer |\n| --- | --- |\n| Bir | 1 |\n"))
        let ad = (belge.string as NSString).range(of: "Ad")
        belge.replaceCharacters(in: ad, with: "İsim")
        XCTAssertEqual(markdownMetniUret(belge), "| İsim | Değer |\n| --- | --- |\n| Bir | 1 |\n")
    }

    func testBozukCerceveliTabloyuMarkdownaDonusturmez() {
        var gorsel = tabloGorunumunuUret(baslik: ["Ad", "Değer"], govde: [["Bir", "1"]]).metin
        let ilkDikey = try! XCTUnwrap(gorsel.firstIndex(of: "│"))
        gorsel.replaceSubrange(ilkDikey...ilkDikey, with: " ")

        XCTAssertNil(tabloGorselindenMarkdownUret(gorsel))
    }

    func testTabloHamMarkdowniKorurVeCizgilerHizalidir() {
        let kod = "\u{0060}#\u{0060}"
        let kaynak = "| \(kod) | **Kalın** |\n| --- | --- |\n| kod ışı | Türkçe ş |\n"
        let belge = markdowndenAttributedStringUret(kaynak)
        XCTAssertTrue(belge.string.contains(kod))
        XCTAssertTrue(belge.string.contains("**Kalın**"))
        XCTAssertEqual(markdownMetniUret(belge), kaynak)
        let satirlar = belge.string.split(separator: "\n", omittingEmptySubsequences: true)
        let icerikSatirlari = satirlar.filter { $0.first == "│" }
        func ayiracKonumlari(_ satir: Substring) -> [Int] {
            satir.enumerated().compactMap { $0.element == "│" ? $0.offset : nil }
        }
        XCTAssertEqual(ayiracKonumlari(icerikSatirlari[0]), ayiracKonumlari(icerikSatirlari[1]))
    }
}
