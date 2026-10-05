import AppKit
import NotDefteriCekirdek

// Çağrı imzaları korunur; pencere ve sürükle-bırak yollarının uyarıları da bu katmandadır.
func benzersizSayfaURL(taban: String, klasor: URL) -> URL {
    let sonuc = benzersizSayfaURLSonucu(taban: taban, klasor: klasor)
    if sonuc.gecersizAd {
        let uyari = NSAlert()
        uyari.messageText = "Bu ad kullanılamaz"
        uyari.informativeText = "Gizli, ayrılmış veya geçersiz bir ad girdiniz. Not, Yeni Sayfa adıyla kaydedilecek."
        uyari.addButton(withTitle: "Tamam")
        uyari.runModal()
        return benzersizSayfaURLSonucu(taban: "Yeni Sayfa", klasor: klasor).url
    }
    return sonuc.url
}

@discardableResult
func sayfayiYenidenAdlandir(_ icerikURL: URL, yeniAd: String) -> URL? {
    sayfaTasimaUyarisiIle { try sayfayiYenidenAdlandirmaSonucu(icerikURL, yeniAd: yeniAd) }
}

@discardableResult
func sayfayiTasi(_ icerikURL: URL, hedefKlasor: URL) -> URL? {
    sayfaTasimaUyarisiIle { try sayfaTasimaSonucu(icerikURL, hedefKlasor: hedefKlasor) }
}

private func sayfaTasimaUyarisiIle(_ islem: () throws -> URL?) -> URL? {
    do {
        return try islem()
    } catch {
        let tasimaHatasi = error as? SayfaTasimaHatasi
        let uyari = NSAlert(error: tasimaHatasi?.neden ?? error)
        uyari.messageText = "Sayfa taşınamadı"
        if let tasimaHatasi, let geriAlmaHatasi = tasimaHatasi.geriAlmaHatasi {
            uyari.informativeText += "\nDosya eski yerine alınamadı: \(geriAlmaHatasi.localizedDescription)\nDosyanın bulunduğu yol: \(tasimaHatasi.dosyaURL.path)"
        }
        uyari.runModal()
        return nil
    }
}

// MARK: - KenarPaneli: Sayfa ekleme, yeniden adlandırma, silme

extension KenarPaneli {

    // MARK: Klasör / not işlemleri

    /// Başlık çubuğundaki "yeni not" için hedef: seçili sayfanın kardeşi olacak
    /// şekilde onun bulunduğu klasör; seçim yoksa kök.
    func hedefKlasor() -> URL {
        // Gizliyken gezinme seçili satırı güncellemez; yeni not eski dala gitmesin.
        if !gorunumGuncellemeleriEtkin, acikNotURL != duraklatilanAcikNotURL, let acikNotURL {
            return ustKlasor(acikNotURL)
        }
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
        guard sayfaAdiGecerliMi(yeniAd) else {
            let uyari = NSAlert()
            uyari.messageText = "Bu ad kullanılamaz"
            uyari.informativeText = "Sayfa adı boş olamaz, noktayla başlayamaz, / veya : içeremez; ekler ve Görseller adları ayrılmıştır."
            uyari.addButton(withTitle: "Tamam")
            uyari.runModal()
            yenile(secili: acikNotURL)
            return
        }
        guard tasinmadanOnce?() ?? true else { return }
        baglantiOnbelleginiHazirla()
        let eskiCocukKlasoru = dugum.klasorURL
        let yeniCocukKlasoru: URL
        var yeniSayfaURL: URL?

        if let icerik = dugum.icerikURL {
            guard let yeni = sayfayiYenidenAdlandir(icerik, yeniAd: yeniAd) else {
                yenile(secili: acikNotURL)
                return
            }
            guard yeni != icerik else { return }
            yeniCocukKlasoru = sayfaKlasoru(yeni)
            yeniSayfaURL = yeni
            if acikNotURL == icerik {
                acikNotURL = yeni
                notYenidenAdlandirildi?(icerik, yeni)
            }
        } else {
            // Salt kapsayıcı klasör (eski yapıdan).
            let ust = dugum.klasorURL.deletingLastPathComponent()
            guard yeniAd != dugum.ad else { return }
            let aday = benzersizSayfaURL(taban: yeniAd, klasor: ust).deletingLastPathComponent()
            guard (try? FileManager.default.moveItem(at: dugum.klasorURL, to: aday)) != nil else { return }
            yeniCocukKlasoru = aday
        }
        siraAdiniDegistir(klasor: eskiCocukKlasoru.deletingLastPathComponent(),
                          eski: dugum.ad, yeni: yeniCocukKlasoru.lastPathComponent)
        acikDaliTasindiOlarakIsle(eskiKlasor: eskiCocukKlasoru, yeniKlasor: yeniCocukKlasoru,
                                  eskiIcerik: dugum.icerikURL, yeniIcerik: yeniSayfaURL)
        yenile(secili: acikNotURL)
    }

