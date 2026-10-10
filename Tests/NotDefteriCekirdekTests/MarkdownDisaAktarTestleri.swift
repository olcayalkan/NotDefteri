import XCTest
@testable import NotDefteriCekirdek

/// Markdown dışa aktarımı: dosya baytları aynen, görseller yanına, kök dışı kaynak yok.
final class MarkdownDisaAktarTestleri: GeciciKokTestCase {

    private var hedefKlasor: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        hedefKlasor = kok.deletingLastPathComponent().appendingPathComponent("aktarim-\(UUID().uuidString)")
        try fm.createDirectory(at: hedefKlasor, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: hedefKlasor)
        try super.tearDownWithError()
    }

    private func gorselliSayfa() throws -> URL {
        let icerik = try sayfaKur("Sayfa", metin: "---\ntags: [a]\n---\n# Sayfa\r\n![](\(kGorsellerKlasorAdi)/r.png){10x10}\n")
        let gk = sayfaKlasoru(icerik).appendingPathComponent(kGorsellerKlasorAdi)
        try fm.createDirectory(at: gk, withIntermediateDirectories: true)
        try Data([7, 7, 7]).write(to: gk.appendingPathComponent("r.png"))
        return icerik
    }

    func testDosyaBaytlariAynenYazilir() throws {
        let icerik = try gorselliSayfa()
        let sayfa = try MarkdownDisaAktar.oku(icerik, kok: kok)
        try MarkdownDisaAktar.aktar(sayfa, hedef: hedefKlasor.appendingPathComponent("Sayfa.md"), kok: kok)

        XCTAssertEqual(try Data(contentsOf: hedefKlasor.appendingPathComponent("Sayfa.md")), try Data(contentsOf: icerik),
                       "frontmatter ve CRLF dahil hiçbir bayt değişmemeli")
    }

    func testGorsellerYanaKopyalanir() throws {
        let sayfa = try MarkdownDisaAktar.oku(try gorselliSayfa(), kok: kok)
        try MarkdownDisaAktar.aktar(sayfa, hedef: hedefKlasor.appendingPathComponent("Sayfa.md"), kok: kok)
        let kopya = hedefKlasor.appendingPathComponent("\(kGorsellerKlasorAdi)/r.png")
        XCTAssertEqual(try Data(contentsOf: kopya), Data([7, 7, 7]))
    }

    func testDogrulanmayanGorselAtlanir() throws {
        let sayfa = try MarkdownDisaAktar.oku(try gorselliSayfa(), kok: kok)
        try MarkdownDisaAktar.aktar(sayfa, hedef: hedefKlasor.appendingPathComponent("Sayfa.md"), kok: kok,
                                    gorselDogrula: { _ in false })
        XCTAssertFalse(fm.fileExists(atPath: hedefKlasor.appendingPathComponent("\(kGorsellerKlasorAdi)/r.png").path))
        XCTAssertTrue(fm.fileExists(atPath: hedefKlasor.appendingPathComponent("Sayfa.md").path))
    }

    /// Hedefte farklı içerikli aynı adlı görsel varsa ezilmemeli.
    func testFarkliIcerikliGorselEzilmez() throws {
        let sayfa = try MarkdownDisaAktar.oku(try gorselliSayfa(), kok: kok)
        let mevcut = hedefKlasor.appendingPathComponent("\(kGorsellerKlasorAdi)/r.png")
        try fm.createDirectory(at: mevcut.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1]).write(to: mevcut)

        XCTAssertThrowsError(try MarkdownDisaAktar.aktar(sayfa, hedef: hedefKlasor.appendingPathComponent("Sayfa.md"), kok: kok))
        XCTAssertEqual(try Data(contentsOf: mevcut), Data([1]))
    }

    func testKaynakKlasoreAktarilamaz() throws {
        let icerik = try gorselliSayfa()
        let sayfa = try MarkdownDisaAktar.oku(icerik, kok: kok)
        XCTAssertThrowsError(try MarkdownDisaAktar.aktar(sayfa, hedef: sayfaKlasoru(icerik).appendingPathComponent("kopya.md"), kok: kok))
    }

    func testKokDisiSayfaOkunmaz() throws {
        let disari = hedefKlasor.appendingPathComponent("disari.md")
        try "x".write(to: disari, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try MarkdownDisaAktar.oku(disari, kok: kok))
    }

    /// Bağ kök dışına çıkan bir görseli gösteriyorsa aktarım dosya sızdırmamalı.
    func testKokDisiGorselReddedilir() throws {
        let disGorsel = hedefKlasor.appendingPathComponent("gizli.png")
        try Data([9]).write(to: disGorsel)
        let goreli = "../../\(hedefKlasor.lastPathComponent)/gizli.png"
        let icerik = try sayfaKur("Sayfa", metin: "![](\(goreli)){10x10}\n")
        let sayfa = try MarkdownDisaAktar.oku(icerik, kok: kok)

        XCTAssertThrowsError(try MarkdownDisaAktar.gorselKaynaklariniDogrula(sayfa, kok: kok))
    }
}
