import AppKit

// MARK: - KenarPaneli: Ağacı yükleme, arama filtresi

extension KenarPaneli {

    // MARK: Ağacı yükleme / filtreleme

    func yenile(secili: URL?) {
        if let secili { acikNotURL = secili }
        tumKokDugumler = agaciYukle()
        tumNotlar = notlariDuzlestir(tumKokDugumler)
        icerikOnbellek = Dictionary(uniqueKeysWithValues: tumNotlar.compactMap { url in
            (try? String(contentsOf: url, encoding: .utf8)).map { (url, isaretlemeleriTemizle($0)) }
        })
        filtreUygula()
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
        if let icerik = icerikOnbellek[url] { return aramaIcinSadelestir(icerik).contains(sorgu) }
        return false
    }

    private func filtreUygula() {
        let sorgu = aramaIcinSadelestir(aramaAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        kokDugumler = sorgu.isEmpty ? tumKokDugumler : suzulmusAgac(tumKokDugumler, sorgu: sorgu)
        notListesi = notlariDuzlestir(kokDugumler)
        tablo.reloadData()

        programatikSecimYapiliyor = true
        if sorgu.isEmpty {
            acikKlasorleriGeriYukle(kokDugumler)
        } else {
            // Arama sırasında eşleşmeler görünsün diye tüm klasörler açılır.
            tablo.expandItem(nil, expandChildren: true)
        }

        // Filtre değiştiğinde, üzerinde çalışılan not ağaçta hâlâ varsa doğru satırı
        // yeniden seç; yoksa eski (artık alakasız) bir satır seçili görünmesin.
        if let acikNotURL, let dugum = dugumBul(acikNotURL, kokDugumler) {
            atalariAc(acikNotURL)
            let satir = tablo.row(forItem: dugum)
            if satir >= 0 {
                tablo.selectRowIndexes(IndexSet(integer: satir), byExtendingSelection: false)
            }
        } else {
            tablo.deselectAll(nil)
        }
        programatikSecimYapiliyor = false
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
        UserDefaults.standard.set(Array(acikKlasorYollari), forKey: "acikKlasorler")
    }

    func controlTextDidChange(_ obj: Notification) {
        aramaTemizleButonu.isHidden = aramaAlani.stringValue.isEmpty
        filtreUygula()
    }

    @objc func aramaTemizleTiklandi() {
        aramaAlani.stringValue = ""
        aramaTemizleButonu.isHidden = true
        filtreUygula()
        window?.makeFirstResponder(aramaAlani)
    }
}
