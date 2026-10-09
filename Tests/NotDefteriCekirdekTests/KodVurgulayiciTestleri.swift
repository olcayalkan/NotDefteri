import XCTest
@testable import NotDefteriCekirdek

final class KodVurgulayiciTestleri: XCTestCase {

    private func tokenTuru(_ parca: String, kod: String, dil: String? = nil) -> KodTokenTuru? {
        let aralik = (kod as NSString).range(of: parca)
        return kodVurgula(kod, dil: dil).first { $0.aralik == aralik }?.tur
    }

    func testDilsizKodBloguGenelSozdiziminiRenklendirir() {
        let kod = "import Foundation\nif let deger: String = \"metin\" { print(deger + 1) }\n// yorum"
        XCTAssertEqual(tokenTuru("import", kod: kod), .anahtarKelime)
        XCTAssertEqual(tokenTuru("if", kod: kod), .anahtarKelime)
        XCTAssertEqual(tokenTuru("String", kod: kod), .tur)
        XCTAssertEqual(tokenTuru("\"metin\"", kod: kod), .metin)
        XCTAssertEqual(tokenTuru("print", kod: kod), .fonksiyon)
        XCTAssertEqual(tokenTuru("+", kod: kod), .operator)
        XCTAssertEqual(tokenTuru("1", kod: kod), .sayi)
        XCTAssertEqual(tokenTuru("// yorum", kod: kod), .yorum)
    }

    func testDilKuraliYorumVeMetinIcindekiAnahtarKelimedenOnceGelir() {
        let kod = "// if import\nlet deger = \"if import\""
        let tokenlar = kodVurgula(kod, dil: "swift")
        XCTAssertTrue(tokenlar.contains { $0.tur == .yorum && (kod as NSString).substring(with: $0.aralik) == "// if import" })
        XCTAssertTrue(tokenlar.contains { $0.tur == .metin && (kod as NSString).substring(with: $0.aralik) == "\"if import\"" })
        XCTAssertFalse(tokenlar.contains { $0.tur == .anahtarKelime && ["if", "import"].contains((kod as NSString).substring(with: $0.aralik)) })
    }

    func testTaninmayanDilGenelRenklendirmeyeDuser() {
        XCTAssertEqual(tokenTuru("return", kod: "return value", dil: "rust"), .anahtarKelime)
    }
}
