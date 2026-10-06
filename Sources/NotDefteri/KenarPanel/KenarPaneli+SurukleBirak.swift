import AppKit
import NotDefteriCekirdek

// MARK: - KenarPaneli: Sayfaları sürükleyip taşıma
//
// Kenar panelde bir sayfayı başka bir sayfanın üzerine bırakmak onu o sayfanın
// alt sayfası yapar; boşluğa bırakmak köke taşır. Kardeşlerin ARASINA bırakmak
// (ekleme çizgisi) aynı üst altındaysa yalnızca sırayı değiştirir (.sira.json),
// farklı üst altındaysa taşıyıp o konuma yerleştirir. Diskte sayfanın klasörü
// olduğu gibi taşındığı için alt sayfalar ve görseller birlikte gider.

/// Sürüklenen sayfayı taşıyan özel pano tipi.
///
/// Dosya URL'si yerine kendi tipimizi kullanıyoruz: `public.file-url` olsaydı
/// panel, Finder'a sürüklenen her dosyayı da kabul eder ve notlar klasörünün
/// dışından gelen şeyleri sayfaymış gibi taşımaya kalkardı.
let kSayfaSurukleTipi = NSPasteboard.PasteboardType("tr.notdefteri.sayfa")

/// validateDrop her fare hareketinde çağrılır; dosya sistemi doğrulaması yalnızca kaynak/hedef değişince
/// yeniden yapılır. Sürükleme bitince (acceptDrop) ya da kısa sürede bayatlayarak düşer.
/// Ana iş parçacığında kullanılır (AppKit sürükleme geri çağrıları).
private var sonTasimaDogrulamasi: (anahtar: String, gecerli: Bool, zaman: Date)?

extension KenarPaneli {

    /// Sürüklemeyi başlatan düğümün yolları panoya yazılır.
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let dugum = item as? AgacDugumu else { return nil }
        let oge = NSPasteboardItem()
        if favoriBolumu.sayfalar.contains(where: { $0 === dugum }), let url = dugum.icerikURL {
            oge.setString(url.path, forType: kFavoriSurukleTipi)
            return oge
        }
        guard !kisaYolMu(dugum) else { return nil }
        oge.setPropertyList(["klasor": dugum.klasorURL.path,
                             "icerik": dugum.icerikURL?.path ?? ""],
                            forType: kSayfaSurukleTipi)
        return oge
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo,
                     proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if info.draggingPasteboard.string(forType: kFavoriSurukleTipi) != nil {
            guard info.draggingSource as? NSOutlineView === outlineView,
                  item as? KenarBolumu === favoriBolumu, index >= 0 else { return [] }
            return .move
        }
        guard !(item is KenarBolumu),
              !((item as? AgacDugumu).map { kisaYolMu($0) } ?? false),
              let surukleneN = suruklenenYollar(info) else { return [] }
        let hedefKlasor = birakmaHedefi(item)
        // Arama sırasında düğümler kopya; araya bırakma eski "üstüne bırak" davranışına düşer.
        if index >= 0, !aramaFiltresiEtkin {
            let (liste, kayma) = kardesListesi(item)
            if aynıUstMu(hedefKlasor, surukleneN.mevcutUst) {
                let konum = araKonum(index - kayma, liste: liste, klasor: surukleneN.klasor)
                outlineView.setDropItem(item, dropChildIndex: konum + kayma)
                return .move
            }
            guard tasimaGecerliMi(surukleneN.klasor, hedefKlasor, surukleneN.mevcutUst) else { return [] }
            outlineView.setDropItem(item, dropChildIndex: araKonum(index - kayma, liste: liste,
                                                                   klasor: surukleneN.klasor) + kayma)
            return .move
        }
        guard tasimaGecerliMi(surukleneN.klasor, hedefKlasor, surukleneN.mevcutUst) else { return [] }

