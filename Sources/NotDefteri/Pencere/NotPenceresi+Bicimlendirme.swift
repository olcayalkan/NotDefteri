import AppKit

// MARK: - NotPenceresi: Kalın, punto, tema

extension NotPenceresi {

    enum SatirIciBicim { case kalin, italik, ustuCizili, kod, vurgu }

    @objc func kalinKomutu(_ sender: Any?) { satirIciBicimiDegistir(.kalin) }
    @objc func italikKomutu(_ sender: Any?) { satirIciBicimiDegistir(.italik) }
    @objc func ustuCiziliKomutu(_ sender: Any?) { satirIciBicimiDegistir(.ustuCizili) }
    @objc func satirIciKodKomutu(_ sender: Any?) { satirIciBicimiDegistir(.kod) }
    @objc func vurguKomutu(_ sender: Any?) { satirIciBicimiDegistir(.vurgu) }

    private func satirIciBicimiDegistir(_ bicim: SatirIciBicim) {
        guard let depo = metinGorunumu.textStorage else { return }
        let secim = metinGorunumu.selectedRange()
        func etkin(_ oznitelikler: [NSAttributedString.Key: Any]) -> Bool {
            let font = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            switch bicim {
            case .kalin: return kalinMi(font)
            case .italik: return italikMi(font)
            case .ustuCizili: return oznitelikler[kUstuCiziliAnahtari] as? Bool == true
            case .kod: return oznitelikler[kSatirIciKodAnahtari] as? Bool == true
            case .vurgu: return oznitelikler[kVurguAnahtari] as? Bool == true
            }
        }
        func degistir(_ eski: [NSAttributedString.Key: Any], ac: Bool) -> [NSAttributedString.Key: Any] {
            var yeni = eski
            let font = (eski[.font] as? NSFont) ?? varsayilanFont()
            switch bicim {
            case .kalin, .italik:
                let ozellik: NSFontTraitMask = bicim == .kalin ? .boldFontMask : .italicFontMask
                yeni[.font] = ac ? NSFontManager.shared.convert(font, toHaveTrait: ozellik)
                    : NSFontManager.shared.convert(font, toNotHaveTrait: ozellik)
            case .ustuCizili:
                yeni[kUstuCiziliAnahtari] = ac ? true : nil
                let yapilacak = (eski[kMetinBloguAnahtari] as? MetinBlogu)?.tamamlandi == true
                yeni[.strikethroughStyle] = ac || yapilacak ? NSUnderlineStyle.single.rawValue : nil
            case .kod:
                yeni[kSatirIciKodAnahtari] = ac ? true : nil
                let temel = ac ? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
                    : NSFont.systemFont(ofSize: font.pointSize)
                yeni[.font] = NSFontManager.shared.convert(temel, toHaveTrait: NSFontManager.shared.traits(of: font).intersection([.boldFontMask, .italicFontMask]))
                yeni[.backgroundColor] = eski[kVurguAnahtari] as? Bool == true
                    ? NSColor.systemYellow.withAlphaComponent(0.3) : (ac ? kMetinRenk.withAlphaComponent(0.08) : nil)
            case .vurgu:
                yeni[kVurguAnahtari] = ac ? true : nil
                yeni[.backgroundColor] = ac ? NSColor.systemYellow.withAlphaComponent(0.3)
                    : (eski[kSatirIciKodAnahtari] as? Bool == true ? kMetinRenk.withAlphaComponent(0.08) : nil)
            }
            return yeni
        }
        if secim.length == 0 {
            metinGorunumu.typingAttributes = degistir(metinGorunumu.typingAttributes, ac: !etkin(metinGorunumu.typingAttributes))
            return
        }
        var tumuEtkin = true
        depo.enumerateAttributes(in: secim) { oznitelikler, _, durdur in
            if !etkin(oznitelikler) { tumuEtkin = false; durdur.pointee = true }
        }
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: secim))
        yeni.enumerateAttributes(in: NSRange(location: 0, length: yeni.length)) { oznitelikler, alt, _ in
            if oznitelikler[kBlokIsaretiAnahtari] as? Bool != true, oznitelikler[.attachment] == nil {
                yeni.setAttributes(degistir(oznitelikler, ac: !tumuEtkin), range: alt)
            }
        }
        metinGorunumu.blokDuzenle(secim, yeni: yeni, secim: secim, yazim: metinGorunumu.typingAttributes)
        metinGorunumu.secimCubugunuGuncelle()
    }

    @objc func baglantiKomutu(_ sender: Any?) {
        metinGorunumu.blokYaziminiGuncelle()
        let secim = metinGorunumu.selectedRange()
        let uyari = NSAlert()
        uyari.messageText = "Bağlantı"
        uyari.informativeText = "URL girin. Boş bırakırsanız bağlantı kaldırılır."
        uyari.addButton(withTitle: "Uygula")
        uyari.addButton(withTitle: "Vazgeç")
        let giris = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        giris.placeholderString = "https://…"
        if let depo = metinGorunumu.textStorage, secim.location < depo.length,
           let url = depo.attribute(.link, at: secim.location, effectiveRange: nil) {
            giris.stringValue = String(describing: url)
        }
        uyari.accessoryView = giris
        uyari.window.initialFirstResponder = giris
        metinGorunumu.yuzerGorunumleriGizle()
        guard uyari.runModal() == .alertFirstButtonReturn else { return }
        let metin = giris.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: metin)
        guard metin.isEmpty || url.map(disBaglantiGecerliMi) == true else { NSSound.beep(); return }
        guard let depo = metinGorunumu.textStorage, NSMaxRange(secim) <= depo.length else { return }
        let yeni = secim.length > 0
            ? NSMutableAttributedString(attributedString: depo.attributedSubstring(from: secim))
            : NSMutableAttributedString(string: metin, attributes: metinGorunumu.typingAttributes)
        let tumu = NSRange(location: 0, length: yeni.length)
        yeni.removeAttribute(kCiplakBagAnahtari, range: tumu)
        if let url, !metin.isEmpty { yeni.addAttribute(.link, value: url, range: tumu) }
        else { yeni.removeAttribute(.link, range: tumu) }
        metinGorunumu.blokDuzenle(secim, yeni: yeni,
                                  secim: NSRange(location: secim.location, length: yeni.length),
                                  yazim: metinGorunumu.typingAttributes)
        makeFirstResponder(metinGorunumu)
        metinGorunumu.secimCubugunuGuncelle()
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
            let olcek = (oznitelikler[kSayfaYaziOlcegiAnahtari] as? CGFloat) ?? 1
            let yeniBoyut = boyutSinirla(mevcutFont.pointSize / olcek + fark)
            guard yeniBoyut != mevcutFont.pointSize / olcek else { return }
            oznitelikler[.font] = NSFontManager.shared.convert(mevcutFont, toSize: yeniBoyut * olcek)
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
            let olcek = (textStorage.attribute(kSayfaYaziOlcegiAnahtari, at: altAralik.location, effectiveRange: nil) as? CGFloat) ?? 1
            let yeniBoyut = boyutSinirla(eskiFont.pointSize / olcek + fark)
            textStorage.addAttribute(.font, value: NSFontManager.shared.convert(eskiFont, toSize: yeniBoyut * olcek), range: altAralik)
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
            return font.pointSize / ((textStorage.attribute(kSayfaYaziOlcegiAnahtari, at: secilen.location, effectiveRange: nil) as? CGFloat) ?? 1)
        }
        return ((metinGorunumu.typingAttributes[.font] as? NSFont) ?? varsayilanFont()).pointSize
            / ((metinGorunumu.typingAttributes[kSayfaYaziOlcegiAnahtari] as? CGFloat) ?? 1)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        metinGorunumu.secimCubugunuGuncelle()
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
        anaSayfa.temayiUygula()
        icindekiler.temayiUygula()
        metinGorunumu.blokMenusunuGuncelle()
        metinGorunumu.secimCubugunuGuncelle()
    }
}
