import XCTest
@testable import NotDefteriCekirdek

/// Sayfa sürüm geçmişi: gizli `.gecmis` klasörü, eşik, aynı içerik ve listeleme.
final class SayfaGecmisiTestleri: GeciciKokTestCase {

    /// Kayıt arka plan kuyruğunda, sonuç ana iş parçacığında döner; test bunu bekler.
    @discardableResult
    private func kaydet(_ metin: String, _ icerik: URL, zorla: Bool = false) throws -> URL? {
        let bekle = expectation(description: "kayıt")
        var sonuc: Result<URL?, Error>!
        SayfaGecmisi.kaydet(metin: metin, icerikURL: icerik, zorla: zorla, kok: kok) { sonuc = $0; bekle.fulfill() }
        wait(for: [bekle], timeout: 5)
        return try sonuc.get()
    }

    private func listele(_ icerik: URL) -> [SayfaSurumu] {
        let bekle = expectation(description: "liste")
        var surumler: [SayfaSurumu] = []
        SayfaGecmisi.listele(icerik) { surumler = $0; bekle.fulfill() }
        wait(for: [bekle], timeout: 5)
        return surumler
    }

    func testIlkKayitSurumOlusturur() throws {
        let icerik = try sayfaKur("Not")
        let surum = try XCTUnwrap(try kaydet("ilk", icerik))
        XCTAssertEqual(surum.deletingLastPathComponent().lastPathComponent, ".gecmis")
        XCTAssertEqual(try oku(surum), "ilk")
    }

    func testGecmisAgactaGorunmez() throws {
        let icerik = try sayfaKur("Not")
        try kaydet("ilk", icerik)
        XCTAssertTrue(try dugum("Not").cocuklar.isEmpty)
    }

    func testAyniIcerikIkinciSurumOlusturmaz() throws {
        let icerik = try sayfaKur("Not")
        try kaydet("aynı", icerik)
        XCTAssertNil(try kaydet("aynı", icerik, zorla: true))
        XCTAssertEqual(listele(icerik).count, 1)
    }

    /// 10 dakika içinde küçük düzeltmeler her otomatik kayıtta yeni sürüm üretmemeli.
    func testKucukDegisiklikEsikteBekler() throws {
        let icerik = try sayfaKur("Not")
        let uzun = String(repeating: "uzun bir paragraf ", count: 20)
        try kaydet(uzun, icerik)
        XCTAssertNil(try kaydet(uzun + "!", icerik))
        XCTAssertEqual(listele(icerik).count, 1)
    }

    func testBuyukDegisiklikHemenSurumOlur() throws {
        let icerik = try sayfaKur("Not")
        try kaydet("kısa", icerik)
        XCTAssertNotNil(try kaydet("tamamen farklı ve çok daha uzun bir metin", icerik))
        XCTAssertEqual(listele(icerik).count, 2)
    }

    func testZorlaKayitEsigiAsar() throws {
        let icerik = try sayfaKur("Not")
        let uzun = String(repeating: "uzun bir paragraf ", count: 20)
        try kaydet(uzun, icerik)
        XCTAssertNotNil(try kaydet(uzun + "!", icerik, zorla: true))
    }

    func testListeYenidenEskiyeSiralidir() throws {
        let icerik = try sayfaKur("Not")
        try kaydet("bir", icerik)
        try kaydet("iki farklı metin", icerik, zorla: true)
        let surumler = listele(icerik)
        XCTAssertEqual(try surumler.map { try SayfaGecmisi.surumMetniniOku($0, kok: kok) }, ["iki farklı metin", "bir"])
        XCTAssertGreaterThan(surumler[0].tarih, surumler[1].tarih)
    }

    /// Kuyruk beklerken silinen sayfanın klasörü yeniden yaratılmamalı.
    func testSilinmisSayfaIcinKayitHataVerir() throws {
        let icerik = try sayfaKur("Not")
        try fm.removeItem(at: sayfaKlasoru(icerik))
        XCTAssertThrowsError(try kaydet("x", icerik))
        XCTAssertFalse(varMi("Not"))
    }

    func testKokDisiSayfaKaydedilmez() throws {
        XCTAssertThrowsError(try kaydet("x", URL(fileURLWithPath: "/tmp/disari/index.md")))
    }

    func testEnFazlaSurumSiniri() throws {
        let icerik = try sayfaKur("Not")
        for i in 0...SayfaGecmisi.enFazlaSurum { try kaydet("sürüm \(i) " + String(repeating: "x", count: i), icerik, zorla: true) }
        XCTAssertEqual(listele(icerik).count, SayfaGecmisi.enFazlaSurum, "en eski sürüm silinmeli")
    }
}
