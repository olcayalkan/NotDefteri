import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Anlamsal belge ile editör görünümü arasındaki adaptör: font, görsel eki ve kayıpsız dönüş.
final class BelgeAdaptoruTestleri: XCTestCase {

    private var klasor: URL!

    override func setUpWithError() throws {
        klasor = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("adaptor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: klasor.appendingPathComponent(kGorsellerKlasorAdi), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: klasor) }

    private func ac(_ md: String) -> NSAttributedString { MacBelgeAdaptoru.markdownuAc(md, taban: klasor) }

    private func font(_ belge: NSAttributedString, _ metin: String) throws -> NSFont {
        let konum = (belge.string as NSString).range(of: metin).location
        XCTAssertNotEqual(konum, NSNotFound, metin)
        return try XCTUnwrap(belge.attribute(.font, at: konum, effectiveRange: nil) as? NSFont)
    }

    private func pngYaz(_ ad: String) throws {
        let temsil = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 2, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        try temsil.representation(using: .png, properties: [:])!
            .write(to: klasor.appendingPathComponent("\(kGorsellerKlasorAdi)/\(ad)"))
    }

    func testBaslikFontuGovdedenBuyuk() throws {
        let belge = ac("# Başlık\ngövde")
        XCTAssertGreaterThan(try font(belge, "Başlık").pointSize, try font(belge, "gövde").pointSize)
        XCTAssertEqual(try font(belge, "gövde").pointSize, kTabanPunto)
    }

    func testKalinVeItalikFontOzelligi() throws {
        let belge = ac("**kalın** *italik*")
        XCTAssertTrue(try font(belge, "kalın").fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(try font(belge, "italik").fontDescriptor.symbolicTraits.contains(.italic))
    }

    func testPuntoUzantisiUygulanir() throws {
        XCTAssertEqual(try font(ac("<punto=20>iri</punto>"), "iri").pointSize, 20)
    }

    func testOkunabilenGorselEkOlur() throws {
        try pngYaz("r.png")
        let belge = ac("![](\(kGorsellerKlasorAdi)/r.png){120x60}")
        let ek = try XCTUnwrap(belge.attribute(.attachment, at: 0, effectiveRange: nil) as? ResimEki)
        XCTAssertEqual(ek.gosterimBoyutu, NSSize(width: 120, height: 60))
        XCTAssertEqual(ek.bagYolu, "\(kGorsellerKlasorAdi)/r.png")
    }

    /// Dosya yok ya da çözülemiyorsa bağ metin olarak kalmalı; kayıtta kaybolmamalı.
    func testOkunamayanGorselMetinKalir() {
        let md = "![](\(kGorsellerKlasorAdi)/yok.png){10x10}"
        let belge = ac(md)
        XCTAssertNil(belge.attribute(.attachment, at: 0, effectiveRange: nil))
        XCTAssertEqual(markdownMetniUret(belge), md)
    }

    func testBozukGorselDosyasiMetinKalir() throws {
        try Data([1, 2, 3]).write(to: klasor.appendingPathComponent("\(kGorsellerKlasorAdi)/bozuk.png"))
        let md = "![](\(kGorsellerKlasorAdi)/bozuk.png){10x10}"
        XCTAssertEqual(markdownMetniUret(ac(md)), md)
    }

    /// Editörde açılıp dokunulmadan kaydedilen belge baytı baytına aynı kalmalı.
    func testGorunumKatmaniKayipsizdir() throws {
        try pngYaz("r.png")
        let md = """
        # Başlık
        Paragraf **kalın** *italik* ~~çizik~~ ==vurgu== `kod` <punto=18>iri</punto>
        - madde
          - alt madde
        3. üç
        - [x] bitti
        > alıntı
        ara
        > [!🔥 kırmızı] uyarı
        ---
        ![](\(kGorsellerKlasorAdi)/r.png){120x60}
        [[Sayfa Bağı]] [site](https://example.com)
        ```swift
        let x = "**değil kalın**"
        ```
        | tablo | korunur |
        """
        XCTAssertEqual(markdownMetniUret(ac(md)), md)
    }

    /// Bitişik alıntı ve uyarı başka okuyucularda tek kutuya birleşir; yazıcı araya boş satır koyar.
    func testBitisikAlintiVeUyariAyrilir() {
        XCTAssertEqual(markdownMetniUret(ac("> alıntı\n> [!🔥 kırmızı] uyarı")), "> alıntı\n\n> [!🔥 kırmızı] uyarı")
    }

    func testGorselAnlamsaliEktenUretilir() throws {
        try pngYaz("r.png")
        let url = klasor.appendingPathComponent("\(kGorsellerKlasorAdi)/r.png")
        let ek = resimEkiUret(gorsel: try XCTUnwrap(NSImage(contentsOf: url)), dosyaURL: url,
                              bagYolu: "\(kGorsellerKlasorAdi)/r.png", gosterimBoyutu: NSSize(width: 80, height: 40))
        let anlamsal = try XCTUnwrap(MacBelgeAdaptoru.gorselAnlamsali(ek))
        XCTAssertEqual(anlamsal["yol"] as? String, "\(kGorsellerKlasorAdi)/r.png")
        XCTAssertEqual(anlamsal["genislik"] as? Double, 80)
        XCTAssertEqual(anlamsal["yukseklik"] as? Double, 40)
    }
}
