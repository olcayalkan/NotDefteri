import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Sayfa yeniden adlandırma. Alt sayfalar ve görseller sayfanın klasörünün
/// içinde durduğu için tek `moveItem` ile taşınmaları gerekir.
final class YenidenAdlandirmaTestleri: XCTestCase {

    // Çekirdek fonksiyon kökle birlikte çağrılır: geçici klasör varsayılan kökün
    // dışında kaldığı için AppKit sarmalayıcısı modal uyarı açıp testi kilitliyordu.
    private var kok: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        kok = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("adlandirma-\(UUID().uuidString)")
        try fm.createDirectory(at: kok, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: kok)
    }

    /// Yeni düzende bir sayfa kurar: <ad>/index.md (+ isteğe bağlı alt sayfa, görsel).
    @discardableResult
    private func sayfaKur(_ ad: String, altSayfa: String? = nil, gorselli: Bool = false) throws -> URL {
        let klasor = kok.appendingPathComponent(ad)
        try fm.createDirectory(at: klasor, withIntermediateDirectories: true)
        try "# \(ad)\n".write(to: klasor.appendingPathComponent(kIcerikDosyaAdi),
                              atomically: true, encoding: .utf8)
        if gorselli {
            let g = klasor.appendingPathComponent(kGorsellerKlasorAdi)
            try fm.createDirectory(at: g, withIntermediateDirectories: true)
            try Data().write(to: g.appendingPathComponent("a.png"))
        }
        if let altSayfa {
            let ak = klasor.appendingPathComponent(altSayfa)
            try fm.createDirectory(at: ak, withIntermediateDirectories: true)
            try "# \(altSayfa)\n".write(to: ak.appendingPathComponent(kIcerikDosyaAdi),
                                         atomically: true, encoding: .utf8)
        }
        return klasor.appendingPathComponent(kIcerikDosyaAdi)
    }

    func testAdDegisirIcerikKorunur() throws {
        let url = try sayfaKur("Eski")
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandirmaSonucu(url, yeniAd: "Yeni", kok: kok))

        XCTAssertEqual(sayfaAdi(yeni), "Yeni")
        XCTAssertEqual(try String(contentsOf: yeni, encoding: .utf8), "# Eski\n",
                       "yalnızca ad değişmeli, içerik aynı kalmalı")
        XCTAssertFalse(fm.fileExists(atPath: url.path), "eski yol kalmamalı")
    }

    /// Alt sayfalar sayfanın klasöründe olduğu için birlikte taşınmalı.
    func testAltSayfalarBirlikteTasinir() throws {
        let url = try sayfaKur("Ana", altSayfa: "Alt")
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandirmaSonucu(url, yeniAd: "AnaYeni", kok: kok))

        let altYolu = sayfaKlasoru(yeni).appendingPathComponent("Alt/\(kIcerikDosyaAdi)")
        XCTAssertTrue(fm.fileExists(atPath: altYolu.path), "alt sayfa taşınmalı")
    }

    /// Görseller de sayfanın klasöründe; taşınmazlarsa bağlar kırılır.
    func testGorsellerBirlikteTasinir() throws {
        let url = try sayfaKur("Resimli", gorselli: true)
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandirmaSonucu(url, yeniAd: "ResimliYeni", kok: kok))

        let gorsel = sayfaKlasoru(yeni).appendingPathComponent("\(kGorsellerKlasorAdi)/a.png")
        XCTAssertTrue(fm.fileExists(atPath: gorsel.path), "görsel taşınmalı, yoksa bağ kırılır")
    }

    func testCakismadaSayacEklenir() throws {
        try sayfaKur("Dolu")
        let url = try sayfaKur("Boş")
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandirmaSonucu(url, yeniAd: "Dolu", kok: kok))

        XCTAssertEqual(sayfaAdi(yeni), "Dolu (2)")
        XCTAssertTrue(fm.fileExists(atPath: kok.appendingPathComponent("Dolu/\(kIcerikDosyaAdi)").path),
                      "var olan sayfa bozulmamalı")
    }

    func testAyniAdDegisiklikYapmaz() throws {
        let url = try sayfaKur("Sabit")
        XCTAssertEqual(try sayfayiYenidenAdlandirmaSonucu(url, yeniAd: "Sabit", kok: kok), url)
        XCTAssertTrue(fm.fileExists(atPath: url.path))
    }

    func testTurkceKarakterliAd() throws {
        let url = try sayfaKur("Sifreleme")
        let yeni = try XCTUnwrap(sayfayiYenidenAdlandirmaSonucu(url, yeniAd: "Şifreleme Ağı", kok: kok))

        XCTAssertTrue(fm.fileExists(atPath: yeni.path))
        XCTAssertEqual(sayfaAdi(yeni), "Şifreleme Ağı")
    }

    /// Eski düzen: "Ad.md" + kardeş "Ad/" klasörü. İkisi birlikte taşınmalı.
    func testEskiDuzenDosyaVeKlasorBirlikteTasinir() throws {
        let dosya = kok.appendingPathComponent("Duz.md")
        try "# Duz\n".write(to: dosya, atomically: true, encoding: .utf8)
        let dal = kok.appendingPathComponent("Duz")
        try fm.createDirectory(at: dal, withIntermediateDirectories: true)
        try Data().write(to: dal.appendingPathComponent("ek.png"))

        let yeni = try XCTUnwrap(sayfayiYenidenAdlandirmaSonucu(dosya, yeniAd: "DuzYeni", kok: kok))

        XCTAssertTrue(fm.fileExists(atPath: yeni.path), "dosya taşınmalı")
        XCTAssertTrue(fm.fileExists(atPath: kok.appendingPathComponent("DuzYeni/ek.png").path),
                      "kardeş klasör de taşınmalı")
        XCTAssertFalse(fm.fileExists(atPath: dosya.path))
    }

    /// Yeniden adlandırdıktan sonra ağaç taraması sayfayı yeni adıyla bulmalı.
    func testAgacYeniAdiGorur() throws {
        let url = try sayfaKur("Once", altSayfa: "Alt")
        _ = try sayfayiYenidenAdlandirmaSonucu(url, yeniAd: "Sonra", kok: kok)

        let agac = agaciYukle(kok)
        let adlar = agac.map(\.ad)
        XCTAssertTrue(adlar.contains("Sonra"), "yeni ad ağaçta olmalı, bulunan: \(adlar)")
        XCTAssertFalse(adlar.contains("Once"), "eski ad ağaçta kalmamalı")

        let sonra = try XCTUnwrap(agac.first { $0.ad == "Sonra" })
        XCTAssertEqual(sonra.cocuklar.map(\.ad), ["Alt"], "alt sayfa ağaçta görünmeli")
    }
}

