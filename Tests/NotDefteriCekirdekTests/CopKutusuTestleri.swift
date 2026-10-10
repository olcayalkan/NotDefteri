import XCTest
@testable import NotDefteriCekirdek

/// Uygulama içi çöp kutusu: silme, listeleme, geri yükleme, kalıcı silme ve temizlik.
final class CopKutusuTestleri: GeciciKokTestCase {

    private var cop: CopKutusu!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cop = CopKutusu(kok: kok)
    }

    func testSilinenSayfaCopeTasinir() throws {
        try sayfaKur("Not", metin: "# Not\niçerik\n")
        let oge = try cop.sil(try dugum("Not"))

        XCTAssertFalse(varMi("Not"), "özgün yer boşalmalı")
        XCTAssertEqual(oge.ad, "Not")
        XCTAssertEqual(oge.bilgi.ozgunYol, "Not")
        XCTAssertEqual(try oku(try XCTUnwrap(oge.icerikURL)), "# Not\niçerik\n")
    }

    /// Çöp gizli klasörde durur; ağaçta sayfa olarak görünmemeli.
    func testCopAgactaGorunmez() throws {
        try sayfaKur("Not")
        try cop.sil(try dugum("Not"))
        XCTAssertTrue(agaciYukle(kok).isEmpty)
    }

    func testOgelerEnYeniOnceListelenir() throws {
        try sayfaKur("Eski")
        try sayfaKur("Yeni")
        // Tarih ISO 8601 ile saniye hassasiyetinde saklanıyor; aynı saniyedeki sıra belirsiz.
        let eski = try cop.sil(try dugum("Eski"))
        let yeni = try cop.sil(try dugum("Yeni"))
        try bilgiyiYaz(eski.klasor, ozgunYol: "Eski", tarih: Date().addingTimeInterval(-60))
        try bilgiyiYaz(yeni.klasor, ozgunYol: "Yeni", tarih: Date())

        let sonuc = try cop.ogeler()
        XCTAssertEqual(sonuc.ogeler.map(\.ad), ["Yeni", "Eski"])
        XCTAssertTrue(sonuc.hatalar.isEmpty, "\(sonuc.hatalar)")
    }

    func testGeriYuklemeOzgunYereDoner() throws {
        try sayfaKur("Ana/Alt", metin: "alt\n")
        let oge = try cop.sil(try dugum("Alt", try dugum("Ana").cocuklar))

        let url = try cop.geriYukle(oge)
        XCTAssertEqual(url.path, kok.appendingPathComponent("Ana/Alt/index.md").path)
        XCTAssertEqual(try oku(url), "alt\n")
        XCTAssertTrue(try cop.ogeler().ogeler.isEmpty)
    }

    func testOzgunYerDoluysaAdBenzersizlesir() throws {
        try sayfaKur("Not", metin: "silinen\n")
        let oge = try cop.sil(try dugum("Not"))
        try sayfaKur("Not", metin: "yeni\n")

        let url = try cop.geriYukle(oge)
        XCTAssertEqual(sayfaAdi(url), "Not (2)")
        XCTAssertEqual(try oku(url), "silinen\n")
        XCTAssertEqual(try oku(kok.appendingPathComponent("Not/index.md")), "yeni\n", "mevcut sayfa ezilmemeli")
    }

    /// Üst sayfa da silinmişse öğe köke döner; kaybolmamalı.
    func testUstSilinmisseKokeDoner() throws {
        try sayfaKur("Ana/Alt")
        let oge = try cop.sil(try dugum("Alt", try dugum("Ana").cocuklar))
        try fm.removeItem(at: kok.appendingPathComponent("Ana"))

        let url = try cop.geriYukle(oge)
        XCTAssertEqual(url.path, kok.appendingPathComponent("Alt/index.md").path)
    }

    func testEskiDuzenNotVeAltKlasoruBirlikteGeriGelir() throws {
        try duzNotKur("Duz", metin: "düz\n")
        try sayfaKur("Duz/Cocuk")
        let oge = try cop.sil(try dugum("Duz"))
        XCTAssertFalse(varMi("Duz.md"))
        XCTAssertFalse(varMi("Duz"))

        let url = try cop.geriYukle(oge)
        XCTAssertEqual(url.lastPathComponent, "Duz.md")
        XCTAssertEqual(try oku(url), "düz\n")
        XCTAssertTrue(varMi("Duz/Cocuk/index.md"))
    }

    func testIkinciGeriYuklemeHataVerir() throws {
        try sayfaKur("Not")
        let oge = try cop.sil(try dugum("Not"))
        try cop.geriYukle(oge)
        XCTAssertThrowsError(try cop.geriYukle(oge))
    }

    func testKaliciSil() throws {
        try sayfaKur("Not")
        let oge = try cop.sil(try dugum("Not"))
        try cop.kaliciSil(oge)

        XCTAssertFalse(fm.fileExists(atPath: oge.klasor.path))
        XCTAssertTrue(try cop.ogeler().ogeler.isEmpty)
    }

    func testTemizlikYeniOgeleriKorur() throws {
        try sayfaKur("Not")
        try cop.sil(try dugum("Not"))

        XCTAssertTrue(cop.temizle(eskiOlanlar: true).isEmpty)
        XCTAssertEqual(try cop.ogeler().ogeler.count, 1, "30 günden yeni öğe kalmalı")
    }

    func testOtuzGunlukOgeTemizlenir() throws {
        try sayfaKur("Not")
        let oge = try cop.sil(try dugum("Not"))
        try bilgiyiYaz(oge.klasor, ozgunYol: "Not", tarih: Date().addingTimeInterval(-31 * 24 * 3600))

        XCTAssertTrue(cop.temizle(eskiOlanlar: true).isEmpty)
        XCTAssertTrue(try cop.ogeler().ogeler.isEmpty)
    }

    func testBosaltmaHepsiniSiler() throws {
        for ad in ["A", "B"] { try sayfaKur(ad); try cop.sil(try dugum(ad)) }
        XCTAssertTrue(cop.temizle(eskiOlanlar: false).isEmpty)
        XCTAssertTrue(try cop.ogeler().ogeler.isEmpty)
    }

    /// Elle bozulmuş bilgi dosyası geri yüklemede kök dışına yazdırmamalı.
    func testKokDisiOzgunYolReddedilir() throws {
        try sayfaKur("Not")
        let oge = try cop.sil(try dugum("Not"))
        try bilgiyiYaz(oge.klasor, ozgunYol: "../disari", tarih: Date())

        let sonuc = try cop.ogeler()
        XCTAssertTrue(sonuc.ogeler.isEmpty)
        XCTAssertEqual(sonuc.hatalar.count, 1, "bozuk öğe listeyi düşürmemeli, hata olarak bildirilmeli")
        XCTAssertThrowsError(try cop.geriYukle(oge))
    }

    func testGizliKlasorSilinemez() throws {
        let gizli = kok.appendingPathComponent(".gizli")
        try fm.createDirectory(at: gizli, withIntermediateDirectories: true)
        XCTAssertThrowsError(try cop.sil(AgacDugumu(icerikURL: nil, klasorURL: gizli)))
        XCTAssertTrue(fm.fileExists(atPath: gizli.path))
    }

    private func bilgiyiYaz(_ klasor: URL, ozgunYol: String, tarih: Date) throws {
        let kodlayici = JSONEncoder()
        kodlayici.dateEncodingStrategy = .iso8601
        let bilgi = CopBilgisi(ozgunYol: ozgunYol, silinmeTarihi: tarih, icerikDosyasi: kIcerikDosyaAdi)
        try kodlayici.encode(bilgi).write(to: klasor.appendingPathComponent(".cop-bilgi.json"))
    }
}
