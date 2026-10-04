import AppKit

extension NotMetinGorunumu: NSTextStorageDelegate {
    func textStorage(_ textStorage: NSTextStorage, willProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        if !sayfaYukleniyor, !baglarGuncelleniyor, !yaziOlcegiUygulaniyor {
            baglarGuncelleniyor = true
            uyariSinirlariniGuncelle(textStorage, aralik: editedRange)
            baglarGuncelleniyor = false
            kelimeSayisiniGuncelle(textStorage, aralik: editedRange, fark: delta)
            yaziOlceginiUygula(textStorage, aralik: editedRange)
        }
        guard !sayfaYukleniyor, !baglarGuncelleniyor, textStorage.length > 0 else { return }
        baglarGuncelleniyor = true
        defer { baglarGuncelleniyor = false }
        let sinirli = NSIntersectionRange(editedRange, NSRange(location: 0, length: textStorage.length))
        let paragraf = textStorage.mutableString.paragraphRange(for: sinirli)
        // Depo kopyalanmaz; yalnızca düzenlenen paragraf/çoklu yapıştırma aralığı okunur.
        textStorage.removeAttribute(kSayfaBagiAnahtari, range: paragraf)
        let metin = textStorage.mutableString.substring(with: paragraf)
        for bag in sayfaBaglariniBul(metin) {
            let aralik = NSRange(location: paragraf.location + bag.aralik.location, length: bag.aralik.length)
            var kodVeyaBag = false
            textStorage.enumerateAttributes(in: aralik) { oznitelikler, _, durdur in
                if oznitelikler[kKodBloguAnahtari] != nil || oznitelikler[kSatirIciKodAnahtari] != nil || oznitelikler[.link] != nil || oznitelikler[kKacisliKoseParantezAnahtari] != nil {
                    kodVeyaBag = true; durdur.pointee = true
                }
            }
            if !kodVeyaBag { textStorage.addAttribute(kSayfaBagiAnahtari, value: bag.hedef, range: aralik) }
        }
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard !sayfaYukleniyor, !baglarGuncelleniyor, textStorage.length > 0 else { return }
        let sinirli = NSIntersectionRange(editedRange, NSRange(location: 0, length: textStorage.length))
        sayfaBaglariniBoya(aralik: textStorage.mutableString.paragraphRange(for: sinirli))
    }

    /// Görsel renkler geçicidir; Markdown kaynağı, fontlar ve undo öznitelikleri değişmez.
    func sayfaBaglariniBoya(aralik: NSRange? = nil) {
        guard let depo = textStorage, let yerlesim = layoutManager else { return }
        let aralik = aralik ?? NSRange(location: 0, length: depo.length)
        yerlesim.removeTemporaryAttribute(.foregroundColor, forCharacterRange: aralik)
        yerlesim.removeTemporaryAttribute(.underlineStyle, forCharacterRange: aralik)
        let baglantilar = (window as? NotPenceresi)?.kenarPaneli.sayfaBaglantilari
        depo.enumerateAttribute(kSayfaBagiAnahtari, in: aralik) { deger, alt, _ in
            guard let hedef = deger as? String else { return }
            let renk = NSColor.systemBlue.withAlphaComponent(baglantilar?.coz(hedef) == nil ? 0.35 : 1)
            yerlesim.addTemporaryAttributes([.foregroundColor: renk, .underlineStyle: NSUnderlineStyle.single.rawValue],
                                            forCharacterRange: alt)
        }
    }

    func sayfaBagYaziminiTemizle() {
        typingAttributes.removeValue(forKey: kSayfaBagiAnahtari)
        typingAttributes.removeValue(forKey: kKacisliKoseParantezAnahtari)
    }