/// Kenar panelin "açık klasör" hafızası. Bir dal taşınınca altındaki tüm
/// kayıtların da taşınması gerekiyor; yoksa alt sayfanın altındaki dallar
/// yeniden açılmıyor ve kayıt kalıcı çöpe dönüşüyor.
final class AcikKlasorKayitlariTestleri: XCTestCase {

    private func panel(_ yollar: [String]) -> KenarPaneli {
        let p = KenarPaneli(frame: .zero)
        p.acikKlasorYollari = Set(yollar)
        return p
    }

    func testTasimaTorunlariDaGunceller() {
        let p = panel(["/n/Ana", "/n/Ana/Alt", "/n/Ana/Alt/AltAlt", "/n/Baska"])
        p.acikKlasorleriTasi(eski: "/n/Ana/Alt", yeni: "/n/Ana/AltYeni")

        XCTAssertTrue(p.acikKlasorYollari.contains("/n/Ana/AltYeni"))
        XCTAssertTrue(p.acikKlasorYollari.contains("/n/Ana/AltYeni/AltAlt"),
                      "torun kaydı da taşınmalı: \(p.acikKlasorYollari.sorted())")
        XCTAssertFalse(p.acikKlasorYollari.contains("/n/Ana/Alt"))
        XCTAssertFalse(p.acikKlasorYollari.contains("/n/Ana/Alt/AltAlt"), "eski kayıt kalmamalı")
    }

