#if os(macOS)
import XCTest
@testable import NotDefteriCekirdek

/// macOS'ta /var, /tmp ve /etc, /private altına sembolik bağdır. Dizin listelemesi yolları
/// /private ile, `resolvingSymlinksInPath` ise /private'sız döndürür. Not kökü böyle bir
/// yerdeyken ağaçtan gelen yollar "kök dışında" sayılıyor, çöp ve taşıma çalışmıyordu (#12).
final class PrivateKokTestleri: XCTestCase {

    private var kok: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        // Bilerek /var/folders/... altında: bağlı kökün kendisi test ediliyor.
        kok = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("private-kok-\(UUID().uuidString)", isDirectory: true)
        XCTAssertTrue(kok.path.hasPrefix("/var/"), "bu testler /private bağı altındaki kökü ölçer")
        try fm.createDirectory(at: kok, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? fm.removeItem(at: kok) }

    @discardableResult
    private func sayfaKur(_ ad: String) throws -> URL {
        let klasor = kok.appendingPathComponent(ad, isDirectory: true)
        try fm.createDirectory(at: klasor, withIntermediateDirectories: true)
        let icerik = klasor.appendingPathComponent(kIcerikDosyaAdi)
        try "# \(ad)\n".write(to: icerik, atomically: true, encoding: .utf8)
        return icerik
    }

    private func dugum(_ ad: String) throws -> AgacDugumu {
        try XCTUnwrap(agaciYukle(kok).first { $0.ad == ad })
    }

    func testAgactanGelenYolKokIcindeSayilir() throws {
        try sayfaKur("Not")
        let url = try XCTUnwrap(try dugum("Not").icerikURL)
        XCTAssertTrue(url.path.hasPrefix(kok.path + "/"), "ağaç yolları kökün yazılışını korumalı: \(url.path)")
        XCTAssertNoThrow(try notlarYolunuDogrula(url, kok: kok))
    }

    /// Ağaç dışından (ör. dosya paneli, sürükle-bırak) /private yazılışıyla gelen yol da kökün içidir.
    func testPrivateYazilisliYolKokIcindeSayilir() throws {
        try sayfaKur("Not")
        XCTAssertNoThrow(try notlarYolunuDogrula(URL(fileURLWithPath: "/private" + kok.path + "/Not/index.md"), kok: kok))
    }

    /// Ters yön: kök /private ile verilmiş, yol /private'sız.
    func testPrivateKokVePrivatesizYolEsdeger() throws {
        try sayfaKur("Not")
        let privateKok = URL(fileURLWithPath: "/private" + kok.path)
        XCTAssertNoThrow(try notlarYolunuDogrula(kok.appendingPathComponent("Not/index.md"), kok: privateKok))
    }

    func testCopKutusuCalisir() throws {
        try sayfaKur("Not")
        let cop = CopKutusu(kok: kok)
        let oge = try cop.sil(try dugum("Not"))

        let sonuc = try cop.ogeler()
        XCTAssertEqual(sonuc.ogeler.map(\.ad), ["Not"])
        XCTAssertTrue(sonuc.hatalar.isEmpty, "\(sonuc.hatalar)")

        let url = try cop.geriYukle(oge)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# Not\n")
    }

    func testTasimaCalisir() throws {
        try sayfaKur("A")
        try sayfaKur("B")
        let a = try XCTUnwrap(try dugum("A").icerikURL)
        let b = try dugum("B").klasorURL
        let yeni = try XCTUnwrap(try sayfaTasimaSonucu(a, hedefKlasor: b, kok: kok))
        XCTAssertTrue(fm.fileExists(atPath: yeni.path))
    }

    // MARK: Güvenlik sınırı korunmalı

    func testPrivateYazilistaUstDizinKacisiReddedilir() {
        let kacis = URL(fileURLWithPath: "/private" + kok.path + "/../disari.md")
        XCTAssertThrowsError(try notlarYolunuDogrula(kacis, kok: kok))
    }

    func testPrivateAltindakiBaskaKlasorReddedilir() {
        let komsu = URL(fileURLWithPath: "/private" + kok.deletingLastPathComponent().path + "/baska/not.md")
        XCTAssertThrowsError(try notlarYolunuDogrula(komsu, kok: kok))
    }

    /// Yalnızca sistemin /var, /tmp, /etc bağları eşdeğer sayılır; rastgele bir /private yolu değil.
    func testIlgisizPrivateYoluKokSayilmaz() {
        XCTAssertThrowsError(try notlarYolunuDogrula(URL(fileURLWithPath: "/private/etc/hosts"), kok: kok))
    }

    func testKokIcindekiSembolikBagHalaReddedilir() throws {
        let disari = kok.deletingLastPathComponent().appendingPathComponent("disari-\(UUID().uuidString)")
        try fm.createDirectory(at: disari, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: disari) }
        try fm.createSymbolicLink(at: kok.appendingPathComponent("bag"), withDestinationURL: disari)

        let privateYol = URL(fileURLWithPath: "/private" + kok.path + "/bag/not.md")
        XCTAssertThrowsError(try notlarYolunuDogrula(privateYol, kok: kok))
        XCTAssertThrowsError(try notlarYolunuDogrula(kok.appendingPathComponent("bag/not.md"), kok: kok))
    }
}
#endif
