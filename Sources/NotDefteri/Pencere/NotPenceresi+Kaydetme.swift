import AppKit

// MARK: - NotPenceresi: Kaydetme ve otomatik kayıt

extension NotPenceresi {

    // MARK: Kaydetme (Cmd+S)

    @objc func kaydetKomutu(_ sender: Any?) { kaydet() }

    private func kaydet() {
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        } else {
            isimSorVeKaydet()
        }
    }

    func kaydetURLe(_ url: URL, hazirMetin: String? = nil, panelYenile: Bool = true) {
        let metin = hazirMetin ?? markdownMetniUret(metinGorunumu.attributedString())
        // Aynı dosyaya aynı içeriği tekrar yazma (dosya diskte duruyorsa).
        guard metin != sonYazilanIcerik
                || url != mevcutDosyaURL
                || !FileManager.default.fileExists(atPath: url.path) else {
            duzenlendiMi = false
            return
        }
        // Sayfa klasörü henüz yoksa (yeni sayfa) oluşturulur.
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? metin.write(to: url, atomically: true, encoding: .utf8)
        sonYazilanIcerik = metin
        mevcutDosyaURL = url
        duzenlendiMi = false
        otomatikKayitBekleyeniIptalEt()
        baslikEtiketiniGuncelle()
        if panelYenile { kenarPaneli.yenile(secili: url) }
    }

    func textDidChange(_ notification: Notification) {
        icerikDegisti()
        gecmisDugmeleriniGuncelle()
    }

    // MARK: Otomatik kayıt

    /// İçerik değiştiğinde çağrılır; 5 saniyelik tek atımlık bir zamanlayıcı kurar.
    /// Zamanlayıcı zaten kuruluysa yenisi açılmaz, yani kesintisiz yazarken de
    /// en fazla 5 saniyede bir disk yazımı olur; boştayken hiç zamanlayıcı dönmez.
    func icerikDegisti() {
        duzenlendiMi = true
        guard otomatikKayitZamanlayici == nil else { return }
        let zamanlayici = Timer(timeInterval: kOtomatikKayitAraligi, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.otomatikKayitZamanlayici = nil
            self.otomatikKaydet()
        }
        zamanlayici.tolerance = 1  // Sistemin uyandırmaları birleştirmesine izin verir (enerji dostu).
        RunLoop.main.add(zamanlayici, forMode: .common)  // Menü/kaydırma sırasında da işler.
        otomatikKayitZamanlayici = zamanlayici
    }

    func otomatikKayitBekleyeniIptalEt() {
        otomatikKayitZamanlayici?.invalidate()
        otomatikKayitZamanlayici = nil
    }

    func otomatikKaydet() {
        guard duzenlendiMi else { return }
        let metin = markdownMetniUret(metinGorunumu.attributedString())
        guard metin != sonYazilanIcerik else {
            duzenlendiMi = false
            return
        }
        guard !metinGorunumu.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard let mevcutURL = mevcutDosyaURL else {
            // Henüz kaydedilmemiş not: ilk satırdan bir ad üretip dosyayı oluşturur.
            otomatikAdlandirildiMi = true
            kaydetURLe(benzersizDosyaURL(taban: otomatikBaslikUret(icerik: metinGorunumu.string)), hazirMetin: metin)
            return
        }

        // Adı otomatik üretilmiş bir notun ilk satırı değiştiyse dosya adı da takip etsin.
        if otomatikAdlandirildiMi {
            let istenenAd = otomatikBaslikUret(icerik: metinGorunumu.string)
            if istenenAd != sayfaAdi(mevcutURL) {
                // Sayfa taşınırken alt sayfalarını tutan klasör de birlikte taşınır.
                if let yeniURL = sayfayiYenidenAdlandir(mevcutURL, yeniAd: istenenAd), yeniURL != mevcutURL {
                    kaydetURLe(yeniURL, hazirMetin: metin)
                    return
                }
            }
        }

        // Normal durum: aynı dosyanın üzerine yaz, kenar paneli boşuna tazeleme
        // (panel tüm notları yeniden okuduğu için asıl maliyet orada).
        kaydetURLe(mevcutURL, hazirMetin: metin, panelYenile: false)
    }

    private func isimSorVeKaydet() {
        let uyari = NSAlert()
        uyari.messageText = "Notu Kaydet"
        uyari.informativeText = "Not için bir isim girin:"
        uyari.addButton(withTitle: "Kaydet")
        uyari.addButton(withTitle: "Vazgeç")
        let girisAlani = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        girisAlani.placeholderString = "Örn: Alışveriş Listesi"
        uyari.accessoryView = girisAlani
        uyari.window.initialFirstResponder = girisAlani

        guard uyari.runModal() == .alertFirstButtonReturn else { return }

        var isim = girisAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if isim.isEmpty { isim = "Adsız Not" }
        isim = isim.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")

        let hedefURL = benzersizDosyaURL(taban: isim)
        otomatikAdlandirildiMi = false
        kaydetURLe(hedefURL)
    }

    /// Yeni sayfayı, kenar panelde seçili olanın yanında oluşturur.
    func benzersizDosyaURL(taban: String, klasor verilenKlasor: URL? = nil) -> URL {
        benzersizSayfaURL(taban: taban, klasor: verilenKlasor ?? kenarPaneli.hedefKlasor())
    }

    /// Uygulama tamamen kapanırken (Cmd+Q gibi) mevcut dosyayı üzerine kaydeder.
    func kapanistaGerekirseKaydet() {
        otomatikKayitBekleyeniIptalEt()
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        }
    }
}
