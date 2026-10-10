import XCTest
@testable import NotDefteriCekirdek

/// Sayfa ağacı: tarama, sayfa adları, üstbilgi (frontmatter), ata yolu ve taşıma doğrulaması.
final class SayfaAgaciTestleri: GeciciKokTestCase {

    // MARK: Ağaç taraması

    func testYeniVeEskiDuzenBirlikteOkunur() throws {
        try sayfaKur("Yeni")
        try duzNotKur("Eski")
        let adlar = Set(agaciYukle(kok).map(\.ad))
        XCTAssertEqual(adlar, ["Yeni", "Eski"])
    }

    func testAltSayfalarCocukOlur() throws {
        for yol in ["Ana", "Ana/Alt", "Ana/Alt/Torun"] { try sayfaKur(yol) }
        let ana = try dugum("Ana")
        let alt = try dugum("Alt", ana.cocuklar)
        XCTAssertEqual(alt.cocuklar.map(\.ad), ["Torun"])
        XCTAssertTrue(ana.sayfaMi)
    }

    /// index.md'siz klasör sayfa değil kapsayıcıdır; çocukları yine görünür.
    func testIndexsizKlasorKapsayicidir() throws {
        try sayfaKur("Klasor/Sayfa")
        let klasor = try dugum("Klasor")
        XCTAssertFalse(klasor.sayfaMi)
        XCTAssertEqual(klasor.cocuklar.map(\.ad), ["Sayfa"])
    }

    func testEskiDuzeninAltKlasoruAyriSayfaSayilmaz() throws {
        try duzNotKur("Duz")
        try sayfaKur("Duz/Cocuk")
        let agac = agaciYukle(kok)
        XCTAssertEqual(agac.map(\.ad), ["Duz"])
        XCTAssertEqual(try dugum("Duz", agac).cocuklar.map(\.ad), ["Cocuk"])
    }