    func testTasimaIlgisizKayitlaraDokunmaz() {
        let p = panel(["/n/Ana", "/n/Ana/Alt", "/n/Baska", "/n/AltBaska"])
        p.acikKlasorleriTasi(eski: "/n/Ana/Alt", yeni: "/n/Ana/AltYeni")

        XCTAssertTrue(p.acikKlasorYollari.contains("/n/Ana"), "üst dal etkilenmemeli")
        XCTAssertTrue(p.acikKlasorYollari.contains("/n/Baska"))
        XCTAssertTrue(p.acikKlasorYollari.contains("/n/AltBaska"),
                      "benzer adlı ama farklı dal etkilenmemeli")
    }

    /// "Alt" öneki "AltBaska"yı yakalamamalı — sınır "/" ile korunuyor.
    func testOnekSinirinaSaygiliDir() {
        let p = panel(["/n/Alt", "/n/AltBaska"])
        p.acikKlasorleriTasi(eski: "/n/Alt", yeni: "/n/Yeni")

        XCTAssertTrue(p.acikKlasorYollari.contains("/n/Yeni"))
        XCTAssertTrue(p.acikKlasorYollari.contains("/n/AltBaska"), "yanlış eşleşme olmamalı")
    }

    func testSilmeDaliTemizler() {
        let p = panel(["/n/Ana", "/n/Ana/Alt", "/n/Ana/Alt/AltAlt", "/n/Baska"])
        p.acikKlasorleriSil(onek: "/n/Ana/Alt")

        XCTAssertFalse(p.acikKlasorYollari.contains("/n/Ana/Alt"))
        XCTAssertFalse(p.acikKlasorYollari.contains("/n/Ana/Alt/AltAlt"), "torunlar da silinmeli")
        XCTAssertTrue(p.acikKlasorYollari.contains("/n/Ana"), "üst dal kalmalı")
        XCTAssertTrue(p.acikKlasorYollari.contains("/n/Baska"))
    }
}

/// Kenar panelin metin alanı delege metotları hangi alandan geldiğini
/// süzmeli. Süzmezse satır üzerinde ad düzenlerken arama mantığı devreye
/// giriyor ve düzenleme yarıda kesiliyor.
final class MetinAlaniDelegeTestleri: XCTestCase {

    /// Ad düzenleme alanından gelen değişiklik arama filtresini ÇALIŞTIRMAMALI.
    ///
    /// Gerçek hata: her tuş vuruşunda `filtreUygula()` -> `reloadData()`
    /// çalışıyor, düzenlenen hücre yok ediliyor ve ad yarım metinle
    /// kaydediliyordu — "A" yazınca dosyanın adı "A" oluyordu.
    func testYabanciAlandanGelenDegisiklikAramayiTetiklemez() {
        let panel = KenarPaneli(frame: .zero)
        panel.aramaAlani.stringValue = "arama metni"
        let onceki = panel.aramaTemizleButonu.isHidden

        // Satır üzerindeki ad düzenleme alanını taklit et.
        let adAlani = NSTextField(string: "A")
        panel.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification,
                                                 object: adAlani))

        XCTAssertEqual(panel.aramaTemizleButonu.isHidden, onceki,
                       "yabancı alandan gelen bildirim arama durumunu değiştirmemeli")
    }

    /// Arama kutusundan gelen değişiklik normal şekilde işlenmeli.
    func testAramaKutusundanGelenDegisiklikIslenir() {
        let panel = KenarPaneli(frame: .zero)
        panel.aramaAlani.stringValue = "bir şey"

        panel.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification,
                                                 object: panel.aramaAlani))

        XCTAssertFalse(panel.aramaTemizleButonu.isHidden,
                       "arama doluyken temizle düğmesi görünmeli")
    }

    func testBosAramaTemizleDugmesiniGizler() {
        let panel = KenarPaneli(frame: .zero)
        panel.aramaAlani.stringValue = ""

        panel.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification,
                                                 object: panel.aramaAlani))

        XCTAssertTrue(panel.aramaTemizleButonu.isHidden)
    }
}
