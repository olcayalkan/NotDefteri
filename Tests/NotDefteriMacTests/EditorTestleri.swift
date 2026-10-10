import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Editörde yazarak çalışan özellikler: Markdown kısayolları, Enter/Tab/geri silme ve kelime sayımı.
/// Editör `NotPenceresi`'nin kurduğu gibi kurulur; sonuç, kaydedilecek Markdown üzerinden ölçülür.
final class EditorTestleri: XCTestCase {

    private var editor: NotMetinGorunumu!

    override func setUp() {
        super.setUp()
        editor = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.isRichText = true
        editor.isEditable = true
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        editor.textStorage?.delegate = editor
    }

    override func tearDown() {
        editor = nil
        super.tearDown()
    }

    /// Sayfa açılışının aynısı: adaptörle yükle, imleci sona koy.
    private func ac(_ md: String) {
        editor.sayfaYukleniyor = true
        editor.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md, taban: URL(fileURLWithPath: NSTemporaryDirectory())))
        editor.sayfaYukleniyor = false
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        editor.kelimeSayisiniHazirla()
    }

    /// Karakter karakter klavyeden yazılmış gibi; "\n" Enter'dır.
    private func yaz(_ metin: String) {
        for harf in metin {
            if harf == "\n" { editor.insertNewline(nil) }
            else { editor.insertText(String(harf), replacementRange: NSRange(location: NSNotFound, length: 0)) }
        }
    }

    private var kaydedilen: String { markdownMetniUret(editor.textStorage!) }

    // MARK: Markdown kısayolları

    func testMaddeKisayolu() {
        yaz("- elma")
        XCTAssertEqual(kaydedilen, "- elma")
        XCTAssertTrue(editor.string.hasPrefix("•\t"), "görünümde madde işareti olmalı")
    }

    func testNumaraliListeKisayolu() {
        yaz("1. bir")
        XCTAssertEqual(kaydedilen, "1. bir")
    }

    func testYapilacakKisayolu() {
        yaz("[] iş")
        XCTAssertEqual(kaydedilen, "- [ ] iş")
    }

    func testAlintiKisayolu() {
        yaz("> söz")
        XCTAssertEqual(kaydedilen, "> söz")
    }

    func testBaslikKisayollari() {
        yaz("# Bir\n## İki\n### Üç")
        XCTAssertEqual(kaydedilen, "# Bir\n## İki\n### Üç")
    }

    func testAyiriciKisayolu() {
        yaz("---\nsonra")
        XCTAssertEqual(kaydedilen, "---\nsonra")
    }

    /// Satır ortasındaki "- " kısayol değildir.
    func testSatirOrtasindaKisayolCalismaz() {
        yaz("a - b")
        XCTAssertEqual(kaydedilen, "a - b")
    }

    // MARK: Enter, Tab, geri silme

    func testEnterListeyiSurdurur() {
        yaz("- a\nb")
        XCTAssertEqual(kaydedilen, "- a\n- b")
    }

    func testNumaraliListeEnterIleArtar() {
        yaz("1. a\nb\nc")
        XCTAssertEqual(kaydedilen, "1. a\n2. b\n3. c")
    }

    /// Boş maddede Enter listeden çıkar; imleç yeni normal paragrafta, belge satır sonuyla biter.
    func testIkinciEnterListedenCikar() {
        yaz("- a\n\nnormal")
        XCTAssertEqual(kaydedilen, "- a\nnormal\n")
    }

    func testTabGirintiArtirir() {
        yaz("- a\n")
        editor.insertTab(nil)
        yaz("b")
        XCTAssertEqual(kaydedilen, "- a\n  - b")
    }

    func testShiftTabGirintiAzaltir() {
        ac("- a\n  - b")
        editor.insertBacktab(nil)
        XCTAssertEqual(kaydedilen, "- a\n- b")
    }

    func testSatirBasindaGeriSilmeBicimiKaldirir() {
        yaz("- a")
        editor.setSelectedRange(NSRange(location: blokIsaretiUzunlugu(editor.textStorage!), length: 0))
        editor.deleteBackward(nil)
        XCTAssertEqual(kaydedilen, "a")
    }

    func testAcilanBelgeDuzenlenmedenAynenKaydedilir() {
        let md = "# Başlık\n\n- [ ] görev\n  1. alt\n> [!💡 sarı] not\n```swift\nlet x = 1\n```\n**kalın** [[Bağ]]\n"
        ac(md)
        XCTAssertEqual(kaydedilen, md)
    }

    // MARK: Kelime sayımı

    func testKelimeSayisiIsaretleriSaymaz() {
        ac("# İki kelime\n- üç kelime burada\n- [ ] dört")
        XCTAssertEqual(editor.kelimeSayisi, 6)
    }

    func testKelimeSayisiYazarkenGuncellenir() {
        ac("bir iki")
        yaz(" üç dört")
        XCTAssertEqual(editor.kelimeSayisi, 4)
    }
}