    func testGizliVeGorselKlasorleriAtlanir() throws {
        try sayfaKur("Sayfa")
        for ad in [".gizli", kGorsellerKlasorAdi, "ekler"] {
            try fm.createDirectory(at: kok.appendingPathComponent("Sayfa/\(ad)"), withIntermediateDirectories: true)
            try "x".write(to: kok.appendingPathComponent("Sayfa/\(ad)/a.md"), atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(try dugum("Sayfa").cocuklar.isEmpty)
    }

    func testSayfalarYenidenEskiyeSiralanir() throws {
        let eski = try sayfaKur("Eski")
        try sayfaKur("Yeni")
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: eski.path)
        XCTAssertEqual(agaciYukle(kok).map(\.ad), ["Yeni", "Eski"])
    }

    // MARK: Sayfa adı

    func testSayfaAdiGecerliligi() {
        for ad in ["Not", "Şifreleme Ağı", "2026-01-02", "a.b"] {
            XCTAssertTrue(sayfaAdiGecerliMi(ad), ad)
        }
        for ad in ["", "   ", ".gizli", "a/b", "a:b", "[[x]]", "ekler", "EKLER", kGorsellerKlasorAdi] {
            XCTAssertFalse(sayfaAdiGecerliMi(ad), ad)
        }
    }

    func testBenzersizSayfaAdiCakismadaNumaralanir() throws {
        try sayfaKur("Not")
        try duzNotKur("Not (2)")
        let sonuc = benzersizSayfaURLSonucu(taban: "Not", klasor: kok)
        XCTAssertEqual(sayfaAdi(sonuc.url), "Not (3)", "eski düzen dosyası da dolu sayılmalı")
        XCTAssertFalse(sonuc.gecersizAd)
    }

    func testGecersizAdYeniSayfayaDuser() {
        let sonuc = benzersizSayfaURLSonucu(taban: ".gizli", klasor: kok)
        XCTAssertEqual(sayfaAdi(sonuc.url), "Yeni Sayfa")
        XCTAssertTrue(sonuc.gecersizAd)
    }

    func testSayfaKlasoruVeAdiIkiDuzendeDeDogru() throws {
        let yeni = try sayfaKur("Ana/Yeni")
        let eski = try duzNotKur("Ana/Eski")
        XCTAssertEqual(sayfaAdi(yeni), "Yeni")
        XCTAssertEqual(sayfaAdi(eski), "Eski")
        XCTAssertEqual(ustKlasor(yeni).path, ustKlasor(eski).path)
    }

    func testEskiNotKlasoreDonusturulur() throws {
        let eski = try duzNotKur("Duz", metin: "düz\n")
        let yeni = try XCTUnwrap(sayfayiKlasoreDonustur(eski))
        XCTAssertEqual(yeni.path, kok.appendingPathComponent("Duz/index.md").path)
        XCTAssertEqual(try oku(yeni), "düz\n")
        XCTAssertFalse(varMi("Duz.md"))
    }

    func testBagYoluKokeGorelidir() throws {
        XCTAssertEqual(sayfaBagYolu(try sayfaKur("Ana/Alt")), "Ana/Alt")
    }

    func testSayfaYoluAtalariIcerir() throws {
        try sayfaKur("A")
        try duzNotKur("A/B")
        let c = try sayfaKur("A/B/C")
        XCTAssertEqual(sayfaYolu(c, kok: kok).map(sayfaAdi), ["A", "B", "C"])
    }

    // MARK: Üstbilgi (frontmatter)

    func testUstbilgiAyrilirGovdeKalir() {
        let (bilgi, govde) = sayfaUstbilgisiniAyir("---\ngenislik: genis\nyazi: kucuk\n---\n# Başlık\n")
        XCTAssertEqual(bilgi.genislik, "genis")
        XCTAssertEqual(bilgi.yazi, "kucuk")
        XCTAssertEqual(govde, "# Başlık\n")
    }

    /// Obsidian'ın tags/aliases gibi alanları dokunulmadan korunmalı.
    func testDegismeyenUstbilgiAynenYazilir() {
        let kaynak = "---\ntags:\n  - is\naliases: [x]\ngenislik: genis\n---\n"
        let (bilgi, _) = sayfaUstbilgisiniAyir(kaynak + "metin")
        XCTAssertEqual(bilgi.markdown, kaynak)
    }

    func testDegisenAlanYalnizcaKendiSatirindaGuncellenir() {
        var (bilgi, _) = sayfaUstbilgisiniAyir("---\ntags: [a]\ngenislik: genis\n---\nmetin")
        bilgi.genislik = "dar"
        bilgi.yazi = "buyuk"
        XCTAssertEqual(bilgi.markdown, "---\ntags: [a]\ngenislik: dar\nyazi: buyuk\n---\n")
    }

    func testAlanTemizlenirseSatirSilinir() {
        var (bilgi, _) = sayfaUstbilgisiniAyir("---\ngenislik: genis\n---\nmetin")
        bilgi.genislik = ""
        XCTAssertEqual(bilgi.markdown, "", "boş kalan blok yazılmamalı")
    }

    func testCrlfSatirSonlariKorunur() {
        var (bilgi, govde) = sayfaUstbilgisiniAyir("---\r\ngenislik: genis\r\n---\r\nmetin")
        XCTAssertEqual(govde, "metin")
        bilgi.yazi = "kucuk"
        XCTAssertEqual(bilgi.markdown, "---\r\ngenislik: genis\r\nyazi: kucuk\r\n---\r\n")
    }

    /// Metnin başındaki yatay çizgi (---) frontmatter sanılıp silinmemeli.
    func testAnahtarsizBlokUstbilgiSayilmaz() {
        let metin = "---\nsadece metin\n---\n"
        let (bilgi, govde) = sayfaUstbilgisiniAyir(metin)
        XCTAssertEqual(govde, metin)
        XCTAssertEqual(bilgi, SayfaUstbilgisi())
    }

    func testKapanmayanBlokUstbilgiSayilmaz() {
        let metin = "---\ngenislik: genis\nmetin devam ediyor"
        XCTAssertEqual(sayfaUstbilgisiniAyir(metin).govde, metin)
    }

    // MARK: Taşıma doğrulaması

    func testKendiAltinaTasinamaz() throws {
        try sayfaKur("Ana/Alt")
        let ana = kok.appendingPathComponent("Ana")
        guard case .failure(.kendiAltina) = tasimayiDogrula(kaynakKlasor: ana, hedefKlasor: ana.appendingPathComponent("Alt"),
                                                            mevcutUst: kok, kok: kok) else { return XCTFail() }
    }

    func testAyniUsteTasimaReddedilir() throws {
        try sayfaKur("A")
        guard case .failure(.ayniUst) = tasimayiDogrula(kaynakKlasor: kok.appendingPathComponent("A"), hedefKlasor: kok,
                                                        mevcutUst: kok, kok: kok) else { return XCTFail() }
    }

    func testGecerliTasima() throws {
        try sayfaKur("A")
        try sayfaKur("B")
        XCTAssertTrue(tasimaGecerliMi(kaynakKlasor: kok.appendingPathComponent("A"),
                                      hedefKlasor: kok.appendingPathComponent("B"), mevcutUst: kok, kok: kok))
    }

    func testKokDisinaTasinamaz() throws {
        try sayfaKur("A")
        XCTAssertFalse(tasimaGecerliMi(kaynakKlasor: kok.appendingPathComponent("A"),
                                       hedefKlasor: URL(fileURLWithPath: "/tmp"), mevcutUst: kok, kok: kok))
    }
}
