import CGtk
import Foundation
import NotDefteriCekirdek

/// Ortak GTK 4.6 diyalogları. Hiçbiri bloklamaz; yanıt `response` sinyaliyle alınır ve
/// yanıt işleyicisi diyalog yok edildikten sonra ana döngüde çalışır (yeni diyalog açabilir).
enum LinuxDiyalog {
    typealias Ust = UnsafeMutablePointer<GtkWidget>

    /// GtkMessageDialog (4.6'da AlertDialog yok). Yanıt, düğmenin 1'den başlayan sırasıdır;
    /// pencere kapatılırsa GTK_RESPONSE_DELETE_EVENT (negatif) gelir. İlk düğme varsayılandır.
    /// `kapandi`, yanıt gelmeden (üst pencere yok olurken) yok edilmede de çağrılır.
    static func mesaj(ust: Ust, baslik: String, aciklama: String, dugmeler: [String],
                      tur: GtkMessageType = GTK_MESSAGE_WARNING,
                      kapandi: (() -> Void)? = nil, yanit: @escaping (Int) -> Void) {
        // gtk_message_dialog_new variadic olduğu için özellikler ayrı yazılır.
        let nesne = UnsafeMutableRawPointer(g_object_new_with_properties(gtk_message_dialog_get_type(), 0, nil, nil)!)
        gNesneOzelligi(nesne, "message-type", .sayim(gtk_message_type_get_type(), Int32(tur.rawValue)))
        gNesneOzelligi(nesne, "text", .metin(baslik))
        gNesneOzelligi(nesne, "secondary-text", .metin(aciklama))
        let widget = nesne.assumingMemoryBound(to: GtkWidget.self)
        let pano = nesne.assumingMemoryBound(to: GtkDialog.self)
        gtk_window_set_transient_for(nd_window(widget), nd_window(ust))
        gtk_window_set_modal(nd_window(widget), 1)
        gtk_window_set_destroy_with_parent(nd_window(widget), 1)
        var yanitAlindi = false
        // Yanıt yolunda da yok edilmede de çağrılabilir; yalnızca ilki geçerlidir.
        var kapandiBildirildi = false
        let kapat = {
            guard !kapandiBildirildi else { return }
            kapandiBildirildi = true
            kapandi?()
        }
        for (sira, ad) in dugmeler.enumerated() { gtk_dialog_add_button(pano, ad, Int32(sira + 1)) }
        gtk_dialog_set_default_response(pano, 1)
        GtkKoprusu.sinyalBagla(nesne, "response") { (secilen: gint) in
            guard !yanitAlindi else { return }
            yanitAlindi = true
            g_object_ref(nesne)
            // Sinyal closure'ı yanıt işlenirken serbest kalmasın diye yok etme sonraya bırakılır.
            Platform.anaIsParcaciginda {
                defer { g_object_unref(nesne) }
                gtk_window_destroy(nd_window(widget))
                kapat()
                yanit(Int(secilen))
            }
        }
        GtkKoprusu.sinyalBagla(nesne, "destroy") { kapat() }
        gtk_window_present(nd_window(widget))
    }

    /// Onay: varsayılan düğme iptaldir. `yanit(true)` yalnızca onay düğmesinde gelir.
    static func onay(ust: Ust, baslik: String, aciklama: String, onay: String = "Tamam",
                     iptal: String = "İptal", yanit: @escaping (Bool) -> Void) {
        mesaj(ust: ust, baslik: baslik, aciklama: aciklama, dugmeler: [iptal, onay]) { yanit($0 == 2) }
    }

    /// Bilgi veya hata bildirimi; tek "Tamam" düğmesi. `tamam` kapandıktan sonra çağrılır.
    static func bilgi(ust: Ust, baslik: String, aciklama: String, hata: Bool = false,
                      tamam: @escaping () -> Void = {}) {
        mesaj(ust: ust, baslik: baslik, aciklama: aciklama, dugmeler: ["Tamam"],
              tur: hata ? GTK_MESSAGE_ERROR : GTK_MESSAGE_INFO) { _ in tamam() }
    }

