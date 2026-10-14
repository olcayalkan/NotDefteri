import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Tema, "/" blok menüsü ve ⌘P hızlı bulucu: pencere açmadan ölçülebilen davranışlar.
final class ArayuzBilesenleriTestleri: XCTestCase {

    // MARK: Tema

    func testTemaAdlariBenzersiz() {
        XCTAssertEqual(temaListesi.map(\.ad), ["Sepya", "Terminal", "Yeşilimsi Kağıt", "Gri Kağıt"])
        XCTAssertEqual(Set(temaListesi.map(\.ad)).count, temaListesi.count)
        XCTAssertEqual(temaListesi.count, kTemaSayisi)
    }

    /// #18: kağıt temaları main renklerine dayanır, hepsi aynı oranda koyulaşır; başlık ve
    /// panel editörden ayrışsın diye ek oranla koyulaşır.
    func testKagitTemalariMainRenklerindenAyniOrandaKoyulasir() throws {
        let main: [String: [(CGFloat, CGFloat, CGFloat)]] = [
            "Sepya": [(0.84, 0.81, 0.73), (0.78, 0.74, 0.65), (0.80, 0.77, 0.69)],
            "Yeşilimsi Kağıt": [(0.79, 0.83, 0.76), (0.72, 0.77, 0.70), (0.75, 0.80, 0.73)],
            "Gri Kağıt": [(0.80, 0.80, 0.80), (0.73, 0.73, 0.73), (0.76, 0.76, 0.76)]]
        XCTAssertLessThan(kTemaZeminParlakligi, 1)
        for tema in temaListesi where !tema.koyuMu {
            let beklenen = try XCTUnwrap(main[tema.ad], tema.ad)
            let zemin = CGFloat(kTemaZeminParlakligi), cerceve = zemin * CGFloat(kTemaCerceveParlakligi)
            for (renk, (r, g, b), oran) in zip3([tema.arkaplan, tema.baslikCubugu, tema.kenarPanel], beklenen,
                                                [zemin, cerceve, cerceve]) {
                let rgb = try XCTUnwrap(renk.usingColorSpace(.genericRGB))
                XCTAssertEqual(rgb.redComponent, r * oran, accuracy: 0.002, tema.ad)
                XCTAssertEqual(rgb.greenComponent, g * oran, accuracy: 0.002, tema.ad)
                XCTAssertEqual(rgb.blueComponent, b * oran, accuracy: 0.002, tema.ad)
            }
            let arka = try XCTUnwrap(tema.arkaplan.usingColorSpace(.genericRGB))
            let panel = try XCTUnwrap(tema.kenarPanel.usingColorSpace(.genericRGB))
            XCTAssertGreaterThan(arka.redComponent - panel.redComponent, beklenen[0].0 - beklenen[2].0 + 0.03, tema.ad)
        }
    }

    private func zip3<A, B, C>(_ a: [A], _ b: [B], _ c: [C]) -> [(A, B, C)] {
        zip(zip(a, b), c).map { ($0.0, $0.1, $1) }
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
            XCTAssertEqual(temaSimgeRengi(), kAcikTemaSimgeRengi)
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

    // MARK: Başlık çubuğu

    /// Sayfa adı, iki yandaki düğme sayısı farklı olsa da pencerenin tam ortasında durur.
    func testSayfaAdiBaslikCubugununOrtasinda() {
        _ = NSApplication.shared
        let cubuk = BaslikCubugu(frame: NSRect(x: 0, y: 0, width: 680, height: kBaslikYuksekligi))
        cubuk.notAdiEtiketi.stringValue = "Tablo Deneme"
        cubuk.layout()
        XCTAssertEqual(cubuk.notAdiEtiketi.frame.midX, cubuk.bounds.midX, accuracy: 0.5)
        XCTAssertEqual(cubuk.notAdiEtiketi.alignment, .center)
        XCTAssertGreaterThan(cubuk.notAdiEtiketi.frame.width, 200)
        let sayfalar = ["Üst", "Alt"].map { URL(fileURLWithPath: "/tmp/\($0)/index.md") }
        cubuk.sayfaYolunuGoster(sayfalar)
        cubuk.layout()
        let yol = cubuk.subviews.first { $0 is NSStackView && !$0.isHidden }
        XCTAssertEqual(yol?.frame.midX ?? 0, cubuk.bounds.midX, accuracy: 0.5)
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
