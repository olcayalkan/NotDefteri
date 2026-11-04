import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Notion gibi blok taşıma: ⌘⇧↑/↓ ve ⋮⋮ tutamacıyla sürükleme.
final class BlokTasimaTestleri: XCTestCase {
    private var pencere: NSWindow?

    override func tearDown() {
        pencere?.close()
        pencere = nil
        super.tearDown()
    }

    private func editor(_ md: String) -> NotMetinGorunumu {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        e.isRichText = true; e.isEditable = true; e.allowsUndo = true
        e.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        e.textStorage?.delegate = e
        e.sayfaYukleniyor = true
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        e.sayfaYukleniyor = false
        let p = NSWindow(contentRect: e.frame, styleMask: [.titled], backing: .buffered, defer: false)
        p.isReleasedWhenClosed = false
        p.contentView = e
        pencere = p
        return e
    }

    private func md(_ e: NotMetinGorunumu) -> String { markdownMetniUret(e.textStorage!) }
    private func imlec(_ e: NotMetinGorunumu, _ metin: String) {
        e.setSelectedRange(NSRange(location: (e.string as NSString).range(of: metin).location, length: 0))
    }

    func testParagrafAsagiYukari() {
        let e = editor("bir\niki\nüç\n")
        imlec(e, "bir")
        e.secimiBirBlokTasi(yukari: false)
        XCTAssertEqual(md(e), "iki\nbir\nüç\n")
        XCTAssertEqual(e.selectedRange().location, (e.string as NSString).range(of: "bir").location, "imleç blokla gider")
        e.secimiBirBlokTasi(yukari: false)
        XCTAssertEqual(md(e), "iki\nüç\nbir\n")
        e.secimiBirBlokTasi(yukari: true)
        XCTAssertEqual(md(e), "iki\nbir\nüç\n")
    }

    /// Son satırda satır sonu yoksa satırlar birbirine yapışmaz, belge sonu aynı kalır.
    func testSatirSonuOlmayanSonSatir() {
        let e = editor("bir\niki")
        imlec(e, "iki")
        e.secimiBirBlokTasi(yukari: true)
        XCTAssertEqual(md(e), "iki\nbir")
        imlec(e, "iki")
        e.secimiBirBlokTasi(yukari: false)
        XCTAssertEqual(md(e), "bir\niki")
    }

    func testUyariKutusuBolunmez() {
        let e = editor("önce\n> [!💡 mavi] a\n> b\nsonra\n")
        imlec(e, "sonra")
        e.secimiBirBlokTasi(yukari: true)
        XCTAssertEqual(md(e), "önce\nsonra\n> [!💡 mavi] a\n> b\n")
        imlec(e, "b")
        e.secimiBirBlokTasi(yukari: true)
        XCTAssertEqual(md(e), "önce\n> [!💡 mavi] a\n> b\nsonra\n", "kutunun içindeki satır bütün kutuyu taşır")
    }

    func testKodBloguBolunmez() {
        let e = editor("x\n```swift\nk1\nk2\n```\ny\n")
        imlec(e, "x")
        e.secimiBirBlokTasi(yukari: false)
        XCTAssertEqual(md(e), "```swift\nk1\nk2\n```\nx\ny\n")
    }

    func testListeMaddesiAltMaddeleriyleGider() {
        let e = editor("- a\n  - a1\n- b\n")
        imlec(e, "a")
        e.secimiBirBlokTasi(yukari: false)
        XCTAssertEqual(md(e), "- b\n- a\n  - a1\n")
    }

    func testNumaraliListeYenidenNumaralanir() {
        let e = editor("1. a\n2. b\n")
        imlec(e, "a")
        e.secimiBirBlokTasi(yukari: false)
        XCTAssertEqual(md(e), "1. b\n2. a\n")
    }

    func testCokluSecimBirlikteTasinir() {
        let e = editor("a\nb\nc\nd\n")
        let ns = e.string as NSString
        e.setSelectedRange(NSUnionRange(ns.range(of: "b"), ns.range(of: "c")))
        e.secimiBirBlokTasi(yukari: false)
        XCTAssertEqual(md(e), "a\nd\nb\nc\n")
    }

    /// Sürükle-bırak yolu: blok hedef sınıra gider.
    func testHedefeTasima() {
        let e = editor("a\nb\nc\n")
        let a = e.blokBirimi(0)
        e.bloguTasi(a, hedef: (e.string as NSString).length)
        XCTAssertEqual(md(e), "b\nc\na\n")
        e.bloguTasi(e.blokBirimi((e.string as NSString).range(of: "a").location), hedef: 0)
        XCTAssertEqual(md(e), "a\nb\nc\n")
    }

