import AppKit

extension NotMetinGorunumu {
    /// Sadece açılışta tüm metin alınır; yazarken gölge metindeki değişen paragraf sayılır.
    func kelimeSayisiniHazirla() {
        guard let depo = textStorage else { return }
        kelimeMetni.setString(kelimeMetniUret(depo, aralik: NSRange(location: 0, length: depo.length)))
        kelimeSayisi = kelimeleriSay(kelimeMetni as String)
        altBilgiDegisti?()
    }

    func kelimeSayisiniGuncelle(_ depo: NSTextStorage, aralik: NSRange, fark: Int) {
        let eskiUzunluk = aralik.length - fark
        guard eskiUzunluk >= 0, aralik.location <= kelimeMetni.length,
              aralik.location + eskiUzunluk <= kelimeMetni.length else { return }
        let eskiAralik = NSRange(location: aralik.location, length: eskiUzunluk)
        var paragraf = kelimeMetni.paragraphRange(for: eskiAralik)
        // Silinen satır sonu iki kelimeyi birleştirebilir; sınırdaki komşu da hesaba katılır.
        if NSMaxRange(eskiAralik) == NSMaxRange(paragraf), NSMaxRange(paragraf) < kelimeMetni.length {
            let sonraki = kelimeMetni.paragraphRange(for: NSRange(location: NSMaxRange(paragraf), length: 0))
            paragraf.length += sonraki.length
        }
        let eskiSayi = kelimeleriSay(kelimeMetni.substring(with: paragraf))
        kelimeMetni.replaceCharacters(in: eskiAralik, with: kelimeMetniUret(depo, aralik: aralik))
        let yeniParagraf = NSRange(location: paragraf.location, length: paragraf.length + fark)
        kelimeSayisi += kelimeleriSay(kelimeMetni.substring(with: yeniParagraf)) - eskiSayi
        altBilgiDegisti?()
    }

    private func kelimeMetniUret(_ depo: NSTextStorage, aralik: NSRange) -> String {
        let parca = NSMutableString(string: depo.mutableString.substring(with: aralik))
        depo.enumerateAttribute(kBlokIsaretiAnahtari, in: aralik) { deger, alt, _ in
            if deger as? Bool == true {
                parca.replaceCharacters(in: NSRange(location: alt.location - aralik.location, length: alt.length),
                                       with: String(repeating: " ", count: alt.length))
            }
        }
        return parca as String
    }

    func sayfaYaziOlceginiUygula(kucuk: Bool) {
        kucukYazi = kucuk
        if let depo = textStorage { yaziOlceginiUygula(depo, aralik: NSRange(location: 0, length: depo.length)) }
        yazimOlceginiGuncelle()
    }

    /// Görünüm ölçeği kayıt sırasında geri alınır; punto etiketleri ve kaynak Markdown değişmez.
    func yaziOlceginiUygula(_ depo: NSTextStorage, aralik: NSRange) {
        guard !yaziOlcegiUygulaniyor else { return }
        yaziOlcegiUygulaniyor = true
        defer { yaziOlcegiUygulaniyor = false }
        let hedef: CGFloat = kucukYazi ? 0.85 : 1
        depo.beginEditing()
        depo.enumerateAttributes(in: aralik) { oznitelikler, alt, _ in
            let eski = (oznitelikler[kSayfaYaziOlcegiAnahtari] as? CGFloat) ?? 1
            guard eski != hedef else { return }
            let font = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            depo.addAttributes([.font: NSFontManager.shared.convert(font, toSize: font.pointSize / eski * hedef),
                                kSayfaYaziOlcegiAnahtari: hedef], range: alt)
        }
        depo.endEditing()
    }

    func yazimOlceginiGuncelle() {
        var yazim = typingAttributes
        let eski = (yazim[kSayfaYaziOlcegiAnahtari] as? CGFloat) ?? 1
        let hedef: CGFloat = kucukYazi ? 0.85 : 1
        let font = (yazim[.font] as? NSFont) ?? varsayilanFont()
        yazim[.font] = NSFontManager.shared.convert(font, toSize: font.pointSize / eski * hedef)
        yazim[kSayfaYaziOlcegiAnahtari] = hedef
        typingAttributes = yazim
    }
}
