import XCTest
import AppKit
@testable import NotDefteriMac

/// Başlıktan sürüklenen pencerenin ekran kenarında aldığı yer.
final class PencereYerlesimiTestleri: XCTestCase {

    private let ekran = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let alan = NSRect(x: 0, y: 0, width: 1440, height: 875)  // Menü çubuğu hariç.

    func testKenaraDegmeyenFareYerlesimYok() {
        XCTAssertNil(Yerlesim.bul(fare: NSPoint(x: 700, y: 450), ekran: ekran))
    }

    func testSagVeSolKenarYariya() {
        XCTAssertEqual(Yerlesim.bul(fare: NSPoint(x: 1439, y: 450), ekran: ekran), .sag)
        XCTAssertEqual(Yerlesim.bul(fare: NSPoint(x: 0, y: 450), ekran: ekran), .sol)
    }

    func testUstKenarDoldurur() {
        XCTAssertEqual(Yerlesim.bul(fare: NSPoint(x: 700, y: 899), ekran: ekran), .doldur)
    }

    func testKoselerCeyrege() {
        XCTAssertEqual(Yerlesim.bul(fare: NSPoint(x: 0, y: 899), ekran: ekran), .solUst)
        XCTAssertEqual(Yerlesim.bul(fare: NSPoint(x: 1439, y: 10), ekran: ekran), .sagAlt)
    }

    func testIkinciEkranKendiKenarinaGore() {
        let ikinci = NSRect(x: 1440, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(Yerlesim.bul(fare: NSPoint(x: 3359, y: 500), ekran: ikinci), .sag)
        XCTAssertNil(Yerlesim.bul(fare: NSPoint(x: 1500, y: 500), ekran: ikinci))
    }

    func testCercevelerAlaniBolerVeKaplar() {
        XCTAssertEqual(Yerlesim.doldur.cerceve(alan), alan)
        XCTAssertEqual(Yerlesim.sag.cerceve(alan), NSRect(x: 720, y: 0, width: 720, height: 875))
        let sol = Yerlesim.sol.cerceve(alan), sag = Yerlesim.sag.cerceve(alan)
        XCTAssertEqual(sol.maxX, sag.minX)
        XCTAssertEqual(sol.width + sag.width, alan.width)
        let ust = Yerlesim.solUst.cerceve(alan), alt = Yerlesim.solAlt.cerceve(alan)
        XCTAssertEqual(alt.maxY, ust.minY)
        XCTAssertEqual(ust.height + alt.height, alan.height)
    }
}
