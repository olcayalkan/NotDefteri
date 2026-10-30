import AppKit
import XCTest
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Yerel tabloda (`NSTextTable`) hücreye klavyeden yazmak, silmek ve Enter: imleç hücrede kalır,
/// kayıt Markdown tablosudur. Her tuşta yeni blok üretilince imleç alttaki hücreye atlıyordu.
final class TabloHucreDuzenlemeTestleri: XCTestCase {

    private var editor: NotMetinGorunumu!
    private var pencere: NSWindow!

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        editor = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 520, height: 400))
        pencere = NSWindow(contentRect: editor.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = editor
        editor.isRichText = true
        editor.isEditable = true
        editor.allowsUndo = true
        editor.textStorage?.delegate = editor
        editor.sayfaYukleniyor = true
        editor.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc("| A | B |\n| --- | --- |\n| bir | iki |\n| uc | dort |\n"))
        editor.sayfaYukleniyor = false
    }

    override func tearDown() {
        pencere.close()
        editor = nil
        pencere = nil
        super.tearDown()
    }

    private func yaz(_ metin: String) {
        for harf in metin {
            if harf == "\n" { editor.insertNewline(nil) }
            else { editor.insertText(String(harf), replacementRange: NSRange(location: NSNotFound, length: 0)) }
        }
    }

    private var kaydedilen: String { markdownMetniUret(editor.textStorage!) }

    private func imleciKoy(sonuna parca: String) {
        editor.setSelectedRange(NSRange(location: NSMaxRange((editor.string as NSString).range(of: parca)), length: 0))
    }

    func testHucreyeYazilanHarflerHucredeKalir() {
        imleciKoy(sonuna: "iki")
        yaz("XY")
        XCTAssertEqual(kaydedilen, "| A | B |\n| --- | --- |\n| bir | ikiXY |\n| uc | dort |\n\n")
        editor.setSelectedRange((editor.string as NSString).range(of: "ikiXY"))
        yaz("Durum")
        XCTAssertEqual(kaydedilen, "| A | B |\n| --- | --- |\n| bir | Durum |\n| uc | dort |\n\n")
    }

    func testHucredeGeriSilme() {
        imleciKoy(sonuna: "dort")
        editor.deleteBackward(nil)
        editor.deleteBackward(nil)
        XCTAssertEqual(kaydedilen, "| A | B |\n| --- | --- |\n| bir | iki |\n| uc | do |\n\n")
    }

    /// Hücrede Enter aynı hücrede yeni satır açar; kayıtta satırlar boşlukla birleşir.
    func testHucredeEnterHucredeKalir() {
        imleciKoy(sonuna: "bir")
        yaz("\nek")
        XCTAssertEqual(kaydedilen, "| A | B |\n| --- | --- |\n| bir ek | iki |\n| uc | dort |\n\n")
    }

    /// `/tablo` yolu: tablo eklenir, ilk başlık seçilir, yazılan ad tabloda kalır.
    func testYeniTablonunIlkBasliginaYazilir() throws {
        editor.sayfaYukleniyor = true
        editor.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc("/tablo"))
        editor.sayfaYukleniyor = false
        let yeni = editor.belgeAdaptoru.gorunumluBelge(markdowndenAttributedStringUret(try XCTUnwrap(tabloMarkdownUret(satir: 2, sutun: 2))))
        let ilk = (yeni.string as NSString).range(of: "Başlık 1")
        editor.blokDuzenle(NSRange(location: 0, length: 6), yeni: yeni, secim: ilk,
                           yazim: yeni.attributes(at: ilk.location, effectiveRange: nil))
        yaz("Ad")
        XCTAssertEqual(kaydedilen, "| Ad | Başlık 2 |\n| --- | --- |\n| Hücre | Hücre |\n\n")
    }

    /// Başlık ve gövdenin çift satırları gölgeli, tek satırlar düz.
    func testCiftSatirlarGolgeli() {
        func zemin(_ parca: String) -> NSColor? {
            let konum = (editor.string as NSString).range(of: parca).location
            let stil = editor.textStorage?.attribute(.paragraphStyle, at: konum, effectiveRange: nil) as? NSParagraphStyle
            return (stil?.textBlocks.first as? NSTextTableBlock)?.backgroundColor
        }
        XCTAssertNotNil(zemin("A"), "başlık")
        XCTAssertNil(zemin("bir"), "1. gövde satırı düz")
        XCTAssertNotNil(zemin("uc"), "2. gövde satırı gölgeli")
    }
}
