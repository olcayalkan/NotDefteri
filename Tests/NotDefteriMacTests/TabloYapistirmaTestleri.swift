import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Web sayfasından kopyalanan tablo hücreleri yan yana kalır: AppKit her hücreyi ayrı
/// paragraf yapıyordu, notta "x / Cut character / dw …" alt alta satırlara dönüşüyordu.
final class TabloYapistirmaTestleri: XCTestCase {

    private let pano = NSPasteboard(name: NSPasteboard.Name("notdefteri-tablo-yapistirma-testi"))

    override func tearDown() {
        pano.releaseGlobally()
        super.tearDown()
    }

    private let vimHtml = """
        <meta charset="utf-8"><h3>Vim</h3><table><tbody>
        <tr><td><code>x</code></td><td>Cut character</td></tr>
        <tr><td><code>dw</code></td><td>Cut word</td></tr>
        <tr><td><code>dd</code></td><td>Cut full line</td></tr>
        <tr><td><code>yw</code></td><td>Copy word</td></tr>
        <tr><td><code>yy</code></td><td>Copy full line</td></tr>
        <tr><td><code>p</code></td><td>Paste</td></tr>
        </tbody></table>
        """

    private func zengin(_ html: String) throws -> NSAttributedString {
        try NSAttributedString(data: Data(html.utf8),
                               options: [.documentType: NSAttributedString.DocumentType.html,
                                         .characterEncoding: String.Encoding.utf8.rawValue],
                               documentAttributes: nil)
    }

    /// Editörün gerçek ⌘V yolu: panodaki HTML okunur, sonuç Markdown olarak kaydedilir.
    private func yapistir(_ html: String, tur: NSPasteboard.PasteboardType = .html) throws -> String {
        pano.clearContents()
        if tur == .rtf {
            let kaynak = try zengin(html)
            pano.setData(try XCTUnwrap(kaynak.rtf(from: NSRange(location: 0, length: kaynak.length))), forType: .rtf)
        } else {
            pano.setData(Data(html.utf8), forType: .html)
        }
        let gorunum = NotMetinGorunumu()
        XCTAssertTrue(gorunum.readSelection(from: pano, type: tur))
        let depo = try XCTUnwrap(gorunum.textStorage)
        ekran = depo.string
        let kose = (depo.string as NSString).range(of: "┌")
        ekranKoseStili = kose.location == NSNotFound ? nil
            : depo.attribute(.paragraphStyle, at: kose.location, effectiveRange: nil) as? NSParagraphStyle
        return markdownMetniUret(depo)
    }

    /// Son yapıştırmadan sonra editörde görünen metin.
    private var ekran = ""
    /// Tablonun ilk köşesindeki paragraf stili; kutu görünümü kurulmadıysa satır kırılır.
    private var ekranKoseStili: NSParagraphStyle?

    /// Kayıt Markdown tablosu olsa da ekranda ham `| a | b |` değil, `/tablo` gibi kutu görünür.
    func testYapistirilanTabloEkrandaKutuOlarakGorunur() throws {
        _ = try yapistir(vimHtml)
        XCTAssertTrue(ekran.contains("┌"), ekran)
        XCTAssertTrue(ekran.contains("│ dw "), ekran)
        XCTAssertFalse(ekran.contains("| dw |"), ekran)
        let stil = try XCTUnwrap(ekranKoseStili, "tablo görünümü kurulmadı")
        XCTAssertEqual(stil.firstLineHeadIndent, 14, "tablo girintisi")
        XCTAssertNotEqual(stil.lineBreakMode, .byWordWrapping, "kutu satırları pencereyle kırılmaz")
    }

    func testWebTablosuYanYanaKalir() throws {
        let sonuc = try yapistir(vimHtml)
        XCTAssertTrue(sonuc.contains("Vim"), sonuc)
        XCTAssertTrue(sonuc.contains("""
            | x | Cut character |
            | --- | --- |
            | dw | Cut word |
            """), sonuc)
        XCTAssertTrue(sonuc.contains("| p | Paste |"), sonuc)
        XCTAssertFalse(sonuc.contains("x\nCut character"), "hücreler alt alta düşmez")
    }

    /// Obsidian bitişik tabloyu göstermez; alttaki metin de tabloya satır olarak katılırdı.
    func testTablonunIkiYanindaBosSatirOlur() throws {
        let sonuc = try yapistir("<p>önce</p><table><tr><td>A</td><td>B</td></tr><tr><td>1</td><td>2</td></tr></table><p>sonra</p>")
        XCTAssertTrue(sonuc.contains("önce\n\n| A | B |"), sonuc)
        XCTAssertTrue(sonuc.contains("| 1 | 2 |\n\nsonra"), sonuc)
    }

    /// Safari panoya RTF koyar; tablo bilgisi orada da `NSTextTable` olarak gelir.
    func testRtfTablosuYanYanaKalir() throws {
        let sonuc = try yapistir(vimHtml, tur: .rtf)
        XCTAssertTrue(sonuc.contains("| dd | Cut full line |"), sonuc)
    }

    func testTablonunOncesiVeSonrasiKorunur() throws {
        let parcalar = MacBelgeAdaptoru.tablolaraBol(try zengin(
            "<p>önce</p><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table><p>sonra</p>"))
        guard parcalar.count == 3,
              case .metin(let once) = parcalar[0], case .tablo(let tablo) = parcalar[1],
              case .metin(let sonra) = parcalar[2] else { return XCTFail("\(parcalar)") }
        XCTAssertEqual(once.string, "önce\n")
        XCTAssertEqual(tablo, "| A | B |\n| --- | --- |\n| 1 | 2 |\n")
        XCTAssertEqual(sonra.string, "sonra\n")
    }

    /// Başlık hücreleri (`th`) ilk satır olur; hücredeki `|` sütunu bölmez, kayıt yeniden
    /// açılınca aynı tablo döner.
    func testBaslikliVeBorulukWebTablosuTabloOlarakKaydolur() throws {
        let sonuc = try yapistir("""
            <meta charset="utf-8"><table><thead><tr><th>State</th><th>Meaning</th><th>Implication</th></tr></thead><tbody>
            <tr><td>open</td><td>Accepts connections</td><td>Service actively running</td></tr>
            <tr><td>open|filtered</td><td>Open or filtered</td><td>Cannot determine exact state</td></tr>
            </tbody></table>
            """)
        let tablo = """
            | State | Meaning | Implication |
            | --- | --- | --- |
            | open | Accepts connections | Service actively running |
            | open\\|filtered | Open or filtered | Cannot determine exact state |

            """
        XCTAssertTrue(sonuc.contains(tablo), sonuc)
        XCTAssertEqual(markdownMetniUret(markdowndenAttributedStringUret(sonuc)), sonuc, "yeniden açılınca aynen kaydolur")
    }

    /// Tek satırlık ya da tek sütunlu "tablo" (düzen için kullanılan) metin olarak kalır.
    func testTabloSayilmayanIcerikMetinKalir() throws {
        let parcalar = MacBelgeAdaptoru.tablolaraBol(try zengin("<table><tr><td>yalnız</td><td>satır</td></tr></table>"))
        XCTAssertEqual(parcalar.count, 1)
        guard case .metin = parcalar.first else { return XCTFail("\(parcalar)") }
    }
}
