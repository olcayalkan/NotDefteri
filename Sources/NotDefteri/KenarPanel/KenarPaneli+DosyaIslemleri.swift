import AppKit

// MARK: - KenarPaneli: Sayfa ekleme, yeniden adlandırma, silme

extension KenarPaneli {

    // MARK: Klasör / not işlemleri

    /// Başlık çubuğundaki "yeni not" için hedef: seçili sayfanın kardeşi olacak
    /// şekilde onun bulunduğu klasör; seçim yoksa kök.
    func hedefKlasor() -> URL {
        guard let dugum = tablo.item(atRow: tablo.selectedRow) as? AgacDugumu else { return notlarKlasoru() }
        return dugum.sayfaMi ? dugum.klasorURL.deletingLastPathComponent() : dugum.klasorURL
    }

    /// Sağ tıklanan satırın düğümü (boşluğa tıklandıysa nil).
    func tiklananDugum() -> AgacDugumu? {
        tablo.item(atRow: tablo.clickedRow) as? AgacDugumu
    }

    @objc func altSayfaEkleTiklandi() {
        guard let dugum = tiklananDugum() else {
            yeniSayfaIstendi?(notlarKlasoru())
            return
        }
        let hedefKlasor = dugum.cocuklarKlasoru
        // Bu dal artık açık kalsın ki yeni sayfa görünsün.
        acikKlasorYollari.insert(hedefKlasor.path)
        acikKlasorleriKaydet()
        yeniSayfaIstendi?(hedefKlasor)
    }

    /// Sağ tıklanan sayfanın yanına (aynı seviyeye) yeni bir sayfa açar.
    @objc func kardesSayfaEkleTiklandi() {
        guard let dugum = tiklananDugum() else {
            yeniSayfaIstendi?(notlarKlasoru())
            return
        }
        yeniSayfaIstendi?(dugum.sayfaMi ? dugum.klasorURL.deletingLastPathComponent() : dugum.klasorURL)
    }

    @objc func yenidenAdlandirTiklandi() {
        guard let dugum = tiklananDugum() else { return }
        // Sağ tık menüsü de satır üzerinde düzenlemeyi açar; ayrı bir pencere gerekmez.
        let satir = tablo.row(forItem: dugum)
        guard satir >= 0 else { return }
        adiYerindeDuzenle(dugum: dugum, satir: satir)
    }

    func adiDegistir(_ dugum: AgacDugumu, yeniAd: String) {
        let eskiCocukKlasoru = dugum.klasorURL
        let yeniCocukKlasoru: URL

        if let icerik = dugum.icerikURL {
            guard let yeni = sayfayiYenidenAdlandir(icerik, yeniAd: yeniAd), yeni != icerik else { return }
            yeniCocukKlasoru = sayfaKlasoru(yeni)
            if acikNotURL == icerik {
                acikNotURL = yeni
                notYenidenAdlandirildi?(icerik, yeni)
            }
        } else {
            // Salt kapsayıcı klasör (eski yapıdan).
            let ust = dugum.klasorURL.deletingLastPathComponent()
            var aday = ust.appendingPathComponent(yeniAd, isDirectory: true)
            guard aday != dugum.klasorURL else { return }
            var sayac = 2
            while FileManager.default.fileExists(atPath: aday.path) {
                aday = ust.appendingPathComponent("\(yeniAd) (\(sayac))", isDirectory: true)
                sayac += 1
            }
            guard (try? FileManager.default.moveItem(at: dugum.klasorURL, to: aday)) != nil else { return }
            yeniCocukKlasoru = aday
        }
        // Açık sayfa taşınan dalın altındaysa yeni yolunu bildir.
        if let acik = acikNotURL, acik.path.hasPrefix(eskiCocukKlasoru.path + "/") {
            let yeniURL = URL(fileURLWithPath: yeniCocukKlasoru.path + acik.path.dropFirst(eskiCocukKlasoru.path.count))
            acikNotURL = yeniURL
            notYenidenAdlandirildi?(acik, yeniURL)
        }
        if acikKlasorYollari.remove(eskiCocukKlasoru.path) != nil {
            acikKlasorYollari.insert(yeniCocukKlasoru.path)
            acikKlasorleriKaydet()
        }
        yenile(secili: acikNotURL)
    }

    /// Dönüştürme seçeneği yalnızca eski düzendeki düz notlarda görünür.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let eskiDuzenMi = tiklananDugum()?.icerikURL.map { $0.lastPathComponent != kIcerikDosyaAdi } ?? false
        for oge in menu.items where oge.action == #selector(klasoreDonusturTiklandi) {
            oge.isHidden = !eskiDuzenMi
        }
        // Ayırıcı da onunla birlikte gizlensin.
        if let index = menu.items.firstIndex(where: { $0.action == #selector(klasoreDonusturTiklandi) }), index > 0 {
            menu.items[index - 1].isHidden = !eskiDuzenMi
        }
    }

    /// "Ad.md" düzenindeki notu "Ad/index.md" düzenine taşır.
    @objc func klasoreDonusturTiklandi() {
        guard let dugum = tiklananDugum(), let icerik = dugum.icerikURL,
              let yeni = sayfayiKlasoreDonustur(icerik) else { return }
        if acikNotURL == icerik {
            acikNotURL = yeni
            notYenidenAdlandirildi?(icerik, yeni)
        }
        // Menü bağlamından geliyoruz; ağacı sonraki döngüde kur (bkz. adiDegistir).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.yenile(secili: self.acikNotURL)
        }
    }

    @objc func silTiklandi() {
        guard let dugum = tiklananDugum() else { return }
        let altKlasor = dugum.klasorURL
        let altDallariVar = !dugum.cocuklar.isEmpty

        let uyari = NSAlert()
        uyari.messageText = "\"\(dugum.ad)\" silinsin mi?"
        uyari.informativeText = altDallariVar
            ? "Sayfa ve altındaki tüm sayfalar Çöp Kutusu'na taşınacak."
            : "Bu sayfa Çöp Kutusu'na taşınacak."
        uyari.addButton(withTitle: "Sil")
        uyari.addButton(withTitle: "Vazgeç")
        if let silButonu = uyari.buttons.first {
            silButonu.hasDestructiveAction = true
        }
        guard uyari.runModal() == .alertFirstButtonReturn else { return }

        // Yeni düzende sayfanın her şeyi klasörünün içinde; tek hamlede gider.
        if FileManager.default.fileExists(atPath: altKlasor.path) {
            try? FileManager.default.trashItem(at: altKlasor, resultingItemURL: nil)
        }
        if let icerik = dugum.icerikURL, icerik.lastPathComponent != kIcerikDosyaAdi {
            try? FileManager.default.trashItem(at: icerik, resultingItemURL: nil)
        }

        // Açık sayfa silindiyse (ya da silinen dalın altındaysa) editörü boşalt.
        if let acik = acikNotURL, acik == dugum.icerikURL || acik.path.hasPrefix(altKlasor.path + "/") {
            acikNotURL = nil
            notSilindi?(acik)
        }
        DispatchQueue.main.async { [weak self] in self?.yenile(secili: nil) }
    }
}
