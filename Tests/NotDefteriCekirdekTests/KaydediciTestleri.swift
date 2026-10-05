import XCTest
@testable import NotDefteriCekirdek

/// `NotKaydedici` testleri. Pencere kurmadan çalışır — kayıt mantığının
/// arayüzden ayrılmasının asıl kazancı bu.
final class KaydediciTestleri: XCTestCase {

    private var klasor: URL!

    override func setUpWithError() throws {
        klasor = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kaydedici-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: klasor)
    }

    private func url(_ ad: String = "not.md") -> URL {
        klasor.appendingPathComponent(ad)
    }

    // MARK: Yazma

    func testYazmaDiskeIsler() throws {
        let k = NotKaydedici()
        let hedef = url()

        XCTAssertEqual(k.yaz(metin: "merhaba", url: hedef, mevcutURL: nil), .yazildi)
        XCTAssertEqual(try String(contentsOf: hedef, encoding: .utf8), "merhaba")
        XCTAssertFalse(k.duzenlendiMi, "başarılı yazımdan sonra temiz olmalı")
    }

    func testEksikKlasorOlusturulur() throws {
        let k = NotKaydedici()
        let hedef = klasor.appendingPathComponent("yeni/alt/not.md")

        XCTAssertEqual(k.yaz(metin: "x", url: hedef, mevcutURL: nil), .yazildi)
        XCTAssertTrue(FileManager.default.fileExists(atPath: hedef.path))
    }

    func testAyniIcerikTekrarYazilmaz() {
        let k = NotKaydedici()
        let hedef = url()

        XCTAssertEqual(k.yaz(metin: "ayni", url: hedef, mevcutURL: nil), .yazildi)
        XCTAssertEqual(k.yaz(metin: "ayni", url: hedef, mevcutURL: hedef), .gerekmedi)
    }

    func testDegisenIcerikYenidenYazilir() {
        let k = NotKaydedici()
        let hedef = url()

        XCTAssertEqual(k.yaz(metin: "bir", url: hedef, mevcutURL: nil), .yazildi)
        XCTAssertEqual(k.yaz(metin: "iki", url: hedef, mevcutURL: hedef), .yazildi)
    }

    /// Dosya diskten silinmişse aynı içerik olsa da yeniden yazılmalı.
    func testDosyaSilinmisseYenidenYazilir() throws {
        let k = NotKaydedici()
        let hedef = url()

        XCTAssertEqual(k.yaz(metin: "ayni", url: hedef, mevcutURL: nil), .yazildi)
        try FileManager.default.removeItem(at: hedef)
        XCTAssertEqual(k.yaz(metin: "ayni", url: hedef, mevcutURL: hedef), .yazildi,
                       "dosya yoksa içerik aynı olsa da yazılmalı")
    }

    func testBaskaDosyayaAyniIcerikYazilir() {
        let k = NotKaydedici()
        XCTAssertEqual(k.yaz(metin: "ayni", url: url("a.md"), mevcutURL: nil), .yazildi)
        XCTAssertEqual(k.yaz(metin: "ayni", url: url("b.md"), mevcutURL: url("a.md")), .yazildi,
                       "hedef değiştiyse yazılmalı")
    }

    // MARK: Başarısızlık — bu bir hatanın regresyon testi

    /// Yazma başarısız olduğunda durum GÜNCELLENMEMELİ.
    /// Eskiden güncelleniyordu: not kaydedilmediği hâlde "kaydedildi" sayılıyor,
    /// sonraki otomatik kayıtlar "değişmemiş" deyip atlıyor, kullanıcı
    /// yazdığını sessizce kaybediyordu.
    func testBasarisizYazimDurumuBozmaz() {
        let k = NotKaydedici()
        let iyi = url()
        XCTAssertEqual(k.yaz(metin: "guvenli", url: iyi, mevcutURL: nil), .yazildi)

        k.degisiklikIsaretle()
        let yazilamaz = URL(fileURLWithPath: "/System/olmayan-dizin/not.md")
        guard case .basarisiz = k.yaz(metin: "kayip", url: yazilamaz, mevcutURL: iyi) else {
            return XCTFail("yazılamayan yola yazım başarısız olmalıydı")
        }

        XCTAssertEqual(k.sonYazilanIcerik, "guvenli", "son yazılan içerik korunmalı")
        XCTAssertTrue(k.duzenlendiMi, "kaydedilmemiş değişiklik işareti durmalı ki yeniden denensin")
    }

    /// Başarısızlıktan sonra tekrar denenince yazabilmeli.
    func testBasarisizliktanSonraYenidenDenenebilir() {
        let k = NotKaydedici()
        let yazilamaz = URL(fileURLWithPath: "/System/olmayan-dizin/not.md")
        guard case .basarisiz = k.yaz(metin: "icerik", url: yazilamaz, mevcutURL: nil) else {
            return XCTFail("başarısız olmalıydı")
        }
        XCTAssertEqual(k.yaz(metin: "icerik", url: url(), mevcutURL: nil), .yazildi)
    }

    // MARK: Durum yönetimi

    func testSifirlaDurumuTemizler() {
        let k = NotKaydedici()
        k.degisiklikIsaretle()
        XCTAssertTrue(k.duzenlendiMi)

        k.sifirla(sonYazilan: "acilan not")
        XCTAssertEqual(k.sonYazilanIcerik, "acilan not")
        XCTAssertFalse(k.duzenlendiMi)
        XCTAssertFalse(k.zamanlayiciKurulu, "sıfırlama bekleyen zamanlayıcıyı da iptal etmeli")
    }

    func testYazmakGerekliMantigi() {
        let k = NotKaydedici()
        let hedef = url()
        _ = k.yaz(metin: "ayni", url: hedef, mevcutURL: nil)

        XCTAssertFalse(k.yazmakGerekli(metin: "ayni", url: hedef, mevcutURL: hedef))
        XCTAssertTrue(k.yazmakGerekli(metin: "farkli", url: hedef, mevcutURL: hedef))
        XCTAssertTrue(k.yazmakGerekli(metin: "ayni", url: url("b.md"), mevcutURL: hedef))
    }

    // MARK: Zamanlayıcı

    func testZamanlayiciTekAtimlik() {
        let k = NotKaydedici(aralik: 60)
        k.zamanlayiciKur {}
        XCTAssertTrue(k.zamanlayiciKurulu)

        k.zamanlayiciKur {}   // ikinci çağrı yenisini açmamalı
        k.bekleyeniIptalEt()
        XCTAssertFalse(k.zamanlayiciKurulu)
    }

    func testZamanlayiciTetiklenir() {
        let k = NotKaydedici(aralik: 0.05)
        let beklenti = expectation(description: "otomatik kayıt tetiklendi")
        k.zamanlayiciKur { beklenti.fulfill() }
        wait(for: [beklenti], timeout: 2)
        XCTAssertFalse(k.zamanlayiciKurulu, "tetiklendikten sonra kendini bırakmalı")
    }

    func testBasariliYazimBekleyeniIptalEder() {
        let k = NotKaydedici(aralik: 60)
        k.zamanlayiciKur {}
        _ = k.yaz(metin: "x", url: url(), mevcutURL: nil)
        XCTAssertFalse(k.zamanlayiciKurulu)
    }
}
