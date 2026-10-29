import AppKit
import NotDefteriCekirdek

/// Kök sayfaların üstündeki "Sayfalar" başlığı: seçilmez, katlanmaz, sürükleme hedefi değildir.
final class SayfalarBasligi: NSObject {}

final class KenarBolumu: NSObject {
    let ad: String
    let anahtar: String
    var sayfalar: [AgacDugumu] = []
    var katli: Bool {
        get { gAyarlar.bool(forKey: anahtar) }
        set { gAyarlar.set(newValue, forKey: anahtar) }
    }
    init(_ ad: String, anahtar: String) { self.ad = ad; self.anahtar = anahtar }
}

extension KenarPaneli {
    @objc func copKutusuTiklandi() {
        if copPopover.isShown { copPopover.performClose(nil); return }
        copPopover.behavior = .semitransient
        copPopover.contentViewController = CopKutusuPaneli(copKutusu: copKutusu) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.yenile(secili: self.acikNotURL)
            }
        }
        copPopover.show(relativeTo: copButonu.bounds, of: copButonu, preferredEdge: .maxX)
    }

    var kenarBolumleri: [KenarBolumu] {
        guard !aramaFiltresiEtkin else { return [] }
        return [sonAcilanBolumu]
    }

    /// Kökte sayfalardan önce gelen satırlar: kısa yol bölümleri ve "Sayfalar" başlığı.
    var kokBasliklari: [Any] {
        guard !aramaFiltresiEtkin, !kokDugumler.isEmpty else { return kenarBolumleri }
        return kenarBolumleri + [sayfalarBasligi]
    }

    func kisaYolMu(_ dugum: AgacDugumu) -> Bool {
        guard !aramaFiltresiEtkin else { return false }
        return sonAcilanBolumu.sayfalar.contains { $0 === dugum }
    }

    func kisaYollariHazirla() {
        guard !aramaFiltresiEtkin else { return }
        sonAcilanBolumu.sayfalar = sayfaBaglantilari.sonAcilanlar.prefix(5).map {
            AgacDugumu(icerikURL: $0, klasorURL: sayfaKlasoru($0))
        }
    }

    func bolumleriAc() {
        for bolum in kenarBolumleri where !bolum.katli { tablo.expandItem(bolum) }
    }

    /// Açma/seçim/menü geri çağrısının içinde reloadData yapılmaz.
    func kisaYollariPlanla() {
        guard !kisaYolGuncellemesiBekliyor else { return }
        kisaYolGuncellemesiBekliyor = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.gorunumGuncellemeleriEtkin else { return }
            self.kisaYollariYenile()
        }
    }

    func kisaYollariYenile() {
        kisaYolGuncellemesiBekliyor = false
        guard !aramaFiltresiEtkin else { return }
        guard duzenlenenDugum == nil else { duzenlemeBitinceYenile = true; return }
        programatikSecimYapiliyor = true
        defer { programatikSecimYapiliyor = false }
        kisaYollariHazirla()
        tablo.reloadData()
        bolumleriAc()
        if !anaSayfaSecili, let acikNotURL, let satir = (0..<tablo.numberOfRows).first(where: {
            guard let dugum = tablo.item(atRow: $0) as? AgacDugumu else { return false }
            return !kisaYolMu(dugum) && dugum.icerikURL == acikNotURL
        }) {
            tablo.selectRowIndexes(IndexSet(integer: satir), byExtendingSelection: false)
        } else {
            tablo.deselectAll(nil)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if item is SayfalarBasligi { return false }
        if let bolum = item as? KenarBolumu {
            if outlineView.isItemExpanded(bolum) { outlineView.collapseItem(bolum) }
            else { outlineView.expandItem(bolum) }
            return false
        }
        return true
    }
}
