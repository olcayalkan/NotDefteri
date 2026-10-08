import AppKit
import NotDefteriCekirdek

// MARK: - KenarPaneli: Ağacı yükleme, arama filtresi

extension KenarPaneli {

    // MARK: Ağacı yükleme / filtreleme

    func yenile(secili: URL?) {
        if let secili { acikNotURL = secili }
        // NSOutlineView iç içe reloadData'yı desteklemiyor. Seçim bildirimi
        // bazen ertelendiği için bu yol kendini tetikleyebiliyordu:
        // satır seç -> notSecildi -> notuAc -> yenile -> reloadData (iç içe).
        guard !yenilemeSuruyor else { return }
        yenilemeSuruyor = true
        defer { yenilemeSuruyor = false }
        favoriler.olmayanlariDusur()
        sayfaBaglantilari.olmayanSonAcilanlariDusur()
        tumKokDugumler = agaciYukle()
        tumNotlar = notlariDuzlestir(tumKokDugumler)
        let mevcut = Set(tumNotlar)
        // Panel gizliyken de silinen notlar ana sayfa ve bağlantı önbelleğinde kalmaz.
        icerikOnbellek = icerikOnbellek.filter { mevcut.contains($0.key) }
        // Gezinme modeli güncel kalır; görünmeyen ağacın içerik okumaları bekler.
        onbellekYenilemesiBekliyor = true
        if gorunumGuncellemeleriEtkin { icerikOnbelleginiTazele() }
        sayfaIndeksiniGuncelle()
        baglantiOnbellegiDegisti?()
        filtreUygula()
    }

    func bekleyenGuncellemeleriUygula() {
        if onbellekYenilemesiBekliyor { icerikOnbelleginiTazele() }
        if filtreGuncellemesiBekliyor { filtreUygula() }
        if kisaYolGuncellemesiBekliyor { kisaYollariYenile() }
    }

    /// Arama önbelleğini seri arka plan kuyruğunda günceller; arayüz bu sırada eski
    /// önbellekle çalışır, sonuç tek seferde uygulanır (yarım önbellek görünmez).
    /// Değişmemiş notlar yeniden okunmaz: tarih kontrolü okumadan ~10 kat ucuz.
    ///
    /// Ölçüm (3584 not, %10'u 200 KB): ilk kurulum ~38 s, tarihle artımlı ~20-65 ms.
    private func icerikOnbelleginiTazele() {
        onbellekYenilemesiBekliyor = false
        onbellekNesli += 1
        let nesil = onbellekNesli, notlar = tumNotlar, eski = icerikOnbellek
        let kutu = OnbellekKutusu()
        onbellekKutusu = kutu
        // Arka plan yalnızca kutuya yazar; görünüm nesnesine ana thread'de dokunulur.
        onbellekKuyrugu.async { [weak self] in
            let yeni = icerikOnbellegiUret(notlar, eski: eski)
            kutu.girdiler = yeni
            DispatchQueue.main.async { self?.icerikOnbelleginiUygula(yeni, nesil: nesil) }
        }
    }

    private func icerikOnbelleginiUygula(_ yeni: [URL: OnbellekGirdisi], nesil: Int) {
        guard nesil == onbellekNesli, uygulananOnbellekNesli != nesil else { return }
        uygulananOnbellekNesli = nesil
        let mevcut = Set(tumNotlar)
        // Tarama sürerken kayıtla gelen daha yeni girdi eski okumayla ezilmez.
        var sonuc = icerikOnbellek.filter { mevcut.contains($0.key) }
        for (url, girdi) in yeni where mevcut.contains(url) {
            if let simdiki = sonuc[url], simdiki.tarih > girdi.tarih { continue }
            sonuc[url] = girdi
        }
        icerikOnbellek = sonuc
        baglantiOnbellegiDegisti?()
        if !aramaAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { filtrelemeyiPlanla() }
    }

