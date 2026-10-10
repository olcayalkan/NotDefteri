import XCTest
@testable import NotDefteriCekirdek

/// Favoriler: göreli yol kaydı, sıralama ve olmayan dosyaların düşürülmesi.
final class FavorilerTestleri: GeciciKokTestCase {

    private var ayarlar: UserDefaults!
    private var alanAdi: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Gerçek tercih dosyasına yazılmasın.
        alanAdi = "notdefteri-test-\(UUID().uuidString)"
        ayarlar = UserDefaults(suiteName: alanAdi)
    }

    override func tearDownWithError() throws {
        ayarlar.removePersistentDomain(forName: alanAdi)
        try super.tearDownWithError()
    }

    private func favoriler() -> Favoriler { Favoriler(kok: kok, ayarlar: ayarlar) }

    func testEklenenSayfaGoreliYollaKaydedilir() throws {
        let a = try sayfaKur("A")
        let f = favoriler()
        f.ekle(a)

        XCTAssertTrue(f.iceriyor(a))
        XCTAssertEqual(f.yollar, ["A/index.md"])
        XCTAssertEqual(ayarlar.stringArray(forKey: "favoriSayfalar"), ["A/index.md"])
    }

    func testKayitYeniOrnekteOkunur() throws {
        let a = try sayfaKur("A")
        favoriler().ekle(a)
        XCTAssertTrue(favoriler().iceriyor(a))
    }

    func testAyniSayfaIkiKezEklenmez() throws {
        let a = try sayfaKur("A")
        let f = favoriler()
        f.ekle(a)
        f.ekle(a)
        XCTAssertEqual(f.yollar.count, 1)
    }

    func testOlmayanVeKokDisiDosyaEklenmez() throws {
        let f = favoriler()
        f.ekle(kok.appendingPathComponent("Yok/index.md"))
        f.ekle(URL(fileURLWithPath: "/etc/hosts"))
        XCTAssertTrue(f.yollar.isEmpty)
    }

    func testCikar() throws {
        let a = try sayfaKur("A")
        let f = favoriler()
        f.ekle(a)
        f.cikar(a)
        XCTAssertFalse(f.iceriyor(a))
        XCTAssertEqual(ayarlar.stringArray(forKey: "favoriSayfalar"), [])
    }

    func testTasimaArayaBirakmaIndeksiniKullanir() throws {
        let (a, b, c) = (try sayfaKur("A"), try sayfaKur("B"), try sayfaKur("C"))
        let f = favoriler()
        [a, b, c].forEach(f.ekle)

        f.tasi(a, hedef: 3)   // sona
        XCTAssertEqual(f.yollar, ["B/index.md", "C/index.md", "A/index.md"])
        f.tasi(a, hedef: 0)   // başa
        XCTAssertEqual(f.yollar, ["A/index.md", "B/index.md", "C/index.md"])
        f.tasi(c, hedef: 1)   // A ile B arasına
        XCTAssertEqual(f.yollar, ["A/index.md", "C/index.md", "B/index.md"])
    }

    func testTasimaSinirDisiIndeksiKirpar() throws {
        let (a, b) = (try sayfaKur("A"), try sayfaKur("B"))
        let f = favoriler()
        [a, b].forEach(f.ekle)
        f.tasi(a, hedef: 99)
        XCTAssertEqual(f.yollar, ["B/index.md", "A/index.md"])
        f.tasi(a, hedef: -5)
        XCTAssertEqual(f.yollar, ["A/index.md", "B/index.md"])
    }

    /// Sayfa yeniden adlandırılınca favori yeni yolu izlemeli; iki yol aynı yere düşerse tek kalmalı.
    func testYolGuncelleYenidenAdlandirmayiIzler() throws {
        let (a, b) = (try sayfaKur("A"), try sayfaKur("B"))
        let f = favoriler()
        [a, b].forEach(f.ekle)

        f.yolGuncelle { $0.path.contains("/A/") ? self.kok.appendingPathComponent("Yeni/index.md") : $0 }
        XCTAssertEqual(f.yollar, ["Yeni/index.md", "B/index.md"])

        f.yolGuncelle { _ in self.kok.appendingPathComponent("B/index.md") }
        XCTAssertEqual(f.yollar, ["B/index.md"])
    }

    func testSilinenSayfaAcilistaDuser() throws {
        let (a, b) = (try sayfaKur("A"), try sayfaKur("B"))
        let f = favoriler()
        [a, b].forEach(f.ekle)
        try fm.removeItem(at: sayfaKlasoru(a))

        XCTAssertEqual(favoriler().yollar, ["B/index.md"])
        XCTAssertEqual(ayarlar.stringArray(forKey: "favoriSayfalar"), ["B/index.md"], "temizlik kalıcı olmalı")
    }

    /// Elle bozulmuş kayıttaki ../ kök dışına çıkmamalı.
    func testKokDisinaKacanKayitDuser() throws {
        try sayfaKur("A")
        ayarlar.set(["../disari.md", "A/index.md", "A/index.md"], forKey: "favoriSayfalar")
        XCTAssertEqual(favoriler().yollar, ["A/index.md"])
    }
}
