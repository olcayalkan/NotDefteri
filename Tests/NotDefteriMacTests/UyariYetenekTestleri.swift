import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Her uyarı rengi aynı yeteneklere sahiptir ve kod bloğuyla ortak yetenekler uyarıda da çalışır.
final class UyariYetenekTestleri: XCTestCase {
    private let renkler = ["gri", "mavi", "sarı", "kırmızı", "yeşil"]

    private func editor(_ md: String) -> NotMetinGorunumu {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        e.isRichText = true; e.isEditable = true; e.allowsUndo = true
        e.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        e.textStorage?.delegate = e
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        return e
    }

    private func md(_ e: NotMetinGorunumu) -> String { markdownMetniUret(e.textStorage!) }

    private func imleciKoy(_ e: NotMetinGorunumu, sonuna metin: String) {
        e.setSelectedRange(NSRange(location: NSMaxRange((e.string as NSString).range(of: metin)), length: 0))
    }

    private func kutular(_ e: NotMetinGorunumu) -> [NSRange] {
        e.cerceveliBlokAraliklari(NSRange(location: 0, length: e.textStorage!.length), anahtar: kUyariKutusuAnahtari)
    }

    private func gorsel() -> ResimEki {
        resimEkiUret(gorsel: NSImage(size: NSSize(width: 100, height: 80)), dosyaURL: URL(fileURLWithPath: "/tmp/x.png"),
                     bagYolu: "Görseller/x.png", gosterimBoyutu: NSSize(width: 100, height: 80))
    }

    func testMenudenOlusunculunAltindaBosSatir() {
        for renk in renkler {
            let e = editor("alt\n")
            e.setSelectedRange(NSRange(location: 0, length: 0))
            e.insertNewline(nil)
            e.setSelectedRange(NSRange(location: 0, length: 0))
            e.menuBlogunuUygula(MetinBlogu(tur: .uyari, renk: renk, uyariKimligi: "k"), komutAraligi: NSRange(location: 0, length: 0))
            e.insertText("x", replacementRange: e.selectedRange())
            XCTAssertEqual(md(e), "> [!💡 \(renk)] x\n\nalt\n", renk)
        }
    }

    func testIkiEnterKutudanCikarCtrlEnterHerYerden() {
        for renk in renkler {
            let e = editor("> [!💡 \(renk)] bir\nalt\n")
            imleciKoy(e, sonuna: "bir")
            e.insertNewline(nil)
            XCTAssertEqual(e.blok(e.paragrafAraligi())?.tur, .uyari, renk)
            e.insertNewline(nil)
            XCTAssertNil(e.blok(e.paragrafAraligi()), renk)
            XCTAssertEqual(kutular(e).count, 1, renk)
            let c = editor("> [!💡 \(renk)] bir\n> iki\n\nalt\n")
            imleciKoy(c, sonuna: "bir")
            XCTAssertTrue(c.kutudanCik(), renk)
            XCTAssertNil(c.blok(c.paragrafAraligi()), renk)
        }
    }

    /// Kutuda tek `/` düz yazıdır (yollar menü açmaz); komut `//komut` ile çağrılır. Kutu dışı değişmez.
    func testKutudaKomutCiftEgikCizgiyle() throws {
        for renk in renkler {
            for (yazi, aralik, sorgu) in [("/opt", nil, nil), ("/opt/x", nil, nil), ("http://x", nil, nil), ("///kod", nil, nil),
                                          ("//", 2, ""), ("//kod", 5, "kod"), ("bak //kod", 5, "kod")] as [(String, Int?, String?)] {
                let e = editor("> [!💡 \(renk)] a\n")
                imleciKoy(e, sonuna: "a")
                e.deleteBackward(nil)
                e.insertText(yazi, replacementRange: e.selectedRange())
                let komut = e.slashKomutu(imlec: e.selectedRange().location)
                XCTAssertEqual(komut?.aralik.length, aralik, "\(renk) \(yazi)")
                XCTAssertEqual(komut?.sorgu, sorgu, "\(renk) \(yazi)")
            }
        }
        let d = editor("düz\n")
        d.setSelectedRange(NSRange(location: 3, length: 0))
        d.insertText(" /kod", replacementRange: d.selectedRange())
        XCTAssertEqual(d.slashKomutu(imlec: d.selectedRange().location)?.sorgu, "kod")
        let k = editor("```\nx\n```\n")
        k.setSelectedRange(NSRange(location: NSMaxRange((k.string as NSString).range(of: "x")), length: 0))
        k.insertText(" //kod", replacementRange: k.selectedRange())
        XCTAssertNil(k.slashKomutu(imlec: k.selectedRange().location))
    }

