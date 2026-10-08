import CGtk
import Foundation
import NotDefteriCekirdek

private typealias Parca = UnsafeMutablePointer<GtkWidget>

private func ham<T>(_ p: UnsafeMutablePointer<T>) -> UnsafeMutableRawPointer { UnsafeMutableRawPointer(p) }
private func ham(_ p: OpaquePointer) -> UnsafeMutableRawPointer { UnsafeMutableRawPointer(p) }

/// Veri argümanı olarak verilen closure'ı destroy notify ile bırakır.
private final class Tutucu<Eylem> {
    let calistir: Eylem
    init(_ calistir: Eylem) { self.calistir = calistir }
}

private func tutucuyuBirak(_ veri: gpointer?, _ closure: UnsafeMutablePointer<GClosure>?) {
    guard let veri else { return }
    Unmanaged<AnyObject>.fromOpaque(veri).release()
}

private func tutucuyuYokEt(_ veri: gpointer?) {
    guard let veri else { return }
    Unmanaged<AnyObject>.fromOpaque(veri).release()
}

/// GtkGestureClick::pressed (n_press, x, y) köprüdeki imzalara uymaz; kendi çağrısı vardır.
private func basmaCagir(_ jest: gpointer?, _ tikSayisi: Int32, _ x: Double, _ y: Double, _ veri: gpointer?) {
    guard let veri else { return }
    Unmanaged<Tutucu<(Double, Double) -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir(x, y)
}

private func cocukModeliUret(_ oge: gpointer?, _ veri: gpointer?) -> OpaquePointer? {
    guard let oge, let veri else { return nil }
    let tutucu = Unmanaged<Tutucu<(gpointer) -> OpaquePointer?>>.fromOpaque(veri).takeUnretainedValue()
    return tutucu.calistir(oge)
}

// MARK: Sürükle-bırak sinyalleri (dönüş değerli imzalar köprüde yok)

private func cBagla(_ nesne: gpointer, _ ad: String, _ geriCagri: GCallback, _ tutucu: AnyObject) {
    g_signal_connect_data(nesne, ad, geriCagri, Unmanaged.passRetained(tutucu).toOpaque(), tutucuyuBirak,
                          GConnectFlags(rawValue: 0))
}

/// GtkDragSource::prepare → GdkContentProvider (transfer full); nil sürüklemeyi başlatmaz.
private let hazirlaC: @convention(c) (gpointer?, Double, Double, gpointer?) -> gpointer? = { _, _, _, veri in
    guard let veri else { return nil }
    return Unmanaged<Tutucu<() -> gpointer?>>.fromOpaque(veri).takeUnretainedValue().calistir()
}

/// GtkDragSource::drag-end; yalnızca sürükleme durumunu temizler, veri silmez.
private let suruklemeBittiC: @convention(c) (gpointer?, gpointer?, gboolean, gpointer?) -> Void = { _, _, _, veri in
    guard let veri else { return }
    Unmanaged<Tutucu<() -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir()
}

private let hareketC: @convention(c) (gpointer?, Double, Double, gpointer?) -> GdkDragAction = { _, x, y, veri in
    guard let veri else { return GdkDragAction(rawValue: 0) }
    return Unmanaged<Tutucu<(Double, Double) -> GdkDragAction>>.fromOpaque(veri).takeUnretainedValue().calistir(x, y)
}

private let birakC: @convention(c) (gpointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean = {
    _, deger, x, y, veri in
    guard let veri else { return 0 }
    let tutucu = Unmanaged<Tutucu<(UnsafePointer<GValue>?, Double, Double) -> Bool>>.fromOpaque(veri).takeUnretainedValue()
    return tutucu.calistir(deger, x, y) ? 1 : 0
}

private func metinSaglayici(_ metin: String) -> gpointer? {
    var deger = GValue()
    g_value_init(&deger, g_type_from_name("gchararray"))
    defer { g_value_unset(&deger) }
    g_value_set_string(&deger, metin)
    return gdk_content_provider_new_for_value(&deger).map { UnsafeMutableRawPointer($0) }
}

private func turMu(_ widget: Parca, _ tur: GType) -> Bool {
    g_type_check_instance_is_a(UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GTypeInstance.self), tur) != 0
}

/// Pano yalnızca bu oturumda üretilen belirteci taşır; dışarıdan gelen metin sürüklemesi sayfa sayılmaz.
private struct SuruklenenSayfa {
    let klasor: URL
    let icerik: URL?
    let mevcutUst: URL
}

private enum Suruklenen {
    case sayfa(SuruklenenSayfa)
    case favori(URL)
}

/// `ust` nil ise kök; `konum` nil ise üstüne bırakma (sıranın sonuna).
private struct BirakmaPlani {
    let ust: AgacDugumu?
    let hedefKlasor: URL
    let liste: [AgacDugumu]
    let konum: Int?
    let ayniUst: Bool
    var sabitler: Set<String> { Set(liste.filter { $0.sabit }.map { $0.ad }) }
}

/// Linux kenar panelinin sayfa ağacı (macOS KenarPaneli'nin temel ağaç davranışı).
final class LinuxKenarPaneli {
    var islemOncesi: ((@escaping () -> Void) -> Void)?
    /// Bağlanmadıysa işlem sessizce düşmez, doğrudan devam eder.
    private func islemOncesiCalistir(_ devam: @escaping () -> Void) {
        if let islemOncesi { islemOncesi(devam) } else { devam() }
    }
    var notSilindi: ((URL) -> Void)?
    var notYenidenAdlandirildi: ((URL, URL) -> Void)?
    var baglarYenidenYazildi: (([String: String]) -> Void)?
    let favoriler = Favoriler()
    let sayfaBaglantilari = SayfaBaglantilari()
    var veriDegisti: [() -> Void] = []
    var anaSayfaIstendi: (() -> Void)?
    private(set) var acikNotURL: URL?
    /// Arama süzgecinden bağımsız, ağaç sırasındaki tüm notlar (Önceki/Sonraki Not).
    var tumNotUrlListesi: [URL] { tumNotlar }

    private weak var pencere: LinuxPencere?
    private let kok: Parca
    private let aramaAlani = gtk_search_entry_new()!
    private let liste: Parca
    private var secim: OpaquePointer?

    private var tumKokDugumler: [AgacDugumu] = []
    private var gorunenKok: [AgacDugumu] = []
    private var tumNotlar: [URL] = []
    /// Klasör yolu → görüntülenen düğüm; model öğeleri (GtkStringObject) yolu taşır.
    private var dugumler: [String: AgacDugumu] = [:]
    /// Açık bırakılan dallar oturumlar arasında hatırlanır (macOS ile aynı anahtar).
    private var acikKlasorYollari = Set(gAyarlar.stringArray(forKey: "acikKlasorler") ?? [])
    private var aramaFiltresiEtkin = false
    private var dalGeriYukleniyor = false
    /// Her motion olayında dosya sistemi doğrulaması yapılmasın; yalnızca kaynak/hedef değişince yeniden hesaplanır.
    private var tasimaOnbellegi: (anahtar: String, gecerli: Bool)?
    private var aramaIptal: ZamanlayiciIptal?
    private(set) var icerikOnbellek: [URL: OnbellekGirdisi] = [:]
    private var onbellekNesli = 0
    /// Tek örnek: açılış temizliği ve çöp penceresi (LinuxCopKutusu) aynı kilidi paylaşır.
    let copKutusu = CopKutusu()
    private var menuDugumu: AgacDugumu?
    private var acikMenu: Parca?
    private var genislemeBaglari: [OpaquePointer: gulong] = [:]

    private let kisaYolKutusu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
    private let favoriBolumu = gtk_expander_new("Favoriler")!
    private let favoriListesi = gtk_list_box_new()!
    private let sonBolumu = gtk_expander_new("Son açılanlar")!
    private let sonListesi = gtk_list_box_new()!
    private var favoriURLleri: [URL] = []
    private var sonURLleri: [URL] = []
    private var kisaYolBekliyor = false
    private var surukleme: (belirtec: String, oge: Suruklenen)?

