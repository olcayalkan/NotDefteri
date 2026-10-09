import XCTest
@testable import NotDefteriCekirdek

/// Kod bloklarında sözdizimi renklendirmesi.
final class KodVurgulayiciTestleri: XCTestCase {

    private func tokenlar(_ kod: String, _ dil: String) -> [(String, KodTokenTuru)] {
        let ns = kod as NSString
        return kodVurgula(kod, dil: dil).map { (ns.substring(with: $0.aralik), $0.tur) }
    }

    private func tur(_ parca: String, _ kod: String, _ dil: String) -> KodTokenTuru? {
        tokenlar(kod, dil).first { $0.0 == parca }?.1
    }

    func testDilTakmaAdlariNormallesir() {
        XCTAssertEqual(dilAdiniNormallestir("JS"), "javascript")
        XCTAssertEqual(dilAdiniNormallestir(" py "), "python")
        XCTAssertEqual(dilAdiniNormallestir("zsh"), "bash")
        XCTAssertEqual(dilAdiniNormallestir("golang"), "go")
        XCTAssertEqual(dilAdiniNormallestir("SQL"), "sql")
        XCTAssertNil(dilAdiniNormallestir("brainfuck"))
    }

    func testBilinmeyenDilGenelKuralaDuser() {
        XCTAssertFalse(kodVurgula("let x = 1", dil: "bilinmeyen").isEmpty)
        XCTAssertFalse(kodVurgula("let x = 1", dil: nil).isEmpty)
    }

    func testSwiftTokenTurleri() {
        let kod = #"let ad = "let" // let yorum"# + "\nvar n = 0x1F"
        XCTAssertEqual(tur("let", kod, "swift"), .anahtarKelime)
        XCTAssertEqual(tur(#""let""#, kod, "swift"), .metin)
        XCTAssertEqual(tur("// let yorum", kod, "swift"), .yorum)
        XCTAssertEqual(tur("0x1F", kod, "swift"), .sayi)
    }

    /// Metin ya da yorum içindeki anahtar kelime ayrıca renklenmemeli.
    func testMetinIcindekiKelimeAyriTokenOlmaz() {
        let parcalar = tokenlar(#"print("return if else")"#, "swift").map(\.0)
        XCTAssertEqual(parcalar, [#""return if else""#])
    }

    func testPythonYorumuVeUcluTirnak() {
        let kod = "def f():\n    \"\"\"belge\nsatırı\"\"\"  # yorum"
        XCTAssertEqual(tur("def", kod, "python"), .anahtarKelime)
        XCTAssertEqual(tur("\"\"\"belge\nsatırı\"\"\"", kod, "python"), .metin)
        XCTAssertEqual(tur("# yorum", kod, "python"), .yorum)
    }

    func testSqlBuyukKucukHarfDuyarsiz() {
        XCTAssertEqual(tur("SELECT", "SELECT * FROM t -- not", "sql"), .anahtarKelime)
        XCTAssertEqual(tur("-- not", "SELECT * FROM t -- not", "sql"), .yorum)
    }

    /// Kapanmayan yorum/metin metnin sonuna kadar sürer; vurgulayıcı takılmamalı.
    func testKapanmayanYorumSonaKadarSurer() {
        let kod = "/* açık yorum\nlet x = 1"
        XCTAssertEqual(tokenlar(kod, "swift").map(\.1), [.yorum])
    }

    func testJsonDegerleri() {
        let kod = #"{"a": true, "b": 1.5e3, "c": null}"#
        XCTAssertEqual(tur("true", kod, "json"), .anahtarKelime)
        XCTAssertEqual(tur("1.5e3", kod, "json"), .sayi)
        XCTAssertEqual(tur(#""a""#, kod, "json"), .metin)
    }


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
