import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Uyarı/kod kutusunda yazı silmek kutuyu korur; yapılacak, madde ve numara işaretçileri
/// aynı boyutta ve hizada çizilir.
final class IsaretciVeKutuTestleri: XCTestCase {

    private func editor(_ md: String = "") -> NotMetinGorunumu {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        e.isRichText = true
        e.isEditable = true
        e.allowsUndo = true
        e.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        e.textStorage?.delegate = e
        if !md.isEmpty { e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md)) }
        return e
    }

    private func yaz(_ e: NotMetinGorunumu, _ metin: String) {
        for harf in metin { e.insertText(String(harf), replacementRange: NSRange(location: NSNotFound, length: 0)) }
    }

    private func md(_ e: NotMetinGorunumu) -> String { markdownMetniUret(e.textStorage!) }

    /// "Önce" paragrafından sonra uyarı ya da kod kutusu ekleyip içine "abc" yazar.
    private func kutuluEditor(kod: Bool) -> NotMetinGorunumu {
        let e = editor()
        yaz(e, "Önce")
        e.insertNewline(nil)
        e.insertNewline(nil)
        let imlec = NSRange(location: e.selectedRange().location, length: 0)
        if kod { e.kodBlogunuEkle(dil: "swift", komutAraligi: imlec) }
        else { e.menuBlogunuUygula(MetinBlogu(tur: .uyari, renk: "sarı", uyariKimligi: "k"), komutAraligi: imlec) }
        yaz(e, "abc")
        return e
    }

    // MARK: Kutular

    func testYeniKutununAltindaBosSatirOlur() {
        XCTAssertEqual(md(kutuluEditor(kod: false)), "Önce\n\n> [!💡 sarı] abc\n\n")
        XCTAssertEqual(md(kutuluEditor(kod: true)), "Önce\n\n```swift\nabc\n```\n\n")
    }

    func testKutudakiYaziSecilipSilinceKutuKalir() {
        for kod in [false, true] {
            for tumSatir in [false, true] {
                let e = kutuluEditor(kod: kod)
                let ns = e.string as NSString
                let abc = ns.range(of: "abc")
                e.setSelectedRange(tumSatir ? ns.paragraphRange(for: abc) : abc)
                e.deleteBackward(nil)
                yaz(e, "x")
                XCTAssertEqual(md(e), kod ? "Önce\n\n```swift\nx\n```\n\n" : "Önce\n\n> [!💡 sarı] x\n\n",
                               "kod: \(kod), tüm satır: \(tumSatir)")
            }
        }
    }

    func testSinirAsanSecimKutuyuSiler() {
        for kod in [false, true] {
            let e = kutuluEditor(kod: kod)
            let abc = (e.string as NSString).range(of: "abc")
            e.setSelectedRange(NSRange(location: 2, length: NSMaxRange(abc) - 2))
            e.deleteBackward(nil)
            XCTAssertEqual(md(e), "Ön\n\n", "kod: \(kod)")
        }
    }

    func testBosKutudaAyriGeriSilmeKutuyuKaldirir() {
        let e = kutuluEditor(kod: false)
        for _ in 0..<3 { e.deleteBackward(nil) }
        XCTAssertEqual(md(e), "Önce\n\n> [!💡 sarı] \n\n", "yazı gitti, kutu kaldı")
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "Önce\n\n\n\n")
    }

    // MARK: İşaretçiler

    private func cizilmis(_ md: String) -> (NotMetinGorunumu, NSWindow) {
        let e = editor(md)
        let pencere = NSWindow(contentRect: e.frame, styleMask: [.titled], backing: .buffered, defer: false)
        pencere.isReleasedWhenClosed = false
        pencere.contentView = e
        e.layoutManager?.ensureLayout(for: e.textContainer!)
        return (e, pencere)
    }

    private func satirKaresi(_ e: NotMetinGorunumu, _ parca: String) -> NSRect {
        let konum = (e.string as NSString).range(of: parca).location
        let yerlesim = e.layoutManager!
        return yerlesim.lineFragmentRect(forGlyphAt: yerlesim.glyphIndexForCharacter(at: konum), effectiveRange: nil)
    }

    /// ☐ yedek fonttan geldiği için satırı uzatıyor, ☑ başka boyutta çiziliyordu.
    func testYapilacakKutulariAyniBoyuttaSatirlarEsitYukseklikte() throws {
        let (e, pencere) = cizilmis("- [ ] açık\n- [x] tamam\n- madde\nDüz\n")
        defer { pencere.close() }
        let yukseklikler = ["açık", "tamam", "madde", "Düz"].map { satirKaresi(e, $0).height }
        XCTAssertEqual(Set(yukseklikler).count, 1, "\(yukseklikler)")
        let yerlesim = try XCTUnwrap(e.layoutManager as? NotYerlesimYoneticisi)
        let ns = e.string as NSString
        let acik = try XCTUnwrap(yerlesim.yapilacakKutusu(ns.range(of: "☐").location))
        let tamam = try XCTUnwrap(yerlesim.yapilacakKutusu(ns.range(of: "☑").location))
        XCTAssertEqual(acik.kare.size, tamam.kare.size)
        XCTAssertFalse(acik.tamam)
        XCTAssertTrue(tamam.tamam)
        XCTAssertNil(yerlesim.yapilacakKutusu(ns.range(of: "•").location))
    }

    func testCizilenKutuyaTiklamakGoreviIsaretler() throws {
        let (e, pencere) = cizilmis("- [ ] görev\n")
        defer { pencere.close() }
        let yerlesim = try XCTUnwrap(e.layoutManager as? NotYerlesimYoneticisi)
        let kare = try XCTUnwrap(yerlesim.yapilacakKutusu(0)).kare
        let nokta = NSPoint(x: kare.midX + e.textContainerOrigin.x, y: kare.midY + e.textContainerOrigin.y)
        XCTAssertTrue(e.yapilacakKutusunuDegistir(noktada: nokta))
        XCTAssertEqual(md(e), "- [x] görev\n")
    }

    /// "10." metni itip hizayı bozuyordu; numaralar sağa hizalanır, metin aynı yerden başlar.
    func testNumaraliListedeMetinAyniHizada() throws {
        let (e, pencere) = cizilmis("9. dokuz\n10. on\n99. doksan dokuz\n")
        defer { pencere.close() }
        let yerlesim = try XCTUnwrap(e.layoutManager)
        let ns = e.string as NSString
        let baslar = ["dokuz", "on\n", "doksan"].map { parca -> CGFloat in
            let glif = yerlesim.glyphIndexForCharacter(at: ns.range(of: parca).location)
            return yerlesim.location(forGlyphAt: glif).x
        }
        XCTAssertEqual(baslar[0], baslar[1], accuracy: 0.5)
        XCTAssertEqual(baslar[0], baslar[2], accuracy: 0.5)
    }

    func testSekmeliIcListeGorunurVeKayipsizKaydedilir() {
        let kaynak = "- üst\n\t- iç\n\t\t- [ ] derin\n1. bir\n   1. iç numara\n"
        let e = editor(kaynak)
        XCTAssertFalse(e.string.contains("\t- "), "iç liste ham metin kalmamalı")
        XCTAssertEqual(md(e), kaynak)
    }

    /// Boş ara satırı düz paragrafa çevirmek uyarıyı ikiye bölüyordu; kod bloğu gibi satır üsttekine katılır.
    func testUyaridaBosAraSatirGeriSilinceKutuBolunmez() {
        let e = editor("> [!💡 sarı] a\n> \n> b\n")
        let ns = e.string as NSString
        let bosSatir = ns.paragraphRange(for: NSRange(location: ns.range(of: "a").location, length: 0))
        e.setSelectedRange(NSRange(location: NSMaxRange(bosSatir) + 1, length: 0))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "> [!💡 sarı] a\n> b\n")
        var kimlikler = Set<String>()
        e.textStorage!.enumerateAttribute(kUyariKutusuAnahtari, in: NSRange(location: 0, length: e.textStorage!.length)) { deger, _, _ in
            if let deger = deger as? String { kimlikler.insert(deger) }
        }
        XCTAssertEqual(kimlikler.count, 1)
    }

    /// Enter'la açılan boş görevde satır yalnızca görünmez işaretten oluşuyordu; kutu üstteki satıra biniyordu.
    func testYeniBosGorevSatiriUsttekineBinmez() throws {
        let (e, pencere) = cizilmis("- [ ] bir\n")
        defer { pencere.close() }
        e.setSelectedRange(NSRange(location: (e.string as NSString).range(of: "bir").upperBound, length: 0))
        e.insertNewline(nil)
        e.layoutManager?.ensureLayout(for: e.textContainer!)
        let yerlesim = try XCTUnwrap(e.layoutManager as? NotYerlesimYoneticisi)
        let ns = e.string as NSString
        let ilk = try XCTUnwrap(yerlesim.yapilacakKutusu(0)).kare
        let ikinci = try XCTUnwrap(yerlesim.yapilacakKutusu(ns.range(of: "☐", options: .backwards).location)).kare
        XCTAssertGreaterThan(ikinci.minY, ilk.maxY, "kutular üst üste binmez")
        XCTAssertEqual(ikinci.minY - ilk.minY, satirKaresi(e, "bir").height, accuracy: 1.5, "satır aralığı eşit")
    }

    /// İlk satır boşken geri silme eskiden o satırı düz paragrafa çevirip kutunun başlığını
    /// koparıyordu; kutu doluyken ilk satırda geri silme bir şey yapmaz.
    func testUyarininBosIlkSatirindaGeriSilmeKutuyuBozmaz() {
        let e = editor("> [!💡 sarı] \n> alt satır\n")
        e.setSelectedRange(NSRange(location: 1, length: 0))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "> [!💡 sarı] \n> alt satır\n")
    }
}