    init(pencere: LinuxPencere) {
        self.pencere = pencere
        kok = pencere.kenarPanelYuvasi
        liste = gtk_list_view_new(nil, nil)!
        arayuzuKur()
        eylemleriKur()
        sayfaBaglantilari.sonAcilanlarDegisti = { [weak self] in self?.veriyiBildir() }
        yenile()
    }

    deinit {
        aramaIptal?()
    }

    /// Editör bir notu açınca ağacı yeniden kurmadan yalnızca açık sayfayı vurgular.
    func acikNotuBildir(_ url: URL?) {
        let onceki = acikNotURL
        acikNotURL = url
        acikNotuSec()
        if let url, url != onceki { sayfaBaglantilari.acildi(url) }
        veriyiBildir()
    }

    func notIceriginiGuncelle(_ url: URL, metin: String) {
        icerikOnbellek[url] = onbellekGirdisiUret(metin, tarih: degistirilmeTarihi(url))
        // Eski disk okuması yeni kaydı ezmesin; kalan notlar yeni nesilde tamamlanır.
        onbellegiTazele()
        if aramaFiltresiEtkin { filtreUygula() }
        veriyiBildir()
    }

    /// Ağacı diskten yeniden kurar.
    func yenile(secili: URL? = nil) {
        if let secili { acikNotURL = secili }
        tumKokDugumler = agaciYukle()
        tumNotlar = notlariDuzlestir(tumKokDugumler)
        // Yol çözümü pahalı (3.5k notta ~250 ms); değişmeyen sayfa yeniden kurulmaz (macOS sayfaIndeksiniGuncelle).
        let eskiler = Dictionary(sayfaBaglantilari.sayfalar.map { ($0.url, $0) }, uniquingKeysWith: { ilk, _ in ilk })
        let sayfalar = tumNotlar.map { eskiler[$0] ?? SayfaSecenegi(url: $0) }
        if sayfalar != sayfaBaglantilari.sayfalar { sayfaBaglantilari.guncelle(sayfalar) }
        favoriler.olmayanlariDusur()
        sayfaBaglantilari.olmayanSonAcilanlariDusur()
        let mevcut = Set(tumNotlar)
        icerikOnbellek = icerikOnbellek.filter { mevcut.contains($0.key) }
        onbellegiTazele()
        filtreUygula()
        veriyiBildir()
    }

    private func veriyiBildir() {
        kisaYollariPlanla()
        for kanca in veriDegisti { kanca() }
    }

    // MARK: Arayüz

    private func arayuzuKur() {
        // macOS'taki "Ana Sayfa" düğmesi: kenar panelin en üstünde.
        let anaSayfa = GtkKoprusu.simgeliDugme("user-home-symbolic", "Ana Sayfa")
        gtk_widget_set_margin_top(anaSayfa, 8)
        gtk_widget_set_margin_start(anaSayfa, 8)
        gtk_widget_set_margin_end(anaSayfa, 8)
        gtk_widget_set_tooltip_text(anaSayfa, "Ana Sayfa")
        GtkKoprusu.sinyalBagla(ham(anaSayfa), "clicked") { [weak self] in self?.anaSayfaIstendi?() }
        gtk_box_append(nd_box(kok), anaSayfa)

        let yeniSayfa = gtk_button_new_with_label("+ Yeni sayfa")!
        gtk_widget_set_margin_top(yeniSayfa, 8)
        gtk_widget_set_margin_start(yeniSayfa, 8)
        gtk_widget_set_margin_end(yeniSayfa, 8)
        GtkKoprusu.sinyalBagla(ham(yeniSayfa), "clicked") { [weak self] in self?.ustSeviyeSayfaEkle() }
        gtk_box_append(nd_box(kok), yeniSayfa)

        gtk_widget_set_margin_top(aramaAlani, 8)
        gtk_widget_set_margin_bottom(aramaAlani, 8)
        gtk_widget_set_margin_start(aramaAlani, 8)
        gtk_widget_set_margin_end(aramaAlani, 8)
        gtk_widget_set_tooltip_text(aramaAlani, "Notlarda ara...")
        // search-changed'in yerleşik gecikmesine güvenmeyiz; 0,15 sn'lik debounce açıktır.
        GtkKoprusu.sinyalBagla(ham(aramaAlani), "changed") { [weak self] in self?.aramaDegisti() }
        gtk_box_append(nd_box(kok), aramaAlani)

        // ponytail: kısa yollar ağacın üstünde sabit alanda; çok favoride bölüm katlanır, ayrı kaydırma gerekirse eklenir.
        bolumKur(favoriBolumu, favoriListesi, anahtar: "favorilerKatli", favori: true)
        bolumKur(sonBolumu, sonListesi, anahtar: "sonAcilanlarKatli", favori: false)
        gtk_widget_set_visible(favoriBolumu, 0)
        gtk_widget_set_margin_start(kisaYolKutusu, 8)
        gtk_widget_set_margin_end(kisaYolKutusu, 8)
        gtk_box_append(nd_box(kok), kisaYolKutusu)
        birakmaHedefiKur(favoriListesi, hareket: { [weak self] _, _ in
            if case .favori? = self?.surukleme?.oge { return true }
            return false
        }, birak: { [weak self] deger, x, y in self?.favoriyeBirak(deger, x, y) ?? false })

        let fabrika = gtk_signal_list_item_factory_new()!
        GtkKoprusu.sinyalBagla(ham(fabrika), "setup") { [weak self] (oge: gpointer?) in
            if let oge { self?.satirKur(OpaquePointer(oge)) }
        }
        GtkKoprusu.sinyalBagla(ham(fabrika), "bind") { [weak self] (oge: gpointer?) in
            if let oge { self?.satirBagla(OpaquePointer(oge)) }
        }
        GtkKoprusu.sinyalBagla(ham(fabrika), "unbind") { [weak self] (oge: gpointer?) in
            if let oge { self?.satirCoz(OpaquePointer(oge)) }
        }
        gtk_list_view_set_factory(OpaquePointer(ham(liste)), fabrika)
        g_object_unref(ham(fabrika))
        gtk_list_view_set_single_click_activate(OpaquePointer(ham(liste)), 1)
        GtkKoprusu.sinyalBagla(ham(liste), "activate") { [weak self] (konum: guint) in self?.satirEtkinlesti(konum) }
        // Tek hedef: satır, satır arası ve boşluk (kök) aynı yerde ayrılır; satır payına bırakma köke kaçmaz.
        birakmaHedefiKur(liste, hareket: { [weak self] x, y in
            guard let self, case .sayfa(let kaynak)? = self.surukleme?.oge else { return false }
            return self.birakmaPlani(kaynak, x, y) != nil
        }, birak: { [weak self] deger, x, y in self?.agacaBirak(deger, x, y) ?? false })

        let kaydirma = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_policy(OpaquePointer(ham(kaydirma)), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(OpaquePointer(ham(kaydirma)), liste)
        gtk_widget_set_vexpand(kaydirma, 1)
        gtk_box_append(nd_box(kok), kaydirma)
    }

    /// Sağ tık menüsü eylemleri; menü her açılışta güncel etiketlerle yeniden kurulur.
    private func eylemleriKur() {
        let grup = g_simple_action_group_new()!
        let eylemler: [(String, (AgacDugumu) -> Void)] = [
            ("favori", { [weak self] in self?.favoriyiDegistir($0) }),
            ("altsayfa", { [weak self] in self?.altSayfaEkle($0) }),
            ("kardes", { [weak self] in self?.kardesSayfaEkle($0) }),
            ("adlandir", { [weak self] in self?.adlandirmaSor($0) }),
            ("sabitle", { [weak self] in self?.sabitlemeyiDegistir($0) }),
            ("klasor", { [weak self] in self?.klasoreDonustur($0) }),
            ("sil", { [weak self] in self?.silmeSor($0) })
        ]
        for (ad, govde) in eylemler {
            let eylem = g_simple_action_new(ad, nil)!
            GtkKoprusu.sinyalBagla(ham(eylem), "activate") { [weak self] (_: gpointer?) in
                guard let dugum = self?.menuDugumu else { return }
                // Menü kapanırken ağacı yeniden kurmamak için işlem sonraki döngüde çalışır.
                Platform.anaIsParcaciginda {
                    self?.menuyuKapat()
                    govde(dugum)
                }
            }
            g_action_map_add_action(OpaquePointer(ham(grup)), OpaquePointer(ham(eylem)))
            g_object_unref(ham(eylem))
        }
        gtk_widget_insert_action_group(kok, "kenar", OpaquePointer(ham(grup)))
        g_object_unref(ham(grup))
    }

    // MARK: Satır fabrikası

    private func satirKur(_ oge: OpaquePointer) {
        let ikon = gtk_image_new()!
        let etiket = gtk_label_new("")!
        gtk_label_set_xalign(nd_label(etiket), 0)
        gtk_label_set_ellipsize(nd_label(etiket), PANGO_ELLIPSIZE_END)
        gtk_widget_set_hexpand(etiket, 1)
        // Emoji (📌) renkli emoji yazı tipi olmayan sistemlerde kutu görünüyordu; simge temasından gelir.
        let raptiye = gtk_image_new_from_icon_name("view-pin-symbolic")!
        gtk_widget_set_opacity(raptiye, 0.5)
        let kutu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5)!
        gtk_box_append(nd_box(kutu), ikon)
        gtk_box_append(nd_box(kutu), etiket)
        gtk_box_append(nd_box(kutu), raptiye)
        let genisletici = gtk_tree_expander_new()!
        gtk_tree_expander_set_child(OpaquePointer(ham(genisletici)), kutu)
        gtk_list_item_set_child(oge, genisletici)

        // Widget geri kullanılır; düğüm her olayda öğenin GÜNCEL satırından çözülür.
        sagTikKur(genisletici) { [weak self] x, y in
            guard let self, let satir = gtk_list_item_get_item(oge), let dugum = self.dugumu(OpaquePointer(satir)) else { return }
            self.menuAc(dugum, genisletici, x, y)
        }
        surukleKaynagiKur(genisletici) { [weak self] in
            guard let satir = gtk_list_item_get_item(oge), let dugum = self?.dugumu(OpaquePointer(satir)) else { return nil }
            let ust = dugum.icerikURL.map { ustKlasor($0) } ?? dugum.klasorURL.deletingLastPathComponent()
            return .sayfa(SuruklenenSayfa(klasor: dugum.klasorURL, icerik: dugum.icerikURL, mevcutUst: ust))
        }
    }

