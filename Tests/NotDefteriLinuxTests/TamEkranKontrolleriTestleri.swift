import XCTest
import CGtk
import Foundation
@testable import NotDefteriLinux

final class TamEkranKontrolleriTestleri: XCTestCase {
    private static let gtkHazir = GrafikTestOrtami.hazir

    override func setUpWithError() throws {
        try XCTSkipUnless(Self.gtkHazir, "GTK grafik ekranı yok.")
    }

    private func tikla(_ dugme: UnsafeMutablePointer<GtkWidget>) {
        var deger = GValue()
        g_value_init(&deger, gtk_button_get_type())
        g_value_set_object(&deger, UnsafeMutableRawPointer(dugme))
        g_signal_emitv(&deger, g_signal_lookup("clicked", gtk_button_get_type()), 0, nil)
        g_value_unset(&deger)
    }

    private func bekle(_ kosul: () -> Bool) -> Bool {
        let son = Date().addingTimeInterval(1.5)
        repeat {
            for _ in 0..<20 { _ = g_main_context_iteration(nil, 0) }
            if kosul() { return true }
            g_usleep(5_000)
        } while Date() < son
        return kosul()
    }

    func testTamEkranKontrolleriIcerikteGorunurVeEylemleriCalistirir() {
        var cikis = 0, kucult = 0, kapat = 0
        let kontroller = LinuxTamEkranKontrolleri(cik: { cikis += 1 }, kucult: { kucult += 1 }, kapat: { kapat += 1 })
        let pencere = gtk_window_new()!
        defer { gtk_window_destroy(nd_window(pencere)) }
        gtk_window_set_child(nd_window(pencere), kontroller.widget)
        XCTAssertEqual(gtk_widget_get_visible(kontroller.widget), 0)
        kontroller.gorunurluguAyarla(tamEkran: true)
        gtk_window_present(nd_window(pencere))
        for _ in 0..<20 {
            while g_main_context_iteration(nil, 0) != 0 {}
            g_usleep(5_000)
        }
        XCTAssertNotEqual(gtk_widget_get_mapped(kontroller.widget), 0)
        for dugme in [kontroller.cikisDugmesi, kontroller.kucultDugmesi, kontroller.kapatDugmesi] {
            tikla(dugme)
        }
        XCTAssertEqual(cikis, 1)
        XCTAssertEqual(kucult, 1)
        XCTAssertEqual(kapat, 1)
        kontroller.gorunurluguAyarla(tamEkran: false)
        XCTAssertEqual(gtk_widget_get_visible(kontroller.widget), 0)
    }

    func testGercekTamEkrandanIcerikDugmesiyleCikilir() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NOTDEFTERI_FULLSCREEN_WM_TEST"] == "1",
                          "Gerçek tam ekran testi için yalıtılmış pencere yöneticisi oturumu gerekir.")
        let pencere = gtk_window_new()!
        defer { gtk_window_destroy(nd_window(pencere)) }
        let kontroller = LinuxTamEkranKontrolleri(cik: { gtk_window_unfullscreen(nd_window(pencere)) },
                                                kucult: {}, kapat: {})
        gtk_window_set_titlebar(nd_window(pencere), gtk_header_bar_new())
        gtk_window_set_child(nd_window(pencere), kontroller.widget)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(pencere), "notify::fullscreened") { (_: gpointer?) in
            kontroller.gorunurluguAyarla(tamEkran: gtk_window_is_fullscreen(nd_window(pencere)) != 0)
        }
        gtk_window_present(nd_window(pencere))
        gtk_window_fullscreen(nd_window(pencere))
        try XCTSkipUnless(bekle { gtk_window_is_fullscreen(nd_window(pencere)) != 0 },
                          "Pencere yöneticisi tam ekran isteğini uygulamadı.")
        XCTAssertTrue(bekle { gtk_widget_get_mapped(kontroller.widget) != 0 })
        tikla(kontroller.cikisDugmesi)
        XCTAssertTrue(bekle { gtk_window_is_fullscreen(nd_window(pencere)) == 0 })
        XCTAssertEqual(gtk_widget_get_visible(kontroller.widget), 0)
    }
}
