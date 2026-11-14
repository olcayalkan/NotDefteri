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

    /// Kutunun içinden alınan parça boş yere taralı (kod) olarak değil düz yazı olarak yapışır.
    func testKoddanParcaDuzYaziOlur() {
        XCTAssertEqual(kopyalaYapistir(kod, secim: "a = 1", hedef: "sonra"),
                       "önce\n```swift\nlet a = 1\nlet b = 2\n```\nsonraa = 1\n")
    }

    /// Kod parçası Markdown sayılmaz: `**` yapıştırılınca kalına çevrilmez, yazıldığı gibi kalır.
    func testKoddanParcaIsaretleriBicimeCevrilmez() {
        let e = editor("önce\n```\na **b** c\n```\nsonra\n")
        e.setSelectedRange((e.string as NSString).range(of: "**b**"))
        NSPasteboard.general.clearContents()
        e.copy(nil)
        e.setSelectedRange(NSRange(location: NSMaxRange((e.string as NSString).range(of: "sonra")), length: 0))
        e.paste(nil)
        XCTAssertTrue(e.string.contains("sonra**b**"))
        XCTAssertNil(e.textStorage!.attribute(kKalinAnahtari, at: (e.string as NSString).range(of: "sonra").location + 7, effectiveRange: nil))
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

    /// Kutunun içinden çok satır seçilince de satırlar düz yazı olur; kutu kod bloğuyla aynı.
    func testKutuIcindenCokSatirDuzYapisir() {
        XCTAssertEqual(kopyalaYapistir(kutu, secim: "iki\n\u{200B}üç", hedef: "sonra"),
                       "önce\n> [!💡 mavi] bir iki\n> üç dört\nsonraiki\nüç\n")
        XCTAssertEqual(kopyalaYapistir(kod, secim: "let a = 1\nlet b", hedef: "sonra"),
                       "önce\n```swift\nlet a = 1\nlet b = 2\n```\nsonralet a = 1\nlet b\n")
    }

    /// Kutunun tamamı seçilince kutusuyla taşınır; satır sonuna yapışınca altında boş satır kalmaz.
    func testTumKodBloguSatirSonunaBosSatirsizYapisir() {
        let e = editor(kod)
        let ns = e.string as NSString
        let bas = ns.range(of: "let a").location - 1
        e.setSelectedRange(NSRange(location: bas, length: NSMaxRange(ns.range(of: "b = 2")) + 1 - bas))
        NSPasteboard.general.clearContents()
        e.copy(nil)
        e.setSelectedRange(NSRange(location: NSMaxRange((e.string as NSString).range(of: "sonra")), length: 0))
        e.paste(nil)
        XCTAssertEqual(markdownMetniUret(e.textStorage!),
                       "önce\n```swift\nlet a = 1\nlet b = 2\n```\nsonra\n```swift\nlet a = 1\nlet b = 2\n```\n")
    }
}
