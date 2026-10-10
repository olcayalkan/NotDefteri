import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Tema, "/" blok menüsü ve ⌘P hızlı bulucu: pencere açmadan ölçülebilen davranışlar.
final class ArayuzBilesenleriTestleri: XCTestCase {

    // MARK: Tema

    func testTemaAdlariBenzersiz() {
        XCTAssertEqual(temaListesi.map(\.ad), ["Sepya", "Terminal", "Yeşilimsi Kağıt", "Gri Kağıt", "Krem"])
        XCTAssertEqual(Set(temaListesi.map(\.ad)).count, temaListesi.count)
    }

    /// Bozuk kayıtlı indeks uygulamayı çökertmemeli, ilk temaya dönmeli.
    func testGecersizTemaIndeksiIlkTemayaDoner() {
        let onceki = gTemaIndex
        defer { gTemaIndex = onceki }
        gTemaIndex = 99
        XCTAssertEqual(aktifTema.ad, temaListesi[0].ad)
        XCTAssertEqual(gTemaIndex, 0)
    }

    func testKoyulastirmaSifirdaKirpilirVeSaydamligiKorur() throws {
        let renk = NSColor(calibratedRed: 0.1, green: 0.5, blue: 0.9, alpha: 0.4).koyulastir(0.2)
        let rgb = try XCTUnwrap(renk.usingColorSpace(.genericRGB))
        XCTAssertEqual(rgb.redComponent, 0, accuracy: 0.001)
        XCTAssertEqual(rgb.greenComponent, 0.3, accuracy: 0.01)
        XCTAssertEqual(rgb.alphaComponent, 0.4, accuracy: 0.001)
    }

    func testAcikTemalarMainVurguVeSimgeRenkleriniKorur() throws {
        let onceki = gTemaIndex
        defer { gTemaIndex = onceki }
        for (index, tema) in temaListesi.enumerated() where !tema.koyuMu {
            gTemaIndex = index
            XCTAssertEqual(aramaKutuRengi(), tema.kenarPanel.koyulastir(0.07))
            XCTAssertEqual(secimVurguRengi(), tema.kenarPanel.koyulastir(0.14))
            XCTAssertEqual(aramaOdakRengi(), tema.kenarPanel.koyulastir(0.16))
            XCTAssertEqual(temaSimgeRengi(), NSColor.darkGray)
        }
    }

    func testKoyuTemaTonFarkiBirdeKirpilirVeSaydamligiKorur() throws {
        let renk = NSColor(calibratedRed: 0.1, green: 0.5, blue: 0.9, alpha: 0.4)
            .tonFarki(0.2, koyuTema: true)
        let rgb = try XCTUnwrap(renk.usingColorSpace(.genericRGB))
        XCTAssertEqual(rgb.redComponent, 0.3, accuracy: 0.01)
        XCTAssertEqual(rgb.greenComponent, 0.7, accuracy: 0.01)
        XCTAssertEqual(rgb.blueComponent, 1, accuracy: 0.001)
        XCTAssertEqual(rgb.alphaComponent, 0.4, accuracy: 0.001)
    }

    func testVurguRenkleriHerTemadaPaneldenAyristirilir() throws {
        let onceki = gTemaIndex
        defer { gTemaIndex = onceki }
        for (index, tema) in temaListesi.enumerated() {
            gTemaIndex = index
            let panel = try XCTUnwrap(tema.kenarPanel.usingColorSpace(.genericRGB)).redComponent
            for renk in [aramaKutuRengi(), secimVurguRengi(), aramaOdakRengi()] {
                let bilesen = try XCTUnwrap(renk.usingColorSpace(.genericRGB)).redComponent
                if tema.koyuMu {
                    XCTAssertGreaterThan(bilesen, panel, tema.ad)
                } else {
                    XCTAssertLessThan(bilesen, panel, tema.ad)
                }
            }
        }
    }

    // MARK: Blok menüsü ("/")

    private func menuSecenekleri(_ sorgu: String) -> [String]? {
        let menu = BlokMenusu()
        guard menu.filtrele(sorgu) else { return nil }
        return menu.subviews.compactMap { ($0 as? NSButton)?.title }
    }

    func testBosSorguTumKomutlariGosterir() {
        XCTAssertEqual(menuSecenekleri("")?.count, BlokMenusu.Komut.allCases.count)
    }

    func testTurkceDuyarsizFiltre() {
        XCTAssertEqual(menuSecenekleri("baslik"), ["Başlık 1", "Başlık 2", "Başlık 3"])
        XCTAssertEqual(menuSecenekleri("UYARI: KIRMIZI"), ["Uyarı: Kırmızı"])
    }

    func testKisayolOnekleri() {
        XCTAssertEqual(menuSecenekleri("b2"), ["Başlık 2"])
        XCTAssertEqual(menuSecenekleri("kod"), ["Kod bloğu"])
        XCTAssertEqual(menuSecenekleri("pa"), ["Alt sayfa"])
    }

    func testEslesmeYoksaMenuKapanir() {
        XCTAssertNil(menuSecenekleri("zzz"))
    }

    func testMenuGezinmesiSecimiDolastirir() {
        let menu = BlokMenusu()
        XCTAssertTrue(menu.filtrele("baslik"))
        var secilen: BlokMenusu.Komut?
        menu.secildi = { secilen = $0 }
        menu.gezin(-1)   // baştan geri: sona sarar
        menu.sec()
        XCTAssertEqual(secilen, .baslik3)
    }

    // MARK: Hızlı bulucu (⌘P)

    private func bulucu(_ sayfalar: [String]) -> HizliBulucu {
        let kok = URL(fileURLWithPath: NSTemporaryDirectory())
        let indeks = SayfaBaglantilari()
        indeks.guncelle(sayfalar.map { SayfaSecenegi(url: kok.appendingPathComponent("\($0)/index.md")) })
        let b = HizliBulucu()
        b.ara = indeks.ara
        return b
    }

    func testBulucuSonuclariListeler() {
        let b = bulucu(["Proje", "Proje Planı", "Alışveriş"])
        b.filtrele("proje")
        let etiketler = b.alttakiDugmeler.map(\.attributedTitle.string)
        XCTAssertEqual(etiketler.count, 2)
        XCTAssertTrue(etiketler[0].contains("Proje\n"))
    }

    func testBulucuGezinipSecer() {
        let b = bulucu(["Proje", "Proje Planı"])
        var secilen: SayfaSecenegi?
        b.secildi = { secilen = $0 }
        b.filtrele("proje")
        b.gezin(1)
        b.sec()
        XCTAssertEqual(secilen?.ad, "Proje Planı")
    }

    func testSonucYoksaSecimYapilmaz() {
        let b = bulucu(["Proje"])
        var secildi = false
        b.secildi = { _ in secildi = true }
        b.filtrele("xyz")
        b.sec()
        XCTAssertFalse(secildi)
        XCTAssertTrue(b.alttakiDugmeler.isEmpty)
    }
}

private extension NSView {
    /// Bulucunun liste düğmeleri iç içe görünümlerde durur.
    var alttakiDugmeler: [NSButton] {
        subviews.flatMap { ($0 as? NSButton).map { [$0] } ?? $0.alttakiDugmeler }
    }
}
