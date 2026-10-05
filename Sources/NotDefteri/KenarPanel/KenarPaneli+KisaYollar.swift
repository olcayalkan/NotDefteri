import AppKit
import NotDefteriCekirdek

final class KenarBolumu: NSObject {
    let ad: String
    let anahtar: String
    var sayfalar: [AgacDugumu] = []
    var katli: Bool {
        get { UserDefaults.standard.bool(forKey: anahtar) }
        set { UserDefaults.standard.set(newValue, forKey: anahtar) }
    }
    init(_ ad: String, anahtar: String) { self.ad = ad; self.anahtar = anahtar }
}

let kFavoriSurukleTipi = NSPasteboard.PasteboardType("tr.notdefteri.favori")

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
        return (favoriBolumu.sayfalar.isEmpty ? [] : [favoriBolumu]) + [sonAcilanBolumu]
    }

    func kisaYolMu(_ dugum: AgacDugumu) -> Bool {
        guard !aramaFiltresiEtkin else { return false }
        return [favoriBolumu, sonAcilanBolumu].contains { $0.sayfalar.contains { $0 === dugum } }
    }

    func kisaYollariHazirla() {
        guard !aramaFiltresiEtkin else { return }
        favoriBolumu.sayfalar = favoriler.sayfalar.map { AgacDugumu(icerikURL: $0, klasorURL: sayfaKlasoru($0)) }
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
        if let bolum = item as? KenarBolumu {
            if outlineView.isItemExpanded(bolum) { outlineView.collapseItem(bolum) }
            else { outlineView.expandItem(bolum) }
            return false
        }
        return true
    }

    @objc func favoriTiklandi() {
        guard let url = tiklananDugum()?.icerikURL else { return }
        if favoriler.iceriyor(url) { favoriler.cikar(url) } else { favoriler.ekle(url) }
        kisaYollariPlanla()
    }
}
