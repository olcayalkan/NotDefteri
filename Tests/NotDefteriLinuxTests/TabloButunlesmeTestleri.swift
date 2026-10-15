import XCTest
import CGtk
import Foundation
import NotDefteriCekirdek
@testable import NotDefteriLinux

final class TabloButunlesmeTestleri: XCTestCase {
    private static let gtkHazir = GrafikTestOrtami.hazir

    private func bekle(_ kosul: () -> Bool) -> Bool {
        let son = Date().addingTimeInterval(2)
        repeat {
            while g_main_context_iteration(nil, 0) != 0 {}
            if kosul() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.002))
        } while Date() < son
        return kosul()
    }

    private func girisBul(_ widget: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWidget>? {
        if g_type_check_instance_is_a(UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GTypeInstance.self), gtk_entry_get_type()) != 0 { return widget }
        var cocuk = gtk_widget_get_first_child(widget)
        while let mevcut = cocuk {
            if let giris = girisBul(mevcut) { return giris }
            cocuk = gtk_widget_get_next_sibling(mevcut)
        }
        return nil
    }

    private func tusGonder(_ widget: UnsafeMutablePointer<GtkWidget>, tus: UInt32, durum: UInt32) -> Bool {
        let denetleyiciler = gtk_widget_observe_controllers(widget)!
        defer { g_object_unref(UnsafeMutableRawPointer(denetleyiciler)) }
        for i in 0..<g_list_model_get_n_items(denetleyiciler) {
            guard let denetleyici = g_list_model_get_item(denetleyiciler, i) else { continue }
            defer { g_object_unref(denetleyici) }
            guard g_type_check_instance_is_a(denetleyici.assumingMemoryBound(to: GTypeInstance.self), gtk_event_controller_key_get_type()) != 0 else { continue }
            var parametreler = [GValue](repeating: GValue(), count: 4)
            g_value_init(&parametreler[0], gtk_event_controller_key_get_type())
            g_value_set_object(&parametreler[0], denetleyici)
            for j in [1, 2] { g_value_init(&parametreler[j], g_type_from_name("guint")) }
            g_value_set_uint(&parametreler[1], tus)
            g_value_set_uint(&parametreler[2], 0)
            g_value_init(&parametreler[3], gdk_modifier_type_get_type())
            g_value_set_flags(&parametreler[3], durum)
            var sonuc = GValue()
            g_value_init(&sonuc, g_type_from_name("gboolean"))
            g_signal_emitv(&parametreler, g_signal_lookup("key-pressed", gtk_event_controller_key_get_type()), 0, &sonuc)
            let islendi = g_value_get_boolean(&sonuc) != 0
            g_value_unset(&sonuc)
            for j in parametreler.indices { g_value_unset(&parametreler[j]) }
            if islendi { return true }
        }
        return false
    }

    private func olaylariIsle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        while g_main_context_iteration(nil, 0) != 0 {}
    }

    func testHucreTiklamaDuzenlemeKayitGeriAlVeYenidenAcma() throws {
        try XCTSkipUnless(Self.gtkHazir, "GTK grafik ekranı yok.")
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NOTDEFTERI_KOK"]?.hasPrefix("/tmp/") == true,
                          "Bütünleşme testi sentetik NOTDEFTERI_KOK gerektirir.")
        let uygulama = try XCTUnwrap(gtk_application_new("org.notdefteri.TableRegression", G_APPLICATION_NON_UNIQUE))
        defer { g_object_unref(UnsafeMutableRawPointer(uygulama)) }
        XCTAssertNotEqual(g_application_register(UnsafeMutableRawPointer(uygulama).assumingMemoryBound(to: GApplication.self), nil, nil), 0)
        let pencere = LinuxPencere(uygulama: uygulama)
        defer { gtk_window_destroy(nd_window(pencere.pencere)) }
        let editor = LinuxEditor(pencere: pencere)
        pencere.editor = editor
        LinuxGorseller.kur(pencere: pencere, editor: editor)
        LinuxTablolar.kur(editor: editor)
        let klasor = notlarKlasoru().appendingPathComponent("TableRegression-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: klasor) }
        let url = klasor.appendingPathComponent("index.md")
        let tablo = "| Ad | Değer |\n| :--- | ---: |\n| Bir | İki |\n"
        try ("Önce\n\n" + tablo + "\nSonra\n").write(to: url, atomically: true, encoding: .utf8)
        var acildi = false
        editor.notuAc(url) { acildi = $0 }
        guard bekle({ acildi }) else { XCTFail("Sentetik not açılamadı"); return }
        gtk_window_present(nd_window(pencere.pencere))
        XCTAssertTrue(bekle { gtk_widget_get_mapped(editor.metinGorunumu) != 0 })
        let ilk = editor.belge.string
        let konum = (ilk as NSString).range(of: "Bir").location
        guard konum != NSNotFound else { XCTFail("Tablo hücresi yüklenmedi"); return }
        let gorunum: UnsafeMutablePointer<GtkTextView> = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(editor.metinGorunumu))
        var iter = LinuxMetinDonusumu.iter(editor.tampon, konum)
        var kare = GdkRectangle()
        gtk_text_view_get_iter_location(gorunum, &iter, &kare)
        var x: Int32 = 0, y: Int32 = 0
        gtk_text_view_buffer_to_window_coords(gorunum, GTK_TEXT_WINDOW_WIDGET, kare.x, kare.y, &x, &y)
        XCTAssertTrue(editor.tiklamaOncesi.contains { $0(Double(x + 2), Double(y + max(1, kare.height / 2))) })
        XCTAssertTrue(bekle { self.girisBul(editor.metinGorunumu) != nil })
        let giris = try XCTUnwrap(girisBul(editor.metinGorunumu))
        g_object_ref(UnsafeMutableRawPointer(giris))
        defer { g_object_unref(UnsafeMutableRawPointer(giris)) }
        gtk_editable_set_position(OpaquePointer(giris), 1)
        // The parent TextView handles pointer events in capture phase. A click in the
        // open native entry must still reach that entry, rather than recreate it.
        XCTAssertFalse(editor.tiklamaOncesi.contains { $0(Double(x + 2), Double(y + max(1, kare.height / 2))) })
        XCTAssertEqual(girisBul(editor.metinGorunumu), giris)
        XCTAssertEqual(gtk_editable_get_position(OpaquePointer(giris)), 1)
        // Entry odaktayken üstteki capture denetleyicisi Ctrl+B gibi editör
        // kısayollarını sahiplenmemeli; bunlar hücre girişine ulaşmalıdır.
        XCTAssertFalse(tusGonder(editor.metinGorunumu, tus: 0x62, durum: GDK_CONTROL_MASK.rawValue))
        let uzun = "Uzun hücre │ değer | Türkçe 🐈"
        gtk_editable_set_text(OpaquePointer(giris), uzun)
        XCTAssertTrue(bekle { editor.belge.string.contains("Uzun hücre") })
        XCTAssertTrue(editor.simdiKaydet())
        let kayit = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(kayit.contains("Uzun hücre │ değer \\| Türkçe 🐈"), kayit)
        XCTAssertTrue(kayit.contains("| :--- | ---: |"), kayit)
        XCTAssertTrue(kayit.contains("| İki |"), kayit)
        XCTAssertTrue(kayit.hasPrefix("Önce\n\n"), kayit)
        XCTAssertTrue(kayit.hasSuffix("\nSonra\n"), kayit)
        XCTAssertTrue(tusGonder(giris, tus: 0x7a, durum: GDK_CONTROL_MASK.rawValue))
        XCTAssertEqual(editor.belge.string, ilk)
        XCTAssertFalse(gtk_widget_has_focus(editor.metinGorunumu) != 0, "Undo sonrası yazım hücrede kalmalı")
        XCTAssertTrue(tusGonder(giris, tus: 0x79, durum: GDK_CONTROL_MASK.rawValue))
        XCTAssertTrue(editor.belge.string.contains("Uzun hücre"))
        gtk_editable_set_text(OpaquePointer(giris), "Bir")
        olaylariIsle()
        var yer = Int32(3)
        gtk_editable_insert_text(OpaquePointer(giris), " ", -1, &yer)
        olaylariIsle()
        gtk_editable_insert_text(OpaquePointer(giris), "İki", -1, &yer)
        olaylariIsle()
        XCTAssertEqual(String(cString: gtk_editable_get_text(OpaquePointer(giris))), "Bir İki")
        XCTAssertTrue(editor.belge.string.contains("Bir İki"))
        gtk_editable_set_text(OpaquePointer(giris), uzun)
        XCTAssertTrue(editor.simdiKaydet())
        acildi = false
        editor.notuAc(url, yenidenYukle: true) { acildi = $0 }
        guard bekle({ acildi }) else { XCTFail("Sentetik not açılamadı"); return }
        XCTAssertTrue(editor.belge.string.contains("Uzun hücre"))
        XCTAssertTrue(editor.simdiKaydet())
        // Hücre değiştirme aynı güvenli native overlay'i yeniden kullanır.
        XCTAssertTrue(editor.tiklamaOncesi.contains { $0(Double(x + 2), Double(y + max(1, kare.height / 2))) })
        let acikGiris = try XCTUnwrap(girisBul(editor.metinGorunumu))
        XCTAssertTrue(tusGonder(acikGiris, tus: 0xff09, durum: 0))
        XCTAssertTrue(bekle {
            guard let sonraki = self.girisBul(editor.metinGorunumu) else { return false }
            return sonraki == acikGiris
        })
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), kayit)
        let diger = (editor.belge.string as NSString).range(of: "İki")
        XCTAssertNotEqual(diger.location, NSNotFound)
        LinuxMetinDonusumu.secimiAyarla(editor.tampon, diger)
        gtk_text_buffer_delete_selection(editor.tampon, 1, 1)
        gtk_text_buffer_insert_interactive_at_cursor(editor.tampon, "Yeni", -1, 1)
        XCTAssertTrue(bekle { editor.belge.string.contains("Yeni") })
        XCTAssertFalse(editor.belge.string.contains("İki"))
        XCTAssertTrue(editor.belge.string.contains("Uzun hücre"))
        XCTAssertTrue(editor.simdiKaydet())
    }
}
