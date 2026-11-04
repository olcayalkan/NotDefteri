import AppKit
import NotDefteriCekirdek

// MARK: - NotPenceresi: İçerik penceresi ve pencereler arası eşitleme

/// Kenar panelde sayfaya üç kez tıklayınca sayfa ayrı bir `NotPenceresi`nde, kenar panel
/// kapalı açılır. Ana penceredeki editörün aynısıdır: yazma, biçim, tablo, görsel, geri al,
/// sayfa seçenekleri, otomatik kayıt.
///
/// Aynı sayfa iki pencerede açık olabilir. Pencere odağı bırakınca bekleyen değişikliği yazar
/// (`resignKey`), odak alan pencere ya da kaydı duyan pencere diskten yenilenir; böylece
/// iki editör birbirinin kaydını ezmez.
extension NotPenceresi {
    /// İçerik pencereleri kapanana kadar burada tutulur.
    static var icerikPencereleri: [NotPenceresi] = []

    /// Aynı sayfa zaten bir içerik penceresinde açıksa yenisi açılmaz, o öne gelir.
    @discardableResult
    static func icerikPenceresiAc(_ url: URL, yanindaki: NSWindow?) -> NotPenceresi {
        if let acik = icerikPencereleri.first(where: { $0.mevcutDosyaURL == url }) {
            acik.makeKeyAndOrderFront(nil)
            return acik
        }
        let pencere = NotPenceresi(icerikURL: url)
        icerikPencereleri.append(pencere)
        pencere.setContentSize(NSSize(width: 760, height: 820))
        if let yanindaki {
            pencere.setFrameTopLeftPoint(NSPoint(x: yanindaki.frame.minX + 40, y: yanindaki.frame.maxY - 40))
        } else {
            pencere.center()
        }
        pencere.makeKeyAndOrderFront(nil)
        pencere.makeFirstResponder(pencere.metinGorunumu)
        return pencere
    }

    /// Ana pencerede bir dal taşınınca ya da adı değişince içerik pencerelerindeki yol da izler;
    /// yoksa pencere eski yola yazıp sayfayı ikinci kez oluştururdu.
    static func icerikPencereleriniTasi(eskiKlasor: URL, yeniKlasor: URL, eskiIcerik: URL?, yeniIcerik: URL?) {
        for pencere in icerikPencereleri {
            guard let eski = pencere.mevcutDosyaURL else { continue }
            let yeni = SayfaBaglantilari.tasinanURL(eski, eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor,
                                                    eskiIcerik: eskiIcerik, yeniIcerik: yeniIcerik)
            guard yeni != eski else { continue }
            pencere.notYenidenAdlandirildiIsleyici(eski: eski, yeni: yeni)
            pencere.kenarPaneli.yenile(secili: yeni)
        }
    }

    /// Açık sayfa diskte bu pencerenin son yazdığından/okuduğundan farklıysa (başka pencere
    /// kaydetti, bağlar yeniden yazıldı) yeniden yükler. İmleç ve kaydırma yeri korunur.
    /// Kaydedilmemiş değişiklik varsa dokunmaz; o değişiklik diske gidecek olandır.
    func diskleEsitle() {
        guard anaSayfa.isHidden, let url = mevcutDosyaURL, !kaydedici.duzenlendiMi else { return }
        guard let disk = try? String(contentsOf: url, encoding: .utf8) else {
            // Sayfa başka pencerede silindi: içerik penceresi kapanır (yazdıkları zaten kaydedilmişti).
            if icerikModu, !FileManager.default.fileExists(atPath: url.path) { close() }
            return
        }
        guard disk != kaydedici.sonYazilanIcerik else { return }
        let secim = metinGorunumu.selectedRange()
        let kaydirma = kaydirmaGorunumu.contentView.bounds.origin
        notuAc(url, panelYenile: false, yenidenYukle: true)
        let uzunluk = (metinGorunumu.string as NSString).length
        metinGorunumu.setSelectedRange(NSRange(location: min(secim.location, uzunluk), length: 0))
        metinGorunumu.scroll(kaydirma)
    }

    @objc func baskaPencereKaydetti(_ bildirim: Notification) {
        guard let kaynak = bildirim.object as? NotPenceresi, kaynak !== self,
              let url = bildirim.userInfo?["url"] as? URL,
              let metin = bildirim.userInfo?["metin"] as? String else { return }
        // Arama ve bağ önbelleği bu penceredeki panelde de güncel kalsın.
        kenarPaneli.notIceriginiArkaPlandaGuncelle(url, metin: metin)
        if url == mevcutDosyaURL { diskleEsitle() }
    }

    @objc func baskaPencereTemaSecti(_ bildirim: Notification) {
        guard bildirim.object as? NotPenceresi !== self else { return }
        temaUygulaTumUI()
    }

    /// İçerik penceresinde yeni sayfa, ağacı görünen ana pencerede oluşturulur.
    var anaPencere: NotPenceresi? {
        NSApp.windows.lazy.compactMap { $0 as? NotPenceresi }.first { !$0.icerikModu }
    }
}

extension Notification.Name {
    /// Tema seçilince diğer pencereler renklerini yeniler; `object` temayı seçen penceredir.
    static let notDefteriTemaDegisti = Notification.Name("NotDefteri.temaDegisti")
    /// Bir pencere sayfayı diske yazdı; `object` pencere, `userInfo` "url" ve "metin".
    static let notDefteriSayfaKaydedildi = Notification.Name("NotDefteri.sayfaKaydedildi")
}
