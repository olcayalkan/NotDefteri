import XCTest
import AppKit
@testable import NotDefteriMac

/// Ana Sayfa kart ızgarası: genişliğe göre sütun ve çerçeveler.
final class AnaSayfaIzgaraTestleri: XCTestCase {

    func testDarAlandaTekSutun() {
        XCTAssertEqual(KartIzgarasi.olc(genislik: 150, enAzKart: 200).sutun, 1)
    }

    func testGenisledikceSutunArtar() {
        XCTAssertEqual(KartIzgarasi.olc(genislik: 412, enAzKart: 200).sutun, 2)
        XCTAssertEqual(KartIzgarasi.olc(genislik: 411, enAzKart: 200).sutun, 1)
        XCTAssertEqual(KartIzgarasi.olc(genislik: 1000, enAzKart: 200).sutun, 4)
    }

    func testKartlarSatiraTamOturur() {
        let (sutun, kart) = KartIzgarasi.olc(genislik: 1000, enAzKart: 200)
        XCTAssertEqual(CGFloat(sutun) * kart + CGFloat(sutun - 1) * KartIzgarasi.aralik, 1000, accuracy: 0.001)
    }

    func testCercevelerSatirlaraDizilir() {
        let sonuc = KartIzgarasi.cerceveler(adet: 5, genislik: 424, enAzKart: 200, yukseklik: 100)
        XCTAssertEqual(sonuc.sutun, 2)
        XCTAssertEqual(sonuc.cerceveler.count, 5)
        XCTAssertEqual(sonuc.cerceveler[1].minX, sonuc.cerceveler[0].maxX + KartIzgarasi.aralik)
        XCTAssertEqual(sonuc.cerceveler[2].minY, 100 + KartIzgarasi.aralik)
        XCTAssertEqual(sonuc.yukseklik, 3 * 100 + 2 * KartIzgarasi.aralik)
    }

    func testBosIzgaraYerKaplamaz() {
        XCTAssertEqual(KartIzgarasi.cerceveler(adet: 0, genislik: 600, enAzKart: 200, yukseklik: 100).yukseklik, 0)
    }

    func testSayfaRengiKararli() {
        XCTAssertEqual(AnaSayfa.sayfaRengi("Proje"), AnaSayfa.sayfaRengi("Proje"))
    }
}
