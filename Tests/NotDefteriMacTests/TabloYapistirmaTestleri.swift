import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Web sayfasından kopyalanan tablonun her satırı tek satır olarak yapışır, hücreler sekmeyle
/// ayrılır (tarayıcının düz metin kopyası gibi). AppKit her hücreyi ayrı paragraf yapıyordu;
/// notta "x / Cut character / dw …" alt alta satırlara dönüşüyordu. Tablo oluşturulmaz.
final class TabloYapistirmaTestleri: XCTestCase {

    private let pano = NSPasteboard(name: NSPasteboard.Name("notdefteri-tablo-yapistirma-testi"))

    override func tearDown() {
        pano.releaseGlobally()
        super.tearDown()
    }

    /// Chrome'un panoya koyduğu biçimde: başlık hücreleri `th`, komutlar `code` içinde.
    private let vimHtml = """
        <meta charset="utf-8"><table><thead><tr><th>Command</th><th>Description</th></tr></thead><tbody>
        <tr><td><code>x</code></td><td>Cut character</td></tr>
        <tr><td><code>dw</code></td><td>Cut word</td></tr>
        <tr><td><code>dd</code></td><td>Cut full line</td></tr>
        <tr><td><code>yw</code></td><td>Copy word</td></tr>
        <tr><td><code>yy</code></td><td>Copy full line</td></tr>
        <tr><td><code>p</code></td><td>Paste</td></tr>
        </tbody></table>
        """

    /// Başlık hücreleri (`th`) kaynaktaki gibi kalın kalır.
    private let vimSatirlari = "**Command\tDescription**\nx\tCut character\ndw\tCut word\ndd\tCut full line\n"
        + "yw\tCopy word\nyy\tCopy full line\np\tPaste\n"

    private func zengin(_ html: String) throws -> NSAttributedString {
        try NSAttributedString(data: Data(html.utf8),
                               options: [.documentType: NSAttributedString.DocumentType.html,
                                         .characterEncoding: String.Encoding.utf8.rawValue],
                               documentAttributes: nil)
    }

    /// Editörün gerçek ⌘V yolu: panodaki HTML/RTF okunur, sonuç Markdown olarak kaydedilir.
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
        return markdownMetniUret(try XCTUnwrap(gorunum.textStorage))
    }

    func testWebTablosununSatirlariYanYanaKalir() throws {
        let sonuc = try yapistir(vimHtml)
        XCTAssertTrue(sonuc.contains(vimSatirlari), sonuc)
        XCTAssertFalse(sonuc.contains("|"), "tablo oluşturulmaz")
    }

    /// Safari panoya RTF koyar; tablo bilgisi orada da `NSTextTable` olarak gelir.
    func testRtfTablosununSatirlariYanYanaKalir() throws {
        XCTAssertTrue(try yapistir(vimHtml, tur: .rtf).contains("dd\tCut full line\n"))
    }

    func testTablonunOncesiVeSonrasiKorunur() throws {
        let sonuc = try yapistir("<p>önce</p><table><tr><td>A</td><td>B</td></tr></table><p>sonra</p>")
        XCTAssertTrue(sonuc.contains("önce\nA\tB\nsonra"), sonuc)
    }

    /// Aynı hücredeki iki paragraf hücreyi bölmez, boşlukla birleşir.
    func testHucreIcindekiParagraflarBirlesir() throws {
        let birlesik = MacBelgeAdaptoru.tabloSatirlariniBirlestir(
            try zengin("<table><tr><td><p>bir</p><p>iki</p></td><td>yan</td></tr></table>"))
        XCTAssertEqual(birlesik.string, "bir iki\tyan\n")
    }

    func testTablosuzIcerikDegismez() throws {
        let kaynak = try zengin("<p>bir</p><p>iki</p>")
        XCTAssertEqual(MacBelgeAdaptoru.tabloSatirlariniBirlestir(kaynak).string, kaynak.string)
    }
}
