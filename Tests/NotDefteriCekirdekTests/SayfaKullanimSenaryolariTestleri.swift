import XCTest
@testable import NotDefteriCekirdek

/// Clean Architecture katmanları: data source → depo → use case → konteyner.
final class SayfaKullanimSenaryolariTestleri: GeciciKokTestCase {
    private struct SahteKaynak: SayfaKaynagi {
        let sonuc: Result<String, DosyaIstisnasi>
        func oku(_ url: URL) throws -> String { try sonuc.get() }
    }

    func testSayfayiAcHamUstbilgiVeGovdeyiVerir() throws {
        let url = try sayfaKur("Proje", metin: "---\nicon: 📘\n---\n# Başlık\n")
        let sayfa = try BagimlilikKonteyneri().sayfayiAc(url).get()
        XCTAssertEqual(sayfa.ham, "---\nicon: 📘\n---\n# Başlık\n")
        XCTAssertEqual(sayfa.govde, "# Başlık\n")
        XCTAssertEqual(sayfa.ustbilgi, sayfaUstbilgisiniAyir(sayfa.ham).bilgi)
    }

    func testOkunamayanSayfaBasarisizlikDoner() {
        let depo = SayfaDeposuImpl(kaynak: SahteKaynak(sonuc: .failure(.okunamadi(kok, neden: "yok"))))
        XCTAssertEqual(SayfayiAc(depo: depo)(kok), .failure(.dosya("yok")))
        let gercek = BagimlilikKonteyneri().sayfayiAc(kok.appendingPathComponent("olmayan.md"))
        guard case .failure = gercek else { return XCTFail("olmayan dosya açılmamalı") }
    }

    func testSayfayiKaydetYalnizcaYazilincaGecmiseEkler() throws {
        let url = try sayfaKur("Not")
        var gecmis: [String] = []
        let kaydet = SayfayiKaydet { metin, _ in gecmis.append(metin) }
        let kaydedici = NotKaydedici()
        XCTAssertEqual(kaydet(.init(metin: "bir\n", url: url, mevcutURL: url, kaydedici: kaydedici)), .yazildi)
        XCTAssertEqual(kaydet(.init(metin: "bir\n", url: url, mevcutURL: url, kaydedici: kaydedici)), .gerekmedi)
        XCTAssertEqual(gecmis, ["bir\n"])
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "bir\n")
    }
}
