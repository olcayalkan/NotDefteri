import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// İçindekiler panelinin başlık çıkarımı. Panelin kendisi arayüz ama
/// başlıkları toplama mantığı metin deposundan okunuyor — test edilebilir.
final class IcindekilerTestleri: XCTestCase {

    /// Markdown metninden panel girdilerini üretir (uygulamadaki akışın aynısı).
    private func girdiler(_ markdown: String) -> [IcindekilerPaneli.Girdi] {
        let panel = IcindekilerPaneli(frame: .zero)
        let depo = NSTextStorage(attributedString: markdowndenAttributedStringUret(markdown))
        panel.icerigiGuncelle(depo)
        return panel.girdiler
    }

    func testBasliksizMetinBosGirdiVerir() {
        XCTAssertTrue(girdiler("sadece düz metin\nikinci satır\n").isEmpty)
        XCTAssertTrue(girdiler("").isEmpty)
    }

    func testUcSeviyeBaslikYakalanir() {
        let g = girdiler("# Birinci\nmetin\n## İkinci\n### Üçüncü\n")
        XCTAssertEqual(g.count, 3)
        XCTAssertEqual(g.map(\.metin), ["Birinci", "İkinci", "Üçüncü"])
        XCTAssertEqual(g.map(\.seviye), [1, 2, 3])
    }

    func testBasliklarSiradaGelir() {
        let g = girdiler("# A\n\n## B\n\n# C\n")
        XCTAssertEqual(g.map(\.metin), ["A", "B", "C"])
        // Konumlar artan sırada olmalı; panel bunu vurgulama için kullanıyor.
        XCTAssertEqual(g.map(\.konum), g.map(\.konum).sorted())
    }

    func testAyniBaslikTekrarEtmez() {
        // Aynı öznitelik aralığı birden çok paragrafa yayılabilir; her başlık bir kez gelmeli.
        let g = girdiler("# Tek\n")
        XCTAssertEqual(g.count, 1, "tek başlık bir girdi vermeli, üretilen: \(g.map(\.metin))")
    }

    func testTurkceKarakterlerKorunur() {
        let g = girdiler("# Şifreleme Ağı\n## Güvenlik Açığı\n")
        XCTAssertEqual(g.map(\.metin), ["Şifreleme Ağı", "Güvenlik Açığı"])
    }

    func testDuzMetinBasliklaKarismaz() {
        let g = girdiler("düz\n# Başlık\ndüz devam\n#### dört değil\n")
        XCTAssertEqual(g.map(\.metin), ["Başlık"], "yalnızca 1-3 seviye başlık girdisi olmalı")
    }

    func testBosBaslikAtlanir() {
        let g = girdiler("# \nmetin\n")
        XCTAssertTrue(g.allSatisfy { !$0.metin.isEmpty }, "boş başlık girdi üretmemeli")
    }

    /// Konumlar metin içinde geçerli olmalı — tıklayınca oraya kaydırılıyor.
    func testKonumlarMetinIcindeGecerli() {
        let markdown = "# Bir\nmetin\n## İki\nbaşka metin\n"
        let uzunluk = markdowndenAttributedStringUret(markdown).length
        for g in girdiler(markdown) {
            XCTAssertLessThan(g.konum, uzunluk, "konum metin sınırları içinde olmalı")
            XCTAssertGreaterThanOrEqual(g.konum, 0)
        }
    }
}