    private func sagTikKur(_ widget: Parca, _ eylem: @escaping (Double, Double) -> Void) {
        let jest = gtk_gesture_click_new()!
        gtk_gesture_single_set_button(OpaquePointer(ham(jest)), 3)
        g_signal_connect_data(ham(jest), "pressed",
                              unsafeBitCast(basmaCagir as @convention(c) (gpointer?, Int32, Double, Double, gpointer?) -> Void,
                                            to: GCallback.self),
                              Unmanaged.passRetained(Tutucu(eylem)).toOpaque(), tutucuyuBirak, GConnectFlags(rawValue: 0))
        gtk_widget_add_controller(widget, OpaquePointer(ham(jest)))
    }

    private func satirBagla(_ oge: OpaquePointer) {
        guard let satirNesnesi = gtk_list_item_get_item(oge), let genisletici = gtk_list_item_get_child(oge) else { return }
        let satir = OpaquePointer(satirNesnesi)
        gtk_tree_expander_set_list_row(OpaquePointer(ham(genisletici)), satir)
        if let dugum = dugumu(satir), let kutu = gtk_tree_expander_get_child(OpaquePointer(ham(genisletici))),
           let ikon = gtk_widget_get_first_child(kutu), let etiket = gtk_widget_get_next_sibling(ikon),
           let raptiye = gtk_widget_get_next_sibling(etiket) {
            gtk_image_set_from_icon_name(OpaquePointer(ham(ikon)),
                                         dugum.sayfaMi ? "text-x-generic-symbolic" : "folder-symbolic")
            gtk_label_set_text(nd_label(etiket), dugum.ad)
            gtk_widget_set_tooltip_text(etiket, dugum.ad)
            // Süzülmüş ağaçta düğümler kopyadır; sabit durumu güvenilir değil, ama eşleşen düğümde korunur.
            gtk_widget_set_visible(raptiye, dugum.sabit ? 1 : 0)
        }
        genislemeBaglari[oge] = GtkKoprusu.sinyalBagla(satirNesnesi, "notify::expanded") { [weak self] (_: gpointer?) in
            self?.genislemeDegisti(satir)
        }
    }

    private func satirCoz(_ oge: OpaquePointer) {
        if let ham = gtk_list_item_get_item(oge), let kimlik = genislemeBaglari.removeValue(forKey: oge) {
            g_signal_handler_disconnect(ham, kimlik)
        }
        if let genisletici = gtk_list_item_get_child(oge) {
            gtk_tree_expander_set_list_row(OpaquePointer(ham(genisletici)), nil)
        }
    }

    private func satirEtkinlesti(_ konum: guint) {
        guard let secim, let ham = g_list_model_get_item(secim, konum) else { return }
        let satir = OpaquePointer(ham)
        defer { g_object_unref(ham) }
        guard let dugum = dugumu(satir) else { return }
        guard let url = dugum.icerikURL else {
            // Salt kapsayıcı klasör açılacak sayfa değil; tıklama dalı açar/kapatır.
            gtk_tree_list_row_set_expanded(satir, gtk_tree_list_row_get_expanded(satir) == 0 ? 1 : 0)
            acikNotuSec()
            return
        }
        // Not açmak ağacı yeniden kurabilir; tıklama hareketi sürerken satır widget'ları yok
        // edilince GTK "Broken accounting of active state" uyarısı veriyordu. Hareket bitince açılır.
        Platform.anaIsParcaciginda { [weak self] in
            self?.pencere?.notSecildi(url)
            self?.acikNotuSec()
        }
    }

    private func dugumu(_ satir: OpaquePointer) -> AgacDugumu? {
        guard let oge = gtk_tree_list_row_get_item(satir) else { return nil }
        defer { g_object_unref(oge) }
        guard let metin = gtk_string_object_get_string(OpaquePointer(oge)) else { return nil }
        return dugumler[String(cString: metin)]
    }

    // MARK: Model

    /// Her düğüm bir GtkStringObject'tir; metni klasör yoludur.
    private func listeModeli(_ dugumler: [AgacDugumu]) -> OpaquePointer {
        let depo = g_list_store_new(gtk_string_object_get_type())!
        for dugum in dugumler {
            let oge = gtk_string_object_new(dugum.klasorURL.path)!
            g_list_store_append(depo, ham(oge))
            g_object_unref(ham(oge))
        }
        return depo
    }

    fileprivate func cocukModeli(_ oge: gpointer) -> OpaquePointer? {
        guard let metin = gtk_string_object_get_string(OpaquePointer(oge)),
              let dugum = dugumler[String(cString: metin)], !dugum.cocuklar.isEmpty else { return nil }
        return listeModeli(dugum.cocuklar)
    }

