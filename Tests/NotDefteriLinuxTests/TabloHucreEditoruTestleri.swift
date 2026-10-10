import XCTest
import CGtk
import NotDefteriCekirdek
@testable import NotDefteriLinux

final class TabloHucreEditoruTestleri: XCTestCase {
    private static let gtkHazir = GrafikTestOrtami.hazir

    override func setUpWithError() throws {
        try XCTSkipUnless(Self.gtkHazir, "GTK grafik ekranı yok.")
    }

    // Removing the entry's changed bridge must leave the model unchanged and fail this test.
    func testYerelGirisUzunUnicodeMetniKomsuHucreyiBozmadanKaydeder() throws {
        var model = try XCTUnwrap(TabloModeli(markdown: "| Ad | Soyad |\n| --- | --- |\n| A | B |\n"))
        let giris = LinuxTabloHucreEditoru(metin: "A") { metin in
            _ = model.hucreyiGuncelle(satir: 1, sutun: 0, metin: metin)
        }
        let uzun = String(repeating: "İstanbul 👩🏽‍💻 | ", count: 30) + "son"
        gtk_editable_set_text(OpaquePointer(giris.widget), uzun)
        XCTAssertEqual(model.hucre(satir: 1, sutun: 0), uzun)
        XCTAssertEqual(model.hucre(satir: 1, sutun: 1), "B")
        let tekrar = try XCTUnwrap(TabloModeli(markdown: model.markdown()))
        XCTAssertEqual(tekrar.hucre(satir: 1, sutun: 0), uzun)
    }

    func testTabVeShiftTabHucreGezinmesiniYerelGiriseBirakmaz() {
        let giris = LinuxTabloHucreEditoru(metin: "A") { _ in }
        var hareketler: [Int] = []
        giris.gezin = { hareketler.append($0) }
        XCTAssertTrue(giris.tusIsle(0xff09, durum: 0))
        XCTAssertTrue(giris.tusIsle(0xfe20, durum: GDK_SHIFT_MASK.rawValue))
        XCTAssertEqual(hareketler, [1, -1])
        XCTAssertFalse(giris.tusIsle(0x61, durum: 0))
    }
}
