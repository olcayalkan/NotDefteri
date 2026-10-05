import AppKit
import NotDefteriCekirdek

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

    /// Notu diske yazar. Başarılıysa `true` döner.
    ///
    /// Yazma mantığı `NotKaydedici`de; burada yalnızca arayüz tepkileri var
    /// (uyarı gösterme, başlık etiketi, kenar panel tazeleme).
    @discardableResult
    func kaydetURLe(_ url: URL, hazirMetin: String? = nil, panelYenile: Bool = true) -> Bool {
        let metin = hazirMetin ?? sayfaMarkdownunuUret(metinGorunumu.attributedString(), ustbilgi: sayfaUstbilgisi)

        switch kaydedici.yaz(metin: metin, url: url, mevcutURL: mevcutDosyaURL) {
        case .gerekmedi:
            return true
        case .basarisiz(let neden):
            kayitHatasiniBildir(url: url, neden: neden)
            return false
        case .yazildi:
            kayitHatasiBildirildi = false
            SayfaGecmisi.kaydet(metin: metin, icerikURL: url)
            mevcutDosyaURL = url
            baslikEtiketiniGuncelle()
            kenarPaneli.notIceriginiGuncelle(url, metin: metin)
            if panelYenile { kenarPaneli.yenile(secili: url) }
            return true
        }
    }

    /// Kayıt hatasını bir kez bildirir. Otomatik kayıt sürekli denediği için
    /// hata devam ederken uyarı tekrarlanmaz; başarılı kayıtta bayrak sıfırlanır.
    private func kayitHatasiniBildir(url: URL, neden: String) {
        guard !kayitHatasiBildirildi else { return }
        kayitHatasiBildirildi = true

        let uyari = NSAlert()
        uyari.alertStyle = .critical
        uyari.messageText = "Not kaydedilemedi"
        uyari.informativeText = """
            "\(sayfaAdi(url))" diske yazılamadı. Yazdıkların pencerede duruyor; \
            kapatmadan önce başka bir yere kopyala.

            Neden: \(neden)
            """
        uyari.addButton(withTitle: "Tamam")
        uyari.addButton(withTitle: "Klasörü Göster")
        if uyari.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
        }
    }

    func textDidChange(_ notification: Notification) {
        icerikDegisti()
        gecmisDugmeleriniGuncelle()
        icindekileriTazelemeyiPlanla()
    }

    func icindekileriTazelemeyiPlanla() {
        icindekiler.icerigiGuncellemeyiPlanla(metinGorunumu.textStorage)
        icindekiler.etkinBasligiGuncelle(imlecKonumu: metinGorunumu.selectedRange().location)
    }

    // MARK: Otomatik kayıt

    /// İçerik değiştiğinde çağrılır; kaydediciye zamanlayıcı kurdurur.
    func icerikDegisti() {
        sonDuzenleme = Date()
        altBilgiyiGuncellemeyiPlanla()
        kaydedici.degisiklikIsaretle()
        kaydedici.zamanlayiciKur { [weak self] in self?.otomatikKaydet() }
    }

    func otomatikKayitBekleyeniIptalEt() {
        kaydedici.bekleyeniIptalEt()
    }

    func otomatikKaydet() {
        guard kaydedici.duzenlendiMi else { return }
        let metin = sayfaMarkdownunuUret(metinGorunumu.attributedString(), ustbilgi: sayfaUstbilgisi)
        // Kaydedilmiş bir notta içerik diskle aynıysa yazmaya gerek yok.
        // (Henüz dosyası olmayan not bu kontrolden muaf; aşağıda oluşturulur.)
        if let url = mevcutDosyaURL,
           !kaydedici.yazmakGerekli(metin: metin, url: url, mevcutURL: url) {
            kaydedici.temizIsaretle()
            return
        }
        guard let mevcutURL = mevcutDosyaURL else {
            guard !metin.isEmpty else { return }
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
                guard kaydetURLe(mevcutURL, hazirMetin: metin, panelYenile: false) else { return }
                kenarPaneli.baglantiOnbelleginiHazirla()
                if let yeniURL = sayfayiYenidenAdlandir(mevcutURL, yeniAd: istenenAd), yeniURL != mevcutURL {
                    // Taşıma gerçekleşti; yazma başarısız olsa da yol artık budur.
                    mevcutDosyaURL = yeniURL
                    baslikEtiketiniGuncelle()
                    kenarPaneli.acikNotuBildir(yeniURL)
                    kaydetURLe(yeniURL, hazirMetin: metin, panelYenile: false)
                    kenarPaneli.acikDaliTasindiOlarakIsle(eskiKlasor: sayfaKlasoru(mevcutURL), yeniKlasor: sayfaKlasoru(yeniURL),
                                                        eskiIcerik: mevcutURL, yeniIcerik: yeniURL)
                    kenarPaneli.yenile(secili: yeniURL)
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

    /// Kapanış öncesi son kayıt. Yazma başarısızsa kullanıcıya kaydetmeden
    /// çıkma seçeneği sunar; vazgeçerse çağıran kapanmayı iptal eder.
    @discardableResult
    func kapanistaGerekirseKaydet() -> Bool {
        otomatikKayitBekleyeniIptalEt()
        if mevcutNotuKaybolmayacakSekildeKaydet() { return true }

        let uyari = NSAlert()
        uyari.alertStyle = .warning
        uyari.messageText = "Kaydetmeden çıkılsın mı?"
        uyari.informativeText = "Not kaydedilemedi. Kaydetmeden çıkarsanız son değişiklikler kaybolacak."
        uyari.addButton(withTitle: "Vazgeç")
        uyari.addButton(withTitle: "Kaydetmeden Çık")
        guard uyari.runModal() == .alertSecondButtonReturn else { return false }
        // Pencere kapandıktan sonraki uygulama çıkışında tekrar kayıt sorma.
        kaydedici.temizIsaretle()
        return true
    }
}
