import XCTest
import AppKit
@testable import NotDefteriMac

/// Uzak görsel içeren HTML yapıştırılınca AppKit görseli ana thread'de indiriyordu;
/// erişilemeyen adres uygulamayı ~60 sn donduruyordu.
final class YapistirmaDonmaTestleri: XCTestCase {

    private let pano = NSPasteboard(name: NSPasteboard.Name("notdefteri-yapistirma-donma-testi"))

    override func tearDown() {
        pano.releaseGlobally()
    }

    /// Yönlendirilemeyen adres bağlantı zaman aşımına kadar bekletir; ağ yoksa test hızlı geçer.
    private func uzakGorselliHtml() {
        pano.clearContents()
        let html = "<p>Önce</p><img src='https://10.255.255.1/resim.png'><p>Sonra</p>"
        pano.setData(Data(html.utf8), forType: .html)
        pano.setString("Önce Sonra", forType: .string)
    }

    private func sureliOku(_ gorunum: NotMetinGorunumu) -> TimeInterval {
        let baslangic = Date()
        XCTAssertTrue(gorunum.readSelection(from: pano, type: .html))
        return Date().timeIntervalSince(baslangic)
    }

    func testUzakGorselliHtmlDondurmaz() {
        uzakGorselliHtml()
        let gorunum = NotMetinGorunumu()
        XCTAssertLessThan(sureliOku(gorunum), 10)
        XCTAssertTrue(gorunum.string.contains("Önce"))
    }

    func testKaynakBicimiyleYapistirmaDondurmaz() {
        uzakGorselliHtml()
        let gorunum = NotMetinGorunumu()
        gorunum.hamYapistirmaModu = true
        defer { gorunum.hamYapistirmaModu = false }
        XCTAssertLessThan(sureliOku(gorunum), 10)
        XCTAssertTrue(gorunum.string.contains("Önce"))
    }
}
