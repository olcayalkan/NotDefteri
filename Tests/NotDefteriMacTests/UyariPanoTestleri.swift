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

    /// Kutunun içine yapıştırılan kutu satırı ikinci kutu doğurmaz; aynı kutunun satırı olur.
    func testKutuIcineYapistirmaBosKutuDogurmaz() {
        let sonuc = kopyalaYapistir("önce\n\(kutu)sonra\n", kopya: (2, 2), hedef: 3, satirSonu: true)
        XCTAssertEqual(sonuc, "önce\n\(kutu)> iki\nsonra\n")
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
        XCTAssertEqual(md(e), "önce\n> [!💡 mavi] bir\n> bir\n> iki\n> üç\n> iki\n> üç\nsonra\n")
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

    // MARK: Kısmi kopya, kutuya/koda yapıştırma

    /// Metindeki ilk eşleşmeyi seçip kopyalar; hedefteki ilk eşleşmenin önüne (ya da sonuna) yapıştırır.
    private func parcaKopyala(_ kaynak: String, sec: String, hedef: String, sonuna: Bool = false) -> String {
        let e = editor(kaynak)
        let ns = e.string as NSString
        e.setSelectedRange(ns.range(of: sec))
        NSPasteboard.general.clearContents()
        e.copy(nil)
        let h = ns.range(of: hedef, options: sonuna ? .backwards : [])
        e.setSelectedRange(NSRange(location: sonuna ? NSMaxRange(h) : h.location, length: 0))
        e.paste(nil)
        return md(e)
    }

    /// Kutunun içinden alınan sözcük düz metindir; yapıştırıldığı yerde alıntı ya da kutu doğurmaz.
    func testKutudanKismiKopyaBlokTasimaz() {
        XCTAssertEqual(parcaKopyala("önce\n\(kutu)sonra\n", sec: "ik", hedef: "sonra"),
                       "önce\n\(kutu)iksonra\n")
    }

    /// Başka renkteki kutu, kutunun satır ortasına yapıştırılınca hedef kutunun satırları olur.
    func testKutuIcineKutuYapistirmaTekKutuKalir() {
        let e = editor("> [!🔥 kırmızı] xy\n")
        let kaynak = editor(kutu)
        kaynak.setSelectedRange(NSRange(location: 0, length: (kaynak.string as NSString).length))
        NSPasteboard.general.clearContents()
        kaynak.copy(nil)
        e.setSelectedRange(NSRange(location: (e.string as NSString).range(of: "y").location, length: 0))
        e.paste(nil)
        XCTAssertEqual(md(e), "> [!🔥 kırmızı] x\n> bir\n> iki\n> üç\n> y\n")
    }

    /// Kutuya yapıştırılan kod bloğu kutunun satırı olur; kutunun içinde çit doğmaz.
    func testKutuIcineKodYapistirmaKutuSatiriOlur() {
        XCTAssertEqual(parcaKopyala("```\nabc\n```\n\(kutu)", sec: "\u{200B}abc\n", hedef: "üç", sonuna: true),
                       "```\nabc\n```\n\(kutu.dropLast())\n> abc\n")
    }

    /// Koda yapıştırılan kutu düz metin olur; görünmez blok işaretleri koda karışmaz.
    func testKodaKutuYapistirmaGorunmezIsaretBirakmaz() {
        let sonuc = parcaKopyala("\(kutu)```\nabc\n```\n", sec: "\u{200B}bir\n\u{200B}iki", hedef: "abc", sonuna: true)
        XCTAssertFalse(sonuc.contains("\u{200B}"), "kayda görünmez işaret sızmamalı")
        XCTAssertEqual(sonuc, "\(kutu)```\nabcbir\niki\n```\n")
    }

    // MARK: Kod bloğunda Enter ve dışarıdan yapıştırma

    /// Kodun son satırında üç Enter koddan çıkar; yazılan metin kutunun altına düşer.
    func testKoddaUcEnterKutudanCikar() {
        let e = editor("```\nabc\n```\n")
        e.setSelectedRange(NSRange(location: NSMaxRange((e.string as NSString).range(of: "abc")), length: 0))
        e.insertNewline(nil)
        e.insertNewline(nil)
        e.insertNewline(nil)
        e.insertText("x", replacementRange: e.selectedRange())
        XCTAssertEqual(md(e), "```\nabc\n```\nx\n")
    }

    /// Enter'dan sonra koda yapıştırılan, kodun dışındaki satırlar: liste işareti ("•\t") koda
    /// sızmaz, tam satırın satır sonu kodda boş satır bırakmaz.
    func testKodaDisaridanSatirYapistirmaKoduBozmaz() {
        for (sec, beklenen) in [("madde", "madde"), ("Başlık", "Başlık"), ("kutu1", "kutu1\nkutu2")] {
            let e = editor("# Başlık\n- madde\n\(kutu.replacingOccurrences(of: "bir", with: "kutu1").replacingOccurrences(of: "iki", with: "kutu2"))```\nabc\n```\n")
            let ns = e.string as NSString
            var aralik = ns.paragraphRange(for: ns.range(of: sec))
            if sec == "kutu1" { aralik = NSUnionRange(aralik, ns.paragraphRange(for: ns.range(of: "kutu2"))) }
            e.setSelectedRange(aralik)
            NSPasteboard.general.clearContents()
            e.copy(nil)
            e.setSelectedRange(NSRange(location: NSMaxRange(ns.range(of: "abc")), length: 0))
            e.insertNewline(nil)
            e.paste(nil)
            XCTAssertTrue(md(e).hasSuffix("```\nabc\n\(beklenen)\n```\n"), md(e))
        }
    }

    /// Başka uygulamadan gelen çok satırlı metin de kodda boş satır bırakmaz.
    func testKodaDisUygulamadanTamSatirYapistirma() {
        let e = editor("```\nabc\n```\n")
        e.setSelectedRange(NSRange(location: NSMaxRange((e.string as NSString).range(of: "abc")), length: 0))
        e.insertNewline(nil)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("dış1\ndış2\n", forType: .string)
        e.paste(nil)
        XCTAssertEqual(md(e), "```\nabc\ndış1\ndış2\n```\n")
    }

    /// Dışarıdan başlayıp kodun ortasında biten seçim silinince, üzerine yazılınca ya da
    /// yapıştırılınca kalan kod kendi satırında kod olarak kalır; kayıtta çoğalmaz.
    func testKodaUzananSecimKoduBozmaz() {
        for islem in ["sil", "yaz", "yapistir"] {
            let e = editor("önce\n```\nabc\ndef\n```\nsonra\n")
            let ns = e.string as NSString
            e.setSelectedRange(NSRange(location: 2, length: ns.range(of: "bc").location - 2))
            switch islem {
            case "sil": e.deleteBackward(nil)
            case "yaz": e.insertText("X", replacementRange: e.selectedRange())
            default:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("X", forType: .string)
                e.paste(nil)
            }
            XCTAssertEqual(md(e), "ön\(islem == "sil" ? "" : "X")\n```\nbc\ndef\n```\nsonra\n", islem)
            let kod = (e.string as NSString).range(of: "bc").location - 1
            XCTAssertNotNil(e.textStorage?.attribute(kBlokIsaretiAnahtari, at: kod, effectiveRange: nil), islem)
        }
    }

    /// Aynı kural uyarı kutusunda: dışarıdan kutunun ortasına uzanan seçim silinince kutu kalır.
    func testKutuyaUzananSecimSilinceKutuKalir() {
        let e = editor("önce\n\(kutu)sonra\n")
        let ns = e.string as NSString
        e.setSelectedRange(NSRange(location: 2, length: ns.range(of: "ki").location - 2))
        e.deleteBackward(nil)
        XCTAssertEqual(md(e), "ön\n> [!💡 mavi] ki\n> üç\nsonra\n")
    }

    /// Satır başından kodun içine uzanan seçime yazılan metin kendi satırında kalır, koda karışmaz.
    func testSatirBasindanKodaUzananSecimeYazmaKodaKarismaz() {
        for yapistir in [false, true] {
            let e = editor("önce\n```\nabc\n```\n")
            e.setSelectedRange(NSRange(location: 0, length: (e.string as NSString).range(of: "bc").location))
            if yapistir {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("X", forType: .string)
                e.paste(nil)
            } else {
                e.insertText("X", replacementRange: e.selectedRange())
            }
            XCTAssertEqual(md(e), "X\n```\nbc\n```\n")
        }
    }

    /// Kodun tüm gövdesi seçiliyken yapıştırma görünmez blok işaretini silmez.
    func testKodGovdesiSeciliykenYapistirmaIsaretiKorur() {
        let e = editor("```\nabc\n```\n")
        e.setSelectedRange(NSRange(location: 0, length: (e.string as NSString).length))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("X\n", forType: .string)
        e.setSelectedRange(NSRange(location: 1, length: 3))
        e.paste(nil)
        XCTAssertEqual(md(e), "```\nX\n```\n")
        XCTAssertNotNil(e.textStorage?.attribute(kBlokIsaretiAnahtari, at: 0, effectiveRange: nil))
    }
}
