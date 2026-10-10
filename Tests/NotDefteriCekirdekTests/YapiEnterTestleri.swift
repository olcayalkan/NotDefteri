import XCTest
@testable import NotDefteriCekirdek

/// Enter ve geri silme: liste/görev/alıntı devam eder, boş satırda yapıdan çıkılır.
/// İki platform da bu kuralı kullanır; sonuç kaydedilen Markdown üzerinden ölçülür.
final class YapiEnterTestleri: XCTestCase {

    /// İmleç verilmezse belgenin sonundadır.
    private func enter(_ md: String, imlec: Int? = nil) -> String? {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret(md))
        guard let degisim = yapiEnterKurali(belge, imlec: NSRange(location: imlec ?? belge.length, length: 0)) else { return nil }
        belge.replaceCharacters(in: degisim.aralik, with: degisim.metin)
        return markdownMetniUret(belge)
    }

    private func geriSil(_ md: String) -> String? {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret(md))
        // İmleç son satırın işaretinden hemen sonra.
        let son = (belge.string as NSString).paragraphRange(for: NSRange(location: belge.length, length: 0))
        let imlec = son.location + blokIsaretiUzunlugu(belge, konum: son.location)
        guard let degisim = yapiDevamindaGeriSil(belge, imlec: NSRange(location: imlec, length: 0)) else { return nil }
        belge.replaceCharacters(in: degisim.aralik, with: degisim.metin)
        return markdownMetniUret(belge)
    }

    func testMaddeListesiDevamEder() {
        XCTAssertEqual(enter("- bir"), "- bir\n- ")
    }

    func testNumaraliListeArtar() {
        XCTAssertEqual(enter("1. bir"), "1. bir\n2. ")
    }

    func testGorevYeniAcikGorevAcar() {
        XCTAssertEqual(enter("- [x] bitti"), "- [x] bitti\n- [ ] ")
    }

    func testAlintiDevamEder() {
        XCTAssertEqual(enter("> söz"), "> söz\n> ")
    }

    /// Boş maddede Enter listeden çıkar; imleç yeni, boş ve normal bir paragrafa geçer.
    func testBosMaddedeListedenCikilir() throws {
        let iki = try XCTUnwrap(enter("- bir"))
        XCTAssertEqual(enter(iki), "- bir\n\n")
    }

    func testDuzParagraftaKuralDevredisi() {
        XCTAssertNil(enter("düz metin"), "normal paragrafta sistemin Enter'ı çalışmalı")
    }

    func testBaslikSonrasiNormalParagraf() throws {
        let sonuc = try XCTUnwrap(enter("# Başlık"))
        XCTAssertEqual(sonuc, "# Başlık\n")
    }

    func testOrtadanBolunenMaddeIkiMaddeOlur() throws {
        let belge = markdowndenAttributedStringUret("- birinci")
        let ortasi = (belge.string as NSString).range(of: "inci").location
        XCTAssertEqual(enter("- birinci", imlec: ortasi), "- bir\n- inci")
    }

    func testGeriSilmeDevamSatiriniBirlestirir() {
        XCTAssertEqual(geriSil("- bir\n- iki"), "- biriki")
    }

    func testFarkliTurlerBirlesmez() {
        XCTAssertNil(geriSil("- bir\n1. iki"))
    }
}