    /// Bir dal taşındıktan (ya da adı değiştikten) sonra açık notun yolunu ve
    /// açık klasör kayıtlarını yeni yere göre günceller.
    ///
    /// Taşınan sayfanın kendisi açıksa `eskiIcerik`/`yeniIcerik` üzerinden,
    /// açık not taşınan dalın ALTINDAysa yol öneki değiştirilerek bildirilir;
    /// yoksa editör silinmiş bir yolu kaydetmeye çalışıyordu.
    func acikDaliTasindiOlarakIsle(eskiKlasor: URL, yeniKlasor: URL, eskiIcerik: URL?, yeniIcerik: URL?) {
        if let eskiIcerik, let yeniIcerik, acikNotURL == eskiIcerik {
            acikNotURL = yeniIcerik
            notYenidenAdlandirildi?(eskiIcerik, yeniIcerik)
        } else if let acik = acikNotURL, acik.path.hasPrefix(eskiKlasor.path + "/") {
            let yeniURL = URL(fileURLWithPath: yeniKlasor.path + acik.path.dropFirst(eskiKlasor.path.count))
            acikNotURL = yeniURL
            notYenidenAdlandirildi?(acik, yeniURL)
        }
        acikKlasorleriTasi(eski: eskiKlasor.path, yeni: yeniKlasor.path)
        dalBaglantilariniGuncelle(eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor,
                                 eskiIcerik: eskiIcerik, yeniIcerik: yeniIcerik)
    }

