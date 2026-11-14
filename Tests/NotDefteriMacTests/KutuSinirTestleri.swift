import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Kod bloğu ve uyarı kutusunun sınırı: dışarıda yazılan kutuya girmez, silme kutuyla dış satırı birleştirmez.
/// Her iki kutu türü aynı kuralı izler.
final class KutuSinirTestleri: XCTestCase {
    private let kutular = ["```\nbir\niki\n```", "> [!💡 mavi] bir\n> iki"]

    private func editor(_ md: String) -> NotMetinGorunumu {
        _ = NSApplication.shared
        let e = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        e.isRichText = true; e.isEditable = true; e.allowsUndo = true
        e.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        e.textStorage?.delegate = e
        e.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(md))
        return e
    }

    private func md(_ e: NotMetinGorunumu) -> String { markdownMetniUret(e.textStorage!) }
    private func konum(_ e: NotMetinGorunumu, _ metin: String) -> NSRange { (e.string as NSString).range(of: metin) }
    private func yaz(_ e: NotMetinGorunumu, _ metin: String) { e.insertText(metin, replacementRange: NSRange(location: NSNotFound, length: 0)) }

    /// Belge sonundaki kutunun altına yazılan metin kutuya (koda) karışmaz.
    func testBelgeSonundaKutununAltinaYazilanDisaridaKalir() {
        for kutu in kutular {
            let e = editor("ust\n\(kutu)\n")
            e.setSelectedRange(NSRange(location: e.textStorage!.length, length: 0))
            e.blokYaziminiGuncelle()
            yaz(e, "dis")
            XCTAssertEqual(md(e), "ust\n\(kutu)\ndis", kutu)
        }
    }

    /// Satır sonu olmadan biten çitin ardına yazılan metin, yeniden açılınca koda dönüşmez.
    func testSatirSonsuzCitinArdindakiMetinKodaGirmez() {
        let e = editor("ust\n```\nbir\n```")
        e.setSelectedRange(NSRange(location: e.textStorage!.length, length: 0))
        e.blokYaziminiGuncelle()
        yaz(e, "dis")
        XCTAssertEqual(md(e), "ust\n```\nbir\n```\ndis")
    }

    /// Alt satırın başında geri silme kutuyla birleştirmez; imleç kutunun sonuna geçer.
    func testKutuAltindaGeriSilmeBirlestirmez() {
        for kutu in kutular {
            let e = editor("ust\n\(kutu)\nalt\n")
            e.setSelectedRange(NSRange(location: konum(e, "alt").location, length: 0))
            e.deleteBackward(nil)
            XCTAssertEqual(md(e), "ust\n\(kutu)\nalt\n", kutu)
            XCTAssertEqual(e.selectedRange().location, NSMaxRange(konum(e, "iki")), kutu)
            for sil in [{ e.deleteWordBackward(nil) }, { e.deleteToBeginningOfLine(nil) }] {
                e.setSelectedRange(NSRange(location: konum(e, "alt").location, length: 0))
                sil()
                XCTAssertEqual(md(e), "ust\n\(kutu)\nalt\n", kutu)
            }
        }
    }

    /// Kutunun son satırında ileri silme alttaki dolu satırı içeri çekmez; boş satırı siler.
    func testKutuSonundaIleriSilme() {
        for kutu in kutular {
            let e = editor("ust\n\(kutu)\nalt\n")
            e.setSelectedRange(NSRange(location: NSMaxRange(konum(e, "iki")), length: 0))
            e.deleteForward(nil)
            e.deleteWordForward(nil)
            XCTAssertEqual(md(e), "ust\n\(kutu)\nalt\n", kutu)
            let b = editor("ust\n\(kutu)\n\nalt\n")
            b.setSelectedRange(NSRange(location: NSMaxRange(konum(b, "iki")), length: 0))
            b.deleteForward(nil)
            XCTAssertEqual(md(b), "ust\n\(kutu)\nalt\n", kutu)
            b.deleteForward(nil)
            XCTAssertEqual(md(b), "ust\n\(kutu)\nalt\n", kutu)
        }
    }

    /// Kutunun altındaki boş satırda geri silme o satırı kaldırır, kutu bütün kalır.
    func testKutuAltindakiBosSatirSilinir() {
        for kutu in kutular {
            let e = editor("ust\n\(kutu)\n\nalt\n")
            e.setSelectedRange(NSRange(location: konum(e, "alt").location - 1, length: 0))
            e.deleteBackward(nil)
            XCTAssertEqual(md(e), "ust\n\(kutu)\nalt\n", kutu)
        }
    }

    /// İki kutu aynı kural: son satırdan üçüncü Enter çıkar (belge sonunda da), ortadaki boş satırlar kalır.
    func testUcuncuEnterHerKutudanCikar() {
        for kutu in kutular {
            for alt in ["", "alt\n"] {
                let e = editor("ust\n\(kutu)\n\(alt)")
                e.setSelectedRange(NSRange(location: NSMaxRange(konum(e, "iki")), length: 0))
                for _ in 0..<3 { e.insertNewline(nil) }
                yaz(e, "dis")
                XCTAssertEqual(md(e), "ust\n\(kutu)\ndis\n\(alt)", kutu)
            }
            let o = editor("ust\n\(kutu)\n")
            o.setSelectedRange(NSRange(location: NSMaxRange(konum(o, "bir")), length: 0))
            for _ in 0..<3 { o.insertNewline(nil) }
            XCTAssertNotNil(kKutuAnahtarlari.first { o.textStorage!.attribute($0, at: o.selectedRange().location, effectiveRange: nil) != nil },
                            "ortadaki boş satırlar kutuda kalır: \(kutu)")
        }
    }

    /// Belge kutuyla başlayınca kutunun üst kenarı görünümün içinde kalır (TextKit ilk satıra üst
    /// boşluk vermiyordu, kenar kesiliyordu); düz ilk satır eskisi gibi boşluksuz.
    func testBelgeBasindakiKutununUstKenariGorunur() {
        for kutu in kutular {
            let e = editor("\(kutu)\nalt\n")
            e.layoutManager!.delegate = e   // pencereye eklenince kurulur
            e.layoutManager!.ensureLayout(for: e.textContainer!)
            let kare = e.blokCerceveKaresi(NSRange(location: 0, length: 1), anahtar: kKutuAnahtarlari.first {
                e.textStorage!.attribute($0, at: 0, effectiveRange: nil) != nil }!)
            XCTAssertGreaterThanOrEqual(kare?.minY ?? -1, 0, kutu)
        }
        let duz = editor("duz\n")
        XCTAssertEqual(duz.layoutManager(duz.layoutManager!, paragraphSpacingBeforeGlyphAt: 0, withProposedLineFragmentRect: .zero), 0)
    }

    /// Kutunun üstündeki satırın sonundan ileri silme kutunun ilk satırını dışarı çekmez.
    func testKutuUstundenIleriSilme() {
        for kutu in kutular {
            let e = editor("ust\n\(kutu)\n")
            e.setSelectedRange(NSRange(location: NSMaxRange(konum(e, "ust")), length: 0))
            e.deleteForward(nil)
            XCTAssertEqual(md(e), "ust\n\(kutu)\n", kutu)
        }
    }
}
