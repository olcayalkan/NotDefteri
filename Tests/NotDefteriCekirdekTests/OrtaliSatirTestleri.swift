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

    func testHtmlDisaAktarimdaOrtali() throws {
        let html = try htmlUret(markdown: "<center>orta</center>\n", baslik: "t",
                                taban: URL(fileURLWithPath: NSTemporaryDirectory()))
        XCTAssertTrue(html.contains("<p style=\"text-align:center\">orta"), html)
    }
}
