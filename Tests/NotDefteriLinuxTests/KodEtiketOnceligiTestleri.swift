import XCTest
import CGtk
@testable import NotDefteriLinux

final class KodEtiketOnceligiTestleri: XCTestCase {
    func testOncelikBirKezKurulurVeSonradanEklenenEtiketleYenilenir() {
        let tampon = gtk_text_buffer_new(nil)!
        defer { g_object_unref(UnsafeMutableRawPointer(tampon)) }
        let tablo = gtk_text_buffer_get_tag_table(tampon)!
        func ekle(_ ad: String) -> UnsafeMutablePointer<GtkTextTag> {
            let tag = gtk_text_tag_new(ad)!
            gtk_text_tag_table_add(tablo, tag)
            g_object_unref(UnsafeMutableRawPointer(tag))
            return tag
        }
        let temel = ekle("temel")
        let kod = (0..<7).map { ekle("kod-\($0)") }
        let gec = ekle("gec")
        XCTAssertLessThanOrEqual(LinuxKodEtiketOnceligi.uygula(kod, tablo: tablo), 7)
        XCTAssertEqual(kod.map { gtk_text_tag_get_priority($0) }, Array(2...8).map(Int32.init))
        XCTAssertEqual(LinuxKodEtiketOnceligi.uygula(kod, tablo: tablo), 0,
                       "Değişmeyen renklendirmede tablo yeniden sıralanmamalı")
        XCTAssertLessThan(gtk_text_tag_get_priority(temel), gtk_text_tag_get_priority(kod[0]))
        XCTAssertLessThan(gtk_text_tag_get_priority(gec), gtk_text_tag_get_priority(kod[0]))
        let yeni = ekle("yeni")
        XCTAssertLessThanOrEqual(LinuxKodEtiketOnceligi.uygula(kod, tablo: tablo), 7)
        XCTAssertEqual(kod.map { gtk_text_tag_get_priority($0) }, Array(3...9).map(Int32.init))
        XCTAssertLessThan(gtk_text_tag_get_priority(yeni), gtk_text_tag_get_priority(kod[0]))
        XCTAssertEqual(LinuxKodEtiketOnceligi.uygula(kod, tablo: tablo), 0)
    }
}
