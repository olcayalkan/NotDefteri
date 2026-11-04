import XCTest
import CGtk
import Foundation
import NotDefteriCekirdek
@testable import NotDefteriLinux

/// Özellikler art arda (yazma, Enter, silme, blok, biçim, punto, başlık, geri al) uygulanınca
/// GTK tamponu ile anlamsal belge ayrışmamalı; ayrışma ekranda bozulma ve kayıtta veri kaybıdır.
final class UstUsteKullanimTestleri: XCTestCase {
    private struct Rastgele: RandomNumberGenerator {
        var durum: UInt64
        mutating func next() -> UInt64 {
            durum ^= durum << 13; durum ^= durum >> 7; durum ^= durum << 17; return durum
        }
    }

    private func olaylariIsle() {
        for _ in 0..<3 {
            while g_main_context_iteration(nil, 0) != 0 {}
            RunLoop.current.run(until: Date().addingTimeInterval(0.001))
        }
    }

    private func tusGonder(_ widget: UnsafeMutablePointer<GtkWidget>, tus: UInt32, durum: UInt32 = 0) {
        let denetleyiciler = gtk_widget_observe_controllers(widget)!
        defer { g_object_unref(UnsafeMutableRawPointer(denetleyiciler)) }
        for i in 0..<g_list_model_get_n_items(denetleyiciler) {
            guard let denetleyici = g_list_model_get_item(denetleyiciler, i) else { continue }
            defer { g_object_unref(denetleyici) }
            guard g_type_check_instance_is_a(denetleyici.assumingMemoryBound(to: GTypeInstance.self), gtk_event_controller_key_get_type()) != 0 else { continue }
            var p = [GValue](repeating: GValue(), count: 4)
            g_value_init(&p[0], gtk_event_controller_key_get_type()); g_value_set_object(&p[0], denetleyici)
            for j in [1, 2] { g_value_init(&p[j], g_type_from_name("guint")) }
            g_value_set_uint(&p[1], tus); g_value_set_uint(&p[2], 0)
            g_value_init(&p[3], gdk_modifier_type_get_type()); g_value_set_flags(&p[3], durum)
            var sonuc = GValue(); g_value_init(&sonuc, g_type_from_name("gboolean"))
            g_signal_emitv(&p, g_signal_lookup("key-pressed", gtk_event_controller_key_get_type()), 0, &sonuc)
            let islendi = g_value_get_boolean(&sonuc) != 0
            g_value_unset(&sonuc); for j in p.indices { g_value_unset(&p[j]) }
            if islendi { return }
        }
        // Hiçbir denetleyici işlemediyse GTK'nın varsayılanı: Enter yeni satır, Backspace siler.
        if tus == 0xff0d { gtk_text_buffer_insert_interactive_at_cursor(gtk_text_view_get_buffer(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(widget))), "\n", -1, 1) }
        if tus == 0xff08, let tampon = gtk_text_view_get_buffer(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(widget))) {
            var iter = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(tampon, &iter, gtk_text_buffer_get_insert(tampon))
            gtk_text_buffer_backspace(tampon, &iter, 1, 1)
        }
    }

    func testRastgeleArdisikIslemlerTamponuBozmaz() throws {
        try XCTSkipUnless(GrafikTestOrtami.hazir, "GTK grafik ekranı yok.")
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NOTDEFTERI_KOK"]?.hasPrefix("/tmp/") == true,
                          "Bütünleşme testi sentetik NOTDEFTERI_KOK gerektirir.")
        let uygulama = try XCTUnwrap(gtk_application_new("org.notdefteri.UstUste", G_APPLICATION_NON_UNIQUE))
        defer { g_object_unref(UnsafeMutableRawPointer(uygulama)) }
        XCTAssertNotEqual(g_application_register(UnsafeMutableRawPointer(uygulama).assumingMemoryBound(to: GApplication.self), nil, nil), 0)
        let pencere = LinuxPencere(uygulama: uygulama)
        defer { gtk_window_destroy(nd_window(pencere.pencere)) }
        let editor = LinuxEditor(pencere: pencere)
        pencere.editor = editor
        LinuxBlokMenusu.kur(pencere: pencere, editor: editor)
        LinuxGorseller.kur(pencere: pencere, editor: editor)
        LinuxTablolar.kur(editor: editor)
        LinuxKodVeUyari.kur(pencere: pencere, editor: editor)
        LinuxKatlama.kur(pencere: pencere, editor: editor)
        let klasor = notlarKlasoru().appendingPathComponent("UstUste-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: klasor) }
        let url = klasor.appendingPathComponent("index.md")
        try "# Başlık\n\nDüz **kalın** metin.\n- madde\n> [!💡 mavi] kutu\n```swift\nlet a = 1\n```\n| a | b |\n| --- | --- |\n| 1 | 2 |\n\nson\n"
            .write(to: url, atomically: true, encoding: .utf8)
        var acildi = false
        editor.notuAc(url) { acildi = $0 }
        olaylariIsle()
        XCTAssertTrue(acildi)
        gtk_window_present(nd_window(pencere.pencere))
        olaylariIsle()
        gtk_widget_grab_focus(editor.metinGorunumu)

        let tohum = UInt64(ProcessInfo.processInfo.environment["ND_TOHUM"] ?? "") ?? 0x9E3779B97F4A7C15
        let adimSayisi = Int(ProcessInfo.processInfo.environment["ND_ADIM"] ?? "") ?? 250
        var r = Rastgele(durum: tohum)
        let turler: [MetinBlogu.Tur] = [.madde, .numarali, .yapilacak, .alinti, .uyari, .ayirici]
        var gecmis: [String] = []
        for adim in 0..<adimSayisi {
            let uzunluk = editor.belge.length
            let islem: String
            switch Int.random(in: 0..<11, using: &r) {
            case 0, 1:
                let kelime = ["a", "kod ", "Ölç", "**", "- ", "> ", "|", "1. ", "`x`", "🐈"].randomElement(using: &r)!
                islem = "yaz(\(kelime))"; gtk_text_buffer_insert_interactive_at_cursor(editor.tampon, kelime, -1, 1)
            case 2: islem = "enter"; tusGonder(editor.metinGorunumu, tus: 0xff0d)
            case 3: islem = "sil"; tusGonder(editor.metinGorunumu, tus: 0xff08)
            case 4:
                let bas = Int.random(in: 0...uzunluk, using: &r), boy = Int.random(in: 0...min(12, uzunluk - bas), using: &r)
                // Kullanıcı yarım emoji seçemez: seçim karakter sınırına hizalanır.
                let hizali = (editor.belge.string as NSString).rangeOfComposedCharacterSequences(for: NSRange(location: bas, length: boy))
                islem = "sec(\(hizali.location),\(hizali.length))"; LinuxMetinDonusumu.secimiAyarla(editor.tampon, hizali)
            case 5: let tur = turler.randomElement(using: &r)!; islem = "blok(\(tur))"; editor.blokUygula(tur)
            case 6: let k = Bool.random(using: &r); islem = "kalin(\(k))"; editor.satirIciBicimUygula(kKalinAnahtari, deger: k ? true : nil)
            case 7: let f: CGFloat = Bool.random(using: &r) ? 1 : -1; islem = "punto(\(f))"; editor.puntoDegistir(fark: f)
            case 8: let s = Int.random(in: 0...3, using: &r); islem = "baslik(\(s))"; editor.baslikSeviyesiUygula(s)
            case 9: islem = "geriAl"; editor.geriAlIstendi(ileri: false)
            default: islem = "yinele"; editor.geriAlIstendi(ileri: true)
            }
            olaylariIsle()
            gecmis.append(islem)
            if let hata = GtkKoprusu.aynalamaHatasi(editor.tampon) {
                XCTFail("Adım \(adim) (\(islem)) sonrası ayrışma: \(hata)\nSon işlemler: \(gecmis.suffix(12))\nTohum: \(tohum)")
                return
            }
            if case .hata(let neden) = editor.simdiKaydetSonucu() {
                XCTFail("Adım \(adim) (\(islem)) sonrası kayıt hatası: \(neden)\nSon işlemler: \(gecmis.suffix(12))\nTohum: \(tohum)")
                return
            }
        }
        // Kaydedilen Markdown yeniden açılınca aynı metni üretmeli.
        let kayit = try String(contentsOf: url, encoding: .utf8)
        let govde = sayfaUstbilgisiniAyir(kayit).govde
        XCTAssertEqual(markdownMetniUret(markdowndenAttributedStringUret(govde)), govde, "Kayıt kararlı değil.\nSon işlemler: \(gecmis.suffix(12))")
    }
}
