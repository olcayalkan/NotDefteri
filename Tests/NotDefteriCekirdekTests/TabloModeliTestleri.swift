import XCTest
@testable import NotDefteriCekirdek

final class TabloModeliTestleri: XCTestCase {
    func testTekHucreDuzenlemesiDigerKaynaklariVeHizalamayiKorur() throws {
        let kaynak = "|  Ad | **Değer** |\r\n| :--- | ---: |\r\n| Bir | 1 |"
        var model = try XCTUnwrap(TabloModeli(markdown: kaynak))
        XCTAssertEqual(model.markdown(), kaynak)
        XCTAssertTrue(model.hucreyiGuncelle(satir: 1, sutun: 0, metin: "İki"))
        XCTAssertEqual(model.markdown(), kaynak.replacingOccurrences(of: "Bir", with: "İki"))
        XCTAssertEqual(model.hucre(satir: 0, sutun: 1), "**Değer**")
        XCTAssertFalse(model.hucreyiGuncelle(satir: 9, sutun: 0, metin: "Yok"))
    }

    func testLiteralAyiraclarBosBaslikVeYeniSatirYenidenAcilir() throws {
        var model = try XCTUnwrap(TabloModeli(markdown: "| Ad | Değer |\n| --- | --- |\n| Bir | 1 |\n"))
        XCTAssertTrue(model.hucreyiGuncelle(satir: 0, sutun: 0, metin: ""))
        let metin = "a|b\\c│d\nikinci"
        XCTAssertTrue(model.hucreyiGuncelle(satir: 1, sutun: 0, metin: metin))
        let tekrar = try XCTUnwrap(TabloModeli(markdown: model.markdown()))
        XCTAssertEqual(tekrar.hucre(satir: 1, sutun: 0), metin)
        XCTAssertEqual(tekrar.hucre(satir: 0, sutun: 0), "")
        let belge = markdowndenAttributedStringUret(model.markdown())
        let saklanan = try XCTUnwrap(TabloModeli(oznitelik: belge.attribute(kTabloModeliAnahtari, at: 0, effectiveRange: nil)))
        XCTAssertEqual(belge.string, saklanan.gorsel().metin)
        XCTAssertEqual(belge.string, tekrar.gorsel().metin)
        XCTAssertEqual(markdownMetniUret(belge), model.markdown())
    }

    func testYazarkenHucreKenarBosluklariKaynakPaddinginiBuyutmez() throws {
        let kaynak = "| Ad | Değer |\n| --- | --- |\n| Bir | 1 |\n"
        var model = try XCTUnwrap(TabloModeli(markdown: kaynak))
        for _ in 0..<3 {
            XCTAssertTrue(model.hucreyiGuncelle(satir: 1, sutun: 0, metin: "Bir "))
            XCTAssertEqual(model.markdown(), kaynak)
            XCTAssertTrue(model.hucreyiGuncelle(satir: 1, sutun: 0, metin: "Bir İki"))
            XCTAssertEqual(model.markdown(), kaynak.replacingOccurrences(of: "Bir", with: "Bir İki"))
            XCTAssertTrue(model.hucreyiGuncelle(satir: 1, sutun: 0, metin: "Bir "))
            XCTAssertTrue(model.hucreyiGuncelle(satir: 1, sutun: 0, metin: "Bir"))
            XCTAssertEqual(model.markdown(), kaynak)
        }
        XCTAssertTrue(model.hucreyiGuncelle(satir: 1, sutun: 0, metin: "  başka söz\t"))
        XCTAssertEqual(model.markdown(), kaynak.replacingOccurrences(of: "Bir", with: "başka söz"))
    }

    func testSonKacisliBoruDisAyiracSanilmaz() throws {
        let kaynak = "A | B\\|\n--- | ---\nC | D\\|\n"
        let model = try XCTUnwrap(TabloModeli(markdown: kaynak))
        XCTAssertEqual(model.hucre(satir: 1, sutun: 1), "D|")
        let belge = markdowndenAttributedStringUret(kaynak)
        XCTAssertNotNil(belge.attribute(kTabloModeliAnahtari, at: 0, effectiveRange: nil))
        XCTAssertEqual(markdownMetniUret(belge), kaynak)
    }

    func testHucreAraligiUnicodeDikeyCizgiyiBolmez() throws {
        let model = try XCTUnwrap(TabloModeli(markdown: "| A | B |\n| --- | --- |\n| ş😀│ | son |\n"))
        let aralik = try XCTUnwrap(model.hucreAraligi(satir: 1, sutun: 0))
        XCTAssertEqual((model.gorsel().metin as NSString).substring(with: aralik), "ş😀│")
        XCTAssertNil(model.hucreAraligi(satir: 2, sutun: 0))
        let kopru = try XCTUnwrap(TabloModeli(oznitelik: model.oznitelikDegeri))
        XCTAssertEqual(kopru.markdown(), model.markdown())
    }

    func testGovdedekiSadeceCizgilerTabloVerisiOlarakKalir() throws {
        let kaynak = "| Durum | Değer |\n| --- | --- |\n| --- | --- |\n| tamam | evet |\n"
        let belge = markdowndenAttributedStringUret(kaynak)

        let model = try XCTUnwrap(TabloModeli(oznitelik: belge.attribute(kTabloModeliAnahtari, at: 0, effectiveRange: nil)))
        XCTAssertEqual(model.hucre(satir: 1, sutun: 0), "---")
        XCTAssertEqual(model.hucre(satir: 2, sutun: 1), "evet")
        XCTAssertEqual(markdownMetniUret(belge), kaynak)
    }
}
