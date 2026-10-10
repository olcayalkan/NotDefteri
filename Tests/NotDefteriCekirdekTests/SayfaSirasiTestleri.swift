import XCTest
@testable import NotDefteriCekirdek

/// Kardeş sırası: gizli `.sira.json`, sabitlenen sayfalar ve ağaca uygulanması.
final class SayfaSirasiTestleri: GeciciKokTestCase {

    private func adlar(_ dugumler: [AgacDugumu]) -> [String] { dugumler.map(\.ad) }

    func testEksikAnahtarliDosyaOkunur() throws {
        let kayit = try JSONDecoder().decode(SayfaSirasi.self, from: Data(#"{"sira":["B","A"]}"#.utf8))
        XCTAssertEqual(kayit, SayfaSirasi(sabitler: [], sira: ["B", "A"]))
    }

    func testBozukDosyaNilDoner() throws {
        try Data("{bozuk".utf8).write(to: kok.appendingPathComponent(kSiraDosyaAdi))
        XCTAssertNil(siraOku(kok))
    }

    func testSiraUygulaSabitlerOnceSonraSiraSonraKalanlar() {
        let dugumler = ["A", "B", "C", "D"].map {
            AgacDugumu(icerikURL: nil, klasorURL: kok.appendingPathComponent($0))
        }
        let sonuc = siraUygula(dugumler, SayfaSirasi(sabitler: ["C"], sira: ["D", "Olmayan", "A"]))

        XCTAssertEqual(adlar(sonuc), ["C", "D", "A", "B"])
        XCTAssertEqual(sonuc.map(\.sabit), [true, false, false, false])
    }

    func testKayitYoksaSiraDegismez() {
        let dugumler = ["B", "A"].map { AgacDugumu(icerikURL: nil, klasorURL: kok.appendingPathComponent($0)) }
        XCTAssertEqual(adlar(siraUygula(dugumler, nil)), ["B", "A"])
    }

    func testYazilanSiraGeriOkunur() throws {
        let kayit = SayfaSirasi(sabitler: ["A"], sira: ["C", "B"])
        XCTAssertTrue(siraYaz(kayit, klasor: kok))
        XCTAssertEqual(siraOku(kok), kayit)
    }

    /// Hiç sıralanmamış klasörde boş kayıt için dosya oluşturulmamalı.
    func testBosKayitDosyaOlusturmaz() {
        XCTAssertTrue(siraYaz(SayfaSirasi(), klasor: kok))
        XCTAssertFalse(varMi(kSiraDosyaAdi))
    }

    func testKokDisinaYazilmaz() throws {
        let disari = kok.deletingLastPathComponent().appendingPathComponent("disari-\(UUID().uuidString)")
        try fm.createDirectory(at: disari, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: disari) }

        XCTAssertFalse(siraYaz(SayfaSirasi(sira: ["A"]), klasor: disari))
        XCTAssertFalse(fm.fileExists(atPath: disari.appendingPathComponent(kSiraDosyaAdi).path))
    }

    /// Sembolik bağ üzerinden kök dışındaki bir dosyanın ezilmesi engellenmeli.
    func testSembolikBagUzerineYazilmaz() throws {
        let hedef = kok.deletingLastPathComponent().appendingPathComponent("hedef-\(UUID().uuidString).json")
        try Data("dokunma".utf8).write(to: hedef)
        defer { try? fm.removeItem(at: hedef) }
        try fm.createSymbolicLink(at: kok.appendingPathComponent(kSiraDosyaAdi), withDestinationURL: hedef)

        XCTAssertFalse(siraYaz(SayfaSirasi(sira: ["A"]), klasor: kok))
        XCTAssertEqual(try oku(hedef), "dokunma")
    }

    func testSiraKaydetSabitleriAyirir() {
        XCTAssertTrue(siraKaydet(klasor: kok, adlar: ["A", "B", "C"], sabitler: ["B"]))
        XCTAssertEqual(siraOku(kok), SayfaSirasi(sabitler: ["B"], sira: ["A", "C"]))
    }

    func testYenidenAdlandirmaKayittaGuncellenir() {
        siraYaz(SayfaSirasi(sabitler: ["A"], sira: ["B"]), klasor: kok)
        siraAdiniDegistir(klasor: kok, eski: "A", yeni: "Yeni")
        XCTAssertEqual(siraOku(kok), SayfaSirasi(sabitler: ["Yeni"], sira: ["B"]))
    }

    func testSilinenAdKayittanCikar() {
        siraYaz(SayfaSirasi(sabitler: ["A"], sira: ["B", "C"]), klasor: kok)
        siraAdiniDegistir(klasor: kok, eski: "B", yeni: nil)
        XCTAssertEqual(siraOku(kok), SayfaSirasi(sabitler: ["A"], sira: ["C"]))
    }

    /// Uçtan uca: ağaç taraması kayıttaki sırayı ve sabitleri uygular, kayıt dosyası sayfa sayılmaz.
    func testAgacTaramasiSirayiUygular() throws {
        for ad in ["Elma", "Armut", "Kiraz"] { try sayfaKur(ad) }
        siraYaz(SayfaSirasi(sabitler: ["Kiraz"], sira: ["Armut", "Elma"]), klasor: kok)

        let agac = agaciYukle(kok)
        XCTAssertEqual(adlar(agac), ["Kiraz", "Armut", "Elma"])
        XCTAssertTrue(try dugum("Kiraz", agac).sabit)
    }

    func testAltKlasorSirasiAyridir() throws {
        for ad in ["Ana/X", "Ana/Y"] { try sayfaKur(ad) }
        siraYaz(SayfaSirasi(sira: ["Y", "X"]), klasor: kok.appendingPathComponent("Ana"))
        XCTAssertEqual(adlar(try dugum("Ana").cocuklar), ["Y", "X"])
    }
}
