import XCTest
@testable import NotDefteriCekirdek

/// Blok önekleri (liste, görev, alıntı, ayırıcı, uyarı kutusu) ve numaralama.
final class MetinBloguTestleri: XCTestCase {

    private func cozumle(_ satir: String) -> MetinBlogu? { metinBlogunuCozumle(satir)?.blok }

    func testOnekTurleriTaninir() {
        let beklenen: [(String, MetinBlogu.Tur)] = [
            ("- madde", .madde), ("* madde", .madde), ("3. numaralı", .numarali),
            ("- [ ] görev", .yapilacak), ("- [x] bitti", .yapilacak), ("> alıntı", .alinti), ("---", .ayirici)
        ]
        for (satir, tur) in beklenen { XCTAssertEqual(cozumle(satir)?.tur, tur, satir) }
    }

    func testOnekOlmayanSatirlar() {
        for satir in ["düz metin", "-bitişik", "0. sıfır", "1.nokta", "--- sonrası", "#başlık"] {
            XCTAssertNil(cozumle(satir), satir)
        }
    }

    func testGorevDurumuVeNumaraOkunur() {
        XCTAssertEqual(cozumle("- [X] bitti")?.tamamlandi, true)
        XCTAssertEqual(cozumle("- [ ] açık")?.tamamlandi, false)
        XCTAssertEqual(cozumle("12. on iki")?.numara, 12)
    }

    /// İki boşluk bir girinti düzeyidir; tek boşluk geçersiz sayılır.
    func testGirintiSeviyesi() {
        XCTAssertEqual(cozumle("    - iki düzey")?.seviye, 2)
        XCTAssertNil(cozumle(" - tek boşluk"))
    }

    func testUyariKutusuEmojiVeRenkOkunur() throws {
        let blok = try XCTUnwrap(cozumle("> [!🔥 kırmızı] dikkat"))
        XCTAssertEqual(blok.tur, .uyari)
        XCTAssertEqual(blok.emoji, "🔥")
        XCTAssertEqual(blok.renk, "kırmızı")
        XCTAssertFalse(blok.uyariKimligi.isEmpty)
    }

    func testBilinmeyenRenkliUyariAlintiSayilir() {
        XCTAssertEqual(cozumle("> [!🔥 mor] metin")?.tur, .alinti)
    }

    func testEmojiDogrulamasi() {
        for emoji in ["💡", "🔥", "⚠️", "1️⃣"] { XCTAssertTrue(emojiGecerliMi(emoji), emoji) }
        for deger in ["a", "1", "💡💡", "", "!"] { XCTAssertFalse(emojiGecerliMi(deger), deger) }
    }

    /// Dosyadaki yazılış (yıldız, numara, girinti) düzenlenene kadar korunur.
    func testKaynakOnekiKorunur() throws {
        XCTAssertEqual(cozumle("* yıldız")?.markdownOnEki, "* ")
        var blok = try XCTUnwrap(cozumle("  7. yedi"))
        XCTAssertEqual(blok.markdownOnEki, "  7. ")
        blok.kaynakOnEk = nil
        blok.numara = 8
        XCTAssertEqual(blok.markdownOnEki, "  8. ")
    }

    func testKanonikOnekler() {
        XCTAssertEqual(MetinBlogu(tur: .madde, seviye: 1).markdownOnEki, "  - ")
        XCTAssertEqual(MetinBlogu(tur: .yapilacak, tamamlandi: true).markdownOnEki, "- [x] ")
        XCTAssertEqual(MetinBlogu(tur: .uyari, emoji: "📌", renk: "mavi").markdownOnEki, "> [!📌 mavi] ")
        XCTAssertEqual(MetinBlogu(tur: .uyari, devam: true).markdownOnEki, "> ")
    }

    func testGorunenIsaretler() {
        XCTAssertEqual(MetinBlogu(tur: .madde).isaret, "•\t")
        XCTAssertEqual(MetinBlogu(tur: .numarali, numara: 4).isaret, "4.\t")
        XCTAssertEqual(MetinBlogu(tur: .yapilacak, tamamlandi: true).isaret, "☑\t")
    }

    /// Öznitelikte Foundation sözlüğü taşınır; geri okununca aynı model çıkmalı.
    func testAnlamsalDegerGidisDonusu() {
        let blok = MetinBlogu(tur: .uyari, seviye: 2, emoji: "🔥", renk: "yeşil", devam: true,
                              uyariKimligi: "k1", kaynakOnEk: "    > ")
        XCTAssertEqual(MetinBlogu(oznitelik: blok.anlamsalDeger), blok)
        XCTAssertNil(MetinBlogu(oznitelik: ["tur": "bilinmeyen"]))
        XCTAssertNil(MetinBlogu(oznitelik: "metin"))
    }

    func testNumaralarArdisikHaleGelir() {
        let metin = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("1. bir\n1. iki\n1. üç"))
        var secim = NSRange(location: 0, length: 0)
        blokNumaralariniGuncelle(metin, secim: &secim)
        XCTAssertEqual(markdownMetniUret(metin), "1. bir\n2. iki\n3. üç")
    }

    func testAraVerenParagrafNumarayiSifirlar() {
        let metin = NSMutableAttributedString(attributedString: markdowndenAttributedStringUret("1. bir\n1. iki\nara\n5. beş\n1. altı"))
        var secim = NSRange(location: 0, length: 0)
        blokNumaralariniGuncelle(metin, secim: &secim)
        XCTAssertEqual(markdownMetniUret(metin), "1. bir\n2. iki\nara\n5. beş\n6. altı")
    }

    func testKodBloguDilEtiketi() {
        XCTAssertEqual(kodBloguDilEtiketi(["acilis": "```swift\n"]), "swift")
        XCTAssertEqual(kodBloguDilEtiketi(["acilis": "````  python extra\n"]), "python")
        XCTAssertEqual(kodBloguDilEtiketi(["acilis": "```\n"]), "")
    }
}
