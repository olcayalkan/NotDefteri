import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Kod bloğunda eşli karakterler ve Tab kalıpları; sonuç kaydedilecek Markdown'dan ölçülür.
final class KodYazimiTestleri: XCTestCase {

    private var editor: NotMetinGorunumu!

    override func setUp() {
        super.setUp()
        editor = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.isRichText = true
        editor.isEditable = true
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        editor.textStorage?.delegate = editor
    }

    override func tearDown() {
        editor = nil
        super.tearDown()
    }

    /// Belgeyi açar, imleci `isaret`in yerine koyar (işaret metinden çıkarılır).
    private func ac(_ md: String, isaret: String = "‸") {
        let konum = (md as NSString).range(of: isaret)
        let temiz = md.replacingOccurrences(of: isaret, with: "")
        editor.sayfaYukleniyor = true
        editor.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(temiz, taban: URL(fileURLWithPath: NSTemporaryDirectory())))
        editor.sayfaYukleniyor = false
        // Markdown'daki konum görünümde kayar (çit satırı gizli); imleç metindeki komşusundan bulunur.
        let once = (temiz as NSString).substring(to: konum.location).components(separatedBy: "\n").last ?? ""
        let satirlar = editor.string.components(separatedBy: "\n")
        var toplam = 0
        for satir in satirlar {
            let temizSatir = satir.replacingOccurrences(of: "\u{200B}", with: "")
            if temizSatir.hasPrefix(once) {
                let fark = (satir as NSString).length - (temizSatir as NSString).length
                editor.setSelectedRange(NSRange(location: toplam + fark + (once as NSString).length, length: 0))
                return
            }
            toplam += (satir as NSString).length + 1
        }
        XCTFail("imleç yeri bulunamadı")
    }

    private func yaz(_ metin: String) {
        for harf in metin { editor.insertText(String(harf), replacementRange: NSRange(location: NSNotFound, length: 0)) }
    }

    private var kaydedilen: String { markdownMetniUret(editor.textStorage!) }

    // MARK: Eşli karakterler

    func testKodBlogundaParantezVeTirnakKapanirUstundenGecilir() {
        ac("```swift\nlet x = ‸\n```\n")
        yaz("f(\"a\")")
        XCTAssertEqual(kaydedilen, "```swift\nlet x = f(\"a\")\n```\n")
        yaz("[{")
        XCTAssertEqual(kaydedilen, "```swift\nlet x = f(\"a\")[{}]\n```\n")
    }

    func testBosEsGeriSilinceIkisiGider() {
        ac("```js\nfoo‸\n```\n")
        yaz("(")
        editor.deleteBackward(nil)
        XCTAssertEqual(kaydedilen, "```js\nfoo\n```\n")
    }

    func testSecimSarmalanir() {
        ac("```py\nprint(‸ad)\n```\n")
        let konum = editor.selectedRange().location
        editor.setSelectedRange(NSRange(location: konum, length: 2))
        yaz("\"")
        XCTAssertEqual(kaydedilen, "```py\nprint(\"ad\")\n```\n")
    }

    func testKodDisindaEslenmez() {
        ac("Metin ‸\n")
        yaz("(\"")
        XCTAssertEqual(kaydedilen, "Metin (\"\n")
    }

    // MARK: Kalıplar

    func testTryTabIleAcilirTekAdimdaGeriAlinir() throws {
        let pencere = NSWindow(contentRect: editor.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = editor
        defer { pencere.close() }
        ac("```swift\ntry‸\n```\n")
        let geri = try XCTUnwrap(editor.undoManager)
        geri.beginUndoGrouping()
        editor.insertTab(nil)
        geri.endUndoGrouping()
        XCTAssertEqual(kaydedilen, "```swift\ndo {\n\t\n} catch {\n\tprint(error)\n}\n```\n")
        let ns = editor.string as NSString
        let imlec = editor.selectedRange().location
        XCTAssertEqual(ns.substring(with: NSRange(location: imlec - 1, length: 1)), "\t")
        XCTAssertEqual(ns.substring(with: NSRange(location: imlec - 6, length: 4)), "do {")
        geri.undo()
        XCTAssertEqual(kaydedilen, "```swift\ntry\n```\n")
    }

    func testKalipBloguGirintisineUyar() {
        ac("```python\ndef f():\n    if‸\n```\n")
        editor.insertTab(nil)
        XCTAssertEqual(kaydedilen, "```python\ndef f():\n    if :\n        pass\n```\n")
    }

    func testKelimeYoksaTabNormalCalisir() {
        ac("```swift\nlet try‸\n```\n")
        editor.insertTab(nil)
        XCTAssertEqual(kaydedilen, "```swift\nlet try\t\n```\n")
    }
}