        outlineView.setDropItem(item, dropChildIndex: NSOutlineViewDropOnItemIndex)
        return .move
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo,
                     item: Any?, childIndex index: Int) -> Bool {
        if let yol = info.draggingPasteboard.string(forType: kFavoriSurukleTipi) {
            guard info.draggingSource as? NSOutlineView === outlineView,
                  item as? KenarBolumu === favoriBolumu, index >= 0 else { return false }
            favoriler.tasi(URL(fileURLWithPath: yol), hedef: index)
            kisaYollariPlanla()
            return true
        }
        sonTasimaDogrulamasi = nil
        guard !(item is KenarBolumu),
              !((item as? AgacDugumu).map { kisaYolMu($0) } ?? false),
              let suruklenen = suruklenenYollar(info) else { return false }
        let hedefKlasor = birakmaHedefi(item)
        let (liste, kayma) = kardesListesi(item)
        let konum: Int? = index >= 0 && !aramaFiltresiEtkin
            ? araKonum(index - kayma, liste: liste, klasor: suruklenen.klasor) : nil
        let ad = suruklenen.klasor.lastPathComponent

        // Aynı üst altında araya bırakma: dosya taşınmaz, yalnızca sıra kaydı değişir.
        if let konum, aynıUstMu(hedefKlasor, suruklenen.mevcutUst) {
            var adlar = liste.map { $0.ad }
            guard let eski = adlar.firstIndex(of: ad) else { return false }
            adlar.remove(at: eski)
            adlar.insert(ad, at: konum - (eski < konum ? 1 : 0))
            guard siraKaydet(klasor: hedefKlasor, adlar: adlar,
                             sabitler: Set(liste.filter { $0.sabit }.map { $0.ad })) else { return false }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.yenile(secili: self.acikNotURL)
            }
            return true
        }

        guard tasinmadanOnce?() ?? true else { return false }
        baglantiOnbelleginiHazirla()
        let yeniKlasor: URL
        var yeniIcerik: URL?
        if let icerik = suruklenen.icerik {
            guard let yeni = sayfayiTasi(icerik, hedefKlasor: hedefKlasor) else { return false }
            yeniIcerik = yeni
            yeniKlasor = sayfaKlasoru(yeni)
        } else {
            guard let yeni = sayfaTasimaUyarisiIle({
                try klasorTasimaSonucu(suruklenen.klasor, hedefKlasor: hedefKlasor)
            }) else { return false }
            yeniKlasor = yeni
        }

        // Eski klasörün kaydından çık; araya bırakıldıysa yeni klasörde konuma yerleş.
        let yeniAd = yeniKlasor.lastPathComponent
        siraAdiniDegistir(klasor: suruklenen.mevcutUst, eski: ad, yeni: nil)
        if let konum {
            var adlar = liste.map { $0.ad }
            adlar.insert(yeniAd, at: min(konum, adlar.count))
            siraKaydet(klasor: hedefKlasor, adlar: adlar, sabitler: Set(liste.filter { $0.sabit }.map { $0.ad }))
        } else {
            siraAdiniDegistir(klasor: hedefKlasor, eski: yeniAd, yeni: nil)
        }

        // Taşınan sayfa görünsün diye hedef dal açık kalsın.
        if item != nil {
            acikKlasorYollari.insert(hedefKlasor.path)
            acikKlasorleriKaydet()
        }
        acikDaliTasindiOlarakIsle(eskiKlasor: suruklenen.klasor, yeniKlasor: yeniKlasor,
                                  eskiIcerik: suruklenen.icerik, yeniIcerik: yeniIcerik)

        // Ağacı bu geri çağrının içinde kurmak yasak: sürükleme oturumu hâlâ
        // kapanıyor ve o sırada reloadData outline view'ın durumunu bozuyor.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.yenile(secili: self.acikNotURL)
        }
        return true
    }

    // MARK: Yardımcılar

    /// Araya bırakmada üst düğümün çocukları ve çocuk dizinindeki kayma
    /// (kökte Favoriler/Son açılanlar bölümleri önce gelir).
    private func kardesListesi(_ item: Any?) -> (liste: [AgacDugumu], kayma: Int) {
        if let dugum = item as? AgacDugumu { return (dugum.cocuklar, 0) }
        return (kokDugumler, kenarBolumleri.count)
    }

    /// Aynı kaynak/hedef çifti için sonuç 2 sn boyunca yeniden kullanılır (hover başına disk doğrulaması yok).
    private func tasimaGecerliMi(_ kaynak: URL, _ hedef: URL, _ mevcutUst: URL) -> Bool {
        let anahtar = [kaynak.path, hedef.path, mevcutUst.path].joined(separator: "\n")
        if let onbellek = sonTasimaDogrulamasi, onbellek.anahtar == anahtar, Date().timeIntervalSince(onbellek.zaman) < 2 {
            return onbellek.gecerli
        }
        var gecerli = false
        if case .success = tasimayiDogrula(kaynakKlasor: kaynak, hedefKlasor: hedef, mevcutUst: mevcutUst) { gecerli = true }
        sonTasimaDogrulamasi = (anahtar, gecerli, Date())
        return gecerli
    }

    private func aynıUstMu(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL.path == b.standardizedFileURL.path
    }

    /// Bırakma konumunu bölge sınırına oturtur: sabit öğe sabitler içinde, değilse sabitlerin ardında.
    private func araKonum(_ index: Int, liste: [AgacDugumu], klasor: URL) -> Int {
        let sabitSayisi = liste.prefix { $0.sabit }.count
        let yol = klasor.standardizedFileURL.path
        let sabitMi = liste.first { $0.klasorURL.standardizedFileURL.path == yol }?.sabit ?? false
        let konum = min(max(index, 0), liste.count)
        return sabitMi ? min(konum, sabitSayisi) : max(konum, sabitSayisi)
    }

    /// Bırakılan yerin çocuk klasörü; boşluğa bırakıldıysa kök.
    private func birakmaHedefi(_ item: Any?) -> URL {
        (item as? AgacDugumu)?.cocuklarKlasoru ?? notlarKlasoru()
    }

    /// Sürüklenen düğümün yolları. Kendi tipimiz yoksa (dışarıdan gelen bir
    /// sürükleme) nil döner.
    private func suruklenenYollar(_ info: NSDraggingInfo) -> (klasor: URL, icerik: URL?, mevcutUst: URL)? {
        guard let oge = info.draggingPasteboard.pasteboardItems?.first,
              let bilgi = oge.propertyList(forType: kSayfaSurukleTipi) as? [String: String],
              let klasorYolu = bilgi["klasor"], !klasorYolu.isEmpty else { return nil }
        let klasor = URL(fileURLWithPath: klasorYolu)
        let icerikYolu = bilgi["icerik"] ?? ""
        let icerik = icerikYolu.isEmpty ? nil : URL(fileURLWithPath: icerikYolu)
        return (klasor, icerik, icerik.map { ustKlasor($0) } ?? klasor.deletingLastPathComponent())
    }
}
