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

/// Linux kenar panelinin sayfa ağacı (macOS KenarPaneli'nin temel ağaç davranışı).
final class LinuxKenarPaneli {
    /// Taşıma/silme/yeniden adlandırma/yeni sayfa öncesi açık notu kaydeder; false dönerse işlem iptal olur.
    var tasinmadanOnce: (() -> Bool)?
    var kaydetmedenDevam: ((@escaping () -> Void) -> Void)?
    var notSilindi: ((URL) -> Void)?
    var notYenidenAdlandirildi: ((URL, URL) -> Void)?
    private(set) var acikNotURL: URL?

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
    private var acikKlasorYollari = Set(UserDefaults.standard.stringArray(forKey: "acikKlasorler") ?? [])
    private var aramaFiltresiEtkin = false
    private var dalGeriYukleniyor = false
    private var aramaIptal: ZamanlayiciIptal?
    private var icerikOnbellek: [URL: OnbellekGirdisi] = [:]
    private var onbellekNesli = 0
    private let copKutusu = CopKutusu()
    private var menuDugumu: AgacDugumu?
    private var acikMenu: Parca?
    private var genislemeBaglari: [OpaquePointer: gulong] = [:]

    init(pencere: LinuxPencere) {
        self.pencere = pencere
        kok = pencere.kenarPanelYuvasi
        liste = gtk_list_view_new(nil, nil)!
        arayuzuKur()
        eylemleriKur()
        yenile()
    }

    deinit {
        aramaIptal?()
    }

    /// Editör bir notu açınca ağacı yeniden kurmadan yalnızca açık sayfayı vurgular.
    func acikNotuBildir(_ url: URL?) {
        acikNotURL = url
        acikNotuSec()
    }

    func notIceriginiGuncelle(_ url: URL, metin: String) {
        icerikOnbellek[url] = onbellekGirdisiUret(metin, tarih: degistirilmeTarihi(url))
        // Eski disk okuması yeni kaydı ezmesin; kalan notlar yeni nesilde tamamlanır.
        onbellegiTazele()
        if aramaFiltresiEtkin { filtreUygula() }
    }

    /// Ağacı diskten yeniden kurar.
    func yenile(secili: URL? = nil) {
        if let secili { acikNotURL = secili }
        tumKokDugumler = agaciYukle()
        tumNotlar = notlariDuzlestir(tumKokDugumler)
        let mevcut = Set(tumNotlar)
        icerikOnbellek = icerikOnbellek.filter { mevcut.contains($0.key) }
        onbellegiTazele()
        filtreUygula()
    }

    // MARK: Arayüz

    private func arayuzuKur() {
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
            ("altsayfa", { [weak self] in self?.altSayfaEkle($0) }),
            ("adlandir", { [weak self] in self?.adlandirmaSor($0) }),
            ("sabitle", { [weak self] in self?.sabitlemeyiDegistir($0) }),
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
        let raptiye = gtk_label_new("")!
        gtk_widget_set_opacity(raptiye, 0.5)
        let kutu = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5)!
        gtk_box_append(nd_box(kutu), ikon)
        gtk_box_append(nd_box(kutu), etiket)
        gtk_box_append(nd_box(kutu), raptiye)
        let genisletici = gtk_tree_expander_new()!
        gtk_tree_expander_set_child(OpaquePointer(ham(genisletici)), kutu)
        gtk_list_item_set_child(oge, genisletici)