    func testKisayolTusuVeGeriAlma() throws {
        let e = editor("bir\niki\n")
        imlec(e, "bir")
        let olay = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .shift],
            timestamp: 0, windowNumber: pencere!.windowNumber, context: nil,
            characters: String(UnicodeScalar(NSDownArrowFunctionKey)!), charactersIgnoringModifiers: String(UnicodeScalar(NSDownArrowFunctionKey)!),
            isARepeat: false, keyCode: 125))
        let geri = try XCTUnwrap(e.undoManager)
        geri.beginUndoGrouping()
        e.keyDown(with: olay)
        geri.endUndoGrouping()
        XCTAssertEqual(md(e), "iki\nbir\n")
        geri.undo()
        XCTAssertEqual(md(e), "bir\niki\n")
    }

    func testTabloTekBlok() {
        let e = editor("a\n\n| x | y |\n| --- | --- |\n| 1 | 2 |\n\nb\n")
        let ns = e.string as NSString
        let birim = e.blokBirimi(ns.range(of: "1").location)
        XCTAssertTrue(NSLocationInRange(ns.range(of: "x").location, birim))
        XCTAssertTrue(NSLocationInRange(ns.range(of: "2").location, birim))
        XCTAssertFalse(NSLocationInRange(ns.range(of: "a").location, birim))
        XCTAssertFalse(NSLocationInRange(ns.range(of: "b").location, birim))
    }

    private func uygulamaGibi(_ md: String) -> NotMetinGorunumu {
        let e = editor(md)
        e.textContainerInset = NSSize(width: kEditorYanPayi, height: kEditorDikeyBoslugu)
        e.textContainer?.size = NSSize(width: 600 - kEditorYanPayi * 2, height: .greatestFiniteMagnitude)
        e.layoutManager?.ensureLayout(for: e.textContainer!)
        return e
    }

    /// Kod ve uyarı kutusunda tutamaç çerçevenin dışında, solunda ve ilk satır hizasında.
    func testKutuTutamaciCerceveninSolunda() throws {
        let e = uygulamaGibi("önce\n```swift\nlet a = 1\nlet b = 2\n```\n> [!💡 mavi] uyarı\n> iki\nsonra\n")
        for metin in ["let a", "uyarı"] {
            let birim = e.blokBirimi((e.string as NSString).range(of: metin).location)
            let cerceve = try XCTUnwrap(e.blokGorselKaresi(birim))
            let tutamac = try XCTUnwrap(e.blokTutamacKaresi(birim))
            XCTAssertLessThanOrEqual(tutamac.maxX, cerceve.minX, metin)
            XCTAssertGreaterThanOrEqual(tutamac.minY, cerceve.minY - 1, metin)
            XCTAssertLessThan(tutamac.midY, cerceve.minY + 30, "\(metin): ilk satır hizasında")
        }
    }

    /// Bırakma çizgisi iki kutunun arasında durur, çerçevenin içine düşmez.
    func testBirakmaCizgisiKutularinArasinda() throws {
        let e = uygulamaGibi("a\n```\nk\n```\n> [!💡 mavi] u\nb\n")
        let ns = e.string as NSString
        let kod = e.blokBirimi(ns.range(of: "k").location)
        let kutu = e.blokBirimi(ns.range(of: "u").location)
        let kodKare = try XCTUnwrap(e.blokGorselKaresi(kod)), kutuKare = try XCTUnwrap(e.blokGorselKaresi(kutu))
        let sinir = try XCTUnwrap(e.blokSiniri(noktada: NSPoint(x: kodKare.midX, y: kodKare.maxY - 2), tasinan: e.blokBirimi(0)))
        XCTAssertEqual(sinir.konum, NSMaxRange(kod))
        XCTAssertGreaterThanOrEqual(sinir.y, kodKare.maxY)
        XCTAssertLessThanOrEqual(sinir.y, kutuKare.minY)
        XCTAssertNil(e.blokSiniri(noktada: NSPoint(x: 50, y: 2), tasinan: e.blokBirimi(0)), "kendi yeri hedef değil")
    }

    func testSuruklemeGorselleriEklenipKaldirilir() {
        let e = uygulamaGibi("bir\niki\n")
        let once = e.subviews.count
        let gorseller = BlokSuruklemeGorselleri(editor: e, birim: e.blokBirimi(0), tutulan: NSPoint(x: 50, y: 10))
        XCTAssertEqual(e.subviews.count, once + 3)
        XCTAssertNotNil(e.subviews.compactMap { $0 as? NSImageView }.first?.image, "yarı saydam kopya")
        gorseller.cizgiyiGoster(NSRect(x: 0, y: 20, width: 100, height: 8))
        gorseller.kaldir()
        XCTAssertEqual(e.subviews.count, once)
    }

    func testTutamacFareUzerindeGorunur() throws {
        let e = editor("bir\niki\n")
        e.textContainerInset = NSSize(width: kEditorYanPayi, height: kEditorDikeyBoslugu)
        e.layoutManager?.ensureLayout(for: e.textContainer!)
        let kare = try XCTUnwrap(e.blokIlkSatirKaresi(e.blokBirimi((e.string as NSString).range(of: "iki").location)))
        e.blokTutamaciniGuncelle(noktada: NSPoint(x: kare.minX + 5, y: kare.midY))
        XCTAssertFalse(e.blokTutamaci.isHidden)
        XCTAssertEqual(e.blokTutamaci.birim, e.blokBirimi((e.string as NSString).range(of: "iki").location))
        XCTAssertLessThan(e.blokTutamaci.frame.maxX, kare.minX, "tutamaç metnin solunda")
        e.blokTutamaciniGuncelle(noktada: nil)
        XCTAssertTrue(e.blokTutamaci.isHidden)
    }
}
