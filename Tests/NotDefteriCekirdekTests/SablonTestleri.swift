import XCTest
@testable import NotDefteriCekirdek

/// Toplantı/günlük/proje şablonları ve günlük sayfa adı.
final class SablonTestleri: XCTestCase {

    private func tarih(_ yil: Int, _ ay: Int, _ gun: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: yil, month: ay, day: gun, hour: 12))!
    }

    func testGunlukSayfaAdiIsoBicimindedir() {
        XCTAssertEqual(gunlukSayfaAdi(tarih(2026, 3, 5)), "2026-03-05")
    }

    /// Cihaz Türkçe ya da Hicri takvimde olsa da ad değişmemeli; yoksa aynı günün iki sayfası olur.
    func testGunlukSayfaAdiYerelAyardanBagimsizdir() {
        let ad = gunlukSayfaAdi(tarih(2026, 12, 31))
        XCTAssertEqual(ad, "2026-12-31")
        XCTAssertTrue(ad.allSatisfy { $0.isASCII })
    }

    func testHerSablonBaslikVeGorevIcerir() {
        for sablon in SayfaSablonu.allCases {
            let md = sablon.markdown(tarih: tarih(2026, 1, 2))
            XCTAssertTrue(md.hasPrefix("# "), "\(sablon) başlıkla başlamalı")
            XCTAssertTrue(md.contains("- [ ] "), "\(sablon) en az bir görev içermeli")
        }
    }

    func testGunlukSablonuBasligiTarihtir() {
        XCTAssertTrue(SayfaSablonu.gunluk.markdown(tarih: tarih(2026, 1, 2)).hasPrefix("# 2026-01-02\n"))
    }

    func testToplantiSablonuTarihiIcerir() {
        XCTAssertTrue(SayfaSablonu.toplanti.markdown(tarih: tarih(2026, 1, 2)).contains("Tarih: 2026-01-02"))
    }

    /// Şablondan oluşturulan sayfa açılıp hiç dokunulmadan kaydedilince metin değişmemeli.
    func testSablonlarCeviricidenKayipsizGecer() {
        for sablon in SayfaSablonu.allCases {
            let md = sablon.markdown(tarih: tarih(2026, 1, 2))
            XCTAssertEqual(markdownMetniUret(markdowndenAttributedStringUret(md)), md, "\(sablon)")
        }
    }
}
