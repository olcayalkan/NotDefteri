import XCTest
import CGtk
import NotDefteriCekirdek
@testable import NotDefteriLinux

final class KodBloguBoslukTestleri: XCTestCase {
    func testBoslukYalnizKutununDisindaVeSonrakiParagrafAyridir() throws {
        try XCTSkipUnless(GrafikTestOrtami.hazir, "GTK grafik ekranı yok")
        let pencere = gtk_window_new()!
        defer { gtk_window_destroy(nd_window(pencere)) }
        let widget = gtk_text_view_new()!
        let gorunum: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(widget))
        let tampon = gtk_text_view_get_buffer(gorunum)!
        let adaptor = LinuxBelgeAdaptoru(tampon: tampon)
        adaptor.yukle(markdowndenAttributedStringUret("```swift\nbir\niki\nuc\n```\nparagraf\n"))
        gtk_window_set_child(nd_window(pencere), widget)
        gtk_window_present(nd_window(pencere))
        for _ in 0..<30 {
            while g_main_context_iteration(nil, 0) != 0 {}
            g_usleep(5_000)
        }
        func olc(_ metin: String) -> (y: Int32, boy: Int32, harf: GdkRectangle) {
            var iter = GtkKoprusu.iter(tampon, utf16: (adaptor.belge.string as NSString).range(of: metin).location)
            var y: Int32 = 0, boy: Int32 = 0, harf = GdkRectangle()
            gtk_text_view_get_line_yrange(gorunum, &iter, &y, &boy)
            gtk_text_view_get_iter_location(gorunum, &iter, &harf)
            return (y, boy, harf)
        }
        let bir = olc("bir"), iki = olc("iki"), uc = olc("uc"), paragraf = olc("paragraf")
        XCTAssertGreaterThanOrEqual(bir.boy - iki.boy, 8, "Üst boşluk yalnız ilk satırda olmalı")
        XCTAssertGreaterThanOrEqual(uc.boy - iki.boy, 10, "Alt boşluk yalnız son satırda olmalı")
        XCTAssertEqual(uc.harf.y - iki.harf.y, iki.harf.y - bir.harf.y, "Kodun kendi satır aralığı büyümemeli")
        XCTAssertGreaterThanOrEqual(paragraf.harf.y - uc.harf.y - uc.harf.height, 10)
        let cerceve = LinuxKutuGeometrisi.dikey(ilkY: bir.y, sonY: uc.y, sonBoy: uc.boy)
        XCTAssertLessThanOrEqual(cerceve.ust, bir.harf.y)
        XCTAssertGreaterThanOrEqual(cerceve.alt, uc.harf.y + uc.harf.height)
        XCTAssertGreaterThanOrEqual(paragraf.harf.y - cerceve.alt, 8,
                                    "Dış boşluk çerçeveye katılıp kaybolmamalı")
        let konum = (adaptor.belge.string as NSString).range(of: "uc").upperBound
        let enter = try XCTUnwrap(yapiEnterKurali(adaptor.belge, imlec: NSRange(location: konum, length: 0)))
        adaptor.degistir(enter.aralik, ile: enter.metin)
        for _ in 0..<30 {
            while g_main_context_iteration(nil, 0) != 0 {}
            g_usleep(5_000)
        }
        XCTAssertEqual(olc("uc").boy, olc("iki").boy, "Eski son satır dış boşluğu taşımamalı")
        XCTAssertEqual(olc("bir").boy, bir.boy, "İlk satırın dış boşluğu korunmalı")
    }
}
