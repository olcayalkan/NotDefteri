import XCTest
@testable import NotDefteri

/// Arama önbelleğinin girdi tipi ve tazeleme mantığı.
/// Önbellek `KenarPaneli` içinde olduğu için burada davranışın çekirdeği
/// (tarih karşılaştırması) doğrulanıyor.
final class OnbellekTestleri: XCTestCase {

    private var klasor: URL!

    override func setUpWithError() throws {
        klasor = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("onbellek-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: klasor)
    }

    /// Aynı dosya değişmediyse `degistirilmeTarihi` aynı kalmalı —
    /// artımlı önbelleğin dayandığı varsayım bu.
    func testDegismeyenDosyaAyniTarihiVerir() throws {
        let url = klasor.appendingPathComponent("not.md")
        try "icerik".write(to: url, atomically: true, encoding: .utf8)

        let bir = degistirilmeTarihi(url)
        let iki = degistirilmeTarihi(url)
        XCTAssertEqual(bir, iki)
    }

    /// DİKKAT: `URL.resourceValues` değerleri ÖRNEK BAŞINA önbellekler.
    /// Aynı `URL` örneği yeniden sorgulanırsa dosya değişse bile eski tarihi
    /// döndürür. Bu yüzden her ölçümde taze bir `URL` üretiliyor —
    /// `agaciYukle()` de gerçekte böyle çalışıyor (her taramada yeni URL kurar),
    /// yani artımlı önbellek güvenli.
    func testDegisenDosyaYeniTarihVerir() throws {
        let yol = klasor.appendingPathComponent("not.md").path

        try "birinci".write(to: URL(fileURLWithPath: yol), atomically: true, encoding: .utf8)
        let once = degistirilmeTarihi(URL(fileURLWithPath: yol))

        Thread.sleep(forTimeInterval: 0.05)
        try "ikinci".write(to: URL(fileURLWithPath: yol), atomically: true, encoding: .utf8)
        let sonra = degistirilmeTarihi(URL(fileURLWithPath: yol))

        XCTAssertGreaterThan(sonra, once, "değişen dosya daha yeni tarih vermeli")
    }

    /// Önbelleğin dayandığı varsayımın regresyon testi: aynı yolun taze
    /// URL'siyle ard arda yazımlar farklı tarihler vermeli.
    func testArdArdaYazimlarFarkliTarihVerir() throws {
        let yol = klasor.appendingPathComponent("seri.md").path
        var tarihler: Set<Date> = []
        for i in 0..<3 {
            try "icerik \(i)".write(to: URL(fileURLWithPath: yol), atomically: true, encoding: .utf8)
            tarihler.insert(degistirilmeTarihi(URL(fileURLWithPath: yol)))
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertEqual(tarihler.count, 3, "her yazım ayrı tarih vermeli; yoksa önbellek bayat sonuç döndürür")
    }

    func testOlmayanDosyaUzakGecmisVerir() {
        let yok = klasor.appendingPathComponent("olmayan.md")
        XCTAssertEqual(degistirilmeTarihi(yok), .distantPast)
    }

    /// Önbellek girdisi aranabilir metni işaretlemeler temizlenmiş tutmalı;
    /// aksi hâlde "**kalın**" araması "kalın" yazınca eşleşmez.
    func testGirdiAranabilirMetinTutar() {
        let girdi = OnbellekGirdisi(tarih: Date(),
                                     aranabilirMetin: isaretlemeleriTemizle("# Başlık\n**kalın** metin"))
        XCTAssertFalse(girdi.aranabilirMetin.contains("**"))
        XCTAssertFalse(girdi.aranabilirMetin.contains("# "))
        XCTAssertTrue(girdi.aranabilirMetin.contains("kalın"))
        XCTAssertTrue(girdi.aranabilirMetin.contains("Başlık"))
    }

    /// Türkçe arama önbellekteki metinde de çalışmalı (uçtan uca).
    func testOnbellekMetnindeTurkceAramaCalisir() {
        let girdi = OnbellekGirdisi(tarih: Date(),
                                     aranabilirMetin: isaretlemeleriTemizle("# İstanbul Gezisi\nnotlar"))
        let sade = aramaIcinSadelestir(girdi.aranabilirMetin)
        XCTAssertTrue(sade.contains(aramaIcinSadelestir("istanbul")))
    }
}