    /// İki küçük sayı alanı gereken komutlar için ortak, bloklamayan pencere.
    static func ikiTamsayiGir(ust: Ust, baslik: String, aciklama: String,
                              ilk: Int = 3, ikinci: Int = 3,
                              yanit: @escaping (Int, Int) -> Void) {
        let diyalog = gtk_window_new()!
        gtk_widget_add_css_class(diyalog, "notdefteri")
        gtk_window_set_title(nd_window(diyalog), baslik)
        gtk_window_set_modal(nd_window(diyalog), 1)
        gtk_window_set_transient_for(nd_window(diyalog), nd_window(ust))
        gtk_window_set_resizable(nd_window(diyalog), 0)
        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)!
        for kenar in [(gtk_widget_set_margin_top, Int32(16)), (gtk_widget_set_margin_bottom, Int32(16)),
                      (gtk_widget_set_margin_start, Int32(16)), (gtk_widget_set_margin_end, Int32(16))] {
            kenar.0(kutu, kenar.1)
        }
        let aciklamaEtiketi = gtk_label_new(aciklama)!
        gtk_label_set_wrap(nd_label(aciklamaEtiketi), 1)
        gtk_label_set_xalign(nd_label(aciklamaEtiketi), 0)
        gtk_box_append(nd_box(kutu), aciklamaEtiketi)
        let satir = gtk_entry_new()!, sutun = gtk_entry_new()!
        gtk_editable_set_text(OpaquePointer(satir), String(ilk))
        gtk_editable_set_text(OpaquePointer(sutun), String(ikinci))
        for (ad, alan) in [("Satır (başlık dahil)", satir), ("Sütun", sutun)] {
            let satirKutusu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10)!
            let etiket = gtk_label_new(ad)!
            gtk_label_set_xalign(nd_label(etiket), 0)
            gtk_widget_set_hexpand(etiket, 1)
            gtk_widget_set_size_request(alan, 82, -1)
            gtk_box_append(nd_box(satirKutusu), etiket)
            gtk_box_append(nd_box(satirKutusu), alan)
            gtk_box_append(nd_box(kutu), satirKutusu)
        }
        let dugmeler = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_widget_set_halign(dugmeler, GTK_ALIGN_END)
        let vazgec = gtk_button_new_with_label("Vazgeç")!
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(vazgec), "clicked") { gtk_window_destroy(nd_window(diyalog)) }
        gtk_box_append(nd_box(dugmeler), vazgec)
        let ekle = gtk_button_new_with_label("Ekle")!
        let onayla: () -> Void = {
            let satirMetni = String(cString: gtk_editable_get_text(OpaquePointer(satir)))
            let sutunMetni = String(cString: gtk_editable_get_text(OpaquePointer(sutun)))
            guard let satirSayisi = Int(satirMetni.trimmingCharacters(in: .whitespaces)),
                  let sutunSayisi = Int(sutunMetni.trimmingCharacters(in: .whitespaces)) else { return }
            gtk_window_destroy(nd_window(diyalog))
            Platform.anaIsParcaciginda { yanit(satirSayisi, sutunSayisi) }
        }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(ekle), "clicked") { onayla() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(satir), "activate") { onayla() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(sutun), "activate") { onayla() }
        gtk_box_append(nd_box(dugmeler), ekle)
        gtk_box_append(nd_box(kutu), dugmeler)
        gtk_window_set_child(nd_window(diyalog), kutu)
        gtk_window_present(nd_window(diyalog))
        gtk_widget_grab_focus(satir)
        gtk_editable_select_region(OpaquePointer(satir), 0, -1)
    }

    /// Dosya aç. İptalde ve seçilemeyen dosyada `yanit(nil)`.
    static func dosyaAc(ust: Ust, baslik: String = "Aç", yanit: @escaping (URL?) -> Void) {
        sec(ust: ust, baslik: baslik, eylem: GTK_FILE_CHOOSER_ACTION_OPEN, kabul: "Aç", ad: nil, yanit: yanit)
    }

    /// Dosya kaydet; `onerilenAd` ad alanına yazılır. Üzerine yazma onayını GTK seçici sorar.
    static func dosyaKaydet(ust: Ust, baslik: String = "Kaydet", onerilenAd: String? = nil,
                            yanit: @escaping (URL?) -> Void) {
        sec(ust: ust, baslik: baslik, eylem: GTK_FILE_CHOOSER_ACTION_SAVE, kabul: "Kaydet", ad: onerilenAd, yanit: yanit)
    }

    static func klasorSec(ust: Ust, baslik: String = "Klasör seç", yanit: @escaping (URL?) -> Void) {
        sec(ust: ust, baslik: baslik, eylem: GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER, kabul: "Seç", ad: nil, yanit: yanit)
    }

    private static func sec(ust: Ust, baslik: String, eylem: GtkFileChooserAction, kabul: String,
                            ad: String?, yanit: @escaping (URL?) -> Void) {
        let secici = gtk_file_chooser_native_new(baslik, nd_window(ust), eylem, kabul, "İptal")!
        let dialog = UnsafeMutableRawPointer(secici)
        let arayuz = secici
        let yerel = dialog.assumingMemoryBound(to: GtkNativeDialog.self)
        gtk_native_dialog_set_modal(yerel, 1)
        if let ad { gtk_file_chooser_set_current_name(arayuz, ad) }
        var yanitAlindi = false
        GtkKoprusu.sinyalBagla(dialog, "response") { (secilen: gint) in
            guard !yanitAlindi else { return }
            yanitAlindi = true
            var url: URL?
            if secilen == GTK_RESPONSE_ACCEPT.rawValue, let dosya = gtk_file_chooser_get_file(arayuz) {
                if let yol = g_file_get_path(dosya) { url = URL(fileURLWithPath: String(cString: yol)); g_free(yol) }
                g_object_unref(UnsafeMutableRawPointer(dosya))
            }
            // Seçici sinyal içinde bırakılmaz; çağıran referansı yanıttan sonra serbest kalır.
            Platform.anaIsParcaciginda {
                gtk_native_dialog_hide(yerel)
                g_object_unref(dialog)
                yanit(url)
            }
        }
        gtk_native_dialog_show(yerel)
    }
}
