import XCTest
import AppKit
@testable import NotDefteri

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

    // MARK: Bilinen kayıplar
    // Bu testler çeviricinin ŞU ANKİ kayıplı davranışını belgeliyor.
    // Açık İşler 1. madde (kayıpsız çevirici) yapılınca bunlar
    // gidisDonusKontrol'e çevrilmeli.

    func testListeSozdizimiBicimKaybeder() {
        // Metin korunuyor ama madde işareti biçim taşımıyor: düz metin olarak dönüyor.
        let metin = "- birinci\n- ikinci\n"
        let geri = markdownMetniUret(markdowndenAttributedStringUret(metin))
        XCTAssertEqual(geri, metin, "liste metni en azından metin olarak korunmalı")
    }

    func testItalikYildizlariMetneDonusur() {
        // *italik* tanınmıyor; yıldızlar düz metin olarak kalıyor.
        let metin = "*italik*"
        let geri = markdownMetniUret(markdowndenAttributedStringUret(metin))
        XCTAssertEqual(geri, metin)
    }

    func testDortIsaretliBaslikTaninmaz() {
        // Yalnızca 1-3 seviye destekleniyor; #### düz metin kalmalı.
        let metin = "#### dört\n"
        let geri = markdownMetniUret(markdowndenAttributedStringUret(metin))
        XCTAssertEqual(geri, metin)
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

    // MARK: Font yardımcıları

    func testKalinMi() {
        XCTAssertTrue(kalinMi(fontUret(boyut: 14, kalin: true)))
        XCTAssertFalse(kalinMi(fontUret(boyut: 14, kalin: false)))
    }

    func testBaslikFontuSeviyeyeGoreBuyur() {
        let b1 = baslikFontu(1).pointSize
        let b2 = baslikFontu(2).pointSize
        let b3 = baslikFontu(3).pointSize
        XCTAssertGreaterThan(b1, b2)
        XCTAssertGreaterThan(b2, b3)
        XCTAssertGreaterThan(b3, kTabanPunto, "en küçük başlık bile tabandan büyük olmalı")
        XCTAssertTrue(kalinMi(baslikFontu(1)), "başlıklar kalın olmalı")
    }

    func testVarsayilanFontTabanPuntoda() {
        XCTAssertEqual(varsayilanFont().pointSize, kTabanPunto)
        XCTAssertFalse(kalinMi(varsayilanFont()))
    }
}
