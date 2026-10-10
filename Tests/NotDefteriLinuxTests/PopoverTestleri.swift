import XCTest
import CGtk
@testable import NotDefteriLinux

final class PopoverTestleri: XCTestCase {
    private static let gtkHazir = GrafikTestOrtami.hazir

    override func setUpWithError() throws {
        try XCTSkipUnless(Self.gtkHazir, "GTK grafik ekranı yok; görüntülü oturumda tekrar çalıştırın.")
    }

    private func olaylariIsle() {
        // Frame clock yerleşimlerine de fırsat tanı; bekleme üst sınırı 150 ms.
        for _ in 0..<30 {
            while g_main_context_iteration(nil, 0) != 0 {}
            g_usleep(5_000)
        }
    }

    func testYuzeysizHedefPopupAcamaz() {
        XCTAssertEqual(nd_popup_hedefi_hazir(nil), 0)
        let pencere = gtk_window_new()!
        defer { gtk_window_destroy(nd_window(pencere)) }
        XCTAssertEqual(nd_popup_hedefi_hazir(pencere), 0)
    }

    func testGizlenenPencerePopupHedefiOlamaz() {
        let pencere = gtk_window_new()!
        defer { gtk_window_destroy(nd_window(pencere)) }
        gtk_window_present(nd_window(pencere))
        olaylariIsle()
        XCTAssertNotEqual(nd_popup_hedefi_hazir(pencere), 0)
        gtk_widget_set_visible(pencere, 0)
        XCTAssertEqual(nd_popup_hedefi_hazir(pencere), 0)
    }

    func testMenuButtonYerlesimiPresentCagrisiGerektirmez() {
        let pencere = gtk_window_new()!
        defer { gtk_window_destroy(nd_window(pencere)) }
        let dugme = gtk_menu_button_new()!
        let metin = gtk_text_view_new()!
        let gorunum: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(metin))
        gtk_menu_button_set_child(OpaquePointer(dugme), gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0))
        gtk_menu_button_set_has_frame(OpaquePointer(dugme), 0)
        gtk_widget_set_size_request(dugme, 1, 1)
        let menu = gtk_popover_new()!
        let popover: UnsafeMutablePointer<GtkPopover> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(menu))
        gtk_popover_set_child(popover, gtk_label_new("Test menüsü"))
        gtk_menu_button_set_popover(OpaquePointer(dugme), menu)
        gtk_text_view_add_overlay(gorunum, dugme, 0, 0)
        gtk_window_set_child(nd_window(pencere), metin)
        gtk_window_present(nd_window(pencere))
        olaylariIsle()
        for boyut: Int32 in [200, 320, 240] {
            gtk_window_set_default_size(nd_window(pencere), boyut, boyut)
            gtk_text_view_move_overlay(gorunum, dugme, boyut / 3, boyut / 3)
            gtk_popover_popup(popover)
            olaylariIsle()
            XCTAssertNotEqual(gtk_widget_get_mapped(menu), 0)
            XCTAssertGreaterThan(gtk_widget_get_width(menu), 0)
            gtk_popover_popdown(popover)
            olaylariIsle()
        }
    }

    func testPencereyeBagliPopoverYerlesimiVeKapanisi() {
        let pencere = gtk_window_new()!
        defer { gtk_window_destroy(nd_window(pencere)) }
        // Uygulamadaki gibi bir içerik ve odak hedefi bulunsun.
        gtk_window_set_child(nd_window(pencere), gtk_entry_new())
        let menu = gtk_popover_new()!
        g_object_ref_sink(UnsafeMutableRawPointer(menu))
        defer { g_object_unref(UnsafeMutableRawPointer(menu)) }
        let popover: UnsafeMutablePointer<GtkPopover> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(menu))
        gtk_popover_set_child(popover, gtk_label_new("Sayfa bulucu"))
        gtk_window_present(nd_window(pencere))
        olaylariIsle()
        for boyut: Int32 in [240, 360, 280] {
            gtk_widget_set_parent(menu, pencere)
            gtk_window_set_default_size(nd_window(pencere), boyut, boyut)
            var kare = GdkRectangle(x: boyut / 2, y: boyut / 2, width: 1, height: 1)
            gtk_popover_set_pointing_to(popover, &kare)
            gtk_widget_queue_allocate(pencere)
            gtk_popover_popup(popover)
            olaylariIsle()
            XCTAssertNotEqual(gtk_widget_get_mapped(menu), 0)
            XCTAssertGreaterThan(gtk_widget_get_width(menu), 0)
            gtk_popover_popdown(popover)
            gtk_widget_unparent(menu)
            olaylariIsle()
        }
    }
}
