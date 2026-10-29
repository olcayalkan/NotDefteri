import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Kod bloğunun üstündeki yazı silinince blok üstteki metne ve alttaki satırlara karışıyordu.
final class KodBloguUstuSilmeTestleri: XCTestCase {

    private let sayfa = "ilk satır\nsilinecek yazı\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n"

    private func editor(_ md: String) -> NotMetinGorunumu {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        e.isRichText = true; e.isEditable = true; e.allowsUndo = true
        e.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        e.textStorage?.delegate = e
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        return e
    }

    private func md(_ e: NotMetinGorunumu) -> String { markdownMetniUret(e.textStorage!) }

    private func satir(_ e: NotMetinGorunumu, _ metin: String) -> NSRange {
        let ns = e.string as NSString
        return ns.paragraphRange(for: ns.range(of: metin))
    }

    /// Üç tıklamanın seçtiği gibi: satır, satır sonuyla birlikte seçilip silinir.
    func testSatirSatirSonuylaSilinince() {
        let e = editor(sayfa)
        e.setSelectedRange(satir(e, "silinecek yazı"))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
    }

    func testSatirinYazisiSilinipBosSatirKalinca() {
        let e = editor(sayfa)
        let r = satir(e, "silinecek yazı")
        e.setSelectedRange(NSRange(location: r.location, length: r.length - 1))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\n\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
    }

    /// Seçim üstteki birden çok satırı kaplayınca.
    func testUstteBirdenCokSatirSilinince() {
        let e = editor(sayfa)
        e.setSelectedRange(NSUnionRange(satir(e, "ilk satır"), satir(e, "silinecek yazı")))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
    }

    func testKodunIlkSatiriSecilipSilinince() {
        let e = editor(sayfa)
        e.setSelectedRange(satir(e, "let a = 1"))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\nsilinecek yazı\n```swift\nprint(a)\n```\nalt satır\n")
    }

    /// Seçim üstteki yazıdan kodun içine taşınca.
    func testSecimUsttenKodunIcineTasinca() {
        let e = editor(sayfa)
        let ust = satir(e, "silinecek yazı")
        let kod = (e.string as NSString).range(of: "let a")
        e.setSelectedRange(NSRange(location: ust.location, length: NSMaxRange(kod) - ust.location))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\n```swift\n = 1\nprint(a)\n```\nalt satır\n")
    }

    /// Kodun başında geri silme kodu üstteki satıra yapıştırmaz.
    func testKodunBasindaGeriSilme() {
        let e = editor(sayfa)
        e.setSelectedRange(NSRange(location: (e.string as NSString).range(of: "let a").location, length: 0))
        e.deleteBackward(nil)
        let sonuc = md(e)
        XCTAssertTrue(sonuc.contains("```swift\nlet a = 1\nprint(a)\n```\nalt satır\n"), sonuc)
    }

    private func satirSonu(_ e: NotMetinGorunumu, _ metin: String) {
        let r = (e.string as NSString).range(of: metin)
        e.setSelectedRange(NSRange(location: NSMaxRange(r), length: 0))
    }

    /// ⌥⌫ ile kelime kelime, sonra ⌫ ile boş satır silinir.
    func testKelimeKelimeSilinince() {
        let e = editor(sayfa)
        satirSonu(e, "silinecek yazı")
        e.deleteWordBackward(nil)
        e.deleteWordBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\n\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
    }

    /// ⌘⌫ satırın başına kadar siler.
    func testSatirBasinaKadarSilinince() {
        let e = editor(sayfa)
        satirSonu(e, "silinecek yazı")
        e.deleteToBeginningOfLine(nil)
        XCTAssertEqual(md(e), "ilk satır\n\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
    }

    /// Yazı ile kod arasında boş satır varken üstteki yazı silinir.
    func testArayaBosSatirliYaziSilinince() {
        let e = editor("ilk satır\nsilinecek yazı\n\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
        e.setSelectedRange(satir(e, "silinecek yazı"))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ilk satır\n\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
        e.deleteBackward(nil)
        e.deleteBackward(nil)
        let sonuc = md(e)
        XCTAssertTrue(sonuc.hasSuffix("```swift\nlet a = 1\nprint(a)\n```\nalt satır\n"), sonuc)
    }

    /// Kod bloğunun hemen üstündeki tek yazı satırı (sayfanın başında) silinir.
    func testSayfaBasindakiYaziSilinince() {
        let e = editor("silinecek yazı\n```swift\nlet a = 1\n```\nalt satır\n")
        satirSonu(e, "silinecek yazı")
        for _ in 0..<14 { e.deleteBackward(nil) }
        XCTAssertEqual(md(e), "\n```swift\nlet a = 1\n```\nalt satır\n")
        e.deleteForward(nil)
        XCTAssertEqual(md(e), "```swift\nlet a = 1\n```\nalt satır\n")
    }

    /// İleri silme (fn+⌫) de aynı sonucu verir.
    func testIleriSilmeyle() {
        let e = editor(sayfa)
        e.setSelectedRange(satir(e, "silinecek yazı"))
        e.deleteForward(nil)
        XCTAssertEqual(md(e), "ilk satır\n```swift\nlet a = 1\nprint(a)\n```\nalt satır\n")
    }
}
