import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Kod, uyarı kutusu ve diğer bloklardan kopyalanan parçanın yapıştırıldığı yerin yapısını bozmaması.
final class BlokParcasiKopyalamaTestleri: XCTestCase {
    private func editor(_ md: String) -> NotMetinGorunumu {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        e.isRichText = true; e.isEditable = true; e.allowsUndo = true
        e.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        e.textStorage?.delegate = e
        e.icerikEklenecek = { md, taban in MacBelgeAdaptoru.markdownuAc(md, taban: taban ?? notlarKlasoru()) }
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        return e
    }

    /// Görünen metinde `secim`i kopyalar, son `hedef` geçişinin hemen arkasına yapıştırır.
    private func kopyalaYapistir(_ kaynak: String, secim: String, hedef: String) -> String {
        let e = editor(kaynak)
        let s = (e.string as NSString).range(of: secim)
        XCTAssertNotEqual(s.location, NSNotFound, "seçim bulunamadı: \(e.string.debugDescription)")
        e.setSelectedRange(s)
        NSPasteboard.general.clearContents()
        e.copy(nil)
        let h = (e.string as NSString).range(of: hedef, options: .backwards)
        e.setSelectedRange(NSRange(location: NSMaxRange(h), length: 0))
        e.paste(nil)
        return markdownMetniUret(e.textStorage!)
    }

    private let kod = "önce\n```swift\nlet a = 1\nlet b = 2\n```\nsonra\n"
    private let kutu = "önce\n> [!💡 mavi] bir iki\n> üç dört\nsonra\n"

    func testKoddanParcaSatirIciKodOlur() {
        XCTAssertEqual(kopyalaYapistir(kod, secim: "a = 1", hedef: "sonra"),
                       "önce\n```swift\nlet a = 1\nlet b = 2\n```\nsonra`a = 1`\n")
    }

    /// Kod parçası düz metne dönseydi `**` yapıştırılınca kalına çevrilirdi.
    func testKoddanParcaIsaretleriBicimeCevrilmez() {
        XCTAssertEqual(kopyalaYapistir("önce\n```\na **b** c\n```\nsonra\n", secim: "**b**", hedef: "sonra"),
                       "önce\n```\na **b** c\n```\nsonra`**b**`\n")
    }

    func testKoddanParcaKodIcineDuzYapisir() {
        XCTAssertEqual(kopyalaYapistir(kod, secim: "a = 1", hedef: "b = 2"),
                       "önce\n```swift\nlet a = 1\nlet b = 2a = 1\n```\nsonra\n")
    }

    func testKutudanParcaSatiriBolmez() {
        XCTAssertEqual(kopyalaYapistir(kutu, secim: "iki", hedef: "sonra"),
                       "önce\n> [!💡 mavi] bir iki\n> üç dört\nsonraiki\n")
    }

    func testKutuDevamSatirindanParcaAlintiOlmaz() {
        XCTAssertEqual(kopyalaYapistir(kutu, secim: "üç dört", hedef: "sonra"),
                       "önce\n> [!💡 mavi] bir iki\n> üç dört\nsonraüç dört\n")
    }

    func testKutudanParcaKutuIcineYapisir() {
        XCTAssertEqual(kopyalaYapistir(kutu, secim: "iki", hedef: "dört"),
                       "önce\n> [!💡 mavi] bir iki\n> üç dörtiki\nsonra\n")
    }

    func testAlintiMaddeVeBasliktanParcaDuzYapisir() {
        XCTAssertEqual(kopyalaYapistir("önce\n> alıntı satırı\nsonra\n", secim: "satırı", hedef: "sonra"),
                       "önce\n> alıntı satırı\nsonrasatırı\n")
        XCTAssertEqual(kopyalaYapistir("önce\n- madde yazı\nsonra\n", secim: "yazı", hedef: "sonra"),
                       "önce\n- madde yazı\nsonrayazı\n")
        XCTAssertEqual(kopyalaYapistir("# Büyük başlık\nsonra\n", secim: "başlık", hedef: "sonra"),
                       "# Büyük başlık\nsonrabaşlık\n")
    }

    /// Satır içi biçimler parçayla birlikte gider.
    func testSatirIciBicimKorunur() {
        XCTAssertEqual(kopyalaYapistir("önce\n> [!💡 mavi] bir **kalın** iki\nsonra\n", secim: "r kal", hedef: "sonra"),
                       "önce\n> [!💡 mavi] bir **kalın** iki\nsonrar **kal**\n")
    }

    /// Birden çok satır seçilince blok taşınır.
    func testCokSatirliSecimBloguTasir() {
        XCTAssertEqual(kopyalaYapistir(kutu, secim: "iki\n\u{200B}üç", hedef: "sonra"),
                       "önce\n> [!💡 mavi] bir iki\n> üç dört\nsonra\n> [!💡 mavi] iki\n> üç\n")
    }

    /// Satır sonuna yapıştırılan kod bloğunun altında boş satır kalmaz.
    func testKodBloguSatirSonunaBosSatirsizYapisir() {
        XCTAssertEqual(kopyalaYapistir(kod, secim: "let a = 1\n", hedef: "sonra"),
                       "önce\n```swift\nlet a = 1\nlet b = 2\n```\nsonra\n```swift\nlet a = 1\n```\n")
        XCTAssertEqual(kopyalaYapistir(kod, secim: "let a = 1\nlet b", hedef: "sonra"),
                       "önce\n```swift\nlet a = 1\nlet b = 2\n```\nsonra\n```swift\nlet a = 1\nlet b\n```\n")
    }
}
