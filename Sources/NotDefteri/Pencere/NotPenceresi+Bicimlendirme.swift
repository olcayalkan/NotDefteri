import AppKit

// MARK: - NotPenceresi: Kalın, punto, tema

extension NotPenceresi {

    // MARK: Kalın yazı (Cmd+B)

    @objc func kalinKomutu(_ sender: Any?) { kalinYap() }

    private func kalinYap() {
        guard let textStorage = metinGorunumu.textStorage else { return }
        let secilen = metinGorunumu.selectedRange()

        if secilen.length == 0 {
            var oznitelikler = metinGorunumu.typingAttributes
            let mevcutFont = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            let kalinMi = NSFontManager.shared.traits(of: mevcutFont).contains(.boldFontMask)
            oznitelikler[.font] = kalinMi
                ? NSFontManager.shared.convert(mevcutFont, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(mevcutFont, toHaveTrait: .boldFontMask)
            metinGorunumu.typingAttributes = oznitelikler
            return
        }

        var tumuKalin = true
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, _, durdur in
            let font = (deger as? NSFont) ?? varsayilanFont()
            if !NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                tumuKalin = false
                durdur.pointee = true
            }
        }

        // shouldChangeText/didChangeText çifti, öznitelik değişikliğini geri alma
        // yığınına kaydeder ve textDidChange'i tetikler.
        guard metinGorunumu.shouldChangeText(in: secilen, replacementString: nil) else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, altAralik, _ in
            let font = (deger as? NSFont) ?? varsayilanFont()
            let yeniFont = tumuKalin
                ? NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: yeniFont, range: altAralik)
        }
        textStorage.endEditing()
        metinGorunumu.didChangeText()
    }

    // MARK: Punto (Cmd+* büyüt / Cmd+- küçült)

    @objc func yaziBuyutKomutu(_ sender: Any?) { yaziBoyutunuDegistir(fark: 1) }
    @objc func yaziKucultKomutu(_ sender: Any?) { yaziBoyutunuDegistir(fark: -1) }

    /// Seçili metnin puntosunu değiştirir. Seçim yoksa, bundan sonra yazılacak
    /// metnin (ve varsayılan) puntosu değişir.
    func yaziBoyutunuDegistir(fark: CGFloat) {
        guard let textStorage = metinGorunumu.textStorage else { return }
        let secilen = metinGorunumu.selectedRange()

        if secilen.length == 0 {
            var oznitelikler = metinGorunumu.typingAttributes
            let mevcutFont = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            let yeniBoyut = boyutSinirla(mevcutFont.pointSize + fark)
            guard yeniBoyut != mevcutFont.pointSize else { return }
            oznitelikler[.font] = fontUret(boyut: yeniBoyut, kalin: kalinMi(mevcutFont))
            metinGorunumu.typingAttributes = oznitelikler
            // Yalnızca imlecin o anki yazım puntosu; kalıcı DEĞİL (kayma olmasın).
            gYaziBoyutu = yeniBoyut
            puntoGostergesiniGuncelle()
            return
        }

        guard metinGorunumu.shouldChangeText(in: secilen, replacementString: nil) else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, altAralik, _ in
            let eskiFont = (deger as? NSFont) ?? varsayilanFont()
            let yeniBoyut = boyutSinirla(eskiFont.pointSize + fark)
            textStorage.addAttribute(.font, value: fontUret(boyut: yeniBoyut, kalin: kalinMi(eskiFont)), range: altAralik)
        }
        textStorage.endEditing()
        metinGorunumu.didChangeText()
        puntoGostergesiniGuncelle()
    }

    /// İmlecin/seçimin bulunduğu yerin puntosunu kenar paneldeki göstergeye yazar.
    func puntoGostergesiniGuncelle() {
        kenarPaneli.puntoyuGoster(mevcutPunto())
    }

    private func mevcutPunto() -> CGFloat {
        let secilen = metinGorunumu.selectedRange()
        if secilen.length > 0, let textStorage = metinGorunumu.textStorage,
           secilen.location < textStorage.length,
           let font = textStorage.attribute(.font, at: secilen.location, effectiveRange: nil) as? NSFont {
            return font.pointSize
        }
        return ((metinGorunumu.typingAttributes[.font] as? NSFont) ?? varsayilanFont()).pointSize
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        puntoGostergesiniGuncelle()
        icindekiler.etkinBasligiGuncelle(imlecKonumu: metinGorunumu.selectedRange().location)
    }

    // MARK: Tema (Görünüm menüsü)

    @objc func temaSecKomutu(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, temaListesi.indices.contains(index) else { return }
        gTemaIndex = index
        UserDefaults.standard.set(index, forKey: "temaIndex")
        temaUygulaTumUI()
    }

    private func temaUygulaTumUI() {
        backgroundColor = aktifTema.arkaplan
        icerikGorunum.layer?.backgroundColor = aktifTema.arkaplan.cgColor
        metinGorunumu.backgroundColor = aktifTema.arkaplan
        baslikCubugu.temayiUygula()
        kenarPaneli.temayiUygula()
        icindekiler.temayiUygula()
    }
}
