import Foundation
import XCTest
@testable import NotDefteriCekirdek

final class KodBloguEnterTestleri: XCTestCase {
    private func uygula(_ degisim: YapiEnterDegisimi, belge: NSMutableAttributedString) -> Int {
        belge.replaceCharacters(in: degisim.aralik, with: degisim.metin)
        return degisim.imlec
    }

    func testArdisikEnterKodIcindeBosSatirlariKayittaKorur() throws {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("```swift\nilk\n```\n"))
        var imlec = (belge.string as NSString).range(of: "ilk").upperBound
        var yazim: [NSAttributedString.Key: Any] = [:]
        for _ in 0..<4 {
            let degisim = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0)))
            imlec = uygula(degisim, belge: belge)
            yazim = degisim.yazim
            XCTAssertNotNil(degisim.yazim[kKodBloguAnahtari])
        }
        belge.insert(NSAttributedString(string: "son", attributes: yazim), at: imlec)
        XCTAssertEqual(markdownMetniUret(belge), "```swift\nilk\n\n\n\nson\n```\n")
    }

    func testAcikCikisOrtadanVeSondanTumGovdeyiKorurVeGeriAlinabilir() throws {
        for ortadan in [true, false] {
            let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("```swift\nilk\n\nson\n```\n"))
            let once = NSAttributedString(attributedString: belge)
            let imlec = (belge.string as NSString).range(of: ortadan ? "ilk" : "son").upperBound
            let degisim = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0), koddanCik: true))
            let eski = belge.attributedSubstring(from: degisim.aralik)
            let hedef = uygula(degisim, belge: belge)
            XCTAssertNil(belge.attribute(kKodBloguAnahtari, at: hedef, effectiveRange: nil))
            belge.insert(NSAttributedString(string: "disarida", attributes: degisim.yazim), at: hedef)
            XCTAssertEqual(markdownMetniUret(belge), "```swift\nilk\n\nson\n```\ndisarida\n")
            belge.deleteCharacters(in: NSRange(location: hedef, length: 8))
            belge.replaceCharacters(in: NSRange(location: degisim.aralik.location, length: degisim.metin.length), with: eski)
            XCTAssertTrue(belge.isEqual(to: once))
        }
    }

    func testBoslukluKodSatirindaEnterGovdeyiKorur() throws {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("```swift\n  \nson\n```\n"))
        let imlec = (belge.string as NSString).range(of: "  ").upperBound
        let degisim = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0)))
        _ = uygula(degisim, belge: belge)
        XCTAssertNotNil(degisim.yazim[kKodBloguAnahtari])
        XCTAssertEqual(markdownMetniUret(belge), "```swift\n  \n\nson\n```\n")
    }

    func testAcikCikisKapanmamisUzunKodAyiraciniEsler() throws {
        let kaynak = "````swift\nilk\n```\nson\n"
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret(kaynak))
        let imlec = (belge.string as NSString).range(of: "ilk").upperBound
        let degisim = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0), koddanCik: true))
        let hedef = uygula(degisim, belge: belge)
        let kod = try XCTUnwrap(belge.attribute(kKodBloguAnahtari, at: 0, effectiveRange: nil) as? [String: String])
        XCTAssertEqual(kod["kapanis"], "````\n")
        belge.insert(NSAttributedString(string: "disarida", attributes: degisim.yazim), at: hedef)
        let kayit = markdownMetniUret(belge)
        XCTAssertEqual(kayit, kaynak + "````\ndisarida\n")
        let yeniden = markdowndenAttributedStringUret(kayit)
        let disarida = (yeniden.string as NSString).range(of: "disarida").location
        XCTAssertNil(yeniden.attribute(kKodBloguAnahtari, at: disarida, effectiveRange: nil))
    }

    func testDesteklenmeyenTildeAyiraciDuzMetinKalir() {
        let kaynak = "~~~swift\nilk\n"
        let belge = markdowndenAttributedStringUret(kaynak)
        XCTAssertNil(yapiEnterKurali(belge, imlec: NSRange(location: 5, length: 0), koddanCik: true))
        XCTAssertEqual(markdownMetniUret(belge), kaynak)
    }

    func testKodEnterGeriSilIleBirlesir() throws {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("```swift\nilkson\n```\n"))
        let imlec = (belge.string as NSString).range(of: "ilk").upperBound
        let enter = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0)))
        let hedef = uygula(enter, belge: belge)
        let sil = try XCTUnwrap(yapiDevamindaGeriSil(belge, imlec: NSRange(location: hedef, length: 0)))
        _ = uygula(sil, belge: belge)
        XCTAssertEqual(markdownMetniUret(belge), "```swift\nilkson\n```\n")
    }

    func testBosListeVeUyariEnterIleCikmayaDevamEder() throws {
        for blok in [MetinBlogu(tur: .madde), MetinBlogu(tur: .uyari, uyariKimligi: "uyari")] {
            let belge = NSMutableAttributedString(attributedString: blokIsaretiniUret(blok))
            belge.append(NSAttributedString(string: "\n", attributes: blok.oznitelikler))
            let imlec = belge.length - 1
            XCTAssertNotNil(belge.attribute(kMetinBloguAnahtari, at: imlec, effectiveRange: nil))
            let degisim = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0)))
            _ = uygula(degisim, belge: belge)
            XCTAssertNil(degisim.yazim[kMetinBloguAnahtari])
            XCTAssertNil(belge.attribute(kMetinBloguAnahtari, at: degisim.imlec, effectiveRange: nil))
        }
    }
}
