import XCTest
@testable import NotDefteriCekirdek

/// Not klasörü kendisi bir sembolik bağ olabilir (ör. başka diske giden ~/Notlar).
/// macOS'ta dizin listelemesi bağı çözüp gerçek yolu döndürdüğü için ağaçtan gelen yollar
/// kökün yazılışıyla uyuşmuyor; favori eklenemiyor, çöp listelenmiyordu (#12).
final class BagliKokTestleri: GeciciKokTestCase {

    private var bagliKok: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        bagliKok = kok.deletingLastPathComponent().appendingPathComponent("bagli-\(UUID().uuidString)")
        try fm.createSymbolicLink(at: bagliKok, withDestinationURL: kok)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: bagliKok)
        try super.tearDownWithError()
    }

    private func dugum(_ ad: String) throws -> AgacDugumu {
        try XCTUnwrap(agaciYukle(bagliKok).first { $0.ad == ad })
    }

    func testAgacYollariKokunYazilisiniKorur() throws {
        try sayfaKur("Ana/Alt")
        try sayfaKur("Ana")
        let ana = try dugum("Ana")
        XCTAssertTrue(ana.klasorURL.path.hasPrefix(bagliKok.path + "/"), ana.klasorURL.path)
        XCTAssertTrue(try XCTUnwrap(ana.cocuklar.first?.icerikURL).path.hasPrefix(bagliKok.path + "/"))
        XCTAssertNoThrow(try notlarYolunuDogrula(try XCTUnwrap(ana.icerikURL), kok: bagliKok))
    }

    func testFavoriEklenir() throws {
        try sayfaKur("Not")
        let alan = "notdefteri-test-\(UUID().uuidString)"
        let ayarlar = try XCTUnwrap(UserDefaults(suiteName: alan))
        defer { ayarlar.removePersistentDomain(forName: alan) }
        let favoriler = Favoriler(kok: bagliKok, ayarlar: ayarlar)

        favoriler.ekle(try XCTUnwrap(try dugum("Not").icerikURL))
        XCTAssertEqual(favoriler.yollar, ["Not/index.md"])
    }

    func testCopKutusuCalisir() throws {
        try sayfaKur("Not")
        let cop = CopKutusu(kok: bagliKok)
        let oge = try cop.sil(try dugum("Not"))
        let sonuc = try cop.ogeler()
        XCTAssertEqual(sonuc.ogeler.map(\.ad), ["Not"])
        XCTAssertTrue(sonuc.hatalar.isEmpty, "\(sonuc.hatalar)")
        XCTAssertNoThrow(try cop.geriYukle(oge))
    }

    func testSayfaTasinir() throws {
        try sayfaKur("A")
        try sayfaKur("B")
        let a = try XCTUnwrap(try dugum("A").icerikURL)
        XCTAssertNotNil(try sayfaTasimaSonucu(a, hedefKlasor: try dugum("B").klasorURL, kok: bagliKok))
        XCTAssertTrue(varMi("B/A/index.md"))
    }
}
