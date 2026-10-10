import XCTest
import NotDefteriCekirdek
@testable import NotDefteriLinux

final class LinuxYazimOznitelikleriTestleri: XCTestCase {
    func testTabloGorselOznitelikleriSonrakiDuzMetneTasinmaz() {
        let o: Oznitelikler = [
            kTabloGorselAnahtari: "tablo-1",
            kTabloModeliAnahtari: ["markdown": "| A | B |"],
            kTabloSatiriAnahtari: TabloSatiriTuru.govde.rawValue,
            kKalinAnahtari: true
        ]

        let sonuc = LinuxEditor.yapisalYazimIsaretleriniTemizle(o)

        XCTAssertNil(sonuc[kTabloGorselAnahtari])
        XCTAssertNil(sonuc[kTabloModeliAnahtari])
        XCTAssertNil(sonuc[kTabloSatiriAnahtari])
        XCTAssertEqual(sonuc[kKalinAnahtari] as? Bool, true)
    }
}
