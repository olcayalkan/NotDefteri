import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Dışarıdan yapıştırılan içeriğin notun yazım biçimine uydurulması.
final class YapistirmaTestleri: XCTestCase {

    // MARK: Yardımcılar

    private func yabanciMetin(_ metin: String, punto: CGFloat, kalin: Bool = false,
                              renk: NSColor = .systemBlue) -> NSAttributedString {
        var font = NSFont(name: "Times New Roman", size: punto) ?? NSFont.systemFont(ofSize: punto)
        if kalin { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
        return NSAttributedString(string: metin, attributes: [
            .font: font,
            .foregroundColor: renk,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .backgroundColor: NSColor.yellow
        ])
    }

    private func oznitelik(_ attr: NSAttributedString, _ anahtar: NSAttributedString.Key, _ konum: Int) -> Any? {
        attr.attribute(anahtar, at: konum, effectiveRange: nil)
    }

    /// Editördeki zengin yapıştırma yolunun aynısı: font önce adaptörde anlamsala indirgenir.
    private func yapistir(_ gelen: NSAttributedString) -> NSAttributedString {
        disIcerigiNotBicimineCevir(MacBelgeAdaptoru.disIcerigiAnlamsalaCevir(gelen))
    }

    /// Çekirdek yalnızca anlamsal öznitelik üretir; font ve renk editördeki gibi adaptörde uygulanır.
    private func gorunumlu(_ anlamsal: NSAttributedString) -> NSAttributedString {
        MacBelgeAdaptoru().gorunumluBelge(anlamsal)
    }

    // MARK: Gövde metni

    func testYabanciFontVeRenkVarsayilanaDoner() {
        let sonuc = yapistir(yabanciMetin("Merhaba dünya", punto: 19))

        let font = oznitelik(gorunumlu(sonuc), .font, 0) as? NSFont
        XCTAssertEqual(font?.pointSize, kTabanPunto)
        XCTAssertEqual(font?.fontName, varsayilanFont().fontName)
        XCTAssertEqual(oznitelik(gorunumlu(sonuc), .foregroundColor, 0) as? NSColor, kMetinRenk)
        XCTAssertNil(oznitelik(gorunumlu(sonuc), .underlineStyle, 0))
        XCTAssertNil(oznitelik(gorunumlu(sonuc), .backgroundColor, 0))
    }

    func testKalinlikKorunur() {
        let gelen = NSMutableAttributedString(attributedString: yabanciMetin("düz ", punto: 12))
        gelen.append(yabanciMetin("vurgulu", punto: 12, kalin: true))
        let sonuc = yapistir(gelen)

        XCTAssertFalse(kalinMi((oznitelik(gorunumlu(sonuc), .font, 0) as? NSFont)!))
        XCTAssertTrue(kalinMi((oznitelik(gorunumlu(sonuc), .font, 5) as? NSFont)!))
        XCTAssertEqual((oznitelik(gorunumlu(sonuc), .font, 5) as? NSFont)?.pointSize, kTabanPunto)
    }

    // MARK: Başlıklar

    func testIriKisaParagrafBasligaDonusur() {
        let gelen = NSMutableAttributedString(attributedString: yabanciMetin("Bölüm Başlığı\n", punto: 24))
        // Gövde: başlıktan uzun olmalı ki baskın punto o olsun.
        gelen.append(yabanciMetin("Bu paragraf gövde metnidir ve normal puntoyla yazılmıştır.", punto: 12))
        let sonuc = yapistir(gelen)

        XCTAssertEqual(oznitelik(sonuc, kBaslikSeviyesiAnahtari, 0) as? Int, 1)
        XCTAssertEqual((oznitelik(gorunumlu(sonuc), .font, 0) as? NSFont)?.pointSize, baslikFontu(1).pointSize)
        // Gövde başlık olmamalı.
        XCTAssertNil(oznitelik(sonuc, kBaslikSeviyesiAnahtari, sonuc.length - 1))
    }

    func testUzunIriParagrafBaslikSayilmaz() {
        let uzun = String(repeating: "uzun cümle ", count: 20)
        let gelen = NSMutableAttributedString(attributedString: yabanciMetin(uzun + "\n", punto: 24))
        gelen.append(yabanciMetin("kısa gövde", punto: 12))
        let sonuc = yapistir(gelen)

        XCTAssertNil(oznitelik(sonuc, kBaslikSeviyesiAnahtari, 0))
    }

    func testGovdePuntosuBuyukOlsaBileBaslikOranaGoreBulunur() {
        // Gövdesi 18 punto olan bir web sayfası: mutlak punto değil oran belirler.
        // 26/18 = 1.44 -> ikinci düzey başlık; 18 puntolu gövde başlık değil.
        let gelen = NSMutableAttributedString(attributedString: yabanciMetin("Ana Başlık\n", punto: 26))
        gelen.append(yabanciMetin("Gövde metni burada ve epey uzun sürüyor.", punto: 18))
        let sonuc = yapistir(gelen)

        XCTAssertEqual(oznitelik(sonuc, kBaslikSeviyesiAnahtari, 0) as? Int, 2)
        XCTAssertNil(oznitelik(sonuc, kBaslikSeviyesiAnahtari, sonuc.length - 1))
    }

    // MARK: Sadeleştirme

    func testYabanciBosluklarSadelesir() {
        let sonuc = yapistirmaMetniniSadelestir("bir\u{00A0}iki\r\nüç\u{200B}dört   \nbeş")
        XCTAssertEqual(sonuc, "bir iki\nüçdört\nbeş")
    }

    func testListeMaddeImleriSadelesir() {
        XCTAssertEqual(yapistirmaMetniniSadelestir("\t\u{2022}\tbirinci\n  \u{00B7}  ikinci"),
                       "• birinci\n• ikinci")
    }

    func testSadelestirmeZenginMetindeDeCalisir() {
        let sonuc = yapistir(yabanciMetin("bir\u{00A0}iki\r\nüç", punto: 13))
        XCTAssertEqual(sonuc.string, "bir iki\nüç")
    }

    // MARK: Düz metin

    func testDuzMetinMarkdownOlarakYorumlanir() {
        let sonuc = disMetniNotBicimineCevir("# Başlık\nnormal **kalın** metin")

        XCTAssertEqual(oznitelik(sonuc, kBaslikSeviyesiAnahtari, 0) as? Int, 1)
        XCTAssertFalse(sonuc.string.contains("#"))
        XCTAssertFalse(sonuc.string.contains("**"))
        let kalinKonum = (sonuc.string as NSString).range(of: "kalın").location
        XCTAssertTrue(kalinMi((oznitelik(gorunumlu(sonuc), .font, kalinKonum) as? NSFont)!))
    }

    func testDuzMetinVarsayilanFontlaGelir() {
        let sonuc = disMetniNotBicimineCevir("sıradan bir satır")
        XCTAssertEqual((oznitelik(gorunumlu(sonuc), .font, 0) as? NSFont)?.pointSize, kTabanPunto)
        XCTAssertEqual(oznitelik(gorunumlu(sonuc), .foregroundColor, 0) as? NSColor, kMetinRenk)
    }

    func testBosIcerikBosDoner() {
        XCTAssertEqual(yapistir(NSAttributedString(string: "")).length, 0)
        XCTAssertEqual(disMetniNotBicimineCevir("").length, 0)
    }

    // MARK: Kayda dönüş

    /// Uydurulan içerik notun kendi Markdown'ına eksiksiz yazılabilmeli.
    func testUydurulanIcerikMarkdownaYazilabilir() {
        let gelen = NSMutableAttributedString(attributedString: yabanciMetin("Başlık\n", punto: 28))
        gelen.append(yabanciMetin("düz ", punto: 12))
        gelen.append(yabanciMetin("kalın", punto: 12, kalin: true))
        let markdown = markdownMetniUret(yapistir(gelen))

        XCTAssertEqual(markdown, "# Başlık\ndüz **kalın**")
    }
}
