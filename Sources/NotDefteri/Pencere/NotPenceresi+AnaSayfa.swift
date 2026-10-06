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
        anaSayfa.guncelle(sonlar: baglar.sonAcilanlar.prefix(8).compactMap(kart),
                         favoriler: kenarPaneli.favoriler.sayfalar.compactMap(kart),
                         yapilacaklar: bekleyenYapilacaklariBul(onbellek))
    }

    /// Disk yalnızca tıklanan hedef için okunur; eski konumla başka satır işaretlenmez.
    private func guncelYapilacakMetni(_ gorev: BekleyenYapilacak) -> String? {
        guard mevcutNotuKaybolmayacakSekildeKaydet() else { return nil }
        do {
            try notlarYolunuDogrula(gorev.url)
            let metin = try String(contentsOf: gorev.url, encoding: .utf8)
            guard yapilacakGecerliMi(gorev, metin: metin,
                onbellekMetni: kenarPaneli.icerikOnbellek[gorev.url]?.hamMarkdown,
                acikSayfaMi: mevcutDosyaURL == gorev.url, acikSayfaMetni: kaydedici.sonYazilanIcerik) else {
                kenarPaneli.notIceriginiGuncelle(gorev.url, metin: metin)
                if mevcutDosyaURL == gorev.url, kaydedici.sonYazilanIcerik != metin {
                    notuAc(gorev.url, yenidenYukle: true)
                    anaSayfayiGoster(kaydirmaSifirlansin: false)
                } else { anaSayfayiTazele() }
                NSSound.beep()
                return nil
            }
            return metin
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }

    private func yapilacakEditorKonumu(_ gorev: BekleyenYapilacak, metin: String) -> Int {
        let govde = sayfaUstbilgisiniAyir(metin).govde as NSString
        // Özgün kaynak satırları ile görünen paragraf uzunlukları farklıdır.
        // Aynı çevirici, yalnızca tıklamada, başlık/görsel/kod öncesindeki farkı çözer.
        return MacBelgeAdaptoru.markdownuAc(govde.substring(to: gorev.govdeKonumu), taban: sayfaKlasoru(gorev.url)).length
    }

    func yapilacagaGit(_ gorev: BekleyenYapilacak) {
        guard let metin = guncelYapilacakMetni(gorev) else { return }
        let konum = yapilacakEditorKonumu(gorev, metin: metin)
        notuAc(gorev.url)
        guard mevcutDosyaURL == gorev.url, anaSayfa.isHidden else { return }
        basligaGit(konum)
    }

    func yapilacagiTamamla(_ gorev: BekleyenYapilacak) {
        guard let metin = guncelYapilacakMetni(gorev) else {
            anaSayfa.temayiUygula()
            return
        }
        let sonuc: (markdown: String, satir: String)
        do { sonuc = try yapilacagiTamamlayanMetin(gorev, metin: metin) }
        catch {
            NSAlert(error: error).runModal()
            anaSayfa.temayiUygula()
            return
        }
        if mevcutDosyaURL == gorev.url {
            let konum = yapilacakEditorKonumu(gorev, metin: metin)
            guard let depo = metinGorunumu.textStorage, konum < depo.length else { return }
            let paragraf = depo.mutableString.paragraphRange(for: NSRange(location: konum, length: 0))
            let yeniParagraf = MacBelgeAdaptoru.markdownuAc(sonuc.satir, taban: sayfaKlasoru(gorev.url))
            // Ortak blok düzenleme yolu yalnızca hedef paragrafı değiştirir ve undo'yu korur.
            metinGorunumu.isEditable = true
            metinGorunumu.blokDuzenle(paragraf, yeni: yeniParagraf, secim: metinGorunumu.selectedRange(),
                                      yazim: metinGorunumu.typingAttributes)
            metinGorunumu.isEditable = false
            guard metinGorunumu.blok(paragraf)?.tamamlandi == true else {
                anaSayfa.temayiUygula()
                return
            }
            guard kaydetURLe(gorev.url, hazirMetin: sonuc.markdown, panelYenile: false) else {
                anaSayfa.temayiUygula()
                return
            }
        } else {
            do {
                try notlarYolunuDogrula(gorev.url)
                try sonuc.markdown.write(to: gorev.url, atomically: true, encoding: .utf8)
                kenarPaneli.notIceriginiGuncelle(gorev.url, metin: sonuc.markdown)
            } catch {
                NSAlert(error: error).runModal()
                anaSayfa.temayiUygula()
                return
            }
        }
        anaSayfayiTazele()
        icindekiler.isHidden = true
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
