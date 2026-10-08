import AppKit
import NotDefteriCekirdek

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
        // Biçim yalnızca anlamsal anahtara yazılır; font ve renk adaptörde türetilir.
        let anahtar: NSAttributedString.Key
        switch bicim {
        case .kalin: anahtar = kKalinAnahtari
        case .italik: anahtar = kItalikAnahtari
        case .ustuCizili: anahtar = kUstuCiziliAnahtari
        case .kod: anahtar = kSatirIciKodAnahtari
        case .vurgu: anahtar = kVurguAnahtari
        }
        func etkin(_ oznitelikler: [NSAttributedString.Key: Any]) -> Bool {
            bicim == .kalin ? metinGorunumu.belgeAdaptoru.kalinMi(oznitelikler) : oznitelikler[anahtar] as? Bool == true
        }
        func degistir(_ eski: [NSAttributedString.Key: Any], ac: Bool) -> [NSAttributedString.Key: Any] {
            metinGorunumu.belgeAdaptoru.bicimiYaz(anahtar, etkin: ac, oznitelikler: eski)
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
           let url = depo.attribute(kBaglantiAnahtari, at: secim.location, effectiveRange: nil) {
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
        if let url, !metin.isEmpty { yeni.addAttribute(kBaglantiAnahtari, value: url, range: tumu) }
        else { yeni.removeAttribute(kBaglantiAnahtari, range: tumu) }
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
        let adaptor = metinGorunumu.belgeAdaptoru
        // Gövde puntosu anlamsala, başlığın geçici puntosu görünüm katmanına yazılır.
        func puntoyuYaz(_ oznitelikler: inout [NSAttributedString.Key: Any]) -> Bool {
            let eski = adaptor.punto(oznitelikler)
            let yeni = boyutSinirla(eski + fark)
            guard yeni != eski else { return false }
            adaptor.puntoyuYaz(yeni, oznitelikler: &oznitelikler)
            return true
        }

        if secilen.length == 0 {
            var oznitelikler = metinGorunumu.typingAttributes
            guard puntoyuYaz(&oznitelikler) else { return }
            metinGorunumu.typingAttributes = oznitelikler
            // Yalnızca imlecin o anki yazım puntosu; kalıcı DEĞİL (kayma olmasın).
            gYaziBoyutu = adaptor.punto(oznitelikler)
            puntoGostergesiniGuncelle()
            return
        }

        let yeni = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: secilen))
        var degisti = false
        yeni.enumerateAttributes(in: NSRange(location: 0, length: yeni.length)) { oznitelikler, altAralik, _ in
            var o = oznitelikler
            if puntoyuYaz(&o) { yeni.setAttributes(o, range: altAralik); degisti = true }
        }
        guard degisti else { return }
        metinGorunumu.blokDuzenle(secilen, yeni: yeni, secim: secilen, yazim: metinGorunumu.typingAttributes)
        metinGorunumu.undoManager?.setActionName("Yazı Boyutu")
        puntoGostergesiniGuncelle()
    }

    /// İmlecin/seçimin bulunduğu yerin puntosunu kenar paneldeki göstergeye yazar.
    func puntoGostergesiniGuncelle() {
        kenarPaneli.puntoyuGoster(mevcutPunto())
    }

    private func mevcutPunto() -> CGFloat {
        let secilen = metinGorunumu.selectedRange()
        if secilen.length > 0, let textStorage = metinGorunumu.textStorage, secilen.location < textStorage.length {
            return metinGorunumu.belgeAdaptoru.punto(textStorage.attributes(at: secilen.location, effectiveRange: nil))
        }
        return metinGorunumu.belgeAdaptoru.punto(metinGorunumu.typingAttributes)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        metinGorunumu.secimCubugunuGuncelle()
        puntoGostergesiniGuncelle()
        icindekiler.etkinBasligiGuncelle(imlecKonumu: metinGorunumu.selectedRange().location)
    }

    /// Kaydırırken etkin başlık imleci değil okunan bölümü izler: görünür alanın üst çeyreğindeki
    /// satırın başlığı. Sona gelindiyse son satır alınır ki son bölümün başlığı da etkin olabilsin.
    @objc func editorKaydirildi(_ bildirim: Notification) {
        guard let yerlesim = metinGorunumu.layoutManager, let kap = metinGorunumu.textContainer else { return }
        let gorunur = metinGorunumu.visibleRect
        let sonda = gorunur.maxY >= metinGorunumu.bounds.maxY - 1
        let y = sonda ? gorunur.maxY - 1 : gorunur.minY + min(80, gorunur.height * 0.25)
        let nokta = NSPoint(x: gorunur.minX - metinGorunumu.textContainerOrigin.x,
                            y: y - metinGorunumu.textContainerOrigin.y)
        let konum = yerlesim.characterIndex(for: nokta, in: kap, fractionOfDistanceBetweenInsertionPoints: nil)
        icindekiler.etkinBasligiGuncelle(imlecKonumu: konum)
    }

    // MARK: Tema (Görünüm menüsü)

    @objc func temaSecKomutu(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, temaListesi.indices.contains(index) else { return }
        gTemaIndex = index
        gAyarlar.set(index, forKey: "temaIndex")
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
