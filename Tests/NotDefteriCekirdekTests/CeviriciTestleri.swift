import XCTest
@testable import NotDefteriCekirdek

/// Markdown <-> AttributedString çeviricisinin testleri.
/// En kritik olan gidiş-dönüş: metin çevrilip geri döndüğünde özdeş kalmalı.
final class CeviriciTestleri: XCTestCase {

    /// `markdown -> attr -> markdown` dönüşünün metni bozmadığını doğrular.
    private func gidisDonusKontrol(_ metin: String,
                                    _ mesaj: String = "",
                                    dosya: StaticString = #filePath,
                                    satir: UInt = #line) {
        let attr = markdowndenAttributedStringUret(metin)
        let geri = markdownMetniUret(attr)
        XCTAssertEqual(geri, metin, mesaj, file: dosya, line: satir)
    }

    // MARK: Gidiş-dönüş

    func testDuzMetinKorunur() {
        gidisDonusKontrol("merhaba dünya")
        gidisDonusKontrol("birinci satır\nikinci satır")
        gidisDonusKontrol("Türkçe karakterler: ğüşıöç ĞÜŞİÖÇ")
    }

    func testKalinKorunur() {
        gidisDonusKontrol("**kalın**")
        gidisDonusKontrol("önce **kalın** sonra")
    }

    func testBasliklarKorunur() {
        gidisDonusKontrol("# Başlık 1\n")
        gidisDonusKontrol("## Başlık 2\n")
        gidisDonusKontrol("### Başlık 3\n")
        gidisDonusKontrol("# Başlık\nnormal metin\n")
    }

    func testPuntoEtiketiKorunur() {
        gidisDonusKontrol("<punto=18>büyük</punto>")
        gidisDonusKontrol("normal<punto=10>küçük</punto>normal")
    }

    func testBosMetin() {
        gidisDonusKontrol("")
    }

    // MARK: Obsidian sözdizimi — gidiş-dönüşte bozulmamalı
    //
    // Bu biçimleri uygulama TANIMIYOR ama metin olarak korumalı;
    // aksi hâlde Obsidian'da yazılan not NotDefteri'nde kaydedilince bozulur.

    func testTanimayanSozdizimiMetinOlarakKorunur() {
        gidisDonusKontrol("- birinci\n- ikinci\n", "liste")
        gidisDonusKontrol("- [ ] görev\n- [x] biten\n", "onay kutusu")
        gidisDonusKontrol("| a | b |\n|---|---|\n| 1 | 2 |\n", "tablo")
        gidisDonusKontrol("```swift\nlet x = 1\n```\n", "kod bloğu")
        gidisDonusKontrol("---\ntags: [a]\n---\n\nmetin\n", "frontmatter")
        gidisDonusKontrol("[[Başka Not]]\n", "wikilink")
        gidisDonusKontrol("[metin](http://a.com)\n", "bağlantı")
        gidisDonusKontrol("*italik*\n", "italik")
        gidisDonusKontrol("> alıntı satırı\n", "alıntı")
        gidisDonusKontrol("#### dört\n", "4+ seviye başlık desteklenmiyor")
        gidisDonusKontrol("<b>kalın</b>\n", "ham HTML")
    }

    /// Kod bloğu içindeki işaretleme yorumlanmamalı.
    func testKodBlogundakiIsaretlemeYorumlanmaz() {
        gidisDonusKontrol("```\n# başlık değil\n```\n")
        gidisDonusKontrol("```\n<punto=20>metin</punto>\n```\n")
        gidisDonusKontrol("```\na ** b\n```\n")
    }

    // MARK: Eşleşmemiş işaretleme
    //
    // Bu testler bir hatayı yakaladı: kapanışı olmayan "**" ya da "<punto=..>"
    // biçim başlatıyor, geri yazarken sona uydurma bir kapanış ekleniyordu.
    // "2 ** 3 = 8" kaydedince "2 ** 3 = 8\n**" oluyordu.

    func testEslesmemisKalinIsaretiDuzMetinKalir() {
        gidisDonusKontrol("2 ** 3 = 8\n", "çarpma işareti bozulmamalı")
        gidisDonusKontrol("yıldız * ortada\n")
        gidisDonusKontrol("tek ** açık kaldı")
    }

    func testEslesmemisPuntoEtiketiDuzMetinKalir() {
        gidisDonusKontrol("<punto=16>açık kaldı\n")
    }