    /// Başarılı kaydın metnini kullanır; diğer notları taramaya gerek yoktur.
    func notIceriginiGuncelle(_ url: URL, metin: String) {
        icerikOnbellek[url] = onbellekGirdisiUret(metin, tarih: degistirilmeTarihi(URL(fileURLWithPath: url.path)))
        baglantiOnbellegiDegisti?()
        if !aramaAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Kayıt seçim delegesinden de gelebilir; reloadData'yı o bağlamdan çıkar.
            filtrelemeyiPlanla()
        }
    }

    /// Kayıt ve açılış yolu: girdi seri önbellek kuyruğunda üretilir. Büyük notta üretim ana
    /// thread'i her otomatik kayıtta ~100 ms donduruyordu. Daha yeni tarihli girdi ezilmez.
    func notIceriginiArkaPlandaGuncelle(_ url: URL, metin: String) {
        let tarih = degistirilmeTarihi(URL(fileURLWithPath: url.path))
        onbellekKuyrugu.async { [weak self] in
            let girdi = onbellekGirdisiUret(metin, tarih: tarih)
            DispatchQueue.main.async {
                guard let self, self.tumNotlar.contains(url) else { return }
                if let simdiki = self.icerikOnbellek[url], simdiki.tarih > girdi.tarih { return }
                self.icerikOnbellek[url] = girdi
                self.baglantiOnbellegiDegisti?()
                if !self.aramaAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.filtrelemeyiPlanla()
                }
            }
        }
    }

    /// Okuma yolları (Ana Sayfa, ⌘P, geri bağlantılar) beklemez; sonuç gelince
    /// `baglantiOnbellegiDegisti` ile yeniden çizilir.
    func icerikOnbelleginiIste() {
        if onbellekYenilemesiBekliyor { icerikOnbelleginiTazele() }
    }

    /// Taramayı beklemez (UI donmasın); yazma yolları eski/eksik girdileri diskten okur.
    func baglantiOnbelleginiHazirla() {
        icerikOnbelleginiIste()
    }

    func sayfaIndeksiniGuncelle() {
        // Yol başına kök klasör çözümü pahalı (3584 notta ~250 ms); değişmeyen sayfa yeniden kurulmaz.
        let eskiler = Dictionary(sayfaBaglantilari.sayfalar.map { ($0.url, $0) }, uniquingKeysWith: { ilk, _ in ilk })
        let sayfalar = tumNotlar.map { eskiler[$0] ?? SayfaSecenegi(url: $0) }
        guard sayfalar != sayfaBaglantilari.sayfalar else { return }
        sayfaBaglantilari.guncelle(sayfalar)
        sayfaIndeksiDegisti?()
    }

    func baglantiVerenler(_ hedef: URL) -> [SayfaSecenegi] {
        icerikOnbelleginiIste()
        return sayfaBaglantilari.sayfalar.filter { sayfa in
            icerikOnbellek[sayfa.url]?.bagHedefleri.contains {
                sayfaBaglantilari.coz($0) == hedef
            } ?? false
        }.sorted { $0.yol.localizedStandardCompare($1.yol) == .orderedAscending }
    }

    /// Ağacı, görüntülenme sırasına göre düz bir not listesine çevirir.
    private func notlariDuzlestir(_ dugumler: [AgacDugumu]) -> [URL] {
        var sonuc: [URL] = []
        for dugum in dugumler {
            if let icerik = dugum.icerikURL { sonuc.append(icerik) }
            sonuc += notlariDuzlestir(dugum.cocuklar)
        }
        return sonuc
    }

    /// Arama sorgusuna uyan notları ve onları içeren klasörleri bırakır.
    private func suzulmusAgac(_ dugumler: [AgacDugumu], sorgu: String) -> [AgacDugumu] {
        var sonuc: [AgacDugumu] = []
        for dugum in dugumler {
            let kendisiEsliyor = aramaIcinSadelestir(dugum.ad).contains(sorgu)
                || (dugum.icerikURL.map { notEsliyor($0, sorgu: sorgu) } ?? false)
            if kendisiEsliyor {
                // Eşleşen sayfa tüm alt dallarıyla birlikte görünsün.
                sonuc.append(dugum)
                continue
            }
            let kalanCocuklar = suzulmusAgac(dugum.cocuklar, sorgu: sorgu)
            if !kalanCocuklar.isEmpty {
                sonuc.append(AgacDugumu(icerikURL: dugum.icerikURL, klasorURL: dugum.klasorURL, cocuklar: kalanCocuklar))
            }
        }
        return sonuc
    }

    private func notEsliyor(_ url: URL, sorgu: String) -> Bool {
        guard let girdi = icerikOnbellek[url] else { return false }
        return girdi.aranabilirMetin.contains(sorgu)
    }

    private func filtreUygula() {
        aramaZamanlayicisi?.invalidate()
        aramaZamanlayicisi = nil
        guard gorunumGuncellemeleriEtkin else {
            filtreGuncellemesiBekliyor = true
            return
        }
        filtreGuncellemesiBekliyor = false
        let sorgu = aramaIcinSadelestir(aramaAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        let aramaTemizlendi = aramaFiltresiEtkin && sorgu.isEmpty
        aramaFiltresiEtkin = !sorgu.isEmpty
        programatikSecimYapiliyor = true
        defer { programatikSecimYapiliyor = false }
        kokDugumler = sorgu.isEmpty ? tumKokDugumler : suzulmusAgac(tumKokDugumler, sorgu: sorgu)
        notListesi = notlariDuzlestir(kokDugumler)
        kisaYollariHazirla()
        tablo.reloadData()

        if sorgu.isEmpty {
            // reloadData aynı düğümlerin aramadaki açık durumunu koruyabilir.
            tablo.collapseItem(nil, collapseChildren: true)
            acikKlasorleriGeriYukle(kokDugumler)
            bolumleriAc()
        } else {
            // Arama sırasında eşleşmeler görünsün diye tüm klasörler açılır.
            tablo.expandItem(nil, expandChildren: true)
        }

        // Filtre değiştiğinde, üzerinde çalışılan not ağaçta hâlâ varsa doğru satırı
        // yeniden seç; yoksa eski (artık alakasız) bir satır seçili görünmesin.
        if !anaSayfaSecili, let acikNotURL, let dugum = dugumBul(acikNotURL, kokDugumler) {
            // Arama temizlenince açık notun ataları eski kapalı dalları açmasın.
            if !aramaTemizlendi { atalariAc(acikNotURL) }
            let satir = tablo.row(forItem: dugum)
            if satir >= 0 {
                tablo.selectRowIndexes(IndexSet(integer: satir), byExtendingSelection: false)
            } else {
                tablo.deselectAll(nil)
            }
        } else {
            tablo.deselectAll(nil)
        }
    }

    private func dugumBul(_ url: URL, _ dugumler: [AgacDugumu]) -> AgacDugumu? {
        for dugum in dugumler {
            if dugum.icerikURL == url { return dugum }
            if let bulunan = dugumBul(url, dugum.cocuklar) { return bulunan }
        }
        return nil
    }

    /// Verilen notun bulunduğu klasörleri kökten aşağıya doğru açar.
    private func atalariAc(_ url: URL) {
        var atalar: [URL] = []
        var klasor = url.deletingLastPathComponent()
        let kok = notlarKlasoru()
        while klasor.path.hasPrefix(kok.path), klasor != kok {
            atalar.insert(klasor, at: 0)
            klasor = klasor.deletingLastPathComponent()
        }
        // Ata klasörlerin karşılığı olan sayfaları kökten aşağıya doğru aç.
        for ata in atalar {
            if let dugum = klasoreGoreDugumBul(ata, kokDugumler) { tablo.expandItem(dugum) }
        }
    }

    /// Alt sayfalarını verilen klasörde tutan düğümü bulur.
    private func klasoreGoreDugumBul(_ klasor: URL, _ dugumler: [AgacDugumu]) -> AgacDugumu? {
        for dugum in dugumler {
            if dugum.cocuklarKlasoru == klasor { return dugum }
            if let bulunan = klasoreGoreDugumBul(klasor, dugum.cocuklar) { return bulunan }
        }
        return nil
    }

    private func acikKlasorleriGeriYukle(_ dugumler: [AgacDugumu]) {
        for dugum in dugumler where !dugum.cocuklar.isEmpty {
            if acikKlasorYollari.contains(dugum.cocuklarKlasoru.path) {
                tablo.expandItem(dugum)
                acikKlasorleriGeriYukle(dugum.cocuklar)
            }
        }
    }

    func acikKlasorleriKaydet() {
        gAyarlar.set(Array(acikKlasorYollari), forKey: "acikKlasorler")
    }

    func controlTextDidChange(_ obj: Notification) {
        // YALNIZCA arama kutusu. Satır üzerinde ad düzenlenirken de bu geri
        // çağrı tetikleniyor; süzmezsek her tuş vuruşunda filtreUygula ->
        // reloadData çalışıyor, düzenlenen hücre yok ediliyor ve ad yarım
        // metinle kaydediliyordu ("A" yazınca dosya adı "A" oluyordu).
        // Aynı yol "Reentrant call to reloadData" uyarısının da kaynağıydı.
        guard (obj.object as AnyObject?) === aramaAlani else { return }
        aramaTemizleButonu.isHidden = aramaAlani.stringValue.isEmpty
        filtrelemeyiPlanla()
    }

    private func filtrelemeyiPlanla() {
        aramaZamanlayicisi?.invalidate()
        guard gorunumGuncellemeleriEtkin else {
            aramaZamanlayicisi = nil
            filtreGuncellemesiBekliyor = true
            return
        }
        let zamanlayici = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.filtreUygula()
        }
        aramaZamanlayicisi = zamanlayici
        RunLoop.main.add(zamanlayici, forMode: .common)
    }

    @objc func aramaTemizleTiklandi() {
        aramaAlani.stringValue = ""
        aramaTemizleButonu.isHidden = true
        filtreUygula()
        window?.makeFirstResponder(aramaAlani)
    }

    /// Ağacı yeniden kurmadan yalnızca "açık not" bilgisini günceller.
    /// Panelden seçilerek açılan notlarda kullanılır.
    func acikNotuBildir(_ url: URL) {
        acikNotURL = url
        kisaYollariPlanla()
    }

    /// Panel dışından (bulucu, bağ, Ana Sayfa) açılan ve ağaçta zaten olan not: diski yeniden
    /// taramadan, bellekteki ağaçta seçilip ataları açılır.
    func acikNotuGoster(_ url: URL) {
        acikNotURL = url
        filtreUygula()
    }
}

/// En son başlatılan taramanın sonucu; yalnızca `onbellekKuyrugu` içinde okunur/yazılır.
final class OnbellekKutusu {
    var girdiler: [URL: OnbellekGirdisi]?
}

/// Yalnızca Foundation; `onbellekKuyrugu` üzerinde çalışır, AppKit'e dokunmaz.
private func icerikOnbellegiUret(_ notlar: [URL], eski: [URL: OnbellekGirdisi]) -> [URL: OnbellekGirdisi] {
    var yeni: [URL: OnbellekGirdisi] = [:]
    yeni.reserveCapacity(notlar.count)
    for url in notlar {
        // Taze URL: arka planda önbelleğe alınmış eski tarih değişikliği gizlemesin.
        let tarih = degistirilmeTarihi(URL(fileURLWithPath: url.path))
        if let girdi = eski[url], girdi.tarih == tarih {
            yeni[url] = girdi                      // değişmemiş: yeniden okumaya gerek yok
        } else if let metin = try? String(contentsOf: url, encoding: .utf8) {
            yeni[url] = onbellekGirdisiUret(metin, tarih: tarih)
        }
    }
    return yeni
}
