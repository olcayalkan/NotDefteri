import CGtk
import Foundation
import NotDefteriCekirdek

/// Klavye kısayolları penceresi (macOS KisayolPenceresi). Yardım menüsünden ve Ctrl+/ ile açılır.
enum LinuxKisayolPenceresi {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        let pano = KisayolListesi(pencere: pencere)
        // Menü kaydı bileşeni yaşatır; bileşen pencereyi zayıf tutar.
        pencere.menuEkle(["Yardım", "Klavye kısayolları"], kisayol: "<Control>slash") { pano.goster() }
    }
}

/// macOS KisayolPenceresi: menüden okunur; yalnızca kısayolu olan öğeler listelenir. Yazım tetikleyicileri sabittir.
private let editorKisayollari: [(String, String)] = [
    ("# ", "Başlık"), ("- ", "Madde listesi"), ("1. ", "Numaralı liste"), ("[] ", "Yapılacak"),
    ("> ", "Alıntı"), ("---", "Ayırıcı"), ("```", "Kod bloğu"), ("/", "Blok menüsü"),
    ("[[", "Sayfa bağlantısı"), ("Tab / Shift+Tab", "Girintiyi artır / azalt")]

/// Pencere her açılışta yeniden kurulur; kapanınca widget'lar yok olduğu için işaretçiler "destroy"da sıfırlanır.
private final class KisayolListesi {
    private weak var pencere: LinuxPencere?
    private var acik: (pencere: UnsafeMutablePointer<GtkWidget>, arama: UnsafeMutablePointer<GtkWidget>,
                       liste: UnsafeMutablePointer<GtkWidget>)?

    init(pencere: LinuxPencere) { self.pencere = pencere }

    func goster() {
        if let acik {
            gtk_window_present(nd_window(acik.pencere))
            gtk_widget_grab_focus(acik.arama)
            return
        }
        guard let ust = pencere?.pencere else { return }
        let ek = gtk_window_new()!
        gtk_window_set_title(nd_window(ek), "Klavye kısayolları")
        gtk_window_set_default_size(nd_window(ek), 480, 520)
        gtk_window_set_transient_for(nd_window(ek), nd_window(ust))
        gtk_window_set_destroy_with_parent(nd_window(ek), 1)
        gtk_widget_add_css_class(ek, "notdefteri")

        let arama = gtk_entry_new()!
        gtk_entry_set_placeholder_text(GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(arama)), "Kısayollarda ara")
        let liste = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5)!
        gtk_widget_set_margin_start(liste, 6)
        gtk_widget_set_margin_end(liste, 6)
        gtk_widget_set_margin_top(liste, 6)
        let kaydirma = gtk_scrolled_window_new()!
        gtk_widget_set_vexpand(kaydirma, 1)
        gtk_scrolled_window_set_policy(OpaquePointer(kaydirma), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(OpaquePointer(kaydirma), liste)
        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8)!
        gtk_widget_set_margin_start(kutu, 10)
        gtk_widget_set_margin_end(kutu, 10)
        gtk_widget_set_margin_top(kutu, 12)
        gtk_widget_set_margin_bottom(kutu, 10)
        gtk_box_append(nd_box(kutu), arama)
        gtk_box_append(nd_box(kutu), kaydirma)
        gtk_window_set_child(nd_window(ek), kutu)

        acik = (ek, arama, liste)
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(arama), "changed") { [weak self] in self?.yenile() }
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(ek), "destroy") { [weak self] in self?.acik = nil }
        LinuxKodGoruntuleyici.escIleKapat(ek)
        yenile()
        gtk_window_present(nd_window(ek))
        gtk_widget_grab_focus(arama)
    }

    /// Menü kayıt sırası korunur; başlık ilk yol parçasıdır, satır adı son parçadır (macOS öğe başlığı).
    private func gruplar() -> [(String, [(String, String)])] {
        var sonuc: [(String, [(String, String)])] = []
        for oge in pencere?.menuKisayollari ?? [] {
            guard let baslik = oge.yol.first, let ad = oge.yol.last, let tus = oge.kisayol else { continue }
            if let sira = sonuc.firstIndex(where: { $0.0 == baslik }) { sonuc[sira].1.append((ad, tus)) }
            else { sonuc.append((baslik, [(ad, tus)])) }
        }
        return sonuc + [("Editör", editorKisayollari)]
    }

    private func yenile() {
        guard let acik else { return }
        let liste = acik.liste
        while let alt = gtk_widget_get_first_child(liste) { gtk_box_remove(nd_box(liste), alt) }
        let sorgu = aramaIcinSadelestir(String(cString: gtk_editable_get_text(OpaquePointer(acik.arama)))
            .trimmingCharacters(in: .whitespacesAndNewlines))
        for (baslik, satirlar) in gruplar() {
            let eslesenler = satirlar.filter { sorgu.isEmpty || aramaIcinSadelestir("\($0.0) \($0.1) \(baslik)").contains(sorgu) }
            guard !eslesenler.isEmpty else { continue }
            let baslikEtiketi = gtk_label_new(baslik)!
            gtk_label_set_xalign(nd_label(baslikEtiketi), 0)
            gtk_widget_add_css_class(baslikEtiketi, "heading")
            gtk_widget_add_css_class(baslikEtiketi, "dim-label")
            gtk_box_append(nd_box(liste), baslikEtiketi)
            for (ad, tus) in eslesenler {
                let satir = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12)!
                let adEtiketi = gtk_label_new(ad)!
                gtk_label_set_xalign(nd_label(adEtiketi), 0)
                gtk_widget_set_hexpand(adEtiketi, 1)
                let tusEtiketi = gtk_label_new(tus)!
                gtk_label_set_xalign(nd_label(tusEtiketi), 1)
                gtk_widget_add_css_class(tusEtiketi, "dim-label")
                gtk_box_append(nd_box(satir), adEtiketi)
                gtk_box_append(nd_box(satir), tusEtiketi)
                gtk_box_append(nd_box(liste), satir)
            }
        }
    }
}
