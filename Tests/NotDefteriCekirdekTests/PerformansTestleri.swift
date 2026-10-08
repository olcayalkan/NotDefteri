import XCTest
@testable import NotDefteriCekirdek

/// Performans düzeltmelerinin davranışı değiştirmediğini doğrular.
final class PerformansTestleri: XCTestCase {

    /// Eski düzenli ifade; satır taramalı kodBloguKapanisi bununla aynı sonucu vermeli.
    private func eskiKapanis(_ metin: String, ayirac: String, sonrasinda: Int) -> NSRange? {
        let desen = try! NSRegularExpression(pattern: "(?m)^" + ayirac + "[ \t]*(?:\r?\n|$)")
        return desen.firstMatch(in: metin, range: NSRange(location: sonrasinda, length: NSString(string: metin).length - sonrasinda))?.range
    }

    func testKodBloguKapanisiDuzenliIfadeyleAyni() {
        let ornekler = [
            "```\nkod\n```\nsonra", "```\nkod\n```", "```\nkod\n```  \t\nsonra", "```\nkod\n````\n```\n",
            "```\nkod\r\n```\r\nsonra", "```\nkod\r```\rsonra", "```\n ```\n```\n", "```\nkod\nbitmedi",
            "````\nkod\n```\n````\n", "```\nşğü\n```x\n```", "```\n\n```\n", "```\nkod\n```\u{2028}son"
        ]
        for metin in ornekler {
            let ns = NSString(string: metin)
            let ilk = ns.lineRange(for: NSRange(location: 0, length: 0))
            let ayirac = kodBloguAyiraci(ns.substring(with: ilk)) ?? "```"
            XCTAssertEqual(kodBloguKapanisi(ns, ayirac: ayirac, sonrasinda: NSMaxRange(ilk)),
                           eskiKapanis(metin, ayirac: ayirac, sonrasinda: NSMaxRange(ilk)), metin.debugDescription)
        }
    }

    /// Kaynak değeri depoya yazılıp geri okunabilmeli; macOS'ta hash'i satır başına dağılmalı.
    func testMarkdownKaynagiDegeri() {
        let a = MarkdownKaynagi(metin: "satır", kanonik: "satır")
        XCTAssertEqual(MarkdownKaynagi(oznitelik: a.oznitelikDegeri), a)
        XCTAssertNil(MarkdownKaynagi(oznitelik: "düz metin"))
        #if os(macOS)
        let n1 = a.oznitelikDegeri as! NSObject
        let n2 = MarkdownKaynagi(metin: "satır", kanonik: "satır").oznitelikDegeri as! NSObject
        XCTAssertEqual(n1, n2)
        XCTAssertEqual(n1.hash, n2.hash)
        XCTAssertNotEqual(n1, MarkdownKaynagi(metin: "satır", kanonik: "başka").oznitelikDegeri as! NSObject)
        let hashler = Set((0..<500).map { (MarkdownKaynagi(metin: "s\($0)", kanonik: "s\($0)").oznitelikDegeri as! NSObject).hash })
        XCTAssertGreaterThan(hashler.count, 490, "eşit metin/kanonik çiftleri aynı hash'e düşmemeli")
        #endif
    }

    /// Büyük not açmak satır sayısıyla doğrusal kalmalı (eskiden karesel büyüyordu).
    func testBuyukNotDogrusalAcilir() {
        func not(_ bolum: Int) -> String {
            (0..<bolum).map { "## Bölüm \($0)\n\nmetin **kalın** \($0)\n\n```\nkod \($0)\n```\n\n" }.joined()
        }
        func sure(_ metin: String) -> Double {
            let t = Date().timeIntervalSinceReferenceDate
            _ = markdowndenAttributedStringUret(metin)
            return Date().timeIntervalSinceReferenceDate - t
        }
        _ = sure(not(20))
        let kucuk = sure(not(100)), buyuk = sure(not(400))
        XCTAssertLessThan(buyuk, kucuk * 8, "4 kat metin 8 kattan fazla sürmemeli (küçük: \(kucuk), büyük: \(buyuk))")
    }

    func testBagOnElemeAlgilananBaglariKacirmaz() {
        let satirlar = ["bkz. https://ornek.com/yol", "posta: ad@ornek.com", "www.ornek.com.tr adresi",
                        "ornek.com", "düz cümle. Bitti.", "saat 10:30 toplantı", "mailto:ad@ornek.com"]
        for satir in satirlar {
            let a = markdowndenAttributedStringUret(satir)
            var bagVar = false
            a.enumerateAttribute(kBaglantiAnahtari, in: NSRange(location: 0, length: a.length)) { d, _, _ in if d != nil { bagVar = true } }
            let beklenen = !(satir.hasPrefix("düz") || satir.hasPrefix("saat"))
            XCTAssertEqual(bagVar, beklenen, satir)
        }
    }
}
