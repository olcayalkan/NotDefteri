import AppKit
import NotDefteriCekirdek

extension NotPenceresi {
    @objc func anaSayfaKomutu(_ sender: Any?) { anaSayfayiGoster() }

    @objc func acilistaAnaSayfaKomutu(_ sender: NSMenuItem) {
        gAcilistaAnaSayfa.toggle()
        sender.state = gAcilistaAnaSayfa ? .on : .off
    }

    func anaSayfayiGoster(kaydirmaSifirlansin: Bool = true) {
        if !mevcutNotuKaybolmayacakSekildeKaydet() {
            let uyari = NSAlert()
            uyari.alertStyle = .warning
            uyari.messageText = "Kaydetmeden devam edilsin mi?"
            uyari.informativeText = "Not kaydedilemedi. Son değişiklikler editörde korunacak."
            uyari.addButton(withTitle: "Vazgeç")
            uyari.addButton(withTitle: "Kaydetmeden Devam")
            guard uyari.runModal() == .alertSecondButtonReturn else { return }
        }
        let ilkGosterim = anaSayfa.isHidden
        anaSayfa.sayfaAc = { [weak self] url in
            guard let self else { return }
            self.notuAc(url)
            if self.anaSayfa.isHidden, self.mevcutDosyaURL == url {
                self.makeFirstResponder(self.metinGorunumu)
            }
        }
        hizliBulucu.gizle()
        metinGorunumu.yuzerGorunumleriGizle()
        geriBagZamanlayicisi?.invalidate()
        anaSayfa.isHidden = false
        kenarPaneli.anaSayfaSecili = true
        metinGorunumu.isEditable = false
        kaydirmaGorunumu.isHidden = true
        sayfaSecenekAlani.isHidden = true
        sayfaAltBilgisi.isHidden = true
        icindekiler.isHidden = true
        // Açık editör korunur; paneldeki eski seçim aynı nota tek tıkla dönüşü engellemesin.
        kenarPaneli.programatikSecimYapiliyor = true
        kenarPaneli.tablo.deselectAll(nil)
        kenarPaneli.programatikSecimYapiliyor = false
        kenarPaneli.kisaYollariPlanla()
        kenarPaneli.icerikOnbelleginiIste()
        anaSayfayiTazele()
        baslikEtiketiniGuncelle()
        baslikCubugu.gecmisDurumunuGoster(geriAlinabilir: false, ileriAlinabilir: false)
        icerikBoyutuDegisti()
        if ilkGosterim, kaydirmaSifirlansin { anaSayfa.basaDon() }
        makeFirstResponder(anaSayfa)
    }

    func anaSayfayiGizle() {
        anaSayfa.isHidden = true
        kenarPaneli.anaSayfaSecili = false
        metinGorunumu.isEditable = true
        kaydirmaGorunumu.isHidden = false
        sayfaSecenekAlani.isHidden = false
        sayfaAltBilgisi.isHidden = false
        baslikEtiketiniGuncelle()
        gecmisDugmeleriniGuncelle()
        icindekileriTazele()
        icerikBoyutuDegisti()
    }

    func anaSayfayiTazele() {
        let baglar = kenarPaneli.sayfaBaglantilari
        let onbellek = kenarPaneli.icerikOnbellek
        func kart(_ url: URL) -> AnaSayfaKarti? {
            guard onbellek[url] != nil else { return nil }
            return AnaSayfaKarti(url: url, tarih: baglar.sonAcilmaTarihi(url))
        }
        anaSayfa.guncelle(sonlar: Array(baglar.sonAcilanlar.lazy.compactMap(kart).prefix(SayfaBaglantilari.anaSayfaKartSayisi)))
    }

    func gunlukNotuAc() {
        let tarih = Date()
        do {
            let url = try gunlukNotURL(tarih)
            if dosyaYoluVarMi(url) { notuAc(url) }
            else { icerikleSayfaOlustur(url: { url }, metin: SayfaSablonu.gunluk.markdown(tarih: tarih)) }
        } catch { NSAlert(error: error).runModal() }
    }

    func sablondanSayfaOlustur() {
        let uyari = NSAlert()
        uyari.messageText = "Şablondan yeni sayfa"
        uyari.addButton(withTitle: "Oluştur")
        uyari.addButton(withTitle: "Vazgeç")
        let secim = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26))
        secim.addItems(withTitles: SayfaSablonu.allCases.map(\.rawValue))
        uyari.accessoryView = secim
        guard uyari.runModal() == .alertFirstButtonReturn else { return }
        let sablon = SayfaSablonu.allCases[secim.indexOfSelectedItem]
        icerikleSayfaOlustur(url: {
            benzersizSayfaURL(taban: sablon.rawValue, klasor: kenarPaneli.hedefKlasor())
        }, metin: sablon.markdown())
    }

    private func icerikleSayfaOlustur(url olusturURL: () -> URL, metin: String) {
        guard mevcutNotuKaybolmayacakSekildeKaydet() else { return }
        let url = olusturURL()
        do {
            try NotDefteriCekirdek.icerikleSayfaOlustur(url: url, metin: metin)
            notuAc(url)
            makeFirstResponder(metinGorunumu)
        } catch {
            let hata = NSAlert(error: error)
            hata.messageText = "Sayfa oluşturulamadı"
            hata.runModal()
        }
    }
}
