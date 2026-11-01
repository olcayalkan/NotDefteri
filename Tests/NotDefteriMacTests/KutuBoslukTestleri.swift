import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Renkli kutu ve kod bloğu çevresindeki boşluk: az olmalı ve düzenlerken gördüğün,
/// uygulama kapatılıp açılınca gördüğünle aynı kalmalı.
final class KutuBoslukTestleri: XCTestCase {
    private func editor(_ md: String) -> NotMetinGorunumu {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        e.isRichText = true; e.isEditable = true; e.allowsUndo = true
        e.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        e.textStorage?.delegate = e
        e.sayfaYukleniyor = true
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        e.sayfaYukleniyor = false
        return e
    }

    private func stil(_ e: NotMetinGorunumu, _ metin: String) -> NSParagraphStyle? {
        let konum = (e.string as NSString).range(of: metin).location
        return e.textStorage?.attribute(.paragraphStyle, at: konum, effectiveRange: nil) as? NSParagraphStyle
    }

    /// Her paragrafın boşluk ve yüksekliği; düzenlenmiş ile yeniden açılmış karşılaştırılır.
    private func ozet(_ e: NotMetinGorunumu) -> [String] {
        let depo = e.textStorage!
        let ns = depo.string as NSString
        var sonuc: [String] = []
        var k = 0
        while k < ns.length {
            let p = ns.paragraphRange(for: NSRange(location: k, length: 0))
            let s = depo.attribute(.paragraphStyle, at: p.location, effectiveRange: nil) as? NSParagraphStyle
            sonuc.append("\(ns.substring(with: p)) \(s?.paragraphSpacingBefore ?? 0) \(s?.paragraphSpacing ?? 0) \(s?.maximumLineHeight ?? 0)")
            k = NSMaxRange(p)
        }
        return sonuc
    }

    private func yenidenAcilinca(_ e: NotMetinGorunumu) -> [String] { ozet(editor(markdownMetniUret(e.textStorage!))) }

    func testKutuAltiAzBosluk() {
        let e = editor("önce\n> [!💡 mavi] bir\nsonra\n")
        XCTAssertEqual(stil(e, "bir")?.paragraphSpacing, kKutuAltBoslugu)
        XCTAssertEqual(stil(e, "bir")?.paragraphSpacingBefore, kKutuDisBoslugu, "yazının hemen altındaki kutu ayrılır")
    }

    func testIkiKutuArasiBoslukAz() {
        let e = editor("> [!💡 mavi] bir\n\n> [!💡 sarı] iki\n> [!💡 yeşil] üç\n")
        XCTAssertEqual(stil(e, "iki")?.paragraphSpacingBefore, kKutuAltBoslugu, "üstte boş satır varsa ek boşluk yok")
        XCTAssertEqual(stil(e, "üç")?.paragraphSpacingBefore, kKutuAltBoslugu, "bitişik kutuda ek boşluk yok")
        let ns = e.string as NSString
        let bos = ns.paragraphRange(for: NSRange(location: NSMaxRange(ns.paragraphRange(for: NSRange(location: 0, length: 0))), length: 0))
        let bosStil = e.textStorage?.attribute(.paragraphStyle, at: bos.location, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(bosStil?.maximumLineHeight, kKutularArasiBosSatirYuksekligi)
    }

    /// Kutunun üstündeki boş satıra yazınca kutunun boşluğu hemen güncellenir (bayat kalmaz).
    func testKomsuSatirDegisinceBoslukGuncellenir() {
        let e = editor("önce\n\n> [!💡 mavi] bir\n")
        let bos = (e.string as NSString).range(of: "önce").location + 5
        e.setSelectedRange(NSRange(location: bos, length: 0))
        e.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(stil(e, "bir")?.paragraphSpacingBefore, kKutuDisBoslugu)
        XCTAssertEqual(ozet(e), yenidenAcilinca(e))
    }

    func testIkiKutuArasiSatiraYazincaNormalYukseklik() {
        let e = editor("> [!💡 mavi] bir\n\n> [!💡 sarı] iki\n")
        e.setSelectedRange(NSRange(location: (e.string as NSString).range(of: "bir").location + 4, length: 0))
        e.insertText("ara", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertNotEqual(stil(e, "ara")?.maximumLineHeight, kKutularArasiBosSatirYuksekligi)
        XCTAssertEqual(ozet(e), yenidenAcilinca(e))
        e.deleteBackward(nil); e.deleteBackward(nil); e.deleteBackward(nil)
        XCTAssertEqual(ozet(e), yenidenAcilinca(e))
    }

    private func yukseklik(_ e: NotMetinGorunumu) -> CGFloat {
        let yerlesim = e.layoutManager!, kap = e.textContainer!
        yerlesim.ensureLayout(for: kap)
        return yerlesim.usedRect(for: kap).height
    }

    /// Bitişik alıntı ve kutuya kayıt araya boş satır yazar; yeniden açınca araya boşluk girmez.
    func testBitisikAlintiVeKutuAcincaAyniGorunur() {
        for md in ["> düz alıntı\n> [!💡 mavi] bir\nsonra\n", "> [!💡 mavi] bir\n\n> düz alıntı\nsonra\n"] {
            let e = editor(md)
            let kayit = markdownMetniUret(e.textStorage!)
            let acilan = editor(kayit)
            XCTAssertEqual(markdownMetniUret(acilan.textStorage!), kayit, "dosya sabit kalır")
            XCTAssertEqual(yukseklik(e), yukseklik(acilan), accuracy: 1.5, md)
        }
    }

    func testKutuSilinceAraSatirNormaleDoner() {
        let e = editor("> [!💡 mavi] bir\n\n> [!💡 sarı] iki\n")
        let iki = (e.string as NSString).paragraphRange(for: NSRange(location: (e.string as NSString).range(of: "iki").location, length: 0))
        e.setSelectedRange(iki)
        e.deleteBackward(nil)
        XCTAssertEqual(ozet(e), yenidenAcilinca(e))
    }
}