    /// Gidiş-dönüş kararlı olmalı: ikinci tur birinciyle aynı sonucu vermeli.
    func testGidisDonusKararli() {
        for metin in ["2 ** 3 = 8\n", "<punto=16>açık\n", "**kalın**", "# Başlık\n"] {
            let bir = markdownMetniUret(markdowndenAttributedStringUret(metin))
            let iki = markdownMetniUret(markdowndenAttributedStringUret(bir))
            XCTAssertEqual(bir, iki, "ikinci tur değişmemeli: \(metin.debugDescription)")
        }
    }

    // MARK: İşaret temizleme

    func testIsaretlemeleriTemizle() {
        XCTAssertEqual(isaretlemeleriTemizle("**kalın**"), "kalın")
        XCTAssertEqual(isaretlemeleriTemizle("# Başlık"), "Başlık")
        XCTAssertEqual(isaretlemeleriTemizle("### Alt"), "Alt")
        XCTAssertEqual(isaretlemeleriTemizle("<punto=16>metin</punto>"), "metin")
        XCTAssertEqual(isaretlemeleriTemizle("![](Görseller/a.png){20x10}son"), "son")
    }

    // MARK: Punto sınırlama

    func testBoyutSinirla() {
        XCTAssertEqual(boyutSinirla(5), kMinYaziBoyutu, "alt sınırın altı kırpılmalı")
        XCTAssertEqual(boyutSinirla(100), kMaksYaziBoyutu, "üst sınırın üstü kırpılmalı")
        XCTAssertEqual(boyutSinirla(14), 14, "aralıktaki değer değişmemeli")
    }

    func testBoyutMetni() {
        XCTAssertEqual(boyutMetni(14), "14", "tam sayı ondalıksız yazılmalı")
        XCTAssertEqual(boyutMetni(14.5), "14.5")
    }

    // MARK: Otomatik başlık

    func testOtomatikBaslikIlkSatirdanUretilir() {
        XCTAssertEqual(otomatikBaslikUret(icerik: "Alışveriş\nsüt"), "Alışveriş")
        XCTAssertEqual(otomatikBaslikUret(icerik: "# Başlıklı\nmetin"), "Başlıklı")
        XCTAssertEqual(otomatikBaslikUret(icerik: "**kalın**"), "kalın")
    }

    func testOtomatikBaslikYolAyraciniTemizler() {
        XCTAssertFalse(otomatikBaslikUret(icerik: "a/b:c").contains("/"))
        XCTAssertFalse(otomatikBaslikUret(icerik: "a/b:c").contains(":"))
    }

    func testOtomatikBaslikKirpilir() {
        let uzun = String(repeating: "x", count: 100)
        XCTAssertEqual(otomatikBaslikUret(icerik: uzun).count, 40, "40 karaktere kırpılmalı")
    }

    func testBosIcerikTarihliAdUretir() {
        let ad = otomatikBaslikUret(icerik: "   \n  ")
        XCTAssertTrue(ad.hasPrefix("Adsız Not"), "boş içerik için tarihli ad üretilmeli, üretilen: \(ad)")
    }

    // MARK: Türkçe arama normalleştirme

    /// Noktalı/noktasız i ailesinin tamamı birbiriyle eşleşmeli.
    /// Bu test bir hatayı yakaladı: eskiden "İstanbul" -> "ıstanbul" oluyor,
    /// "istanbul" araması notu bulamıyordu.
    func testIAilesiBirbiriyleEslesir() {
        let hepsi = ["İstanbul", "istanbul", "Istanbul", "ıstanbul"].map(aramaIcinSadelestir)
        XCTAssertEqual(Set(hepsi).count, 1, "i ailesinin tamamı aynı sonuca inmeli: \(hepsi)")

        XCTAssertEqual(aramaIcinSadelestir("İZMİR"), aramaIcinSadelestir("izmir"))
        XCTAssertEqual(aramaIcinSadelestir("IŞIK"), aramaIcinSadelestir("ışık"))
    }

    func testTurkceHarflerSadelesir() {
        XCTAssertEqual(aramaIcinSadelestir("ĞÜŞÖÇ"), aramaIcinSadelestir("ğüşöç"))
        XCTAssertEqual(aramaIcinSadelestir("Ağustos"), aramaIcinSadelestir("agustos"))
    }

    /// Aramanın asıl kullanımı: parça, bütünün içinde bulunmalı.
    func testAramaAltDizeOlarakCalisir() {
        XCTAssertTrue(aramaIcinSadelestir("Ağustos Notları").contains(aramaIcinSadelestir("ğu")))
        XCTAssertTrue(aramaIcinSadelestir("İstanbul Gezisi").contains(aramaIcinSadelestir("istanbul")))
        XCTAssertTrue(aramaIcinSadelestir("ŞİFRE").contains(aramaIcinSadelestir("şif")))
    }

}