    func sayfaBulucusunuGuncelle() {
        guard let depo = textStorage, let pencere = window as? NotPenceresi, pencere.isKeyWindow,
              pencere.firstResponder === self, selectedRange().length == 0, !hasMarkedText() else {
            sayfaBulucusu.gizle(); bagTamamlamaAraligi = nil; return
        }
        let imlec = selectedRange().location
        let ns = depo.mutableString
        let paragraf = ns.paragraphRange(for: NSRange(location: imlec, length: 0))
        let kapsam = NSRange(location: paragraf.location, length: imlec - paragraf.location)
        let bas = ns.range(of: "[[", options: .backwards, range: kapsam)
        guard bas.location != NSNotFound, bas.location != kapatilanBagKonumu,
              depo.attribute(kKodBloguAnahtari, at: bas.location, effectiveRange: nil) == nil,
              depo.attribute(kSatirIciKodAnahtari, at: bas.location, effectiveRange: nil) == nil,
              depo.attribute(.link, at: bas.location, effectiveRange: nil) == nil,
              depo.attribute(kKacisliKoseParantezAnahtari, at: bas.location, effectiveRange: nil) == nil,
              depo.attribute(kKacisliKoseParantezAnahtari, at: bas.location + 1, effectiveRange: nil) == nil else {
            sayfaBulucusu.gizle(); bagTamamlamaAraligi = nil; return
        }
        var kacis = bas.location
        while kacis > paragraf.location, ns.character(at: kacis - 1) == 92 { kacis -= 1 }
        let sorgu = ns.substring(with: NSRange(location: bas.location + 2, length: imlec - bas.location - 2))
        guard (bas.location - kacis) % 2 == 0, !sorgu.contains("]"), !sorgu.contains("[") else {
            sayfaBulucusu.gizle(); bagTamamlamaAraligi = nil; return
        }
        blokMenusu.gizle()
        bagTamamlamaAraligi = NSRange(location: bas.location, length: imlec - bas.location)
        sayfaBulucusu.ara = { [weak pencere] in pencere?.kenarPaneli.sayfaBaglantilari.ara($0) ?? [] }
        sayfaBulucusu.secildi = { [weak self, weak pencere] sayfa in
            guard let self, let pencere, var aralik = self.bagTamamlamaAraligi,
                  let depo = self.textStorage else { return }
            // İmlecin hemen sağındaki mevcut kapanış iki kez yazılmasın.
            if NSMaxRange(aralik) + 2 <= depo.length,
               depo.mutableString.substring(with: NSRange(location: NSMaxRange(aralik), length: 2)) == "]]" { aralik.length += 2 }
            self.bagTamamlamaAraligi = nil
            self.kapatilanBagKonumu = aralik.location
            self.blokYaziminiGuncelle()
            self.sayfaBagYaziminiTemizle()
            let metin = "[[\(pencere.kenarPaneli.sayfaBaglantilari.bagMetni(sayfa.url))]]"
            let yeni = NSAttributedString(string: metin, attributes: self.typingAttributes)
            self.blokDuzenle(aralik, yeni: yeni,
                             secim: NSRange(location: aralik.location + yeni.length, length: 0), yazim: self.typingAttributes)
            self.undoManager?.setActionName("Sayfa Bağlantısı")
        }
        let kare = imlecEkranKaresi(imlec)
        let yerel = convert(pencere.convertFromScreen(kare), from: nil)
        guard visibleRect.intersects(yerel) else { sayfaBulucusu.gizle(); return }
        sayfaBulucusu.gosterSatirIci(kare, pencere: pencere, sorgu: sorgu)
    }

    func sayfaBaginiTikla(noktada nokta: NSPoint) -> Bool {
        guard let depo = textStorage, let yerlesim = layoutManager, let kapsayici = textContainer else { return false }
        let yerel = NSPoint(x: nokta.x - textContainerOrigin.x, y: nokta.y - textContainerOrigin.y)
        let glif = yerlesim.glyphIndex(for: yerel, in: kapsayici)
        guard glif < yerlesim.numberOfGlyphs,
              yerlesim.boundingRect(forGlyphRange: NSRange(location: glif, length: 1), in: kapsayici).contains(yerel) else { return false }
        let konum = yerlesim.characterIndexForGlyph(at: glif)
        guard konum < depo.length, let hedef = depo.attribute(kSayfaBagiAnahtari, at: konum, effectiveRange: nil) as? String else { return false }
        (window as? NotPenceresi)?.sayfaBaginiAc(hedef)
        return true
    }

    /// Açık not, kendi undo yoluyla aralık aralık güncellenir; geçmiş sıfırlanmaz.
    func sayfaBaglariniYenidenYaz(_ hedefler: [String: String]) {
        guard let depo = textStorage else { return }
        var degisiklikler: [(NSRange, String)] = []
        depo.enumerateAttribute(kSayfaBagiAnahtari, in: NSRange(location: 0, length: depo.length)) { deger, aralik, _ in
            guard let hedef = deger as? String, let yeni = hedefler[hedef.trimmingCharacters(in: .whitespaces)] else { return }
            // Yan yana aynı hedefli bağlar tek öznitelik aralığında birleşebilir.
            for bag in sayfaBaglariniBul(depo.mutableString.substring(with: aralik)) {
                degisiklikler.append((NSRange(location: aralik.location + bag.aralik.location, length: bag.aralik.length), "[[\(yeni)]]"))
            }
        }
        guard !degisiklikler.isEmpty else { return }
        breakUndoCoalescing()
        undoManager?.beginUndoGrouping()
        for (aralik, metin) in degisiklikler.reversed() {
            var secim = selectedRange()
            let fark = (metin as NSString).length - aralik.length
            if secim.location >= NSMaxRange(aralik) { secim.location += fark }
            else if NSMaxRange(secim) > aralik.location { secim = NSRange(location: aralik.location + (metin as NSString).length, length: 0) }
            var oznitelikler = depo.attributes(at: aralik.location, effectiveRange: nil)
            oznitelikler.removeValue(forKey: kSayfaBagiAnahtari)
            let yeni = NSAttributedString(string: metin, attributes: oznitelikler)
            blokDuzenle(aralik, yeni: yeni, secim: secim, yazim: typingAttributes)
        }
        undoManager?.endUndoGrouping()
        undoManager?.setActionName("Sayfa Bağlantılarını Güncelle")
        sayfaBagYaziminiTemizle()
    }
}
