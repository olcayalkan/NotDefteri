import AppKit

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
            let metin = try String(contentsOf: gorev.url, encoding: .utf8)
            let govde = sayfaUstbilgisiniAyir(metin).govde as NSString
            guard kenarPaneli.icerikOnbellek[gorev.url]?.hamMarkdown == metin,
                  mevcutDosyaURL != gorev.url || kaydedici.sonYazilanIcerik == metin,
                  gorev.govdeKonumu < govde.length,
                  govde.substring(with: govde.lineRange(for: NSRange(location: gorev.govdeKonumu, length: 0))) == gorev.satir else {
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
        return markdowndenAttributedStringUret(govde.substring(to: gorev.govdeKonumu), taban: sayfaKlasoru(gorev.url)).length
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
        let sayfa = sayfaUstbilgisiniAyir(metin)
        let yeni = NSMutableString(string: metin)
        yeni.replaceCharacters(in: NSRange(location: (sayfa.bilgi.kaynak as NSString).length + gorev.kutuKonumu, length: 1), with: "x")
        if mevcutDosyaURL == gorev.url {
            let konum = yapilacakEditorKonumu(gorev, metin: metin)
            guard let depo = metinGorunumu.textStorage, konum < depo.length else { return }
            let paragraf = depo.mutableString.paragraphRange(for: NSRange(location: konum, length: 0))
            let satir = NSMutableString(string: gorev.satir)
            satir.replaceCharacters(in: NSRange(location: gorev.kutuKonumu - gorev.govdeKonumu, length: 1), with: "x")
            let yeniParagraf = markdowndenAttributedStringUret(satir as String, taban: sayfaKlasoru(gorev.url))
            // Ortak blok düzenleme yolu yalnızca hedef paragrafı değiştirir ve undo'yu korur.
            metinGorunumu.isEditable = true
            metinGorunumu.blokDuzenle(paragraf, yeni: yeniParagraf, secim: metinGorunumu.selectedRange(),
                                      yazim: metinGorunumu.typingAttributes)
            metinGorunumu.isEditable = false
            guard metinGorunumu.blok(paragraf)?.tamamlandi == true else {
                anaSayfa.temayiUygula()
                return
            }
            guard kaydetURLe(gorev.url, hazirMetin: yeni as String, panelYenile: false) else {
                anaSayfa.temayiUygula()
                return
            }
        } else {
            do {
                try (yeni as String).write(to: gorev.url, atomically: true, encoding: .utf8)
                kenarPaneli.notIceriginiGuncelle(gorev.url, metin: yeni as String)
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
        let klasor = notlarKlasoru().appendingPathComponent("Günlük", isDirectory: true)
        let ad = gunlukSayfaAdi(tarih)
        let url = klasor.appendingPathComponent(ad).appendingPathComponent(kIcerikDosyaAdi)
        let eski = klasor.appendingPathComponent(ad + ".md")
        if FileManager.default.fileExists(atPath: url.path) { notuAc(url) }
        else if FileManager.default.fileExists(atPath: eski.path) { notuAc(eski) }
        else { icerikleSayfaOlustur(url: { url }, metin: SayfaSablonu.gunluk.markdown(tarih: tarih)) }
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
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let geciciURL = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
            defer { try? FileManager.default.removeItem(at: geciciURL) }
            try Data(metin.utf8).write(to: geciciURL, options: .withoutOverwriting)
            // Aynı klasörde taşıma tamamlanmış dosyayı yayımlar; mevcut hedefi ezmez.
            try FileManager.default.moveItem(at: geciciURL, to: url)
            notuAc(url)
            makeFirstResponder(metinGorunumu)
        } catch {
            let hata = NSAlert(error: error)
            hata.messageText = "Sayfa oluşturulamadı"
            hata.runModal()
        }
    }
}