        let jest = gtk_gesture_click_new()!
        gtk_gesture_single_set_button(OpaquePointer(ham(jest)), 3)
        let tutucu = Tutucu<(Double, Double) -> Void> { [weak self] x, y in
            guard let satir = gtk_list_item_get_item(oge) else { return }
            self?.menuAc(OpaquePointer(satir), genisletici, x, y)
        }
        g_signal_connect_data(ham(jest), "pressed",
                              unsafeBitCast(basmaCagir as @convention(c) (gpointer?, Int32, Double, Double, gpointer?) -> Void,
                                            to: GCallback.self),
                              Unmanaged.passRetained(tutucu).toOpaque(), tutucuyuBirak, GConnectFlags(rawValue: 0))
        gtk_widget_add_controller(genisletici, OpaquePointer(ham(jest)))
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
            gtk_label_set_text(nd_label(raptiye), dugum.sabit ? "📌" : "")
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
        pencere?.notSecildi(url)
        acikNotuSec()
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
        UserDefaults.standard.set(Array(acikKlasorYollari), forKey: "acikKlasorler")
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
                if self.aramaFiltresiEtkin { self.filtreUygula() }
            }
        }
    }

    // MARK: Sağ tık menüsü

    private func menuAc(_ satir: OpaquePointer, _ hedef: Parca, _ x: Double, _ y: Double) {
        guard let dugum = dugumu(satir) else { return }
        menuyuKapat()
        menuDugumu = dugum
        let model = g_menu_new()!
        g_menu_append(model, "Yeni alt sayfa", "kenar.altsayfa")
        g_menu_append(model, "Yeniden adlandır", "kenar.adlandir")
        // Süzülmüş ağaçta sıra kaydı güvenilmez; macOS'taki gibi arama sırasında sabitleme yok.
        if !aramaFiltresiEtkin {
            g_menu_append(model, dugum.sabit ? "Sabitlemeyi kaldır" : "📌 Sabitle", "kenar.sabitle")
        }
        g_menu_append(model, "Sil", "kenar.sil")
        let menu = gtk_popover_menu_new_from_model(GtkKoprusu.gtkIsaretci(ham(model)))!
        g_object_unref(ham(model))
        gtk_widget_set_parent(menu, hedef)
        let popover: UnsafeMutablePointer<GtkPopover> = GtkKoprusu.gtkIsaretci(ham(menu))
        gtk_popover_set_has_arrow(popover, 0)
        var dikdortgen = GdkRectangle(x: Int32(x), y: Int32(y), width: 1, height: 1)
        gtk_popover_set_pointing_to(popover, &dikdortgen)
        acikMenu = menu
        GtkKoprusu.sinyalBagla(ham(menu), "closed") { [weak self] in
            // Üst widget yok edilmeden popover ayrılmalı; kapanış sinyali içinde ayırmak GTK'nin önerdiği yoldur.
            self?.menuyuKapat()
        }
        gtk_popover_popup(popover)
    }

    private func menuyuKapat() {
        guard let menu = acikMenu else { return }
        acikMenu = nil
        gtk_widget_unparent(menu)
    }

    // MARK: Sayfa işlemleri

    private func hedefKlasor() -> URL {
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

    /// Sayfayı hemen diske yazar (kenar panelde anında görünsün) ve editörde açar.
    private func yeniSayfa(klasor: URL, kaydiAtla: Bool = false) {
        guard kaydiAtla || islemOncesi({ [weak self] in self?.yeniSayfa(klasor: klasor, kaydiAtla: true) }) else { return }
        let url = benzersizSayfaURLSonucu(taban: "Yeni Sayfa", klasor: klasor).url
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: url, atomically: true, encoding: .utf8)
        } catch {
            hataGoster("Sayfa oluşturulamadı", error.localizedDescription)
            return
        }
        yenile()
        pencere?.notSecildi(url)
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
        guard kaydiAtla || islemOncesi({ [weak self] in self?.adiDegistir(dugum, yeniAd: yeniAd, kaydiAtla: true) }) else { return }
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
            let ust = dugum.klasorURL.deletingLastPathComponent()
            let aday = benzersizSayfaURLSonucu(taban: yeniAd, klasor: ust).url.deletingLastPathComponent()
            do { try FileManager.default.moveItem(at: dugum.klasorURL, to: aday) } catch {
                hataGoster("Klasör yeniden adlandırılamadı", error.localizedDescription)
                return
            }
            yeniKlasor = aday
        }
        siraAdiniDegistir(klasor: eskiKlasor.deletingLastPathComponent(), eski: dugum.ad, yeni: yeniKlasor.lastPathComponent)
        dalTasindi(eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor, eskiIcerik: dugum.icerikURL, yeniIcerik: yeniSayfaURL)
        yenile()
    }

    /// Açık notun yolunu ve açık dal kayıtlarını taşınan dala göre günceller;
    /// aksi hâlde editör silinmiş bir yolu kaydetmeye çalışır.
    private func dalTasindi(eskiKlasor: URL, yeniKlasor: URL, eskiIcerik: URL?, yeniIcerik: URL?) {
        if let eskiIcerik, let yeniIcerik, acikNotURL == eskiIcerik {
            acikNotURL = yeniIcerik
            notYenidenAdlandirildi?(eskiIcerik, yeniIcerik)
        } else if let acik = acikNotURL, acik.path.hasPrefix(eskiKlasor.path + "/") {
            let yeni = URL(fileURLWithPath: yeniKlasor.path + acik.path.dropFirst(eskiKlasor.path.count))
            acikNotURL = yeni
            notYenidenAdlandirildi?(acik, yeni)
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
        guard kaydiAtla || islemOncesi({ [weak self] in self?.sil(dugum, kaydiAtla: true) }) else { return }
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

    private func islemOncesi(_ devam: @escaping () -> Void) -> Bool {
        guard tasinmadanOnce?() == true else {
            kaydetmedenDevam?(devam)
            return false
        }
        return true
    }

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
