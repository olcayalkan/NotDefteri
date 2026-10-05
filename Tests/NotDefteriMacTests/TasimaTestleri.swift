import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Sayfaların sürükle-bırakla başka bir sayfanın altına taşınması.
/// Sayfanın her şeyi kendi klasöründe olduğu için taşıma tek `moveItem`;
/// asıl risk geçersiz hedefler (kendi altına taşıma) ve ad çakışmaları.
final class TasimaTestleri: XCTestCase {

    private var kok: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        kok = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tasima-\(UUID().uuidString)")
        try fm.createDirectory(at: kok, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: kok)
    }

    /// Yeni düzende sayfa kurar: <ust>/<ad>/index.md
    @discardableResult
    private func sayfaKur(_ ad: String, ust: URL? = nil, altSayfa: String? = nil, gorselli: Bool = false) throws -> URL {
        let klasor = (ust ?? kok).appendingPathComponent(ad)
        try fm.createDirectory(at: klasor, withIntermediateDirectories: true)
        try "# \(ad)\n".write(to: klasor.appendingPathComponent(kIcerikDosyaAdi), atomically: true, encoding: .utf8)
        if gorselli {
            let g = klasor.appendingPathComponent(kGorsellerKlasorAdi)
            try fm.createDirectory(at: g, withIntermediateDirectories: true)
            try Data([1, 2, 3]).write(to: g.appendingPathComponent("a.png"))
        }
        if let altSayfa {
            let ak = klasor.appendingPathComponent(altSayfa)
            try fm.createDirectory(at: ak, withIntermediateDirectories: true)
            try "# \(altSayfa)\n".write(to: ak.appendingPathComponent(kIcerikDosyaAdi), atomically: true, encoding: .utf8)
        }
        return klasor.appendingPathComponent(kIcerikDosyaAdi)
    }

    private func varMi(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }

    // MARK: Temel taşıma

    func testSayfaBaskaSayfaninAltinaTasinir() throws {
        let kaynak = try sayfaKur("Notlar")
        let hedef = try sayfaKur("Arşiv")

        let yeni = sayfayiTasi(kaynak, hedefKlasor: sayfaKlasoru(hedef))

        XCTAssertEqual(yeni, kok.appendingPathComponent("Arşiv/Notlar/index.md"))
        XCTAssertTrue(varMi(yeni!))
        XCTAssertFalse(varMi(kok.appendingPathComponent("Notlar")))
    }

    func testAltSayfalarVeGorsellerBirlikteGider() throws {
        let kaynak = try sayfaKur("SSRF", altSayfa: "Laboratuvar", gorselli: true)
        let hedef = try sayfaKur("Güvenlik")

        let yeni = try XCTUnwrap(sayfayiTasi(kaynak, hedefKlasor: sayfaKlasoru(hedef)))
        let yeniKlasor = sayfaKlasoru(yeni)

        XCTAssertTrue(varMi(yeniKlasor.appendingPathComponent("Laboratuvar/\(kIcerikDosyaAdi)")))
        XCTAssertTrue(varMi(yeniKlasor.appendingPathComponent("\(kGorsellerKlasorAdi)/a.png")))
    }

    func testKokeTasima() throws {
        let ust = try sayfaKur("Üst")
        let ic = try sayfaKur("İç", ust: sayfaKlasoru(ust))

        let yeni = try XCTUnwrap(sayfayiTasi(ic, hedefKlasor: kok))

        XCTAssertEqual(yeni, kok.appendingPathComponent("İç/index.md"))
        XCTAssertFalse(varMi(sayfaKlasoru(ust).appendingPathComponent("İç")))
    }

    // MARK: Geçersiz hedefler

    func testSayfaKendiAltinaTasinamaz() throws {
        let ust = try sayfaKur("Üst", altSayfa: "Alt")

        XCTAssertNil(sayfayiTasi(ust, hedefKlasor: sayfaKlasoru(ust)))
        XCTAssertNil(sayfayiTasi(ust, hedefKlasor: sayfaKlasoru(ust).appendingPathComponent("Alt")))
        XCTAssertTrue(varMi(ust), "Başarısız taşıma kaynağa dokunmamalı")
    }

    func testAyniKlasoreTasimaYokSayilir() throws {
        let sayfa = try sayfaKur("Sayfa")
        XCTAssertNil(sayfayiTasi(sayfa, hedefKlasor: kok))
        XCTAssertTrue(varMi(sayfa))
    }

    func testGecerlilikKuraliDogrudan() {
        let a = kok.appendingPathComponent("A")
        let b = kok.appendingPathComponent("B")
        XCTAssertTrue(tasimaGecerliMi(kaynakKlasor: a, hedefKlasor: b, mevcutUst: kok))
        XCTAssertFalse(tasimaGecerliMi(kaynakKlasor: a, hedefKlasor: a, mevcutUst: kok))
        XCTAssertFalse(tasimaGecerliMi(kaynakKlasor: a, hedefKlasor: a.appendingPathComponent("C"), mevcutUst: kok))
        XCTAssertFalse(tasimaGecerliMi(kaynakKlasor: a, hedefKlasor: kok, mevcutUst: kok))
    }

    // MARK: Ad çakışması

    func testAdCakismasindaSayacEklenir() throws {
        let hedef = try sayfaKur("Hedef")
        try sayfaKur("Aynı", ust: sayfaKlasoru(hedef))
        let kaynak = try sayfaKur("Aynı")

        let yeni = try XCTUnwrap(sayfayiTasi(kaynak, hedefKlasor: sayfaKlasoru(hedef)))

        XCTAssertEqual(sayfaAdi(yeni), "Aynı (2)")
        XCTAssertTrue(varMi(sayfaKlasoru(hedef).appendingPathComponent("Aynı/\(kIcerikDosyaAdi)")),
                      "Var olan sayfa üzerine yazılmamalı")
    }

    // MARK: Eski düzen (Ad.md)

    func testEskiDuzenNotDosyaVeKlasoruyleTasinir() throws {
        let notURL = kok.appendingPathComponent("Eski.md")
        try "# Eski\n".write(to: notURL, atomically: true, encoding: .utf8)
        let dalKlasoru = kok.appendingPathComponent("Eski")
        try fm.createDirectory(at: dalKlasoru, withIntermediateDirectories: true)
        try Data([1]).write(to: dalKlasoru.appendingPathComponent("g.png"))
        let hedef = try sayfaKur("Hedef")

        let yeni = try XCTUnwrap(sayfayiTasi(notURL, hedefKlasor: sayfaKlasoru(hedef)))

        XCTAssertEqual(yeni, sayfaKlasoru(hedef).appendingPathComponent("Eski.md"))
        XCTAssertTrue(varMi(sayfaKlasoru(hedef).appendingPathComponent("Eski/g.png")))
        XCTAssertFalse(varMi(notURL))
        XCTAssertFalse(varMi(dalKlasoru))
    }

    func testEskiDuzenAdCakismasi() throws {
        let hedef = try sayfaKur("Hedef")
        let mevcut = sayfaKlasoru(hedef).appendingPathComponent("Eski.md")
        try "# var olan\n".write(to: mevcut, atomically: true, encoding: .utf8)

        let notURL = kok.appendingPathComponent("Eski.md")
        try "# gelen\n".write(to: notURL, atomically: true, encoding: .utf8)

        let yeni = try XCTUnwrap(sayfayiTasi(notURL, hedefKlasor: sayfaKlasoru(hedef)))

        XCTAssertEqual(yeni.lastPathComponent, "Eski (2).md")
        XCTAssertEqual(try String(contentsOf: mevcut, encoding: .utf8), "# var olan\n")
    }

    // MARK: Kapsayıcı klasör

    func testKapsayiciKlasorTasinir() throws {
        let kapsayici = kok.appendingPathComponent("Konular")
        try fm.createDirectory(at: kapsayici, withIntermediateDirectories: true)
        try sayfaKur("İçerdeki", ust: kapsayici)
        let hedef = try sayfaKur("Hedef")

        let yeni = try XCTUnwrap(klasoruTasi(kapsayici, hedefKlasor: sayfaKlasoru(hedef)))

        XCTAssertEqual(yeni, sayfaKlasoru(hedef).appendingPathComponent("Konular"))
        XCTAssertTrue(varMi(yeni.appendingPathComponent("İçerdeki/\(kIcerikDosyaAdi)")))
        XCTAssertFalse(varMi(kapsayici))
    }

    func testKlasorKendiAltinaTasinamaz() throws {
        let kapsayici = kok.appendingPathComponent("Konular/Alt")
        try fm.createDirectory(at: kapsayici, withIntermediateDirectories: true)
        let ust = kok.appendingPathComponent("Konular")

        XCTAssertNil(klasoruTasi(ust, hedefKlasor: kapsayici))
        XCTAssertTrue(varMi(kapsayici))
    }

    // MARK: Ağaç taşımadan sonra doğru kuruluyor mu

    func testTasimaSonrasiAgacDogru() throws {
        let kaynak = try sayfaKur("Gezen", altSayfa: "Yavru")
        let hedef = try sayfaKur("Ev")

        sayfayiTasi(kaynak, hedefKlasor: sayfaKlasoru(hedef))
        let agac = agaciYukle(kok)

        XCTAssertEqual(agac.count, 1)
        let ev = try XCTUnwrap(agac.first)
        XCTAssertEqual(ev.ad, "Ev")
        XCTAssertEqual(ev.cocuklar.map(\.ad), ["Gezen"])
        XCTAssertEqual(ev.cocuklar.first?.cocuklar.map(\.ad), ["Yavru"])
    }
}
