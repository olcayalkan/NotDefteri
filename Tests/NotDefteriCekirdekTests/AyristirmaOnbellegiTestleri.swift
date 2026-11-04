import XCTest
@testable import NotDefteriCekirdek

/// Büyük sayfa yeniden açılınca ayrıştırılmaz; önbellek dönüşü çağıranın değişikliğinden etkilenmez.
final class AyristirmaOnbellegiTestleri: XCTestCase {
    private let buyuk = String(repeating: "Düz **kalın** satır ve `kod`.\n- madde\n", count: 300)
    private let taban = URL(fileURLWithPath: "/tmp/onbellek-test")

    func testAyniMetinAyniBelgeyiVerirVeKopyaDegisinceBozulmaz() {
        let ilk = markdowndenAttributedStringUret(buyuk, taban: taban)
        let kopya = NSMutableAttributedString(attributedString: ilk)
        kopya.replaceCharacters(in: NSRange(location: 0, length: 3), with: "XYZ")
        let ikinci = markdowndenAttributedStringUret(buyuk, taban: taban)
        XCTAssertTrue(ilk === ikinci, "ikinci açılış önbellekten gelmeli")
        XCTAssertFalse(ikinci is NSMutableAttributedString, "önbellek değiştirilemez kopya tutar")
        XCTAssertEqual(markdownMetniUret(ikinci), buyuk)
    }

    func testFarkliTabanVeKucukMetinAyriAyristirilir() {
        let a = markdowndenAttributedStringUret(buyuk, taban: taban)
        let b = markdowndenAttributedStringUret(buyuk, taban: taban.appendingPathComponent("baska"))
        XCTAssertFalse(a === b)
        XCTAssertFalse(markdowndenAttributedStringUret("kısa\n") === markdowndenAttributedStringUret("kısa\n"))
    }
}
