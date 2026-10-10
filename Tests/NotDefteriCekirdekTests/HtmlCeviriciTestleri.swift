import XCTest
@testable import NotDefteriCekirdek

/// Tek dosya HTML dışa aktarımı: kaçırma, biçimler, bloklar ve güvenli bağlantılar.
final class HtmlCeviriciTestleri: GeciciKokTestCase {

    private func govde(_ md: String, baslik: String = "Sayfa") throws -> String {
        let html = try htmlUret(markdown: md, baslik: baslik, taban: kok)
        let bas = try XCTUnwrap(html.range(of: "<body>")).upperBound
        let son = try XCTUnwrap(html.range(of: "</body>")).lowerBound
        return String(html[bas..<son])
    }

    func testHtmlKacirma() {
        XCTAssertEqual(htmlKacir(#"<a href="x">'&'</a>"#), "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;")
    }

    func testBelgeIskeletiVeBaslik() throws {
        let html = try htmlUret(markdown: "metin", baslik: "<Başlık>", taban: kok)
        XCTAssertTrue(html.hasPrefix("<!doctype html>"))
        XCTAssertTrue(html.contains(#"<html lang="tr">"#))
        XCTAssertTrue(html.contains("<title>&lt;Başlık&gt;</title>"))
        XCTAssertTrue(html.contains("prefers-color-scheme:dark"), "koyu tema stili gömülü olmalı")
    }

    /// Not metnindeki HTML çalıştırılabilir etiket olarak geçmemeli.
    func testMetindekiHtmlKacirilir() throws {
        let g = try govde("<script>alert(1)</script>")
        XCTAssertFalse(g.contains("<script>"))
        XCTAssertTrue(g.contains("&lt;script&gt;"))
    }

    func testSatirIciBicimler() throws {
        let g = try govde("**kalın** *italik* ~~çizik~~ ==vurgu== `kod`")
        for etiket in ["<strong>kalın</strong>", "<em>italik</em>", "<del>çizik</del>", "<mark>vurgu</mark>", "<code>kod</code>"] {
            XCTAssertTrue(g.contains(etiket), etiket)
        }
    }

    /// Paragraf aralığı satır sonunu da içerir; etiket içindeki boşluk görüntüyü değiştirmez.
    func testBasliklarVeParagraf() throws {
        let g = try govde("# Bir\n## İki\nparagraf")
        for desen in [#"<h1>Bir\s*</h1>"#, #"<h2>İki\s*</h2>"#, #"<p>paragraf\s*</p>"#] {
            XCTAssertNotNil(g.range(of: desen, options: .regularExpression), desen)
        }
    }

    func testListeVeGorevler() throws {
        let g = try govde("- madde\n3. üç\n- [x] bitti\n- [ ] açık")
        XCTAssertTrue(g.contains("<ul"))
        XCTAssertTrue(g.contains(#"<ol start="3""#))
        XCTAssertTrue(g.contains("checked"))
        XCTAssertEqual(g.components(separatedBy: "type=checkbox").count - 1, 2)
    }

    func testKodBloguKacirilir() throws {
        let g = try govde("```html\n<b>x</b>\n```")
        XCTAssertTrue(g.contains("<pre><code>"))
        XCTAssertTrue(g.contains("&lt;b&gt;x&lt;/b&gt;"))
        XCTAssertFalse(g.contains("<strong>"), "kod içindeki işaretler biçim sayılmamalı")
    }

    func testUyariKutusuTekKutudaToplanir() throws {
        let g = try govde("> [!🔥 kırmızı] ilk\n> devam\nsonra")
        XCTAssertEqual(g.components(separatedBy: "class=uyari").count - 1, 1)
        XCTAssertTrue(g.contains("220,60,60"))
        XCTAssertTrue(g.contains("🔥"))
    }

    func testGuvenliBaglantiVerilir() throws {
        XCTAssertTrue(try govde("[site](https://example.com)").contains(#"<a href="https://example.com">site</a>"#))
    }

    /// javascript: gibi şemalar tıklanabilir bağa dönüşmemeli.
    func testTehlikeliSemaBaglanmaz() throws {
        XCTAssertFalse(try govde("[x](javascript:alert(1))").contains("<a href"))
        XCTAssertFalse(disBaglantiGecerliMi(URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(disBaglantiGecerliMi(URL(string: "file:///etc/passwd")!))
        XCTAssertTrue(disBaglantiGecerliMi(URL(string: "mailto:a@b.c")!))
    }

    func testKokIcindekiGorselGomulur() throws {
        let klasor = kok.appendingPathComponent("Sayfa")
        try fm.createDirectory(at: klasor.appendingPathComponent(kGorsellerKlasorAdi), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: klasor.appendingPathComponent("\(kGorsellerKlasorAdi)/r.png"))

        let html = try htmlUret(markdown: "![](\(kGorsellerKlasorAdi)/r.png){120x60}", baslik: "S", taban: klasor)
        XCTAssertTrue(html.contains("data:image/png;base64,iVBORw=="))
        XCTAssertTrue(html.contains("width:120px"))
    }

    func testGorselMimeTurleri() throws {
        let dosya = kok.appendingPathComponent("a.JPG")
        try Data([1, 2, 3]).write(to: dosya)
        XCTAssertEqual(try htmlGorseli(dosya), "data:image/jpeg;base64,AQID")
    }
}
