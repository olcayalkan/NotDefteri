import XCTest
@testable import NotDefteriCekirdek

/// ⌘O ile ortalanan satır `<center>…</center>` olarak kaydolur ve açılınca ortalı gelir.
final class OrtaliSatirTestleri: XCTestCase {

    private func ortaliMi(_ attr: NSAttributedString, _ metin: String) -> Bool {
        let konum = (attr.string as NSString).range(of: metin).location
        return attr.attribute(kOrtaliAnahtari, at: konum, effectiveRange: nil) as? Bool == true
    }

    func testOrtaliSatirGidisDonusu() {
        let metin = "<center>**Kalın** yazı</center>\nnormal\n<center># Başlık</center>\n"
        let attr = markdowndenAttributedStringUret(metin)
        XCTAssertEqual(markdownMetniUret(attr), metin)
        XCTAssertTrue(ortaliMi(attr, "Kalın"))
        XCTAssertFalse(ortaliMi(attr, "normal"))
        XCTAssertTrue(ortaliMi(attr, "Başlık"))
        XCTAssertEqual(attr.attribute(kBaslikSeviyesiAnahtari, at: (attr.string as NSString).range(of: "Başlık").location,
                                      effectiveRange: nil) as? Int, 1, "içerik Markdown olarak çözülür")
    }

    func testOrtaliOznitelikCenterIleYazilir() {
        let attr = NSMutableAttributedString(string: "orta\nsol\n")
        attr.addAttribute(kOrtaliAnahtari, value: true, range: NSRange(location: 0, length: 5))
        XCTAssertEqual(markdownMetniUret(attr), "<center>orta</center>\nsol\n")
    }

    func testBosVeKapanmayanCenterDuzMetinKalir() {
        for metin in ["<center></center>\n", "<center>yarım\n", "<center>a</center> b</center>\n"] {
            let attr = markdowndenAttributedStringUret(metin)
            XCTAssertEqual(markdownMetniUret(attr), metin)
            XCTAssertNil(attr.attribute(kOrtaliAnahtari, at: 0, effectiveRange: nil), metin)
        }
    }

    /// Kutu, alıntı ve listede `<center>` blok önekinden sonra gelir; blok yapısı korunur.
    func testBlokSatirlarindaOrtaliGidisDonusu() {
        let metin = "> [!💡 mavi] <center>baş</center>\n> <center>devam</center>\n> düz\n\n- <center>madde</center>\n> <center>alıntı</center>\n"
        let attr = markdowndenAttributedStringUret(metin)
        XCTAssertEqual(markdownMetniUret(attr), metin)
        for parca in ["baş", "devam", "madde", "alıntı"] { XCTAssertTrue(ortaliMi(attr, parca), parca) }
        XCTAssertFalse(ortaliMi(attr, "düz"))
        let devam = (attr.string as NSString).range(of: "devam").location
        XCTAssertEqual(MetinBlogu(oznitelik: attr.attribute(kMetinBloguAnahtari, at: devam, effectiveRange: nil))?.tur, .uyari,
                       "ortalı devam satırı kutuda kalır")
    }

    func testBlokSatiriOrtaliYazilir() {
        let attr = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("> [!💡 mavi] bir\n> iki\n"))
        let iki = (attr.string as NSString).paragraphRange(for: NSRange(location: (attr.string as NSString).range(of: "iki").location, length: 0))
        attr.addAttribute(kOrtaliAnahtari, value: true, range: iki)
        XCTAssertEqual(markdownMetniUret(attr), "> [!💡 mavi] bir\n> <center>iki</center>\n")
    }

    /// Kod bloğu bütün olarak açılış çitindeki {center} ile ortalanır; dil etiketi bozulmaz.
    func testKodBloguOrtalamasi() {
        let sinirlar = kodBloguSinirlari(acilis: "```swift\n", kapanis: "```\n")
        let ortali = kodBloguOrtalanmis(sinirlar, ortali: true)
        XCTAssertEqual(ortali["acilis"], "```swift {center}\n")
        XCTAssertTrue(kodBloguOrtaliMi(ortali))
        XCTAssertEqual(kodBloguDilEtiketi(ortali), "swift")
        XCTAssertEqual(kodBloguOrtalanmis(ortali, ortali: false)["acilis"], "```swift\n")
        XCTAssertEqual(kodBloguDilEtiketi(kodBloguOrtalanmis(kodBloguSinirlari(acilis: "```\n", kapanis: "```\n"), ortali: true)), "")
        let metin = "```swift {center}\nlet a = 1\n```\n"
        XCTAssertEqual(markdownMetniUret(markdowndenAttributedStringUret(metin)), metin)
    }

    func testHtmlDisaAktarimdaOrtali() throws {
        let html = try htmlUret(markdown: "<center>orta</center>\n", baslik: "t",
                                taban: URL(fileURLWithPath: NSTemporaryDirectory()))
        XCTAssertTrue(html.contains("<p style=\"text-align:center\">orta"), html)
    }
}
