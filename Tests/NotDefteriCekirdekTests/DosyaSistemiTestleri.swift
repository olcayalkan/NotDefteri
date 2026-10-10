import XCTest
@testable import NotDefteriCekirdek

/// Not kökü ve yol doğrulaması: kök dışına `../`, sembolik bağ ya da mutlak yolla çıkılamamalı.
final class DosyaSistemiTestleri: GeciciKokTestCase {

    func testNotlarKlasoruOrtamDegiskeniniIzler() {
        XCTAssertEqual(notlarKlasoru().standardizedFileURL.path, kok.path)
    }

    func testKokIcindekiYolKabulEdilir() throws {
        let url = try sayfaKur("A")
        XCTAssertEqual(try notlarYolunuDogrula(url, kok: kok).path, url.path)
    }

    /// Kayıtta yeni oluşturulacak dosya henüz yokken de yol geçerli sayılmalı.
    func testHenuzOlmayanHedefKabulEdilir() {
        XCTAssertNoThrow(try notlarYolunuDogrula(kok.appendingPathComponent("Yeni/Alt/index.md"), kok: kok))
    }

    func testKokunKendisiYalnizcaIzinleKabulEdilir() {
        XCTAssertThrowsError(try notlarYolunuDogrula(kok, kok: kok))
        XCTAssertNoThrow(try notlarYolunuDogrula(kok, kok: kok, kokDahil: true))
    }

    func testKokDisiYolReddedilir() {
        XCTAssertThrowsError(try notlarYolunuDogrula(URL(fileURLWithPath: "/etc/hosts"), kok: kok)) { hata in
            guard case DosyaYoluHatasi.kokDisinda = hata else { return XCTFail("beklenmeyen hata: \(hata)") }
        }
    }

    func testUstDizinIleKacisReddedilir() {
        let kacis = URL(fileURLWithPath: kok.path + "/A/../../disari.md")
        XCTAssertThrowsError(try notlarYolunuDogrula(kacis, kok: kok))
    }

    /// Kök adıyla başlayan kardeş klasör ("kok-baska") kökün içi sayılmamalı.
    func testOnekBenzeyenKardesKlasorReddedilir() {
        let kardes = URL(fileURLWithPath: kok.path + "-baska/not.md")
        XCTAssertThrowsError(try notlarYolunuDogrula(kardes, kok: kok))
    }

    func testDisariGidenSembolikBagReddedilir() throws {
        let disari = kok.deletingLastPathComponent().appendingPathComponent("disari-\(UUID().uuidString)")
        try fm.createDirectory(at: disari, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: disari) }
        try fm.createSymbolicLink(at: kok.appendingPathComponent("bag"), withDestinationURL: disari)

        XCTAssertThrowsError(try notlarYolunuDogrula(kok.appendingPathComponent("bag/not.md"), kok: kok)) { hata in
            guard case DosyaYoluHatasi.sembolikBag = hata else { return XCTFail("beklenmeyen hata: \(hata)") }
        }
    }

    /// İçeriyi gösteren bağ da reddedilir: hedef sonradan değiştirilebilir.
    func testIceriGidenSembolikBagDaReddedilir() throws {
        try sayfaKur("Gercek")
        try fm.createSymbolicLink(at: kok.appendingPathComponent("Kisayol"),
                                  withDestinationURL: kok.appendingPathComponent("Gercek"))
        XCTAssertThrowsError(try notlarYolunuDogrula(kok.appendingPathComponent("Kisayol/index.md"), kok: kok))
    }

    func testDosyaYoluVarMiKopukBagiGorur() throws {
        let bag = kok.appendingPathComponent("kopuk")
        try fm.createSymbolicLink(at: bag, withDestinationURL: kok.appendingPathComponent("yok"))
        XCTAssertFalse(fm.fileExists(atPath: bag.path), "fileExists kopuk bağı görmez")
        XCTAssertTrue(dosyaYoluVarMi(bag), "ad seçerken kopuk bağ da dolu sayılmalı")
    }

    func testSayfaHedefiDoluMuEskiDuzeniDeGorur() throws {
        try duzNotKur("Duz")
        XCTAssertTrue(sayfaHedefiDoluMu(kok.appendingPathComponent("Duz")))
        XCTAssertFalse(sayfaHedefiDoluMu(kok.appendingPathComponent("Bos")))
    }

    func testGorsellerKlasoruOlusturulur() {
        let klasor = gorsellerKlasoru(kok.appendingPathComponent("Sayfa"))
        XCTAssertEqual(klasor.lastPathComponent, kGorsellerKlasorAdi)
        XCTAssertTrue(fm.fileExists(atPath: klasor.path))
    }
}
