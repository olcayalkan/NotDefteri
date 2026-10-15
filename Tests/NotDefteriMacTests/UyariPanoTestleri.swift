import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

final class UyariPanoTestleri: XCTestCase {
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
    private func md(_ e: NotMetinGorunumu) -> String { markdownMetniUret(e.textStorage!) }

    /// Paragraf numarasıyla (0 tabanlı) aralık; işaret karakterleri dahil gerçek seçim.
    private func paragraflar(_ e: NotMetinGorunumu, _ ilk: Int, _ son: Int) -> NSRange {
        let ns = e.string as NSString
        var satirlar: [NSRange] = []
        var k = 0
        while k < ns.length { let r = ns.paragraphRange(for: NSRange(location: k, length: 0)); satirlar.append(r); k = NSMaxRange(r) }
        return NSUnionRange(satirlar[ilk], satirlar[son])
    }

    private func kopyalaYapistir(_ kaynak: String, kopya: (Int, Int), tamSatir: Bool = true,
                                 hedef: Int, satirSonu: Bool, kes: Bool = false) -> String {
        let e = editor(kaynak)
        var k = paragraflar(e, kopya.0, kopya.1)
        if !tamSatir { k.length -= 1 }
        e.setSelectedRange(k)
        NSPasteboard.general.clearContents()
        if kes { e.cut(nil) } else { e.copy(nil) }
        let h = paragraflar(e, hedef, hedef)
        e.setSelectedRange(NSRange(location: satirSonu ? NSMaxRange(h) - 1 : h.location, length: 0))
        e.paste(nil)
        return md(e)
    }

    private let kutu = "> [!💡 mavi] bir\n> iki\n> üç\n"

    /// Kutu, satır sonuna yapıştırılınca işareti metne karışmaz; kutu olarak kalır.
    func testKutuSatirSonunaYapistirilincaKutuKalir() {
        XCTAssertEqual(kopyalaYapistir("önce\n\(kutu)sonra\n", kopya: (1, 3), hedef: 4, satirSonu: true),
                       "önce\n\(kutu)sonra\n\(kutu)")
    }

    func testKutuSatirBasinaYapistirilir() {
        XCTAssertEqual(kopyalaYapistir("önce\n\(kutu)sonra\n", kopya: (1, 3), hedef: 0, satirSonu: false),
                       "\(kutu)önce\n\(kutu)sonra\n")
    }

    /// Kutunun ortasından alınan satırlar düz alıntıya değil, kutuya dönüşür.
    func testKutuOrtasindanKopyalananSatirKutuOlur() {
        XCTAssertEqual(kopyalaYapistir("önce\n\(kutu)sonra\n", kopya: (2, 2), hedef: 0, satirSonu: false),
                       "> [!💡 mavi] iki\nönce\n\(kutu)sonra\n")
    }

    /// Kutunun içindeki satır sonuna yapıştırma boş (hayalet) başlıklı kutu doğurmaz.
    func testKutuIcineYapistirmaBosKutuDogurmaz() {
        let sonuc = kopyalaYapistir("önce\n\(kutu)sonra\n", kopya: (2, 2), hedef: 3, satirSonu: true)
        XCTAssertEqual(sonuc, "önce\n\(kutu)> [!💡 mavi] iki\nsonra\n")
    }

    /// İmleç kutu satırının işaretinden hemen sonraysa satır başındadır; satırın işareti yerinde kalır.
    func testKutuSatirBasinaImlecIsaretinSonundayken() {
        let e = editor("önce\n\(kutu)sonra\n")
        e.setSelectedRange(paragraflar(e, 1, 3))
        NSPasteboard.general.clearContents()
        e.copy(nil)
        let iki = paragraflar(e, 2, 2)
        e.setSelectedRange(NSRange(location: iki.location + 1, length: 0))   // işaretin hemen sonrası
        e.paste(nil)
        XCTAssertEqual(md(e), "önce\n> [!💡 mavi] bir\n\(kutu)> [!💡 mavi] iki\n> üç\nsonra\n")
    }

    /// Yeni açılmış boş kutuya kutu yapıştırınca boş kutu kalmaz.
    func testBosKutuYerineYapistirilir() {
        let e = editor("önce\n")
        let kaynak = editor("\(kutu)")
        kaynak.setSelectedRange(NSRange(location: 0, length: kaynak.string.utf16.count))
        NSPasteboard.general.clearContents()
        kaynak.copy(nil)
        e.setSelectedRange(NSRange(location: (e.string as NSString).length, length: 0))
        let konum = NSRange(location: e.selectedRange().location, length: 0)
        e.menuBlogunuUygula(MetinBlogu(tur: .uyari, emoji: "💡", renk: "mavi", uyariKimligi: "bos"), komutAraligi: konum)
        e.paste(nil)
        // Yeni kutunun altındaki boş satır tasarım gereği kalır; boş başlıklı ikinci kutu kalmamalı.
        XCTAssertEqual(md(e), "önce\n\(kutu)\n", "boş kutu geride kalmamalı")
    }

    /// Kes + yapıştır kutuyu aynı yerde bozmadan geri getirir.
    func testKesYapistirKutuyuKorur() {
        let e = editor("önce\n\(kutu)sonra\n")
        e.setSelectedRange(paragraflar(e, 1, 3))
        NSPasteboard.general.clearContents()
        e.cut(nil)
        XCTAssertEqual(md(e), "önce\nsonra\n")
        e.setSelectedRange(NSRange(location: paragraflar(e, 1, 1).location, length: 0))
        e.paste(nil)
        XCTAssertEqual(md(e), "önce\n\(kutu)sonra\n")
    }

    /// Yapıştırma tek adımda geri alınır.
    func testKutuYapistirmaGeriAlinir() throws {
        let e = editor("önce\n\(kutu)sonra\n")
        e.setSelectedRange(paragraflar(e, 1, 3))
        NSPasteboard.general.clearContents()
        e.copy(nil)
        let h = paragraflar(e, 4, 4)
        e.setSelectedRange(NSRange(location: NSMaxRange(h) - 1, length: 0))
        let pencere = NSWindow(contentRect: e.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = e
        defer { pencere.close() }
        let geri = try XCTUnwrap(e.undoManager)
        geri.beginUndoGrouping()
        e.paste(nil)
        geri.endUndoGrouping()
        geri.undo()
        XCTAssertEqual(md(e), "önce\n\(kutu)sonra\n")
    }
}
