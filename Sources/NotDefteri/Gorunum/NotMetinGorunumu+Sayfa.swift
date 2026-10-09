import AppKit
import NotDefteriCekirdek

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

    /// Görünüm ölçeği yalnızca adaptörde durur; anlamsal punto ve kaynak Markdown değişmez.
    func sayfaYaziOlceginiUygula(kucuk: Bool) {
        kucukYazi = kucuk
        let olcek: CGFloat = kucuk ? 0.85 : 1
        guard belgeAdaptoru.olcek != olcek else { return }
        belgeAdaptoru.olcek = olcek
        belgeGorunumunuYenile()
    }

    /// Tema/ölçek yalnızca görünüm özniteliklerini değiştirir. Depo delegeleri
    /// bunu kullanıcı düzenlemesi sanıp tekrar biçimlendirmemeli.
    func belgeGorunumunuYenile() {
        if let depo = textStorage, !yaziOlcegiUygulaniyor {
            yaziOlcegiUygulaniyor = true
            depo.beginEditing()
            belgeAdaptoru.gorunumuUygula(depo, aralik: NSRange(location: 0, length: depo.length))
            depo.endEditing()
            yaziOlcegiUygulaniyor = false
        }
        yazimOlceginiGuncelle()
    }

    /// Yazım görünümü (ölçekli font) güncel anlamsaldan yeniden türetilir.
    func yazimOlceginiGuncelle() {
        typingAttributes = typingAttributes
    }
}
