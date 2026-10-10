import XCTest
@testable import NotDefteriCekirdek

/// Ana Sayfa verisi: bekleyen yapılacaklar, tamamlama, günlük not ve güvenli sayfa oluşturma.
final class AnaSayfaVerisiTestleri: GeciciKokTestCase {

    private func girdi(_ md: String) -> OnbellekGirdisi { onbellekGirdisiUret(md, tarih: Date()) }

    func testYalnizcaAcikVeDoluGorevlerToplanir() {
        let md = "- [ ] açık\n- [x] bitti\n- [ ]   \n* [ ] yıldızlı\n  - [ ] girintili\n"
        XCTAssertEqual(girdi(md).yapilacaklar.map(\.metin), ["açık", "girintili"])
    }

    func testKodBlogundakiGorevlerAtlanir() {
        XCTAssertEqual(girdi("```\n- [ ] kod\n```\n- [ ] gerçek").yapilacaklar.map(\.metin), ["gerçek"])
    }

    /// Konumlar gövdeye görelidir; frontmatter satırları kaydırmamalı.
    func testKonumlarFrontmatterdenBagimsizdir() {
        let duz = girdi("- [ ] iş").yapilacaklar[0]
        let ustbilgili = girdi("---\ntags: [a]\n---\n- [ ] iş").yapilacaklar[0]
        XCTAssertEqual(duz.govdeKonumu, ustbilgili.govdeKonumu)
        XCTAssertEqual(duz.kutuKonumu, 3)
    }

    func testOnbellekGirdisiBaglariVeAramaMetniniTutar() {
        let g = girdi("---\ntags: [x]\n---\n# Başlık\n[[Plan]] **kalın**")
        XCTAssertEqual(g.bagHedefleri, ["Plan"])
        XCTAssertFalse(g.aranabilirMetin.contains("tags"), "frontmatter aranmamalı")
        XCTAssertTrue(g.aranabilirMetin.contains("baslik"))
    }

    func testBekleyenlerSayfaAdinaGoreSiralanir() {
        let b = kok.appendingPathComponent("B/index.md")
        let a = kok.appendingPathComponent("a/index.md")
        let bos = kok.appendingPathComponent("C/index.md")
        let sonuc = bekleyenYapilacaklariBul([b: girdi("- [ ] b1\n- [ ] b2"), a: girdi("- [ ] a1"), bos: girdi("metin")])
        XCTAssertEqual(sonuc.map(\.metin), ["a1", "b1", "b2"])
    }

    func testTamamlamaYalnizcaKutuyuDegistirir() throws {
        let md = "---\nt: 1\n---\nönce\n- [ ] iş **kalın**\nsonra"
        let gorev = try XCTUnwrap(bekleyenYapilacaklariBul([kok.appendingPathComponent("A/index.md"): girdi(md)]).first)
        let sonuc = try yapilacagiTamamlayanMetin(gorev, metin: md)
        XCTAssertEqual(sonuc.markdown, "---\nt: 1\n---\nönce\n- [x] iş **kalın**\nsonra")
        XCTAssertEqual(sonuc.satir, "- [x] iş **kalın**\n")
    }

    /// Dosya Ana Sayfa açıkken değiştiyse yanlış satır işaretlenmemeli.
    func testDegisenDosyadaTamamlamaReddedilir() throws {
        let md = "- [ ] iş"
        let gorev = try XCTUnwrap(bekleyenYapilacaklariBul([kok.appendingPathComponent("A/index.md"): girdi(md)]).first)
        XCTAssertThrowsError(try yapilacagiTamamlayanMetin(gorev, metin: "eklenen satır\n- [ ] iş"))
        XCTAssertFalse(yapilacakGecerliMi(gorev, metin: md, onbellekMetni: "eski", acikSayfaMi: false, acikSayfaMetni: nil))
        XCTAssertFalse(yapilacakGecerliMi(gorev, metin: md, onbellekMetni: md, acikSayfaMi: true, acikSayfaMetni: "düzenleniyor"))
        XCTAssertTrue(yapilacakGecerliMi(gorev, metin: md, onbellekMetni: md, acikSayfaMi: false, acikSayfaMetni: nil))
    }

    func testGunlukNotYoluYeniDuzendedir() throws {
        let tarih = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: 9, hour: 12))!
        XCTAssertEqual(try gunlukNotURL(tarih, kok: kok).path, kok.appendingPathComponent("Günlük/2026-04-09/index.md").path)
    }

    func testMevcutEskiDuzenGunlukAcilir() throws {
        let tarih = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: 9, hour: 12))!
        let eski = try duzNotKur("Günlük/2026-04-09")
        XCTAssertEqual(try gunlukNotURL(tarih, kok: kok).path, eski.path)
    }

    func testIcerikleSayfaOlusturur() throws {
        let url = kok.appendingPathComponent("Yeni/index.md")
        try icerikleSayfaOlustur(url: url, metin: "# Yeni\n", kok: kok)
        XCTAssertEqual(try oku(url), "# Yeni\n")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: url.deletingLastPathComponent().path), ["index.md"],
                       "geçici dosya kalmamalı")
    }

    func testMevcutSayfaninUzerineYazilmaz() throws {
        let url = try sayfaKur("Var", metin: "eski\n")
        XCTAssertThrowsError(try icerikleSayfaOlustur(url: url, metin: "yeni\n", kok: kok))
        XCTAssertEqual(try oku(url), "eski\n")
    }
}
