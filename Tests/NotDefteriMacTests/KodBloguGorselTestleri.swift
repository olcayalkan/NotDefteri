import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Kod bloğuna görsel eklenince kutu tek parça kalır, Kopyala şeridi çalışır; alt alta kutular bitişir.
final class KodBloguGorselTestleri: XCTestCase {
    private func editor(_ md: String) -> NotMetinGorunumu {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        e.isRichText = true; e.isEditable = true; e.allowsUndo = true
        e.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        e.textStorage?.delegate = e
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        return e
    }

    private func gorsel() -> ResimEki {
        let resim = NSImage(size: NSSize(width: 100, height: 80))
        return resimEkiUret(gorsel: resim, dosyaURL: URL(fileURLWithPath: "/tmp/x.png"), bagYolu: "Görseller/x.png",
                            gosterimBoyutu: NSSize(width: 100, height: 80))
    }

    private func kodBloklari(_ e: NotMetinGorunumu) -> [NSRange] {
        e.cerceveliBlokAraliklari(NSRange(location: 0, length: e.textStorage!.length), anahtar: kKodBloguAnahtari)
    }

    private func imleciKoy(_ e: NotMetinGorunumu, sonuna metin: String) {
        e.setSelectedRange(NSRange(location: NSMaxRange((e.string as NSString).range(of: metin)), length: 0))
    }

    /// Görsel kod gövdesine girmez, kutunun altına gider; Markdown geçerli kalır, sonraki yazı koda karışmaz.
    func testGorselKoduParcalamadanAltinaEklenir() {
        for (kaynak, beklenen) in [
            ("```swift\nilk\nson\n```\nalt\n", "```swift\nilk\nson\n```\n![](Görseller/x.png){100x80}\nalt\n"),
            // Altındaki boş satır yeniden kullanılır; boş satır çoğalmaz.
            ("```swift\nilk\nson\n```\n\nalt\n", "```swift\nilk\nson\n```\n![](Görseller/x.png){100x80}\nalt\n"),
            ("```swift\nilk\nson\n```\n", "```swift\nilk\nson\n```\n![](Görseller/x.png){100x80}\n")] {
            let e = editor(kaynak)
            imleciKoy(e, sonuna: "ilk")
            e.ekiEkle(gorsel())
            XCTAssertEqual(kodBloklari(e).count, 1, kaynak)
            XCTAssertEqual(markdownMetniUret(e.textStorage!), beklenen)
            XCTAssertNil(e.typingAttributes[kKodBloguAnahtari], kaynak)
        }
    }

    /// Kodda seçili metin görselle değişmez: kod gövdesi korunur.
    func testKoddaSeciliMetinGorselleSilinmez() {
        let e = editor("```\nilk\n```\n")
        e.setSelectedRange((e.string as NSString).range(of: "ilk"))
        e.ekiEkle(gorsel())
        XCTAssertEqual(markdownMetniUret(e.textStorage!), "```\nilk\n```\n![](Görseller/x.png){100x80}\n")
    }

    /// Panoda yalnızca görsel varken kodda yapıştırma bip sesiyle reddedilmez, görsel kutunun altına gider.
    func testKodaYapistirilanGorselAltinaEklenir() {
        let e = editor("```\nilk\n```\n")
        e.gorselEklenecek = { _, _ in self.gorsel() }
        imleciKoy(e, sonuna: "ilk")
        let pano = NSPasteboard.withUniqueName()
        defer { pano.releaseGlobally() }
        let resim = NSImage(size: NSSize(width: 4, height: 4))
        resim.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 4, height: 4))
        resim.unlockFocus()
        pano.clearContents()
        pano.setData(resim.tiffRepresentation, forType: .tiff)
        XCTAssertTrue(e.readSelection(from: pano, type: .tiff))
        XCTAssertEqual(markdownMetniUret(e.textStorage!), "```\nilk\n```\n![](Görseller/x.png){100x80}\n")
    }

    /// Görsel eklendikten sonra kod satırının üstünde Kopyala şeridi görünür ve yalnızca kodu kopyalar.
    func testGorselSonrasiKopyalaSeridiCalisir() throws {
        let e = editor("üst\n\n```swift\nilk\n```\n")
        imleciKoy(e, sonuna: "ilk")
        e.ekiEkle(gorsel())
        e.layoutManager?.ensureLayout(for: e.textContainer!)
        let konum = (e.string as NSString).range(of: "ilk").location
        let glif = try XCTUnwrap(e.layoutManager).glyphIndexForCharacter(at: konum)
        let satir = try XCTUnwrap(e.layoutManager).lineFragmentRect(forGlyphAt: glif, effectiveRange: nil)
        e.kodAraclariniGuncelle(noktada: NSPoint(x: satir.minX + 10 + e.textContainerOrigin.x, y: satir.midY + e.textContainerOrigin.y))
        XCTAssertFalse(e.kodAraclari.isHidden)
        XCTAssertEqual(e.kodAraclari.dugme.attributedTitle.string, "Kopyala")
        XCTAssertGreaterThan(e.kodAraclari.dugme.frame.width, 0)
        let pano = NSPasteboard.general
        let eski = pano.string(forType: .string)
        defer { pano.clearContents(); if let eski { pano.setString(eski, forType: .string) } }
        e.kodBlogunuKopyala()
        XCTAssertEqual(pano.string(forType: .string), "ilk\n")
        XCTAssertEqual(e.kodAraclari.dugme.attributedTitle.string, "Kopyalandı")
    }

    /// Alt alta iki kod bloğunun çerçeveleri arada boşluk kalmadan bitişir; yeniden açınca da aynı.
    func testBitisikKodBloklariArasindaBoslukYok() throws {
        let e = editor("```\nbir\n```\n```\niki\n```\n")
        e.layoutManager?.ensureLayout(for: e.textContainer!)
        let b = kodBloklari(e)
        XCTAssertEqual(b.count, 2)
        let ust = try XCTUnwrap(e.blokCerceveKaresi(b[0], anahtar: kKodBloguAnahtari))
        let alt = try XCTUnwrap(e.blokCerceveKaresi(b[1], anahtar: kKodBloguAnahtari))
        XCTAssertEqual(alt.minY, ust.maxY, accuracy: 0.5)
    }

    /// Uyarı kutusu `> [!…] ` kısayoluyla yazılınca da altında boş satır açılır, imleç kutuda kalır.
    func testKisayolUyarisininAltindaBosSatirOlur() {
        let e = editor("alt\n")
        e.setSelectedRange(NSRange(location: 0, length: 0))
        e.insertNewline(nil)
        e.setSelectedRange(NSRange(location: 0, length: 0))
        e.insertText("> [!💡 mavi]", replacementRange: e.selectedRange())
        XCTAssertTrue(e.blokKisayolunuUygula(" "))
        XCTAssertEqual(e.blok(e.paragrafAraligi())?.tur, .uyari)
        e.insertText("x", replacementRange: e.selectedRange())
        XCTAssertEqual(markdownMetniUret(e.textStorage!), "> [!💡 mavi] x\n\nalt\n")
    }
}
