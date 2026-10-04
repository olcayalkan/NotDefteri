import XCTest
import AppKit
@testable import NotDefteri

/// Bir sayfadaki içeriğin (metin + görsel) başka bir sayfaya kopyalanması.
/// Kritik kural: kaynak dosya YERİNDE KALIR, hedefe kopyası çıkarılır.
final class KopyalamaTestleri: XCTestCase {

    private var kok: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        kok = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kopyalama-\(UUID().uuidString)")
        try fm.createDirectory(at: kok, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? fm.removeItem(at: kok) }

    /// Diske gerçek bir PNG yazar (NSImage okuyabilmeli).
    @discardableResult
    private func pngYaz(_ url: URL, en: Int = 8, boy: Int = 4) throws -> URL {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temsil = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: en, pixelsHigh: boy,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        try temsil.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    // MARK: Dosya kopyalama

    func testKaynakDosyaYerindeKalir() throws {
        let kaynak = try pngYaz(kok.appendingPathComponent("A/Görseller/Şema.png"))
        let hedefKlasor = kok.appendingPathComponent("B/Görseller")

        let hedef = try XCTUnwrap(gorselDosyasiniKopyala(kaynak, hedefKlasor: hedefKlasor))

        XCTAssertTrue(fm.fileExists(atPath: kaynak.path), "kaynak silinmemeli")
        XCTAssertTrue(fm.fileExists(atPath: hedef.path))
        XCTAssertEqual(hedef.lastPathComponent, "Şema.png")
        XCTAssertEqual(try Data(contentsOf: kaynak), try Data(contentsOf: hedef), "bayt bayt aynı olmalı")
    }

    func testAdCakisirsaBenzersizlestirilir() throws {
        let kaynak = try pngYaz(kok.appendingPathComponent("A/Görseller/Şema.png"))
        let hedefKlasor = kok.appendingPathComponent("B/Görseller")

        _ = gorselDosyasiniKopyala(kaynak, hedefKlasor: hedefKlasor)
        let ikinci = try XCTUnwrap(gorselDosyasiniKopyala(kaynak, hedefKlasor: hedefKlasor))

        XCTAssertEqual(ikinci.lastPathComponent, "Şema-2.png")
    }

    /// Bölüm başlığı ad olarak kullanılırken bağı bozacak karakterler temizlenmeli.
    func testBaslikliAdGuvenlilestirilir() throws {
        let kaynak = try pngYaz(kok.appendingPathComponent("A/Görseller/x.jpg"))
        let hedef = try XCTUnwrap(gorselDosyasiniKopyala(kaynak, hedefKlasor: kok.appendingPathComponent("B"),
                                                          taban: "Bölüm (1)"))
        XCTAssertEqual(hedef.lastPathComponent, "Bölüm -1.jpg", "uzantı korunmalı, parantez temizlenmeli")
    }

    func testOlmayanKaynakNilDoner() {
        XCTAssertNil(gorselDosyasiniKopyala(kok.appendingPathComponent("yok.png"),
                                            hedefKlasor: kok.appendingPathComponent("B")))
    }

    // MARK: Pano gidiş-dönüşü

    /// Kopyalanan seçim Markdown'a çevrilip kaynak klasöre göre geri okunmalı:
    /// başlık, kalın metin ve görsel bağı korunuyor mu?
    func testSecimMarkdownGidisDonusu() throws {
        let sayfaKlasoru = kok.appendingPathComponent("A")
        try pngYaz(sayfaKlasoru.appendingPathComponent("\(kGorsellerKlasorAdi)/Şema.png"))

        let kaynakMetin = "# Başlık\nönce **kalın** sonra\n![](\(kGorsellerKlasorAdi)/Şema.png){120x60}\nson\n"
        let attr = markdowndenAttributedStringUret(kaynakMetin, taban: sayfaKlasoru)
        XCTAssertEqual(markdownMetniUret(attr), kaynakMetin)

        // Panodaki Markdown, kaynak sayfanın klasörüne göre yeniden çözülebilmeli.
        let geri = markdowndenAttributedStringUret(markdownMetniUret(attr), taban: sayfaKlasoru)
        var ekSayisi = 0
        geri.enumerateAttribute(.attachment, in: NSRange(location: 0, length: geri.length), options: []) { deger, _, _ in
            if let ek = deger as? ResimEki {
                ekSayisi += 1
                XCTAssertEqual(ek.gosterimBoyutu, NSSize(width: 120, height: 60))
                XCTAssertEqual(ek.bagYolu, "\(kGorsellerKlasorAdi)/Şema.png")
            }
        }
        XCTAssertEqual(ekSayisi, 1, "görsel ek olarak geri gelmeli")
    }

    /// Hedef sayfaya yapıştırıldığında bağ, hedefin kendi klasörüne göre yazılmalı.
    func testYapistirilanGorselinBagiHedefeGore() throws {
        let kaynakKlasor = kok.appendingPathComponent("A")
        let kaynak = try pngYaz(kaynakKlasor.appendingPathComponent("\(kGorsellerKlasorAdi)/Şema.png"))
        let hedefKlasor = kok.appendingPathComponent("B")

        let yeniURL = try XCTUnwrap(gorselDosyasiniKopyala(kaynak, hedefKlasor: gorsellerKlasoru(hedefKlasor)))
        let ek = resimEkiUret(gorsel: NSImage(contentsOf: yeniURL)!, dosyaURL: yeniURL,
                              bagYolu: "\(kGorsellerKlasorAdi)/\(yeniURL.lastPathComponent)",
                              gosterimBoyutu: NSSize(width: 120, height: 60))

        let metin = markdownMetniUret(NSAttributedString(attachment: ek))
        XCTAssertEqual(metin, "![](\(kGorsellerKlasorAdi)/Şema.png){120x60}")
        // Bağ hedef sayfanın klasöründen çözülebilmeli.
        XCTAssertNotNil(resimBaginiCozumle(metin as NSString, 0, taban: hedefKlasor))
    }
}
