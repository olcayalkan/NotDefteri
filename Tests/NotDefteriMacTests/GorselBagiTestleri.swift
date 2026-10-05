import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Görsel bağlarının sayfa taşınmalarına dayanıklılığı.
/// Bağlar göreli (`Görseller/x.png`) ve `Görseller/` klasörü sayfanın
/// klasöründe olduğu için birlikte taşınmaları gerekir.
final class GorselBagiTestleri: XCTestCase {

    private var kok: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        kok = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gorselbag-\(UUID().uuidString)")
        try fm.createDirectory(at: kok, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? fm.removeItem(at: kok) }

    /// Sayfa + içinde bir görsel kurar, içerik URL'sini döner.
    @discardableResult
    private func sayfaKur(_ ust: URL, _ ad: String, gorsel: String? = nil) throws -> URL {
        let klasor = ust.appendingPathComponent(ad)
        try fm.createDirectory(at: klasor, withIntermediateDirectories: true)
        var metin = "# \(ad)\n"
        if let gorsel {
            let gk = klasor.appendingPathComponent(kGorsellerKlasorAdi)
            try fm.createDirectory(at: gk, withIntermediateDirectories: true)
            try Data([0x89, 0x50, 0x4E, 0x47]).write(to: gk.appendingPathComponent(gorsel))
            metin += "![](\(kGorsellerKlasorAdi)/\(gorsel)){100x100}\n"
        }
        let icerik = klasor.appendingPathComponent(kIcerikDosyaAdi)
        try metin.write(to: icerik, atomically: true, encoding: .utf8)
        return icerik
    }

    /// Çeviricinin bağ çözümleme sırasının aynısı: önce sayfa klasörü, sonra kök.
    private func bagCozuluyorMu(_ icerikURL: URL, _ bag: String) -> Bool {
        [sayfaKlasoru(icerikURL).appendingPathComponent(bag),
         kok.appendingPathComponent(bag)].contains { fm.fileExists(atPath: $0.path) }
    }

    func testYenidenAdlandirmaGorselBaginiBozmaz() throws {
        let url = try sayfaKur(kok, "Notum", gorsel: "resim.png")
        XCTAssertTrue(bagCozuluyorMu(url, "\(kGorsellerKlasorAdi)/resim.png"))

        let yeni = try XCTUnwrap(sayfayiYenidenAdlandir(url, yeniAd: "NotumYeni"))

        XCTAssertTrue(bagCozuluyorMu(yeni, "\(kGorsellerKlasorAdi)/resim.png"),
                      "görsel sayfayla birlikte taşınmalı")
        XCTAssertTrue(try String(contentsOf: yeni, encoding: .utf8).contains("\(kGorsellerKlasorAdi)/resim.png"),
                      "bağ göreli olduğu için metin değişmemeli")
    }

    func testAltSayfaninGorseliKorunur() throws {
        let ana = try sayfaKur(kok, "Ana")
        let alt = try sayfaKur(sayfaKlasoru(ana), "Alt", gorsel: "alt.png")

        let altYeni = try XCTUnwrap(sayfayiYenidenAdlandir(alt, yeniAd: "AltYeni"))
        XCTAssertTrue(bagCozuluyorMu(altYeni, "\(kGorsellerKlasorAdi)/alt.png"))
    }

    /// Üst sayfa yeniden adlandırılınca altındaki sayfanın görseli de taşınmalı.
    func testUstSayfaTasinincaAltinGorseliKorunur() throws {
        let ana = try sayfaKur(kok, "Ana")
        try sayfaKur(sayfaKlasoru(ana), "Alt", gorsel: "alt.png")

        let anaYeni = try XCTUnwrap(sayfayiYenidenAdlandir(ana, yeniAd: "AnaYeni"))
        let altYolu = sayfaKlasoru(anaYeni).appendingPathComponent("Alt/\(kIcerikDosyaAdi)")

        XCTAssertTrue(fm.fileExists(atPath: altYolu.path), "alt sayfa taşınmalı")
        XCTAssertTrue(bagCozuluyorMu(altYolu, "\(kGorsellerKlasorAdi)/alt.png"),
                      "alt sayfanın görseli de taşınmalı")
    }

    /// Çakışma sonucu "(2)" eklenen sayfada da görsel korunmalı.
    func testCakismaliAdlandirmadaGorselKorunur() throws {
        try sayfaKur(kok, "Dolu")
        let url = try sayfaKur(kok, "Kaynak", gorsel: "r.png")

        let yeni = try XCTUnwrap(sayfayiYenidenAdlandir(url, yeniAd: "Dolu"))
        XCTAssertEqual(sayfaAdi(yeni), "Dolu (2)")
        XCTAssertTrue(bagCozuluyorMu(yeni, "\(kGorsellerKlasorAdi)/r.png"))
    }

    /// Görsel adı üretimi bağ ayrıştırıcısıyla uyumlu olmalı — uçtan uca.
    func testUretilenAdlaKurulanBagCozulur() throws {
        let klasor = kok.appendingPathComponent("Sayfa")
        try fm.createDirectory(at: klasor.appendingPathComponent(kGorsellerKlasorAdi),
                                withIntermediateDirectories: true)

        for baslik in ["User-Agent: () { :; }; nslookup $(whoami)",
                       "setspn.exe -q \"-\" -> SPN",
                       "Şifreleme Ağı [test]"] {
            let ad = guvenliDosyaAdi(baslik) + ".png"
            try Data([0x89]).write(to: klasor.appendingPathComponent("\(kGorsellerKlasorAdi)/\(ad)"))

            let metin = "![](\(kGorsellerKlasorAdi)/\(ad)){10x10}"
            let icerik = klasor.appendingPathComponent(kIcerikDosyaAdi)
            try metin.write(to: icerik, atomically: true, encoding: .utf8)

            XCTAssertTrue(bagCozuluyorMu(icerik, "\(kGorsellerKlasorAdi)/\(ad)"),
                          "üretilen ad \"\(ad)\" bağdan geri okunabilmeli")
        }
    }
}
