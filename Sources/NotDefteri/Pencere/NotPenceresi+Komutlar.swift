import AppKit

// MARK: - NotPenceresi: Eğik çizgi komutları, başlıklar, geri al/yinele

extension NotPenceresi {

    // MARK: Eğik çizgi komutları (/1 /2 /3 /page) ve başlıklar

    /// Satır başında yazılıp boşluk veya Enter ile tamamlanan komutlar.
    private func egikCizgiKomutu(_ metin: String) -> String? {
        let komut = metin.trimmingCharacters(in: .whitespaces).lowercased()
        return ["/1", "/2", "/3", "/0", "/page", "/sayfa"].contains(komut) ? komut : nil
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let replacementString, replacementString == " " || replacementString == "\n" else { return true }
        let ns = textView.string as NSString

        // İmlecin bulunduğu satırın başından imlece kadarki metin komut mu?
        let satirAralik = ns.paragraphRange(for: NSRange(location: affectedCharRange.location, length: 0))
        let komutAralik = NSRange(location: satirAralik.location,
                                   length: max(0, affectedCharRange.location - satirAralik.location))
        if komutAralik.length > 0, let komut = egikCizgiKomutu(ns.substring(with: komutAralik)) {
            // Düzenlemeyi bu geri çağrının içinde yapmamak için bir sonraki döngüye bırak.
            DispatchQueue.main.async { [weak self] in self?.komutuCalistir(komut, aralik: komutAralik) }
            return false
        }

        // Başlık satırının sonunda Enter'a basılınca yeni satır normal biçimde başlasın.
        if replacementString == "\n", metinGorunumu.typingAttributes[kBaslikSeviyesiAnahtari] != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var oznitelikler = self.metinGorunumu.typingAttributes
                oznitelikler.removeValue(forKey: kBaslikSeviyesiAnahtari)
                oznitelikler[.font] = varsayilanFont()
                self.metinGorunumu.typingAttributes = oznitelikler
            }
        }
        return true
    }

    private func komutuCalistir(_ komut: String, aralik: NSRange) {
        guard let metinDeposu = metinGorunumu.textStorage,
              NSMaxRange(aralik) <= metinDeposu.length else { return }

        // Önce komut metnini sil.
        if metinGorunumu.shouldChangeText(in: aralik, replacementString: "") {
            metinDeposu.replaceCharacters(in: aralik, with: "")
            metinGorunumu.didChangeText()
        }
        metinGorunumu.setSelectedRange(NSRange(location: aralik.location, length: 0))

        switch komut {
        case "/1": baslikSeviyesiUygula(1)
        case "/2": baslikSeviyesiUygula(2)
        case "/3": baslikSeviyesiUygula(3)
        case "/0": baslikSeviyesiUygula(0)
        case "/page", "/sayfa": altSayfaKomutu()
        default: break
        }
    }

    /// İmlecin bulunduğu paragrafı başlığa çevirir; seviye 0 normal metne döndürür.
    func baslikSeviyesiUygula(_ seviye: Int) {
        guard let metinDeposu = metinGorunumu.textStorage else { return }
        let ns = metinDeposu.string as NSString
        let paragrafAralik = ns.paragraphRange(for: metinGorunumu.selectedRange())

        if paragrafAralik.length > 0, metinGorunumu.shouldChangeText(in: paragrafAralik, replacementString: nil) {
            metinDeposu.beginEditing()
            if seviye > 0 {
                metinDeposu.addAttributes([.font: baslikFontu(seviye), kBaslikSeviyesiAnahtari: seviye], range: paragrafAralik)
            } else {
                metinDeposu.removeAttribute(kBaslikSeviyesiAnahtari, range: paragrafAralik)
                metinDeposu.addAttribute(.font, value: varsayilanFont(), range: paragrafAralik)
            }
            metinDeposu.endEditing()
            metinGorunumu.didChangeText()
        }

        // Boş satırda komut verildiyse yazılacak metin başlık biçiminde başlasın.
        var oznitelikler = metinGorunumu.typingAttributes
        oznitelikler[.font] = seviye > 0 ? baslikFontu(seviye) : varsayilanFont()
        if seviye > 0 {
            oznitelikler[kBaslikSeviyesiAnahtari] = seviye
        } else {
            oznitelikler.removeValue(forKey: kBaslikSeviyesiAnahtari)
        }
        metinGorunumu.typingAttributes = oznitelikler
        icerikDegisti()
        puntoGostergesiniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    /// "/page": açık sayfanın altına yeni bir sayfa oluşturup açar.
    private func altSayfaKomutu() {
        // Sayfanın altına dal açabilmek için önce kendisinin diskte olması gerekir.
        if mevcutDosyaURL == nil {
            duzenlendiMi = true
            otomatikKaydet()
        }
        guard let ustSayfa = mevcutDosyaURL else {
            // Henüz hiç içeriği olmayan, kaydedilmemiş bir sayfadayız: yeni sayfayı
            // kardeş olarak oluştur, komut sessizce kaybolmasın.
            yeniSayfaOlustur(klasor: kenarPaneli.hedefKlasor())
            return
        }
        yeniSayfaOlustur(klasor: sayfaKlasoru(ustSayfa))
    }

    // MARK: Geri al / Yinele

    @objc func geriAlKomutu(_ sender: Any?) { geriAl() }
    @objc func ileriAlKomutu(_ sender: Any?) { ileriAl() }

    func geriAl() {
        guard let yonetici = metinGorunumu.undoManager, yonetici.canUndo else { return }
        yonetici.undo()
        geriAlmaSonrasi()
    }

    func ileriAl() {
        guard let yonetici = metinGorunumu.undoManager, yonetici.canRedo else { return }
        yonetici.redo()
        geriAlmaSonrasi()
    }

    /// Geri/ileri alma metni değiştirir; kaydı ve göstergeleri tazeler, odağı metne verir.
    private func geriAlmaSonrasi() {
        icerikDegisti()
        gecmisDugmeleriniGuncelle()
        puntoGostergesiniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    func gecmisDugmeleriniGuncelle() {
        baslikCubugu.gecmisDurumunuGoster(geriAlinabilir: metinGorunumu.undoManager?.canUndo ?? false,
                                           ileriAlinabilir: metinGorunumu.undoManager?.canRedo ?? false)
    }

    /// Başka bir not açılırken geçmişi temizler; aksi halde ⌘Z önceki notun
    /// içeriğini şu anki notun üzerine geri getirebilir.
    func gecmisiSifirla() {
        metinGorunumu.undoManager?.removeAllActions()
        gecmisDugmeleriniGuncelle()
    }
}
