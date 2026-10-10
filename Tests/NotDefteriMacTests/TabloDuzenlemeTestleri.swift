import AppKit
import XCTest
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

final class TabloDuzenlemeTestleri: XCTestCase {
    private func editor(_ markdown: String) -> NotMetinGorunumu {
        _ = NSApplication.shared
        let gorunum = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        gorunum.isEditable = true
        gorunum.allowsUndo = true
        gorunum.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(markdown))
        return gorunum
    }

    func testHucreDuzenlemesiKaynagiVeKimligiKorur() throws {
        let kaynak = "| A | B |\r\n| :--- | ---: |\r\n| eski | komşu |\r\n"
        let gorunum = editor(kaynak)
        let depo = try XCTUnwrap(gorunum.textStorage)
        let kimlik = try XCTUnwrap(depo.attribute(kTabloGorselAnahtari, at: 0, effectiveRange: nil) as? String)
        let model = try XCTUnwrap(TabloModeli(markdown: kaynak))
        let hucre = try XCTUnwrap(model.hucreAraligi(satir: 1, sutun: 0))
        XCTAssertTrue(gorunum.tabloYoneticisi.hucreyiAc(konum: hucre.location))
        gorunum.tabloYoneticisi.metniKaydet("yeni | \\ metin\nsatır")
        let beklenen = "| A | B |\r\n| :--- | ---: |\r\n| yeni \\| \\\\ metin<br>satır | komşu |\r\n"
        XCTAssertEqual(markdownMetniUret(depo), beklenen)
        XCTAssertEqual(depo.attribute(kTabloGorselAnahtari, at: 0, effectiveRange: nil) as? String, kimlik)
        let duzenlenenModel = try XCTUnwrap(TabloModeli(oznitelik: depo.attribute(kTabloModeliAnahtari, at: 0, effectiveRange: nil)))
        XCTAssertEqual(duzenlenenModel.hucre(satir: 1, sutun: 0), "yeni | \\ metin\nsatır")
        XCTAssertEqual(duzenlenenModel.hucre(satir: 1, sutun: 1), "komşu")
        XCTAssertTrue(depo.string.hasPrefix("┌"))
        XCTAssertTrue(depo.string.hasSuffix("┘\n"))
    }

    func testTasanTablonunSonSutunuYerelPenceredeDuzenlenir() throws {
        let kaynak = "Önce\n\n| A | B | C | D | E | F | G | H | I | J | K | L |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |\n\nSonra\n"
        let gorunum = editor(kaynak)
        gorunum.textContainer?.size.width = 200
        let pencere = NSWindow(contentRect: gorunum.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = gorunum
        defer { gorunum.tabloYoneticisi.kapat(kaydet: false); pencere.close() }
        let baslik = (gorunum.string as NSString).range(of: "│ A").location + 2
        XCTAssertTrue(gorunum.tabloYoneticisi.hucreyiAc(konum: baslik))
        let tasma = try XCTUnwrap(gorunum.tabloYoneticisi.tasmaPenceresi)
        let kaydirici = try XCTUnwrap(tasma.contentView?.subviews.compactMap { $0 as? NSScrollView }.first)
        XCTAssertTrue(kaydirici.hasHorizontalScroller)
        let sonAlan = try XCTUnwrap(kaydirici.documentView?.subviews.compactMap { $0 as? NSTextField }.first { $0.tag == 23 })
        XCTAssertGreaterThan(sonAlan.frame.minX, kaydirici.contentSize.width)
        sonAlan.stringValue = "Son sütun"
        gorunum.tabloYoneticisi.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: sonAlan))
        XCTAssertEqual(markdownMetniUret(gorunum.textStorage!), kaynak.replacingOccurrences(of: "| 12 |\n", with: "| Son sütun |\n"))
        gorunum.sayfaYukleniyor = true
        XCTAssertNil(gorunum.tabloYoneticisi.tasmaPenceresi)
    }

    func testYabanciAlanBildirimiEtkinHucreyiDegistirmez() throws {
        let kaynak = try XCTUnwrap(tabloMarkdownUret(satir: 2, sutun: 2))
        let gorunum = editor(kaynak)
        let model = try XCTUnwrap(TabloModeli(markdown: kaynak))
        XCTAssertTrue(gorunum.tabloYoneticisi.hucreyiAc(konum: try XCTUnwrap(model.hucreAraligi(satir: 0, sutun: 0)).location))
        let eskiAlan = NSTextField(string: "geç bildirim")
        gorunum.tabloYoneticisi.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: eskiAlan))
        XCTAssertEqual(markdownMetniUret(gorunum.textStorage!), kaynak)
    }

    func testTasmaPenceresineGecisteAnaAlanEditorununGeriAlmasiKorunur() throws {
        let kaynak = try XCTUnwrap(tabloMarkdownUret(satir: 2, sutun: 2))
        let gorunum = editor(kaynak)
        gorunum.textContainer?.size.width = 600
        let pencere = NSWindow(contentRect: gorunum.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = gorunum
        defer { gorunum.tabloYoneticisi.kapat(kaydet: false); pencere.close() }
        let paylasilan = try XCTUnwrap(pencere.fieldEditor(true, for: nil) as? NSTextView)
        paylasilan.allowsUndo = true
        let model = try XCTUnwrap(TabloModeli(markdown: kaynak))
        XCTAssertTrue(gorunum.tabloYoneticisi.hucreyiAc(konum: try XCTUnwrap(model.hucreAraligi(satir: 0, sutun: 0)).location))
        XCTAssertTrue(pencere.firstResponder === paylasilan)
        XCTAssertFalse(paylasilan.allowsUndo)
        gorunum.tabloYoneticisi.metniKaydet(String(repeating: "uzun ", count: 100))
        XCTAssertNotNil(gorunum.tabloYoneticisi.tasmaPenceresi)
        XCTAssertTrue(paylasilan.allowsUndo)
    }

    func testYeniTablonunSeciliIlkHucresineYazilir() throws {
        let kaynak = try XCTUnwrap(tabloMarkdownUret(satir: 2, sutun: 2))
        let gorunum = editor(kaynak)
        gorunum.setSelectedRange(tabloIlkHucreAraligi(sutun: 2))
        gorunum.insertText("Ad", replacementRange: gorunum.selectedRange())
        let tamam = expectation(description: "Yerel hücreye yönlendirme")
        DispatchQueue.main.async {
            XCTAssertEqual(markdownMetniUret(gorunum.textStorage!), "| Ad | Başlık 2 |\n| --- | --- |\n| Hücre | Hücre |\n")
            XCTAssertEqual(gorunum.tabloYoneticisi.etkinHucre?.satir, 0)
            XCTAssertEqual(gorunum.tabloYoneticisi.etkinHucre?.sutun, 0)
            tamam.fulfill()
        }
        wait(for: [tamam], timeout: 2)
    }

    func testKontrolEnterKoddanCikarVeGovdeyiKorur() throws {
        let gorunum = editor("```swift\nilk\n\nson\n```\n")
        let imlec = (gorunum.string as NSString).range(of: "ilk").upperBound
        gorunum.setSelectedRange(NSRange(location: imlec, length: 0))
        let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: .control, timestamp: 0, windowNumber: 0, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        gorunum.keyDown(with: enter)
        XCTAssertNil(gorunum.typingAttributes[kKodBloguAnahtari])
        gorunum.insertText("dışarıda", replacementRange: gorunum.selectedRange())
        XCTAssertEqual(markdownMetniUret(gorunum.textStorage!), "```swift\nilk\n\nson\n```\ndışarıda\n")
    }

    func testGezinmeTabloDisindaKapanir() throws {
        let kaynak = try XCTUnwrap(tabloMarkdownUret(satir: 2, sutun: 2))
        let gorunum = editor(kaynak)
        let model = try XCTUnwrap(TabloModeli(markdown: kaynak))
        XCTAssertTrue(gorunum.tabloYoneticisi.hucreyiAc(konum: try XCTUnwrap(model.hucreAraligi(satir: 0, sutun: 0)).location))
        gorunum.tabloYoneticisi.gezin(1)
        XCTAssertEqual(gorunum.tabloYoneticisi.etkinHucre?.satir, 0)
        XCTAssertEqual(gorunum.tabloYoneticisi.etkinHucre?.sutun, 1)
        gorunum.tabloYoneticisi.gezin(-1)
        XCTAssertEqual(gorunum.tabloYoneticisi.etkinHucre?.sutun, 0)
        gorunum.tabloYoneticisi.gezin(-1)
        XCTAssertNil(gorunum.tabloYoneticisi.etkinHucre)
        XCTAssertEqual(markdownMetniUret(gorunum.textStorage!), kaynak)
    }

    func testCerceveKorunurTumTabloSilinebilir() throws {
        let gorunum = editor(try XCTUnwrap(tabloMarkdownUret(satir: 2, sutun: 2)))
        let onceki = gorunum.string
        XCTAssertFalse(gorunum.shouldChangeText(in: NSRange(location: 0, length: 1), replacementString: ""))
        XCTAssertEqual(gorunum.string, onceki)
        XCTAssertTrue(gorunum.shouldChangeText(in: NSRange(location: 0, length: (onceki as NSString).length), replacementString: ""))
    }

    func testSayfaYuklemeHucreyiKapatir() throws {
        let gorunum = editor(try XCTUnwrap(tabloMarkdownUret(satir: 2, sutun: 2)))
        let model = try XCTUnwrap(TabloModeli(markdown: markdownMetniUret(gorunum.textStorage!)))
        XCTAssertTrue(gorunum.tabloYoneticisi.hucreyiAc(konum: try XCTUnwrap(model.hucreAraligi(satir: 0, sutun: 0)).location))
        gorunum.sayfaYukleniyor = true
        XCTAssertNil(gorunum.tabloYoneticisi.etkinHucre)
    }

    func testHucreDuzenlemesiBelgeGecmisiyleGeriAlinir() throws {
        let kaynak = try XCTUnwrap(tabloMarkdownUret(satir: 2, sutun: 2))
        let gorunum = editor(kaynak)
        let pencere = NSWindow(contentRect: gorunum.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = gorunum
        defer { pencere.close() }
        let model = try XCTUnwrap(TabloModeli(markdown: kaynak))
        XCTAssertTrue(gorunum.tabloYoneticisi.hucreyiAc(konum: try XCTUnwrap(model.hucreAraligi(satir: 0, sutun: 0)).location))
        let gecmis = try XCTUnwrap(gorunum.undoManager)
        gecmis.beginUndoGrouping()
        gorunum.tabloYoneticisi.metniKaydet("Yeni")
        gecmis.endUndoGrouping()
        XCTAssertNotEqual(markdownMetniUret(gorunum.textStorage!), kaynak)
        gecmis.undo()
        XCTAssertEqual(markdownMetniUret(gorunum.textStorage!), kaynak)
        gecmis.redo()
        XCTAssertTrue(markdownMetniUret(gorunum.textStorage!).contains("Yeni"))
    }
}
