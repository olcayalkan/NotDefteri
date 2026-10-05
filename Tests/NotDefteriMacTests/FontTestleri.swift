import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

final class FontTestleri: XCTestCase {

    func testKalinMi() {
        XCTAssertTrue(kalinMi(fontUret(boyut: 14, kalin: true)))
        XCTAssertFalse(kalinMi(fontUret(boyut: 14, kalin: false)))
    }

    func testBaslikFontuSeviyeyeGoreBuyur() {
        let b1 = baslikFontu(1).pointSize
        let b2 = baslikFontu(2).pointSize
        let b3 = baslikFontu(3).pointSize
        XCTAssertGreaterThan(b1, b2)
        XCTAssertGreaterThan(b2, b3)
        XCTAssertGreaterThan(b3, kTabanPunto, "en küçük başlık bile tabandan büyük olmalı")
        XCTAssertTrue(kalinMi(baslikFontu(1)), "başlıklar kalın olmalı")
    }

    func testVarsayilanFontTabanPuntoda() {
        XCTAssertEqual(varsayilanFont().pointSize, kTabanPunto)
        XCTAssertFalse(kalinMi(varsayilanFont()))
    }
}
