import XCTest
@testable import NotDefteriCekirdek

/// Sayfa klasöründeki ek dosyalar: toplama, güvenli okuma ve boyut metni.
final class SayfaDosyalariTestleri: GeciciKokTestCase {

    private var sayfa: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sayfa = sayfaKlasoru(try sayfaKur("Proje"))
    }

    private func yaz(_ yol: String, _ icerik: String) throws {
        let url = sayfa.appendingPathComponent(yol)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try icerik.write(to: url, atomically: true, encoding: .utf8)
    }

    func testEkDosyalarToplanir() throws {
        try yaz("main.go", "package main")
        try yaz("src/a.swift", "let a = 1")
        let dosyalar = SayfaDosyalari.topla(sayfaKlasoru: sayfa, kok: kok)
        XCTAssertEqual(dosyalar.map(\.goreliYol), ["main.go", "src/a.swift"])
        XCTAssertTrue(dosyalar.allSatisfy(\.kodMu))
    }

    /// Markdown, gizli dosya, Görseller ve alt sayfalar ek dosya değildir.
    func testSayfaIcerigiVeAltSayfalarAtlanir() throws {
        try yaz(".gizli.txt", "x")
        try yaz("\(kGorsellerKlasorAdi)/r.txt", "x")
        try yaz("node_modules/p.js", "x")
        try sayfaKur("Proje/Alt")
        try yaz("Alt/ek.txt", "alt sayfanın eki")
        try yaz("not.txt", "x")
        XCTAssertEqual(SayfaDosyalari.topla(sayfaKlasoru: sayfa, kok: kok).map(\.goreliYol), ["not.txt"])
    }

    func testMetinDosyasiOkunur() throws {
        try yaz("a.txt", "merhaba")
        guard case .metin(let metin) = try SayfaDosyalari.oku(sayfa.appendingPathComponent("a.txt"), kok: kok) else {
            return XCTFail("metin bekleniyordu")
        }
        XCTAssertEqual(metin, "merhaba")
    }

    func testIkiliDosyaTaninir() throws {
        try Data([0, 1, 2, 3]).write(to: sayfa.appendingPathComponent("veri.bin"))
        guard case .ikili = try SayfaDosyalari.oku(sayfa.appendingPathComponent("veri.bin"), kok: kok) else {
            return XCTFail("ikili bekleniyordu")
        }
    }

    func testBuyukDosyaOkunmaz() throws {
        try Data(repeating: 65, count: SayfaDosyalari.boyutSiniri + 1).write(to: sayfa.appendingPathComponent("buyuk.txt"))
        guard case .buyuk = try SayfaDosyalari.oku(sayfa.appendingPathComponent("buyuk.txt"), kok: kok) else {
            return XCTFail("büyük bekleniyordu")
        }
    }

    /// Kontrol ile okuma arasında bağa çevrilen dosya bile kök dışını okutmamalı.
    func testSembolikBagOkunmaz() throws {
        let disari = kok.deletingLastPathComponent().appendingPathComponent("gizli-\(UUID().uuidString).txt")
        try "sır".write(to: disari, atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: disari) }
        try fm.createSymbolicLink(at: sayfa.appendingPathComponent("bag.txt"), withDestinationURL: disari)

        XCTAssertThrowsError(try SayfaDosyalari.oku(sayfa.appendingPathComponent("bag.txt"), kok: kok))
        XCTAssertFalse(SayfaDosyalari.topla(sayfaKlasoru: sayfa, kok: kok).contains { $0.goreliYol == "bag.txt" })
    }

    func testKokDisiVeUstDizinReddedilir() {
        XCTAssertThrowsError(try SayfaDosyalari.oku(URL(fileURLWithPath: "/etc/hosts"), kok: kok))
        XCTAssertThrowsError(try SayfaDosyalari.oku(URL(fileURLWithPath: sayfa.path + "/../../x.txt"), kok: kok))
    }

    func testDosyaTurleri() {
        let txt = SayfaDosyasi(url: URL(fileURLWithPath: "/a.txt"), goreliYol: "a.txt", boyut: 0)
        let go = SayfaDosyasi(url: URL(fileURLWithPath: "/k/a.GO"), goreliYol: "k/a.GO", boyut: 0)
        let png = SayfaDosyasi(url: URL(fileURLWithPath: "/a.png"), goreliYol: "a.png", boyut: 0)
        XCTAssertTrue(txt.metinMi); XCTAssertFalse(txt.kodMu)
        XCTAssertTrue(go.kodMu); XCTAssertEqual(go.klasor, "k")
        XCTAssertFalse(png.metinMi)
    }

    /// Linux'ta da macOS'un Türkçe ByteCountFormatter çıktısıyla aynı olmalı.
    func testBoyutMetni() {
        XCTAssertEqual(dosyaBoyutuMetni(6), "6 bayt")
        XCTAssertEqual(dosyaBoyutuMetni(999), "999 bayt")
        XCTAssertEqual(dosyaBoyutuMetni(1500), "1,5 KB")
        XCTAssertEqual(dosyaBoyutuMetni(2000), "2 KB")
        XCTAssertEqual(dosyaBoyutuMetni(15_400), "15 KB")
        XCTAssertEqual(dosyaBoyutuMetni(3_200_000), "3,2 MB")
    }
}
