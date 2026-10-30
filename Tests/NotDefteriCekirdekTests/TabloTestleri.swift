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

    func testDisTablodanMarkdownUretir() throws {
        let metin = try XCTUnwrap(disTablodanMarkdownUret([["x", "Cut\ncharacter"], ["a|b"], ["", ""], ["yy", "Copy  "]]))
        XCTAssertEqual(metin, "| x | Cut character |\n| --- | --- |\n| a\\|b |  |\n| yy | Copy |\n",
                       "satır sonu boşluk olur, | kaçışlanır, kısa satır tamamlanır, boş satır atlanır")
        XCTAssertEqual(markdownMetniUret(markdowndenAttributedStringUret(metin)), metin, "tablo olarak açılır ve aynen kaydolur")
    }

    func testDisTabloTekSatirVeyaTekSutundaUretilmez() {
        XCTAssertNil(disTablodanMarkdownUret([["a", "b"]]))
        XCTAssertNil(disTablodanMarkdownUret([["a"], ["b"]]))
        XCTAssertNil(disTablodanMarkdownUret([]))
    }

    func testGecersizBoyutTabloUretmez() {
        XCTAssertNil(tabloMarkdownUret(satir: 1, sutun: 2))
        XCTAssertNil(tabloMarkdownUret(satir: 2, sutun: 1))
        XCTAssertNil(tabloMarkdownUret(satir: 31, sutun: 2))
    }

    /// Tablo kutuya çevrilmez: düz Markdown metni olarak açılır ve aynen kaydolur.
    func testMarkdownTablosuDuzMetinKalirVeAynenKaydolur() throws {
        let metin = "| Ad | Değer |\n| :--- | ---: |\n| Bir | 1 |\n"
        let belge = markdowndenAttributedStringUret(metin)
        XCTAssertEqual(belge.string, metin)
        XCTAssertNil(belge.attribute(kTabloSatiriAnahtari, at: 0, effectiveRange: nil))
        XCTAssertNil(belge.attribute(kTabloGorselAnahtari, at: 0, effectiveRange: nil))
        XCTAssertEqual(markdownMetniUret(belge), metin)
    }

    func testSiradanBoruMetniTabloDegildir() {
        let belge = markdowndenAttributedStringUret("a | b\n")
        XCTAssertNil(belge.attribute(kTabloSatiriAnahtari, at: 0, effectiveRange: nil))
    }

    func testDuzTablodaHucreDuzenlenir() {
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

    func testTabloHamMarkdowniKorur() {
        let kod = "\u{0060}#\u{0060}"
        let kaynak = "| \(kod) | **Kalın** |\n| --- | --- |\n| kod ışı | Türkçe ş |\n"
        let belge = markdowndenAttributedStringUret(kaynak)
        XCTAssertFalse(belge.string.contains("┌"))
        XCTAssertEqual(markdownMetniUret(belge), kaynak)
    }
}
