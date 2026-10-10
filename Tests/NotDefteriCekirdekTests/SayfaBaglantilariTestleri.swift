import XCTest
@testable import NotDefteriCekirdek

/// [[sayfa]] bağlantıları: bulma, çözme, bulanık arama ve taşımada yeniden yazma.
final class SayfaBaglantilariTestleri: GeciciKokTestCase {

    private func hedefler(_ metin: String) -> [String] { sayfaBaglariniBul(metin).map(\.hedef) }

    private func indeks(_ yollar: [String]) throws -> SayfaBaglantilari {
        let i = SayfaBaglantilari()
        i.guncelle(try yollar.map { SayfaSecenegi(url: try sayfaKur($0)) })
        return i
    }

    // MARK: Bulma

    func testBaglarBulunur() {
        XCTAssertEqual(hedefler("bkz. [[Plan]] ve [[Ana/Alt]]"), ["Plan", "Ana/Alt"])
    }

    func testAralikBagiKapsar() {
        let bag = sayfaBaglariniBul("x [[Plan]] y")[0]
        XCTAssertEqual(bag.aralik, NSRange(location: 2, length: 8))
    }

    func testKacisliVeBosBaglarAtlanir() {
        XCTAssertEqual(hedefler(#"\[[Kaçış]] [[ ]] [[]]"#), [])
    }

    func testKodIcindekiBaglarAtlanir() {
        XCTAssertEqual(hedefler("`[[satır içi]]`\n```\n[[blok]]\n```\n[[gerçek]]"), ["gerçek"])
    }

    func testMarkdownBaglantisiSayfaBagiDegildir() {
        XCTAssertEqual(hedefler("[[[iç]]](https://x.com) [etiket](u)"), [])
    }

    func testSatirSonuBagiKirar() {
        XCTAssertEqual(hedefler("[[yarım\nbağ]]"), [])
    }

    // MARK: Çözme

    func testAdVeYolIleCozulur() throws {
        let i = try indeks(["Ana/Plan", "Diger"])
        XCTAssertEqual(i.coz("Plan").map(sayfaAdi), "Plan")
        XCTAssertEqual(i.coz("Ana/Plan").map(sayfaAdi), "Plan")
        XCTAssertEqual(i.coz(" Diger ").map(sayfaAdi), "Diger")
        XCTAssertNil(i.coz("Yok"))
    }

    /// Aynı adlı iki sayfa varsa ad tek başına çözülmez; bağ metni yolu kullanır.
    func testAyniAdBelirsizdir() throws {
        let i = try indeks(["A/Not", "B/Not"])
        XCTAssertNil(i.coz("Not"))
        XCTAssertTrue(i.belirsizMi("Not"))
        XCTAssertEqual(i.bagMetni(kok.appendingPathComponent("A/Not/index.md")), "A/Not")
    }

    func testKoktekiAyniAdNoktaliYolAlir() throws {
        let i = try indeks(["Not", "A/Not"])
        XCTAssertEqual(i.bagMetni(kok.appendingPathComponent("Not/index.md")), "./Not")
        XCTAssertNotNil(i.coz("./Not"))
    }

    func testTekilAdBagMetnidir() throws {
        let i = try indeks(["Ana/Plan"])
        XCTAssertEqual(i.bagMetni(kok.appendingPathComponent("Ana/Plan/index.md")), "Plan")
    }

    // MARK: Arama

    func testAramaSiralamasi() throws {
        let i = try indeks(["Proje", "Proje Planı", "Eski Proje", "Plan/Pr Notu"])
        XCTAssertEqual(i.ara("proje").map(\.ad), ["Proje", "Proje Planı", "Eski Proje"],
                       "tam eşleşme, önek, içerme sırası")
    }

    func testAramaTurkceDuyarsiz() throws {
        let i = try indeks(["İstanbul Gezisi", "Çalışma"])
        XCTAssertEqual(i.ara("istanbul").map(\.ad), ["İstanbul Gezisi"])
        XCTAssertEqual(i.ara("CALISMA").map(\.ad), ["Çalışma"])
    }

    func testBulanikHarfSirasi() throws {
        let i = try indeks(["Toplantı Notları"])
        XCTAssertEqual(i.ara("tpln").map(\.ad), ["Toplantı Notları"])
        XCTAssertTrue(i.ara("xyz").isEmpty)
    }

    func testUstYol() throws {
        XCTAssertEqual(SayfaSecenegi(url: try sayfaKur("A/B/C")).ustYol, "A/B")
    }

    // MARK: Yeniden yazma

    func testBaglarDegistirilir() {
        let metin = "[[Eski]] ve [[ Eski ]] ama `[[Eski]]`"
        XCTAssertEqual(sayfaBaglariniDegistir(metin, hedefler: ["Eski": "Yeni"]), "[[Yeni]] ve [[Yeni]] ama `[[Eski]]`")
    }

    func testTasinanUrlDonusumu() {
        let eski = kok.appendingPathComponent("A")
        let yeni = kok.appendingPathComponent("B/A")
        let torun = kok.appendingPathComponent("A/Alt/index.md")
        XCTAssertEqual(SayfaBaglantilari.tasinanURL(torun, eskiKlasor: eski, yeniKlasor: yeni, eskiIcerik: nil, yeniIcerik: nil).path,
                       kok.appendingPathComponent("B/A/Alt/index.md").path)
        let ilgisiz = kok.appendingPathComponent("AB/index.md")
        XCTAssertEqual(SayfaBaglantilari.tasinanURL(ilgisiz, eskiKlasor: eski, yeniKlasor: yeni, eskiIcerik: nil, yeniIcerik: nil), ilgisiz,
                       "ad öneki benzeyen kardeş taşınmamalı")
    }

    /// Uçtan uca: sayfa yeniden adlandırılınca ona bağ veren notlar diskte güncellenir.
    func testDalTasimasiBaglariDiskteGunceller() throws {
        let hedef = try sayfaKur("Plan")
        let kaynak = try sayfaKur("Gunluk", metin: "---\ntags: [x]\n---\nbkz. [[Plan]]\n")
        let i = SayfaBaglantilari()
        i.guncelle([SayfaSecenegi(url: hedef), SayfaSecenegi(url: kaynak)])

        let yeniKlasor = kok.appendingPathComponent("Yol Haritası")
        try fm.moveItem(at: sayfaKlasoru(hedef), to: yeniKlasor)
        let yeniIcerik = yeniKlasor.appendingPathComponent(kIcerikDosyaAdi)
        let alan = "notdefteri-test-\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: alan) }

        let sonuc = i.daliGuncelle(eskiKlasor: sayfaKlasoru(hedef), yeniKlasor: yeniKlasor, eskiIcerik: hedef, yeniIcerik: yeniIcerik,
                                   notlar: [hedef, kaynak], onbellek: [:],
                                   favoriler: Favoriler(kok: kok, ayarlar: UserDefaults(suiteName: alan)!), kok: kok)

        XCTAssertTrue(sonuc.hatalar.isEmpty, "\(sonuc.hatalar)")
        XCTAssertEqual(try oku(kaynak), "---\ntags: [x]\n---\nbkz. [[Yol Haritası]]\n", "frontmatter korunmalı")
        XCTAssertEqual(i.coz("Yol Haritası")?.path, yeniIcerik.path)
    }
}
