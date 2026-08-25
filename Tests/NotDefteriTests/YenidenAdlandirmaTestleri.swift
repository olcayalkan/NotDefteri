import XCTest
@testable import NotDefteri

/// Sayfa yeniden adlandırma. Alt sayfalar ve görseller sayfanın klasörünün
/// içinde durduğu için tek `moveItem` ile taşınmaları gerekir.
final class YenidenAdlandirmaTestleri: XCTestCase {

    private var kok: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        kok = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("adlandirma-\(UUID().uuidString)")
        try fm.createDirectory(at: kok, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: kok)
    }

    /// Yeni düzende bir sayfa kurar: <ad>/index.md (+ isteğe bağlı alt sayfa, görsel).
    @discardableResult
    private func sayfaKur(_ ad: String, altSayfa: String? = nil, gorselli: Bool = false) throws -> URL {
        let klasor = kok.appendingPathComponent(ad)
        try fm.createDirectory(at: klasor, withIntermediateDirectories: true)
        try "# \(ad)\n".write(to: klasor.appendingPathComponent(kIcerikDosyaAdi),
                              atomically: true, encoding: .utf8)
        if gorselli {
            let g = klasor.appendingPathComponent(kGorsellerKlasorAdi)
            try fm.createDirectory(at: g, withIntermediateDirectories: true)
            try Data().write(to: g.appendingPathComponent("a.png"))
        }
        if let altSayfa {
            let ak = klasor.appendingPathComponent(altSayfa)
            try fm.createDirectory(at: ak, withIntermediateDirectories: true)
            try "# \(altSayfa)\n".write(to: ak.appendingPathComponent(kIcerikDosyaAdi),
                                         atomically: true, encoding: .utf8)
        }
        return klasor.appendingPathComponent(kIcerikDosyaAdi)
    }

    func testAdDegisirIcerikKorunur() throws {
        let url = try sayfaKur("Eski")
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandir(url, yeniAd: "Yeni"))

        XCTAssertEqual(sayfaAdi(yeni), "Yeni")
        XCTAssertEqual(try String(contentsOf: yeni, encoding: .utf8), "# Eski\n",
                       "yalnızca ad değişmeli, içerik aynı kalmalı")
        XCTAssertFalse(fm.fileExists(atPath: url.path), "eski yol kalmamalı")
    }

    /// Alt sayfalar sayfanın klasöründe olduğu için birlikte taşınmalı.
    func testAltSayfalarBirlikteTasinir() throws {
        let url = try sayfaKur("Ana", altSayfa: "Alt")
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandir(url, yeniAd: "AnaYeni"))

        let altYolu = sayfaKlasoru(yeni).appendingPathComponent("Alt/\(kIcerikDosyaAdi)")
        XCTAssertTrue(fm.fileExists(atPath: altYolu.path), "alt sayfa taşınmalı")
    }

    /// Görseller de sayfanın klasöründe; taşınmazlarsa bağlar kırılır.
    func testGorsellerBirlikteTasinir() throws {
        let url = try sayfaKur("Resimli", gorselli: true)
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandir(url, yeniAd: "ResimliYeni"))

        let gorsel = sayfaKlasoru(yeni).appendingPathComponent("\(kGorsellerKlasorAdi)/a.png")
        XCTAssertTrue(fm.fileExists(atPath: gorsel.path), "görsel taşınmalı, yoksa bağ kırılır")
    }

    func testCakismadaSayacEklenir() throws {
        try sayfaKur("Dolu")
        let url = try sayfaKur("Boş")
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandir(url, yeniAd: "Dolu"))

        XCTAssertEqual(sayfaAdi(yeni), "Dolu (2)")
        XCTAssertTrue(fm.fileExists(atPath: kok.appendingPathComponent("Dolu/\(kIcerikDosyaAdi)").path),
                      "var olan sayfa bozulmamalı")
    }

    func testAyniAdDegisiklikYapmaz() throws {
        let url = try sayfaKur("Sabit")
        XCTAssertEqual(sayfayiYenidenAdlandir(url, yeniAd: "Sabit"), url)
        XCTAssertTrue(fm.fileExists(atPath: url.path))
    }

    func testTurkceKarakterliAd() throws {
        let url = try sayfaKur("Sifreleme")
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandir(url, yeniAd: "Şifreleme Ağı"))

        XCTAssertTrue(fm.fileExists(atPath: yeni.path))
        XCTAssertEqual(sayfaAdi(yeni), "Şifreleme Ağı")
    }

    /// Eski düzen: "Ad.md" + kardeş "Ad/" klasörü. İkisi birlikte taşınmalı.
    func testEskiDuzenDosyaVeKlasorBirlikteTasinir() throws {
        let dosya = kok.appendingPathComponent("Duz.md")
        try "# Duz\n".write(to: dosya, atomically: true, encoding: .utf8)
        let dal = kok.appendingPathComponent("Duz")
        try fm.createDirectory(at: dal, withIntermediateDirectories: true)
        try Data().write(to: dal.appendingPathComponent("ek.png"))

        let yeni = try XCTUnwrap(sayfayiYenidenAdlandir(dosya, yeniAd: "DuzYeni"))

        XCTAssertTrue(fm.fileExists(atPath: yeni.path), "dosya taşınmalı")
        XCTAssertTrue(fm.fileExists(atPath: kok.appendingPathComponent("DuzYeni/ek.png").path),
                      "kardeş klasör de taşınmalı")
        XCTAssertFalse(fm.fileExists(atPath: dosya.path))
    }

    /// Yeniden adlandırdıktan sonra ağaç taraması sayfayı yeni adıyla bulmalı.
    func testAgacYeniAdiGorur() throws {
        let url = try sayfaKur("Once", altSayfa: "Alt")
        _ = sayfayiYenidenAdlandir(url, yeniAd: "Sonra")

        let agac = agaciYukle(kok)
        let adlar = agac.map(\.ad)
        XCTAssertTrue(adlar.contains("Sonra"), "yeni ad ağaçta olmalı, bulunan: \(adlar)")
        XCTAssertFalse(adlar.contains("Once"), "eski ad ağaçta kalmamalı")

        let sonra = try XCTUnwrap(agac.first { $0.ad == "Sonra" })
        XCTAssertEqual(sonra.cocuklar.map(\.ad), ["Alt"], "alt sayfa ağaçta görünmeli")
    }
}