    private func modeliKur() {
        menuyuKapat()
        dugumler = [:]
        haritayiKur(gorunenKok)
        let tutucu = Tutucu<(gpointer) -> OpaquePointer?> { [weak self] oge in self?.cocukModeli(oge) }
        // Arama sırasında eşleşmeler görünsün diye tüm dallar açılır; açık durum yalnızca aramasızken kalıcıdır.
        guard let agac = gtk_tree_list_model_new(listeModeli(gorunenKok), 0, aramaFiltresiEtkin ? 1 : 0,
                                                 cocukModeliUret, Unmanaged.passRetained(tutucu).toOpaque(),
                                                 tutucuyuYokEt) else { return }
        if !aramaFiltresiEtkin {
            dalGeriYukleniyor = true
            var sira: guint = 0
            while let satir = gtk_tree_list_model_get_child_row(agac, sira) {
                dalGeriYukle(satir)
                g_object_unref(ham(satir))
                sira += 1
            }
            dalGeriYukleniyor = false
        }
        let yeniSecim = gtk_single_selection_new(agac)!
        gtk_single_selection_set_autoselect(yeniSecim, 0)
        gtk_single_selection_set_can_unselect(yeniSecim, 1)
        gtk_list_view_set_model(OpaquePointer(ham(liste)), yeniSecim)
        if let eski = secim { g_object_unref(ham(eski)) }
        secim = yeniSecim
        acikNotuSec()
    }

    private func haritayiKur(_ dizi: [AgacDugumu]) {
        for dugum in dizi {
            dugumler[dugum.klasorURL.path] = dugum
            haritayiKur(dugum.cocuklar)
        }
    }

    /// Kayıtlı açık dalları (iç içe olanlar dahil) satırdan başlayarak açar.
    private func dalGeriYukle(_ satir: OpaquePointer) {
        guard gtk_tree_list_row_is_expandable(satir) != 0, let dugum = dugumu(satir),
              acikKlasorYollari.contains(dugum.cocuklarKlasoru.path) else { return }
        gtk_tree_list_row_set_expanded(satir, 1)
        var sira: guint = 0
        while let cocuk = gtk_tree_list_row_get_child_row(satir, sira) {
            dalGeriYukle(cocuk)
            g_object_unref(ham(cocuk))
            sira += 1
        }
    }

    private func genislemeDegisti(_ satir: OpaquePointer) {
        guard !dalGeriYukleniyor, !aramaFiltresiEtkin, let dugum = dugumu(satir) else { return }
        let yol = dugum.cocuklarKlasoru.path
        if gtk_tree_list_row_get_expanded(satir) != 0 {
            acikKlasorYollari.insert(yol)
            // GTK çocuk satırları yeniden kurar; alt dalların açık durumu kayıttan döner.
            dalGeriYukleniyor = true
            var sira: guint = 0
            while let cocuk = gtk_tree_list_row_get_child_row(satir, sira) {
                dalGeriYukle(cocuk)
                g_object_unref(ham(cocuk))
                sira += 1
            }
            dalGeriYukleniyor = false
        } else {
            acikKlasorYollari.remove(yol)
        }
        acikKlasorleriKaydet()
    }

    private func acikKlasorleriKaydet() {
        gAyarlar.set(Array(acikKlasorYollari), forKey: "acikKlasorler")
    }

    /// Açık sayfanın satırını seçili (vurgulu) yapar; yoksa seçimi kaldırır.
    private func acikNotuSec() {
        guard let secim else { return }
        var bulunan = guint.max // GTK_INVALID_LIST_POSITION
        if let acikNotURL {
            let sayi = g_list_model_get_n_items(secim)
            for sira in 0..<sayi {
                guard let ham = g_list_model_get_item(secim, sira) else { continue }
                let eslesti = dugumu(OpaquePointer(ham))?.icerikURL == acikNotURL
                g_object_unref(ham)
                if eslesti { bulunan = sira; break }
            }
        }
        gtk_single_selection_set_selected(secim, bulunan)
    }

    // MARK: Arama

    private func aramaDegisti() {
        aramaIptal?()
        aramaIptal = Platform.zamanlayici(0.15) { [weak self] in
            self?.aramaIptal = nil
            self?.filtreUygula()
        }
    }

    private func filtreUygula() {
        aramaIptal?()
        aramaIptal = nil
        let sorgu = aramaIcinSadelestir(aramaMetni().trimmingCharacters(in: .whitespacesAndNewlines))
        aramaFiltresiEtkin = !sorgu.isEmpty
        // macOS'taki gibi arama sırasında kısa yol bölümleri gizlenir.
        gtk_widget_set_visible(kisaYolKutusu, aramaFiltresiEtkin ? 0 : 1)
        gorunenKok = sorgu.isEmpty ? tumKokDugumler : suzulmusAgac(tumKokDugumler, sorgu: sorgu)
        modeliKur()
    }

    private func aramaMetni() -> String {
        gtk_editable_get_text(OpaquePointer(ham(aramaAlani))).map { String(cString: $0) } ?? ""
    }

    /// Eşleşen sayfa tüm alt dallarıyla görünür; eşleşen torunu olan ata da kalır.
    private func suzulmusAgac(_ dizi: [AgacDugumu], sorgu: String) -> [AgacDugumu] {
        var sonuc: [AgacDugumu] = []
        for dugum in dizi {
            let esliyor = aramaIcinSadelestir(dugum.ad).contains(sorgu)
                || (dugum.icerikURL.flatMap { icerikOnbellek[$0] }?.aranabilirMetin.contains(sorgu) ?? false)
            if esliyor {
                sonuc.append(dugum)
                continue
            }
            let kalan = suzulmusAgac(dugum.cocuklar, sorgu: sorgu)
            if !kalan.isEmpty {
                sonuc.append(AgacDugumu(icerikURL: dugum.icerikURL, klasorURL: dugum.klasorURL, cocuklar: kalan))
            }
        }
        return sonuc
    }

    private func notlariDuzlestir(_ dizi: [AgacDugumu]) -> [URL] {
        dizi.flatMap { ($0.icerikURL.map { [$0] } ?? []) + notlariDuzlestir($0.cocuklar) }
    }

