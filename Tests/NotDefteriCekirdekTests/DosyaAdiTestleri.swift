import XCTest
@testable import NotDefteriCekirdek

/// Görsel dosya adlarının güvenli üretimi.
/// Bu testler gerçek bir veri kaybının regresyon korumasıdır: bölüm başlığı
/// parantez içerdiğinde üretilen dosya adı Markdown bağını erken bitiriyor,
/// görsel bir daha okunamıyordu.
final class DosyaAdiTestleri: XCTestCase {

    /// Markdown bağı `![](yol)` biçiminde; yolda ")" varsa bağ erken biter.
    func testParantezTemizlenir() {
        let ad = guvenliDosyaAdi("User-Agent: () { :; }; nslookup $(whoami)")
        XCTAssertFalse(ad.contains("("), "açılış parantezi kalmamalı: \(ad)")
        XCTAssertFalse(ad.contains(")"), "kapanış parantezi kalmamalı: \(ad)")
        XCTAssertFalse(ad.contains("{"), "süslü parantez kalmamalı: \(ad)")
        XCTAssertFalse(ad.contains("}"), "süslü parantez kalmamalı: \(ad)")
    }

    /// Üretilen adın bağa konup geri okunabildiğini uçtan uca doğrular.
    func testUretilenAdBagdanGeriOkunabilir() {
        let baslik = "setspn.exe -q \"-\" -> Kerberos'la çalışan (SPN)"
        let ad = guvenliDosyaAdi(baslik) + ".png"
        let bag = "![](\(kGorsellerKlasorAdi)/\(ad)){360x234}"

        // Çeviricinin kullandığı desenle aynı: ")" ilk kapanışta biter.
        let desen = try! NSRegularExpression(pattern: "^!\\[[^\\]]*\\]\\(([^)]*)\\)")
        let ns = bag as NSString
        let eslesme = desen.firstMatch(in: bag, range: NSRange(location: 0, length: ns.length))
        XCTAssertNotNil(eslesme)
        let okunanYol = ns.substring(with: eslesme!.range(at: 1))
        XCTAssertEqual(okunanYol, "\(kGorsellerKlasorAdi)/\(ad)",
                       "bağdan okunan yol yazılanla aynı olmalı")
    }

    func testTehlikeliKarakterlerTireyeDoner() {
        for karakter in ["/", ":", "[", "]", "#", "?", "*", "|", "<", ">", "\"", "\\"] {
            let ad = guvenliDosyaAdi("a\(karakter)b")
            XCTAssertFalse(ad.contains(karakter), "\(karakter) temizlenmeli, üretilen: \(ad)")
        }
    }

    func testArdArdaTirelerTeklenir() {
        XCTAssertFalse(guvenliDosyaAdi("a////b").contains("--"))
        XCTAssertFalse(guvenliDosyaAdi("() {} []").contains("--"))
    }

    func testTurkceHarflerKorunur() {
        XCTAssertEqual(guvenliDosyaAdi("Şifreleme Ağı"), "Şifreleme Ağı")
        XCTAssertEqual(guvenliDosyaAdi("Güvenlik Açığı"), "Güvenlik Açığı")
    }

    func testBosVeYalnizIsaretliGirdiVarsayilanaDoner() {
        XCTAssertEqual(guvenliDosyaAdi(""), "Görsel")
        XCTAssertEqual(guvenliDosyaAdi("   "), "Görsel")
        XCTAssertEqual(guvenliDosyaAdi("()[]{}"), "Görsel")
        XCTAssertEqual(guvenliDosyaAdi("", varsayilan: "Ek"), "Ek")
    }

    func testUzunlukSinirlanir() {
        let ad = guvenliDosyaAdi(String(repeating: "x", count: 200))
        XCTAssertLessThanOrEqual(ad.count, 40)
    }

    /// macOS'ta nokta ile başlayan dosya gizlidir; görsel istemeden kaybolmasın.
    func testNoktaylaBaslamaz() {
        XCTAssertFalse(guvenliDosyaAdi("...gizli").hasPrefix("."))
        XCTAssertFalse(guvenliDosyaAdi(".env").hasPrefix("."))
    }

    func testSonuTireYaDaBoslukOlmaz() {
        for girdi in ["ad ", "ad-", "ad.", " ad ", "ad ()"] {
            let ad = guvenliDosyaAdi(girdi)
            XCTAssertFalse(ad.hasSuffix(" "), "sonda boşluk kalmamalı: \(ad.debugDescription)")
            XCTAssertFalse(ad.hasSuffix("-"), "sonda tire kalmamalı: \(ad.debugDescription)")
        }
    }

    // MARK: Benzersiz yol

    func testCakismadaSayacEklenir() throws {
        let klasor = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("adtest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: klasor) }

        let ilk = benzersizDosyaYolu(klasor: klasor, taban: "Görsel", uzanti: "png")
        XCTAssertEqual(ilk.lastPathComponent, "Görsel.png")
        try Data().write(to: ilk)

        let ikinci = benzersizDosyaYolu(klasor: klasor, taban: "Görsel", uzanti: "png")
        XCTAssertEqual(ikinci.lastPathComponent, "Görsel-2.png")
        try Data().write(to: ikinci)

        XCTAssertEqual(benzersizDosyaYolu(klasor: klasor, taban: "Görsel", uzanti: "png").lastPathComponent,
                       "Görsel-3.png")
    }
}
