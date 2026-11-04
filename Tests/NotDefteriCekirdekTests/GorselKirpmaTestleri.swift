import XCTest
@testable import NotDefteriCekirdek

/// Görsel kırpması Markdown'a `{EnxBoy kirp=x,y,w,h}` olarak yazılır ve aynen okunur.
final class GorselKirpmaTestleri: XCTestCase {

    private var klasor: URL!

    override func setUpWithError() throws {
        klasor = FileManager.default.temporaryDirectory.appendingPathComponent("kirpma-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: klasor.appendingPathComponent("a.png"))
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: klasor) }

    private func cozumle(_ md: String) -> [String: Any]? {
        resimBaginiCozumle(md as NSString, 0, taban: klasor)?.0
    }

    func testKirpmaOkunur() {
        let gorsel = cozumle("![](a.png){270x200 kirp=0.1,0,0.9,1}")
        XCTAssertEqual(gorsel?["kirpma"] as? String, "0.1,0,0.9,1")
        XCTAssertEqual(gorsel?["genislik"] as? Double, 270)
    }

    func testTamKirpmaVeGecersizKirpmaYazilmaz() {
        XCTAssertNil(cozumle("![](a.png){300x200 kirp=0,0,1,1}")?["kirpma"])
        XCTAssertNil(cozumle("![](a.png){300x200 kirp=0.5,0,0.9,1}")?["kirpma"], "görselin dışına taşıyor")
        XCTAssertNil(cozumle("![](a.png){300x200 kirp=0,0,0.001,1}")?["kirpma"], "çok dar")
    }

    func testKirpmaYazilir() {
        let gorsel: [String: Any] = ["yol": "a.png", "dosyaURL": klasor.appendingPathComponent("a.png"),
                                     "genislik": 270.0, "yukseklik": 200.0, "kirpma": "0.1,0,0.9,1"]
        let belge = NSAttributedString(string: "\u{FFFC}", attributes: [kGorselAnahtari: gorsel])
        XCTAssertEqual(markdownMetniUret(belge), "![](a.png){270x200 kirp=0.1,0,0.9,1}")
    }

    func testMetinDortBasamagaYuvarlanir() {
        XCTAssertEqual(GorselKirpma(x: 1.0 / 3, y: 0, w: 2.0 / 3, h: 1).metin, "0.3333,0,0.6667,1")
    }

    func testIsaretlemeTemizlenir() {
        XCTAssertEqual(isaretlemeleriTemizle("a![](b.png){10x10 kirp=0,0,0.5,1}c"), "ac")
    }
}