    /// Arka planda yalnızca tarihi değişen notlar okunur; sonuç ana döngüde nesil kontrolüyle uygulanır.
    private func onbellegiTazele() {
        onbellekNesli += 1
        let nesil = onbellekNesli, notlar = tumNotlar, eski = icerikOnbellek
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var yeni: [URL: OnbellekGirdisi] = [:]
            for url in notlar {
                let tarih = degistirilmeTarihi(URL(fileURLWithPath: url.path))
                if let girdi = eski[url], girdi.tarih == tarih {
                    yeni[url] = girdi
                } else if let metin = try? String(contentsOf: url, encoding: .utf8) {
                    yeni[url] = onbellekGirdisiUret(metin, tarih: tarih)
                }
            }
            Platform.anaIsParcaciginda {
                guard let self, nesil == self.onbellekNesli else { return }
                self.icerikOnbellek = yeni
                self.veriyiBildir()
                if self.aramaFiltresiEtkin { self.filtreUygula() }
            }
        }
    }

    // MARK: Sağ tık menüsü

    /// `kisaYol`: favori/son açılan satırı; düğüm ağaçtaki örnek olmadığından sabitleme sunulmaz.
    private func menuAc(_ dugum: AgacDugumu, _ hedef: Parca, _ x: Double, _ y: Double, kisaYol: Bool = false) {
        menuyuKapat()
        menuDugumu = dugum
        let model = g_menu_new()!
        if let url = dugum.icerikURL {
            g_menu_append(model, favoriler.iceriyor(url) ? "Favorilerden çıkar" : "Favorilere ekle", "kenar.favori")
        }
        g_menu_append(model, "Yeni alt sayfa", "kenar.altsayfa")
        g_menu_append(model, "Yanına sayfa ekle", "kenar.kardes")
        g_menu_append(model, "Yeniden adlandır", "kenar.adlandir")
        // Süzülmüş ağaçta sıra kaydı güvenilmez; macOS'taki gibi arama sırasında sabitleme yok.
        if !aramaFiltresiEtkin, !kisaYol {
            g_menu_append(model, dugum.sabit ? "Sabitlemeyi kaldır" : "Sabitle", "kenar.sabitle")
        }
        // macOS gibi: dönüştürme yalnızca eski düzendeki ("Ad.md") düz notlarda sunulur.
        if let icerik = dugum.icerikURL, icerik.lastPathComponent != kIcerikDosyaAdi {
            g_menu_append(model, "Sayfa klasörüne dönüştür", "kenar.klasor")
        }
        g_menu_append(model, "Sil", "kenar.sil")
        let menu = gtk_popover_menu_new_from_model(GtkKoprusu.gtkIsaretci(ham(model)))!
        g_object_unref(ham(model))
        // GtkListBoxRow'a bağlanan menü "kenar" eylemlerini bulamıyor, tüm öğeler devre dışı
        // görünüyordu; menü eylem grubunun kurulduğu kenar panele bağlanır, konum ona çevrilir.
        var px = x, py = y
        gtk_widget_translate_coordinates(hedef, kok, x, y, &px, &py)
        gtk_widget_set_parent(menu, kok)
        let popover: UnsafeMutablePointer<GtkPopover> = GtkKoprusu.gtkIsaretci(ham(menu))
        gtk_popover_set_has_arrow(popover, 0)
        var dikdortgen = GdkRectangle(x: Int32(px), y: Int32(py), width: 1, height: 1)
        gtk_popover_set_pointing_to(popover, &dikdortgen)
        acikMenu = menu
        GtkKoprusu.sinyalBagla(ham(menu), "closed") { [weak self] in
            // Öğeye tıklanınca GTK önce menüyü kapatır, eylemi sonra çalıştırır. Menü burada hemen
            // ayrılırsa eylem "kenar" grubunu bulamıyor ve hiçbir öğe çalışmıyordu; ayırma ertelenir.
            Platform.anaIsParcaciginda { [weak self] in self?.menuyuKapat(menu) }
        }
        gtk_popover_popup(popover)
    }

    /// `yalnizca` verilirse yalnızca o menü kapatılır; ertelenen kapanış sonradan açılan menüye dokunmaz.
    private func menuyuKapat(_ yalnizca: UnsafeMutablePointer<GtkWidget>? = nil) {
        guard let menu = acikMenu, yalnizca == nil || yalnizca == menu else { return }
        acikMenu = nil
        gtk_widget_unparent(menu)
    }

    // MARK: Favoriler ve son açılanlar (macOS KenarPaneli+KisaYollar)

    private func bolumKur(_ bolum: Parca, _ liste: Parca, anahtar: String, favori: Bool) {
        let kutu = OpaquePointer(ham(liste))
        gtk_list_box_set_selection_mode(kutu, GTK_SELECTION_NONE)
        gtk_expander_set_child(OpaquePointer(ham(bolum)), liste)
        gtk_expander_set_expanded(OpaquePointer(ham(bolum)), gAyarlar.bool(forKey: anahtar) ? 0 : 1)
        GtkKoprusu.sinyalBagla(ham(bolum), "notify::expanded") { (_: gpointer?) in
            gAyarlar.set(gtk_expander_get_expanded(OpaquePointer(ham(bolum))) == 0, forKey: anahtar)
        }
        GtkKoprusu.sinyalBagla(ham(liste), "row-activated") { [weak self] (satir: gpointer?) in
            guard let self, let satir else { return }
            let sira = Int(gtk_list_box_row_get_index(GtkKoprusu.gtkIsaretci(satir)))
            let urller = favori ? self.favoriURLleri : self.sonURLleri
            guard urller.indices.contains(sira) else { return }
            self.pencere?.notSecildi(urller[sira])
        }
        gtk_box_append(nd_box(kisaYolKutusu), bolum)
    }

    /// Açma/seçim/sürükleme sinyalinin içinde satırlar yok edilmez; güncelleme sonraki döngüdedir.
    private func kisaYollariPlanla() {
        guard !kisaYolBekliyor else { return }
        kisaYolBekliyor = true
        Platform.anaIsParcaciginda { [weak self] in self?.kisaYollariYenile() }
    }

    private func kisaYollariYenile() {
        kisaYolBekliyor = false
        let favoriler = self.favoriler.sayfalar
        let sonlar = Array(sayfaBaglantilari.sonAcilanlar.prefix(5))
        guard favoriler != favoriURLleri || sonlar != sonURLleri else { return }
        // Açık menünün üst satırı silinebilir; popover önce ayrılır.
        menuyuKapat()
        favoriURLleri = favoriler
        sonURLleri = sonlar
        satirlariKur(favoriListesi, favoriler, favori: true)
        satirlariKur(sonListesi, sonlar, favori: false)
        gtk_widget_set_visible(favoriBolumu, favoriler.isEmpty ? 0 : 1)
    }

    private func satirlariKur(_ liste: Parca, _ urller: [URL], favori: Bool) {
        let kutu = OpaquePointer(ham(liste))
        while let cocuk = gtk_widget_get_first_child(liste) { gtk_list_box_remove(kutu, cocuk) }
        for url in urller {
            let etiket = gtk_label_new(sayfaAdi(url))!
            gtk_label_set_xalign(nd_label(etiket), 0)
            gtk_label_set_ellipsize(nd_label(etiket), PANGO_ELLIPSIZE_END)
            gtk_widget_set_margin_start(etiket, 6)
            gtk_widget_set_tooltip_text(etiket, sayfaBagYolu(url))
            gtk_list_box_append(kutu, etiket)
            guard let satir = gtk_widget_get_parent(etiket) else { continue }
            sagTikKur(satir) { [weak self] x, y in
                self?.menuAc(AgacDugumu(icerikURL: url, klasorURL: sayfaKlasoru(url)), satir, x, y, kisaYol: true)
            }
            if favori { surukleKaynagiKur(satir) { .favori(url) } }
        }
    }

    private func favoriyiDegistir(_ dugum: AgacDugumu) {
        guard let url = dugum.icerikURL else { return }
        if favoriler.iceriyor(url) { favoriler.cikar(url) } else { favoriler.ekle(url) }
        veriyiBildir()
    }

    /// Favoriler yalnızca kendi içinde yeniden sıralanır (macOS ile aynı).
    private func favoriyeBirak(_ deger: UnsafePointer<GValue>?, _ x: Double, _ y: Double) -> Bool {
        guard case .favori(let url)? = suruklenenAl(deger) else { return false }
        var hedef = favoriURLleri.count
        if let satir = gtk_list_box_get_row_at_y(OpaquePointer(ham(favoriListesi)), Int32(y)) {
            let sira = Int(gtk_list_box_row_get_index(satir))
            let widget: Parca = GtkKoprusu.gtkIsaretci(UnsafeMutableRawPointer(satir))
            var sx = 0.0, sy = 0.0
            gtk_widget_translate_coordinates(favoriListesi, widget, x, y, &sx, &sy)
            hedef = sy > Double(gtk_widget_get_height(widget)) / 2 ? sira + 1 : sira
        }
        favoriler.tasi(url, hedef: hedef)
        veriyiBildir()
        return true
    }

    // MARK: Sürükle-bırak (macOS KenarPaneli+SurukleBirak)

    private func surukleKaynagiKur(_ widget: Parca, _ oge: @escaping () -> Suruklenen?) {
        let kaynak = gtk_drag_source_new()!
        gtk_drag_source_set_actions(kaynak, GDK_ACTION_MOVE)
        cBagla(ham(kaynak), "prepare", unsafeBitCast(hazirlaC, to: GCallback.self), Tutucu<() -> gpointer?> { [weak self] in
            guard let self, let suruklenen = oge() else { return nil }
            let belirtec = "notdefteri-sayfa:\(UUID().uuidString)"
            self.surukleme = (belirtec, suruklenen)
            return metinSaglayici(belirtec)
        })
        cBagla(ham(kaynak), "drag-end", unsafeBitCast(suruklemeBittiC, to: GCallback.self),
               Tutucu<() -> Void> { [weak self] in
                   self?.surukleme = nil
                   self?.tasimaOnbellegi = nil
               })
        gtk_widget_add_controller(widget, kaynak)
    }

    private func birakmaHedefiKur(_ widget: Parca, hareket: @escaping (Double, Double) -> Bool,
                                  birak: @escaping (UnsafePointer<GValue>?, Double, Double) -> Bool) {
        let hedef = gtk_drop_target_new(g_type_from_name("gchararray"), GDK_ACTION_MOVE)!
        cBagla(ham(hedef), "motion", unsafeBitCast(hareketC, to: GCallback.self),
               Tutucu<(Double, Double) -> GdkDragAction> { hareket($0, $1) ? GDK_ACTION_MOVE : GdkDragAction(rawValue: 0) })
        cBagla(ham(hedef), "drop", unsafeBitCast(birakC, to: GCallback.self), Tutucu(birak))
        gtk_widget_add_controller(widget, hedef)
    }

    /// Yalnızca bu panelin başlattığı sürüklemenin belirteci kabul edilir; bir kez tüketilir.
    private func suruklenenAl(_ deger: UnsafePointer<GValue>?) -> Suruklenen? {
        guard let deger, deger.pointee.g_type == g_type_from_name("gchararray"),
              let metin = g_value_get_string(deger), let surukleme,
              String(cString: metin) == surukleme.belirtec else { return nil }
        self.surukleme = nil
        return surukleme.oge
    }

    private enum BirakmaNoktasi {
        case bosluk
        case cozulemedi
        case satir(OpaquePointer, oran: Double)
    }

    /// Bırakma noktasındaki güncel GtkTreeListRow ve satır içindeki dikey oran. Boşluk (kök) ile
    /// çözülemeyen nokta ayrıdır: ikincisinde bırakma reddedilir, sayfa yanlışlıkla köke gitmez.
    private func satirBul(_ x: Double, _ y: Double) -> BirakmaNoktasi {
        guard var widget = gtk_widget_pick(liste, x, y, GTK_PICK_DEFAULT) else { return .cozulemedi }
        if widget == liste { return .bosluk }
        let tur = gtk_tree_expander_get_type()
        while !turMu(widget, tur) {
            guard let ust = gtk_widget_get_parent(widget) else { return .cozulemedi }
            if ust == liste {
                // Satır kabının payı: içindeki genişletici satırı temsil eder.
                guard let cocuk = gtk_widget_get_first_child(widget), turMu(cocuk, tur) else { return .cozulemedi }
                widget = cocuk
                break
            }
            widget = ust
        }
        guard let satir = gtk_tree_expander_get_list_row(OpaquePointer(ham(widget))) else { return .cozulemedi }
        var sx = 0.0, sy = 0.0
        gtk_widget_translate_coordinates(liste, widget, x, y, &sx, &sy)
        return .satir(satir, oran: sy / Double(max(1, gtk_widget_get_height(widget))))
    }

    /// Üst/alt çeyrek araya, orta üstüne bırakmadır; geçersiz bırakmada nil (macOS validateDrop).
    private func birakmaPlani(_ kaynak: SuruklenenSayfa, _ x: Double, _ y: Double) -> BirakmaPlani? {
        var ust: AgacDugumu?
        var konum: Int?
        switch satirBul(x, y) {
        case .cozulemedi: return nil
        case .bosluk: break
        case .satir(let satir, let oran):
            guard let hedef = dugumu(satir) else { return nil }
            // Arama sırasında düğümler kopya; araya bırakma üstüne bırakmaya düşer.
            let araya = !aramaFiltresiEtkin && (oran < 0.25 || oran > 0.75)
            if araya, oran > 0.75, gtk_tree_list_row_get_expanded(satir) != 0 {
                ust = hedef
                konum = 0
            } else if araya {
                ust = dugumler[hedef.klasorURL.deletingLastPathComponent().path]
                guard let sira = (ust?.cocuklar ?? gorunenKok).firstIndex(where: { $0 === hedef }) else { return nil }
                konum = oran > 0.75 ? sira + 1 : sira
            } else {
                ust = hedef
            }
        }
        let hedefKlasor = ust?.cocuklarKlasoru ?? notlarKlasoru()
        let liste = ust?.cocuklar ?? gorunenKok
        let ayniUst = hedefKlasor.standardizedFileURL.path == kaynak.mevcutUst.standardizedFileURL.path
        if let sira = konum { konum = araKonum(sira, liste: liste, klasor: kaynak.klasor) }
        if (konum == nil || !ayniUst), !tasimaGecerliMi(kaynak, hedefKlasor) { return nil }
        return BirakmaPlani(ust: ust, hedefKlasor: hedefKlasor, liste: liste, konum: konum, ayniUst: ayniUst)
    }

    private func tasimaGecerliMi(_ kaynak: SuruklenenSayfa, _ hedefKlasor: URL) -> Bool {
        let anahtar = [kaynak.klasor.path, hedefKlasor.path, kaynak.mevcutUst.path].joined(separator: "\n")
        if let onbellek = tasimaOnbellegi, onbellek.anahtar == anahtar { return onbellek.gecerli }
        var gecerli = false
        if case .success = tasimayiDogrula(kaynakKlasor: kaynak.klasor, hedefKlasor: hedefKlasor, mevcutUst: kaynak.mevcutUst) {
            gecerli = true
        }
        tasimaOnbellegi = (anahtar, gecerli)
        return gecerli
    }

    /// Bırakma konumunu bölge sınırına oturtur: sabit öğe sabitler içinde, değilse sabitlerin ardında.
    private func araKonum(_ sira: Int, liste: [AgacDugumu], klasor: URL) -> Int {
        let sabitSayisi = liste.prefix { $0.sabit }.count
        let yol = klasor.standardizedFileURL.path
        let sabitMi = liste.first { $0.klasorURL.standardizedFileURL.path == yol }?.sabit ?? false
        let konum = min(max(sira, 0), liste.count)
        return sabitMi ? min(konum, sabitSayisi) : max(konum, sabitSayisi)
    }

    /// Aynı üst altında araya bırakma yalnızca sırayı yazar. Taşıma kayıt kancasından geçer;
    /// onay asenkron olduğundan drop başarı sayılmaz (false) ve taşıma onaydan sonra yapılır.
    private func agacaBirak(_ deger: UnsafePointer<GValue>?, _ x: Double, _ y: Double) -> Bool {
        guard case .sayfa(let kaynak)? = suruklenenAl(deger), let plan = birakmaPlani(kaynak, x, y) else { return false }
        guard let konum = plan.konum, plan.ayniUst else {
            Platform.anaIsParcaciginda { [weak self] in
                self?.islemOncesiCalistir { [weak self] in self?.tasi(kaynak, plan) }
            }
            return false
        }
        let ad = kaynak.klasor.lastPathComponent
        var adlar = plan.liste.map { $0.ad }
        guard let eski = adlar.firstIndex(of: ad) else { return false }
        adlar.remove(at: eski)
        adlar.insert(ad, at: konum - (eski < konum ? 1 : 0))
        let yazildi = siraKaydet(klasor: plan.hedefKlasor, adlar: adlar, sabitler: plan.sabitler)
        // Ağaç sürükleme oturumu kapanmadan yeniden kurulmaz.
        Platform.anaIsParcaciginda { [weak self] in
            if !yazildi { self?.hataGoster("Sıralanamadı", "Sıra kaydı yazılamadı.") }
            self?.yenile()
        }
        return yazildi
    }

    /// Dosya işlemi ve yol doğrulaması çekirdekte yeniden yapılır; hata olursa kayıtlar değişmez.
    private func tasi(_ kaynak: SuruklenenSayfa, _ plan: BirakmaPlani) {
        let yeniKlasor: URL
        var yeniIcerik: URL?
        do {
            if let icerik = kaynak.icerik {
                guard let yeni = try sayfaTasimaSonucu(icerik, hedefKlasor: plan.hedefKlasor) else {
                    if let ust = pencere?.pencere {
                        LinuxDiyalog.bilgi(ust: ust, baslik: "Sayfa taşınamadı",
                                           aciklama: "Sayfa hedef klasöre taşınamadı.", hata: true)
                    }
                    yenile()
                    return
                }
                yeniIcerik = yeni
                yeniKlasor = sayfaKlasoru(yeni)
            } else {
                yeniKlasor = try klasorTasimaSonucu(kaynak.klasor, hedefKlasor: plan.hedefKlasor)
            }
        } catch {
            tasimaHatasiGoster(error)
            yenile()
            return
        }
        // Eski klasörün kaydından çık; araya bırakıldıysa yeni klasörde konuma yerleş.
        let yeniAd = yeniKlasor.lastPathComponent
        siraAdiniDegistir(klasor: kaynak.mevcutUst, eski: kaynak.klasor.lastPathComponent, yeni: nil)
        if let konum = plan.konum {
            var adlar = plan.liste.map { $0.ad }
            adlar.insert(yeniAd, at: min(konum, adlar.count))
            siraKaydet(klasor: plan.hedefKlasor, adlar: adlar, sabitler: plan.sabitler)
        } else {
            siraAdiniDegistir(klasor: plan.hedefKlasor, eski: yeniAd, yeni: nil)
        }
        // Taşınan sayfa görünsün diye hedef dal açık kalır (dalTasindi kaydeder).
        if plan.ust != nil { acikKlasorYollari.insert(plan.hedefKlasor.path) }
        dalTasindi(eskiKlasor: kaynak.klasor, yeniKlasor: yeniKlasor, eskiIcerik: kaynak.icerik, yeniIcerik: yeniIcerik)
        yenile()
    }

    // MARK: Sayfa işlemleri

    func hedefKlasor() -> URL {
        acikNotURL.map { ustKlasor($0) } ?? notlarKlasoru()
    }

    private func ustSeviyeSayfaEkle() {
        yeniSayfa(klasor: hedefKlasor())
    }

    private func altSayfaEkle(_ dugum: AgacDugumu) {
        // Dal açık kalsın ki yeni sayfa görünsün.
        acikKlasorYollari.insert(dugum.cocuklarKlasoru.path)
        acikKlasorleriKaydet()
        yeniSayfa(klasor: dugum.cocuklarKlasoru)
    }

    /// Sağ tıklanan sayfanın yanına (aynı seviyeye) yeni sayfa açar.
    private func kardesSayfaEkle(_ dugum: AgacDugumu) {
        yeniSayfa(klasor: dugum.sayfaMi ? dugum.klasorURL.deletingLastPathComponent() : dugum.klasorURL)
    }

    /// "Ad.md" düzenindeki notu "Ad/index.md" düzenine taşır; açık yol ve bağlar dala göre güncellenir.
    private func klasoreDonustur(_ dugum: AgacDugumu, kaydiAtla: Bool = false) {
        guard let icerik = dugum.icerikURL else { return }
        if !kaydiAtla {
            islemOncesiCalistir { [weak self] in self?.klasoreDonustur(dugum, kaydiAtla: true) }
            return
        }
        guard let yeni = sayfayiKlasoreDonustur(icerik) else {
            hataGoster("Sayfa klasöre dönüştürülemedi", "Dosya taşınamadı veya hedefte index.md zaten var.")
            return
        }
        dalTasindi(eskiKlasor: dugum.klasorURL, yeniKlasor: sayfaKlasoru(yeni), eskiIcerik: icerik, yeniIcerik: yeni)
        yenile()
    }

    /// Sayfayı hemen diske yazar (kenar panelde anında görünsün) ve editörde açar.
    private func yeniSayfa(klasor: URL, kaydiAtla: Bool = false) {
        if !kaydiAtla {
            islemOncesiCalistir { [weak self] in self?.yeniSayfa(klasor: klasor, kaydiAtla: true) }
            return
        }
        let url = benzersizSayfaURLSonucu(taban: "Yeni Sayfa", klasor: klasor).url
        let fm = FileManager.default
        do {
            _ = try notlarYolunuDogrula(url)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: url, atomically: true, encoding: .utf8)
        } catch {
            hataGoster("Sayfa oluşturulamadı", error.localizedDescription)
            return
        }
        yenile()
        pencere?.editor?.yeniSayfayiAc(url)
    }

    /// Editörün otomatik adlandırması: kayıttan hemen sonra çağrılır, soru ve uyarı göstermez
    /// (her otomatik kayıtta tekrarlanırdı). nil dönerse editör otomatik adlandırmayı bırakır.
    func otomatikAdlandir(_ icerik: URL, yeniAd: String) -> URL? {
        guard let yeni = try? sayfayiYenidenAdlandirmaSonucu(icerik, yeniAd: yeniAd) else { return nil }
        guard yeni != icerik else { return yeni }
        let eskiKlasor = sayfaKlasoru(icerik), yeniKlasor = sayfaKlasoru(yeni)
        siraAdiniDegistir(klasor: eskiKlasor.deletingLastPathComponent(), eski: eskiKlasor.lastPathComponent,
                          yeni: yeniKlasor.lastPathComponent)
        dalTasindi(eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor, eskiIcerik: icerik, yeniIcerik: yeni)
        yenile()
        return yeni
    }

    private func adlandirmaSor(_ dugum: AgacDugumu) {
        guard let ust = pencere?.pencere else { return }
        iletisimKutusu(ust: ust, baslik: "Yeniden adlandır", mesaj: "\"\(dugum.ad)\" için yeni ad:",
                       giris: dugum.ad, onay: "Adlandır") { [weak self] metin in
            let yeniAd = metin.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            guard !yeniAd.isEmpty, yeniAd != dugum.ad else { return }
            self?.adiDegistir(dugum, yeniAd: yeniAd)
        }
    }

    private func adiDegistir(_ dugum: AgacDugumu, yeniAd: String, kaydiAtla: Bool = false) {
        guard sayfaAdiGecerliMi(yeniAd) else {
            hataGoster("Bu ad kullanılamaz",
                       "Sayfa adı boş olamaz, noktayla başlayamaz, / veya : içeremez; ekler ve Görseller adları ayrılmıştır.")
            return
        }
        if !kaydiAtla {
            islemOncesiCalistir { [weak self] in self?.adiDegistir(dugum, yeniAd: yeniAd, kaydiAtla: true) }
            return
        }
        let eskiKlasor = dugum.klasorURL
        let yeniKlasor: URL
        var yeniSayfaURL: URL?
        if let icerik = dugum.icerikURL {
            do {
                guard let yeni = try sayfayiYenidenAdlandirmaSonucu(icerik, yeniAd: yeniAd) else {
                    hataGoster("Sayfa yeniden adlandırılamadı", "Dosya taşınamadı.")
                    return
                }
                guard yeni != icerik else { return }
                yeniKlasor = sayfaKlasoru(yeni)
                yeniSayfaURL = yeni
            } catch {
                tasimaHatasiGoster(error)
                return
            }
        } else {
            // Eski yapıdan kalan salt kapsayıcı klasör.
            do {
                guard let aday = try klasoruYenidenAdlandir(dugum.klasorURL, yeniAd: yeniAd) else { return }
                yeniKlasor = aday
            } catch {
                tasimaHatasiGoster(error)
                return
            }
        }
        siraAdiniDegistir(klasor: eskiKlasor.deletingLastPathComponent(), eski: dugum.ad, yeni: yeniKlasor.lastPathComponent)
        dalTasindi(eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor, eskiIcerik: dugum.icerikURL, yeniIcerik: yeniSayfaURL)
        yenile()
    }

    /// Açık notun yolunu ve açık dal kayıtlarını taşınan dala göre günceller;
    /// aksi hâlde editör silinmiş bir yolu kaydetmeye çalışır.
    private func dalTasindi(eskiKlasor: URL, yeniKlasor: URL, eskiIcerik: URL?, yeniIcerik: URL?) {
        let sonuc = sayfaBaglantilari.daliGuncelle(eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor,
            eskiIcerik: eskiIcerik, yeniIcerik: yeniIcerik, notlar: tumNotlar,
            onbellek: icerikOnbellek, favoriler: favoriler)
        tumNotlar = sonuc.notlar
        icerikOnbellek = sonuc.onbellek
        onbellekNesli += 1
        if let acik = acikNotURL {
            let yeni = SayfaBaglantilari.tasinanURL(acik, eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor,
                                                 eskiIcerik: eskiIcerik, yeniIcerik: yeniIcerik)
            if yeni != acik {
                acikNotURL = yeni
                notYenidenAdlandirildi?(acik, yeni)
            }
        }
        baglarYenidenYazildi?(sonuc.hedefler)
        if !sonuc.hatalar.isEmpty {
            hataGoster("Bazı sayfa bağlantıları güncellenemedi", sonuc.hatalar.joined(separator: "\n"))
        }
        let eski = eskiKlasor.path
        for yol in acikKlasorYollari where yol == eski || yol.hasPrefix(eski + "/") {
            acikKlasorYollari.remove(yol)
            acikKlasorYollari.insert(yeniKlasor.path + yol.dropFirst(eski.count))
        }
        acikKlasorleriKaydet()
    }

    /// Sabitse kaldırır (sabitsizlerin başına), değilse sabitlerin sonuna ekler.
    private func sabitlemeyiDegistir(_ dugum: AgacDugumu) {
        guard !aramaFiltresiEtkin else { return }
        let ust = dugumler[dugum.klasorURL.deletingLastPathComponent().path]
        let kardesler = ust?.cocuklar ?? gorunenKok
        let sabitler = kardesler.filter { $0.sabit }.map { $0.ad }
        let digerleri = kardesler.filter { !$0.sabit && $0 !== dugum }.map { $0.ad }
        let yeni = dugum.sabit
            ? SayfaSirasi(sabitler: sabitler.filter { $0 != dugum.ad }, sira: [dugum.ad] + digerleri)
            : SayfaSirasi(sabitler: sabitler + [dugum.ad], sira: digerleri)
        guard siraYaz(yeni, klasor: ust?.cocuklarKlasoru ?? notlarKlasoru()) else {
            hataGoster("Sabitlenemedi", "Sıra kaydı yazılamadı.")
            return
        }
        yenile()
    }

    private func silmeSor(_ dugum: AgacDugumu) {
        guard let ust = pencere?.pencere else { return }
        let altKlasor = dugum.klasorURL
        let altDallariVar = tumNotlar.contains { $0 != dugum.icerikURL && $0.path.hasPrefix(altKlasor.path + "/") }
        let mesaj = altDallariVar
            ? "Sayfa, alt sayfaları ve görselleri uygulamanın çöp kutusunda 30 gün saklanacak."
            : "Bu sayfa uygulamanın çöp kutusunda 30 gün saklanacak."
        iletisimKutusu(ust: ust, baslik: "\"\(dugum.ad)\" silinsin mi?", mesaj: mesaj,
                       onay: "Sil", tehlikeli: true) { [weak self] _ in self?.sil(dugum) }
    }

    private func sil(_ dugum: AgacDugumu, kaydiAtla: Bool = false) {
        if !kaydiAtla {
            islemOncesiCalistir { [weak self] in self?.sil(dugum, kaydiAtla: true) }
            return
        }
        let altKlasor = dugum.klasorURL
        do {
            try copKutusu.sil(dugum)
        } catch {
            hataGoster("Sayfa çöp kutusuna taşınamadı", error.localizedDescription)
            return
        }
        // Açık sayfa silindiyse (ya da silinen dalın altındaysa) editörü boşalt.
        if let acik = acikNotURL, acik == dugum.icerikURL || acik.path.hasPrefix(altKlasor.path + "/") {
            acikNotURL = nil
            notSilindi?(acik)
        }
        siraAdiniDegistir(klasor: altKlasor.deletingLastPathComponent(), eski: dugum.ad, yeni: nil)
        for yol in acikKlasorYollari where yol == altKlasor.path || yol.hasPrefix(altKlasor.path + "/") {
            acikKlasorYollari.remove(yol)
        }
        acikKlasorleriKaydet()
        yenile()
    }

    // MARK: İletişim kutuları (GtkMessageDialog variadik olduğundan GtkWindow ile kurulur)

    private func tasimaHatasiGoster(_ hata: Error) {
        let tasima = hata as? SayfaTasimaHatasi
        var mesaj = (tasima?.neden ?? hata).localizedDescription
        if let geriAlma = tasima?.geriAlmaHatasi, let tasima {
            mesaj += "\nDosya eski yerine alınamadı: \(geriAlma.localizedDescription)\nDosyanın bulunduğu yol: \(tasima.dosyaURL.path)"
        }
        hataGoster("Sayfa taşınamadı", mesaj)
    }

    private func hataGoster(_ baslik: String, _ mesaj: String) {
        guard let ust = pencere?.pencere else { return }
        iletisimKutusu(ust: ust, baslik: baslik, mesaj: mesaj, onay: "Tamam", iptalVar: false) { _ in }
    }

    /// `giris` verilirse metin alanı gösterilir ve onaylanan metin `tamam`a geçer.
    private func iletisimKutusu(ust: Parca, baslik: String, mesaj: String, giris: String? = nil, onay: String,
                                tehlikeli: Bool = false, iptalVar: Bool = true, tamam: @escaping (String) -> Void) {
        let diyalog = gtk_window_new()!
        // Ana pencereyle aynı kağıt teması (LinuxTema yalnızca .notdefteri altını boyar).
        gtk_widget_add_css_class(diyalog, "notdefteri")
        gtk_window_set_title(nd_window(diyalog), baslik)
        gtk_window_set_modal(nd_window(diyalog), 1)
        gtk_window_set_transient_for(nd_window(diyalog), nd_window(ust))
        gtk_window_set_resizable(nd_window(diyalog), 0)
        gtk_window_set_default_size(nd_window(diyalog), 340, -1)
        let kutu = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12)!
        gtk_widget_set_margin_top(kutu, 16)
        gtk_widget_set_margin_bottom(kutu, 16)
        gtk_widget_set_margin_start(kutu, 16)
        gtk_widget_set_margin_end(kutu, 16)
        let etiket = gtk_label_new(mesaj)!
        gtk_label_set_wrap(nd_label(etiket), 1)
        gtk_label_set_xalign(nd_label(etiket), 0)
        gtk_label_set_max_width_chars(nd_label(etiket), 48)
        gtk_box_append(nd_box(kutu), etiket)
        var alan: Parca?
        if let giris {
            let girisAlani = gtk_entry_new()!
            gtk_editable_set_text(OpaquePointer(ham(girisAlani)), giris)
            gtk_editable_select_region(OpaquePointer(ham(girisAlani)), 0, -1)
            gtk_box_append(nd_box(kutu), girisAlani)
            alan = girisAlani
        }
        let onayla: () -> Void = {
            let metin = alan.flatMap { gtk_editable_get_text(OpaquePointer(ham($0))).map { String(cString: $0) } } ?? ""
            gtk_window_destroy(nd_window(diyalog))
            // Onay işlemi diyalog kapandıktan sonra çalışır (ağaç yeniden kurulabilir, yeni diyalog açılabilir).
            Platform.anaIsParcaciginda { tamam(metin) }
        }
        let dugmeler = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_widget_set_halign(dugmeler, GTK_ALIGN_END)
        if iptalVar {
            let vazgec = gtk_button_new_with_label("Vazgeç")!
            GtkKoprusu.sinyalBagla(ham(vazgec), "clicked") { gtk_window_destroy(nd_window(diyalog)) }
            gtk_box_append(nd_box(dugmeler), vazgec)
        }
        let onayDugmesi = gtk_button_new_with_label(onay)!
        if tehlikeli { gtk_widget_add_css_class(onayDugmesi, "destructive-action") }
        GtkKoprusu.sinyalBagla(ham(onayDugmesi), "clicked") { onayla() }
        gtk_box_append(nd_box(dugmeler), onayDugmesi)
        gtk_box_append(nd_box(kutu), dugmeler)
        if let alan { GtkKoprusu.sinyalBagla(ham(alan), "activate") { onayla() } }
        gtk_window_set_child(nd_window(diyalog), kutu)
        gtk_window_present(nd_window(diyalog))
        if let alan { gtk_widget_grab_focus(alan) }
    }
}
