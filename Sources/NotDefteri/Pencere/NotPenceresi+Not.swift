import AppKit

// MARK: - NotPenceresi: Not açma ve oluşturma

extension NotPenceresi {

    // MARK: Not açma / oluşturma

    func notuAc(_ url: URL) {
        if mevcutDosyaURL != url {
            mevcutNotuKaybolmayacakSekildeKaydet()
        }
        guard let icerik = try? String(contentsOf: url, encoding: .utf8) else { return }
        metinGorunumu.textStorage?.setAttributedString(markdowndenAttributedStringUret(icerik, taban: sayfaKlasoru(url)))
        mevcutDosyaURL = url
        kaydedici.sifirla(sonYazilan: icerik)
        otomatikAdlandirildiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        icindekileriTazele()
        kenarPaneli.yenile(secili: url)
        puntoGostergesiniGuncelle()
    }

    func yeniNotOlustur() {
        mevcutNotuKaybolmayacakSekildeKaydet()
        let bosOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: bosOznitelik))
        mevcutDosyaURL = nil
        kaydedici.sifirla(sonYazilan: nil)
        otomatikAdlandirildiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        icindekileriTazele()
        kenarPaneli.tablo.deselectAll(nil)
        makeFirstResponder(metinGorunumu)
    }

    /// Kenar panelden istenen yeni sayfayı oluşturup açar. Adı "Yeni Sayfa"dır;
    /// ilk satırı yazdıkça dosya adı ona göre değişir.
    func yeniSayfaOlustur(klasor: URL) {
        mevcutNotuKaybolmayacakSekildeKaydet()
        let url = benzersizSayfaURL(taban: "Yeni Sayfa", klasor: klasor)
        // Sayfa = kendi klasörü + içindeki index.md
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? "".write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        notuAc(url)
        otomatikAdlandirildiMi = true
        makeFirstResponder(metinGorunumu)
    }

    func notSilindiIsleyici(_ url: URL) {
        guard mevcutDosyaURL == url else { return }
        let bosOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: bosOznitelik))
        mevcutDosyaURL = nil
        kaydedici.sifirla(sonYazilan: nil)
        otomatikAdlandirildiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        icindekileriTazele()
    }

    func notYenidenAdlandirildiIsleyici(eski: URL, yeni: URL) {
        guard mevcutDosyaURL == eski else { return }
        mevcutDosyaURL = yeni
        otomatikAdlandirildiMi = false  // Adı artık kullanıcı belirledi.
        baslikEtiketiniGuncelle()
        icindekileriTazele()
    }

    /// Not değiştirilmeden önce, yazılmış ama kaydedilmemiş içeriği otomatik olarak kaydeder.
    /// Mevcut bir dosya açıksa üzerine yazar; yeni/boş bir nottaysa içerikten otomatik bir isim üretip yeni dosya oluşturur.
    private func mevcutNotuKaybolmayacakSekildeKaydet() {
        guard kaydedici.duzenlendiMi else { return }
        let icerik = metinGorunumu.string
        guard !icerik.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        } else {
            let hedefURL = benzersizDosyaURL(taban: otomatikBaslikUret(icerik: icerik))
            kaydetURLe(hedefURL)
        }
    }

    func baslikEtiketiniGuncelle() {
        let ad = mevcutDosyaURL.map { sayfaAdi($0) } ?? "Yeni Sayfa"
        baslikCubugu.notAdiEtiketi.stringValue = ad
        title = ad
    }

    // MARK: İçindekiler paneli

    /// Başlıklar değişmiş olabilir; paneli yeniden kurar ve yerine oturtur.
    func icindekileriTazele() {
        icindekiler.icerigiGuncelle(metinGorunumu.textStorage)
        icindekiler.frame = icindekiler.hedefKare()
        icindekiler.etkinBasligiGuncelle(imlecKonumu: metinGorunumu.selectedRange().location)
    }

    /// İçindekilerden bir başlığa tıklanınca metni oraya kaydırır ve imleci koyar.
    func basligaGit(_ konum: Int) {
        guard let depo = metinGorunumu.textStorage, konum < depo.length else { return }
        let paragraf = (depo.string as NSString).paragraphRange(for: NSRange(location: konum, length: 0))
        metinGorunumu.scrollRangeToVisible(paragraf)
        metinGorunumu.setSelectedRange(NSRange(location: paragraf.location, length: 0))
        makeFirstResponder(metinGorunumu)
        icindekiler.etkinBasligiGuncelle(imlecKonumu: paragraf.location)
    }
}