    /// Dönüştürme seçeneği yalnızca eski düzendeki düz notlarda görünür.
    func menuNeedsUpdate(_ menu: NSMenu) {
        for oge in menu.items where oge.action == #selector(favoriTiklandi) {
            let url = tiklananDugum()?.icerikURL
            oge.isHidden = url == nil
            oge.title = url.map { favoriler.iceriyor($0) } == true ? "Favorilerden çıkar" : "Favorilere ekle"
        }
        let sabitlenebilir = tiklananDugum().map { !kisaYolMu($0) } ?? false
        for oge in menu.items where oge.action == #selector(sabitleTiklandi) {
            // Süzülmüş ağaçta düğümler kopyadır; sabit durumu güvenilir değil.
            oge.isHidden = !sabitlenebilir || aramaFiltresiEtkin
            oge.title = tiklananDugum()?.sabit == true ? "Sabitlemeyi kaldır" : "📌 Sabitle"
        }
        let eskiDuzenMi = tiklananDugum()?.icerikURL.map { $0.lastPathComponent != kIcerikDosyaAdi } ?? false
        for oge in menu.items where oge.action == #selector(klasoreDonusturTiklandi) {
            oge.isHidden = !eskiDuzenMi
        }
        // Ayırıcı da onunla birlikte gizlensin.
        if let index = menu.items.firstIndex(where: { $0.action == #selector(klasoreDonusturTiklandi) }), index > 0 {
            menu.items[index - 1].isHidden = !eskiDuzenMi
        }
    }

    /// Sabitse kaldırır (sabitsizlerin başına), değilse sabitlerin sonuna ekler.
    @objc func sabitleTiklandi() {
        guard let dugum = tiklananDugum(), !kisaYolMu(dugum), !aramaFiltresiEtkin else { return }
        let ust = tablo.parent(forItem: dugum) as? AgacDugumu
        let kardesler = ust?.cocuklar ?? kokDugumler
        let sabitler = kardesler.filter { $0.sabit }.map { $0.ad }
        let digerleri = kardesler.filter { !$0.sabit && $0 !== dugum }.map { $0.ad }
        let yeni = dugum.sabit
            ? SayfaSirasi(sabitler: sabitler.filter { $0 != dugum.ad }, sira: [dugum.ad] + digerleri)
            : SayfaSirasi(sabitler: sabitler + [dugum.ad], sira: digerleri)
        guard siraYaz(yeni, klasor: ust?.cocuklarKlasoru ?? notlarKlasoru()) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.yenile(secili: self.acikNotURL)
        }
    }

    /// "Ad.md" düzenindeki notu "Ad/index.md" düzenine taşır.
    @objc func klasoreDonusturTiklandi() {
        guard let dugum = tiklananDugum(), let icerik = dugum.icerikURL,
              let yeni = sayfayiKlasoreDonustur(icerik) else { return }
        acikDaliTasindiOlarakIsle(eskiKlasor: dugum.klasorURL, yeniKlasor: sayfaKlasoru(yeni),
                                  eskiIcerik: icerik, yeniIcerik: yeni)
        // Menü bağlamından geliyoruz; ağacı sonraki döngüde kur (bkz. adiDegistir).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.yenile(secili: self.acikNotURL)
        }
    }

    @objc func silTiklandi() {
        guard let dugum = tiklananDugum() else { return }
        let altKlasor = dugum.klasorURL
        let altDallariVar = tumNotlar.contains { $0 != dugum.icerikURL && $0.path.hasPrefix(altKlasor.path + "/") }

        let uyari = NSAlert()
        uyari.messageText = "\"\(dugum.ad)\" silinsin mi?"
        uyari.informativeText = altDallariVar
            ? "Sayfa, alt sayfaları ve görselleri uygulamanın çöp kutusunda 30 gün saklanacak."
            : "Bu sayfa uygulamanın çöp kutusunda 30 gün saklanacak."
        uyari.addButton(withTitle: "Sil")
        uyari.addButton(withTitle: "Vazgeç")
        if let silButonu = uyari.buttons.first {
            silButonu.hasDestructiveAction = true
        }
        guard uyari.runModal() == .alertFirstButtonReturn else { return }

        guard tasinmadanOnce?() ?? true else { return }
        do {
            try copKutusu.sil(dugum)
        } catch {
            let hata = NSAlert(error: error)
            hata.messageText = "Sayfa çöp kutusuna taşınamadı"
            hata.runModal()
            return
        }

        // Açık sayfa silindiyse (ya da silinen dalın altındaysa) editörü boşalt.
        if let acik = acikNotURL, acik == dugum.icerikURL || acik.path.hasPrefix(altKlasor.path + "/") {
            acikNotURL = nil
            notSilindi?(acik)
        }
        siraAdiniDegistir(klasor: altKlasor.deletingLastPathComponent(), eski: dugum.ad, yeni: nil)
        acikKlasorleriSil(onek: altKlasor.path)
        DispatchQueue.main.async { [weak self] in self?.yenile(secili: nil) }
    }

    // MARK: Açık klasör kayıtlarının bakımı

    /// Bir dal taşındığında altındaki TÜM açık klasör kayıtlarını yeni yola taşır.
    ///
    /// Yalnızca taşınan düğümün kendi yolunu güncellemek yetmiyordu: torun
    /// sayfaların kayıtları eski önekte kalıyor, dal yeniden açılmıyor ve
    /// kayıt kalıcı çöpe dönüşüyordu.
    func acikKlasorleriTasi(eski: String, yeni: String) {
        let etkilenen = acikKlasorYollari.filter { $0 == eski || $0.hasPrefix(eski + "/") }
        guard !etkilenen.isEmpty else { return }
        for yol in etkilenen {
            acikKlasorYollari.remove(yol)
            acikKlasorYollari.insert(yeni + yol.dropFirst(eski.count))
        }
        acikKlasorleriKaydet()
    }

    /// Silinen dalın açık klasör kayıtlarını temizler.
    func acikKlasorleriSil(onek: String) {
        let etkilenen = acikKlasorYollari.filter { $0 == onek || $0.hasPrefix(onek + "/") }
        guard !etkilenen.isEmpty else { return }
        etkilenen.forEach { acikKlasorYollari.remove($0) }
        acikKlasorleriKaydet()
    }
}
