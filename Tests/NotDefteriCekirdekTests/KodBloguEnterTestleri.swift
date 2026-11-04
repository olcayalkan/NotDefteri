import Foundation
import XCTest
@testable import NotDefteriCekirdek

final class KodBloguEnterTestleri: XCTestCase {
    private func uygula(_ degisim: YapiEnterDegisimi, belge: NSMutableAttributedString) -> Int {
        belge.replaceCharacters(in: degisim.aralik, with: degisim.metin)
        return degisim.imlec
    }

    /// Kodun ortasındaki boş satırda Enter kodda kalır; boş satırlar kayda geçer.
    func testArdisikEnterKodIcindeBosSatirlariKayittaKorur() throws {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("```swift\nilk\nson\n```\n"))
        var imlec = (belge.string as NSString).range(of: "ilk").upperBound
        var yazim: [NSAttributedString.Key: Any] = [:]
        for _ in 0..<3 {
            let degisim = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0)))
            imlec = uygula(degisim, belge: belge)
            yazim = degisim.yazim
            XCTAssertNotNil(degisim.yazim[kKodBloguAnahtari])
        }
        belge.insert(NSAttributedString(string: "orta", attributes: yazim), at: imlec)
        XCTAssertEqual(markdownMetniUret(belge), "```swift\nilk\n\n\norta\nson\n```\n")
    }

    /// Kodun son satırında art arda üç Enter koddan çıkar; boş satırlar kodda kalmaz.
    func testSonSatirdaUcuncuEnterKoddanCikar() throws {
        for (kaynak, beklenen) in [("```swift\nilk\n```\n", "```swift\nilk\n```\ndisarida\n"),
                                   // Altındaki boş satır yeniden kullanılır; boş satır çoğalmaz.
                                   ("```swift\nilk\n```\n\nalt\n", "```swift\nilk\n```\ndisarida\nalt\n"),
                                   ("```swift\nilk\n```\nalt\n", "```swift\nilk\n```\ndisarida\nalt\n"),
                                   ("```swift\nilk\n", "```swift\nilk\n```\ndisarida\n")] {
            let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret(kaynak))
            let imlec = (belge.string as NSString).range(of: "ilk").upperBound
            var bos = imlec
            // İlk iki Enter kodda boş satır açar.
            for _ in 0..<2 {
                let degisim = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: bos, length: 0)))
                bos = uygula(degisim, belge: belge)
                XCTAssertNotNil(belge.attribute(kKodBloguAnahtari, at: bos, effectiveRange: nil), kaynak)
                XCTAssertNotNil(degisim.yazim[kKodBloguAnahtari], kaynak)
            }
            let ikinci = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: bos, length: 0)))
            let araDurum = NSAttributedString(attributedString: belge)
            let eski = belge.attributedSubstring(from: ikinci.aralik)
            let hedef = uygula(ikinci, belge: belge)
            XCTAssertNil(belge.attribute(kKodBloguAnahtari, at: hedef, effectiveRange: nil), kaynak)
            XCTAssertNil(ikinci.yazim[kKodBloguAnahtari])
            belge.insert(NSAttributedString(string: "disarida", attributes: ikinci.yazim), at: hedef)
            XCTAssertEqual(markdownMetniUret(belge), beklenen)
            // Çıkış tek değişimdir; tersine uygulanınca imleç yeniden koddaki boş satırdadır.
            belge.deleteCharacters(in: NSRange(location: hedef, length: 8))
            belge.replaceCharacters(in: NSRange(location: ikinci.aralik.location, length: ikinci.metin.length), with: eski)
            XCTAssertTrue(belge.isEqual(to: araDurum), kaynak)
        }
    }

    /// Yeni açılan tek satırlık boş kutuda Enter kutuda yeni satır açar; kutu kaybolmaz.
    func testTekSatirlikBosKoddaEnterKoddaKalir() throws {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("```swift\n\n```\n"))
        let imlec = blokIsaretiUzunlugu(belge)
        let degisim = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0)))
        XCTAssertNotNil(degisim.yazim[kKodBloguAnahtari])
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

    func testBosListeEnterIleCikmayaDevamEder() throws {
        for blok in [MetinBlogu(tur: .madde)] {
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

    /// Uyarı kutusu kod bloğu gibi: boş satırda Enter kutuda yeni satır açar (yazı kutunun
    /// dışına düşmez), Ctrl+Enter kutunun altına çıkar.
    func testBosUyariSatirindaEnterKutudaKalirCtrlEnterCikar() throws {
        let blok = MetinBlogu(tur: .uyari, uyariKimligi: "uyari")
        let belge = NSMutableAttributedString(attributedString: blokIsaretiniUret(blok))
        belge.append(NSAttributedString(string: "\n", attributes: blok.oznitelikler))
        let enter = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: belge.length - 1, length: 0)))
        let hedef = uygula(enter, belge: belge)
        XCTAssertEqual(belge.attribute(kUyariKutusuAnahtari, at: hedef, effectiveRange: nil) as? String, "uyari")
        XCTAssertEqual(MetinBlogu(oznitelik: enter.yazim[kMetinBloguAnahtari])?.tur, .uyari)
        let cikis = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: hedef, length: 0), koddanCik: true))
        let disari = uygula(cikis, belge: belge)
        XCTAssertNil(belge.attribute(kMetinBloguAnahtari, at: disari, effectiveRange: nil))
        XCTAssertNil(belge.attribute(kUyariKutusuAnahtari, at: disari, effectiveRange: nil))
        XCTAssertEqual(markdownMetniUret(belge), "> [!💡 sarı] \n> \n\n")
    }

    /// Uyarı kutusunun son satırında iki Enter kutudan çıkar; ortadaki boş satır kutuda kalır.
    func testUyariSonSatirdaIkinciEnterKutudanCikar() throws {
        let belge = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("> [!💡 mavi] bir\n> \n> iki\n"))
        let ns = belge.string as NSString
        let orta = NSMaxRange(ns.paragraphRange(for: ns.range(of: "bir"))) + 1
        let ortaEnter = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: orta, length: 0)))
        XCTAssertEqual(MetinBlogu(oznitelik: ortaEnter.yazim[kMetinBloguAnahtari])?.tur, .uyari)
        let imlec = (belge.string as NSString).range(of: "iki").upperBound
        let ilk = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: imlec, length: 0)))
        let bos = uygula(ilk, belge: belge)
        XCTAssertNotNil(belge.attribute(kUyariKutusuAnahtari, at: bos, effectiveRange: nil))
        let ikinci = try XCTUnwrap(yapiEnterKurali(belge, imlec: NSRange(location: bos, length: 0)))
        let hedef = uygula(ikinci, belge: belge)
        XCTAssertNil(belge.attribute(kUyariKutusuAnahtari, at: hedef, effectiveRange: nil))
        belge.insert(NSAttributedString(string: "disarida", attributes: ikinci.yazim), at: hedef)
        XCTAssertEqual(markdownMetniUret(belge), "> [!💡 mavi] bir\n> \n> iki\ndisarida\n")
    }
}