    /// Görsel kutuyu parçalamaz, kod bloğundaki gibi altına gider.
    func testGorselKutuyuParcalamaz() {
        for renk in renkler {
            let e = editor("> [!💡 \(renk)] ilk\n> son\nalt\n")
            imleciKoy(e, sonuna: "ilk")
            e.ekiEkle(gorsel())
            XCTAssertEqual(kutular(e).count, 1, renk)
            XCTAssertEqual(md(e), "> [!💡 \(renk)] ilk\n> son\n![](Görseller/x.png){100x80}\nalt\n", renk)
        }
    }

    /// Kopyala şeridi uyarıda da görünür ve kutunun metnini işaretsiz kopyalar.
    func testKopyalaSeridi() throws {
        let pano = NSPasteboard.general
        let eski = pano.string(forType: .string)
        defer { pano.clearContents(); if let eski { pano.setString(eski, forType: .string) } }
        for renk in renkler {
            let e = editor("üst\n\n> [!💡 \(renk)] ilk\n> son\n\nalt\n")
            e.layoutManager?.ensureLayout(for: e.textContainer!)
            let konum = (e.string as NSString).range(of: "son").location
            let glif = try XCTUnwrap(e.layoutManager).glyphIndexForCharacter(at: konum)
            let satir = try XCTUnwrap(e.layoutManager).lineFragmentRect(forGlyphAt: glif, effectiveRange: nil)
            e.kodAraclariniGuncelle(noktada: NSPoint(x: satir.minX + 40 + e.textContainerOrigin.x, y: satir.midY + e.textContainerOrigin.y))
            XCTAssertFalse(e.kodAraclari.isHidden, renk)
            e.kodBlogunuKopyala()
            XCTAssertEqual(pano.string(forType: .string)?.trimmingCharacters(in: .newlines), "ilk\nson", renk)
            XCTAssertEqual(e.kodAraclari.dugme.attributedTitle.string, "Kopyalandı", renk)
        }
    }

    /// Sağ tık menüsü renk seçimini ekler, düzenleme komutlarını (kes/kopyala/yapıştır) kaldırmaz.
    func testSagTikMenusuDuzenlemeKomutlariniKorur() throws {
        for renk in renkler {
            let e = editor("> [!💡 \(renk)] ilk\nalt\n")
            let pencere = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
            pencere.isReleasedWhenClosed = false
            pencere.contentView?.addSubview(e)
            defer { pencere.close() }
            e.layoutManager?.ensureLayout(for: e.textContainer!)
            let konum = (e.string as NSString).range(of: "ilk").location
            let glif = try XCTUnwrap(e.layoutManager).glyphIndexForCharacter(at: konum)
            let satir = try XCTUnwrap(e.layoutManager).lineFragmentRect(forGlyphAt: glif, effectiveRange: nil)
            let nokta = e.convert(NSPoint(x: 40 + e.textContainerOrigin.x, y: satir.midY + e.textContainerOrigin.y), to: nil)
            let olay = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: nokta, modifierFlags: [], timestamp: 0,
                                                        windowNumber: pencere.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            let menu = try XCTUnwrap(e.menu(for: olay))
            XCTAssertTrue(menu.items.contains { $0.action == #selector(NSText.paste(_:)) }, renk)
            let renkMenusu = try XCTUnwrap(menu.items.first { $0.title == "Renk" }?.submenu, renk)
            XCTAssertEqual(renkMenusu.items.count, renkler.count, renk)
        }
    }
}
