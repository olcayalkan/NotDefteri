import AppKit

extension NotMetinGorunumu {
    func paragrafAraligi() -> NSRange {
        guard let depo = textStorage else { return selectedRange() }
        return depo.mutableString.paragraphRange(for: selectedRange())
    }

    func blok(_ aralik: NSRange) -> MetinBlogu? {
        guard let depo = textStorage, aralik.location < depo.length else { return nil }
        return depo.attribute(kMetinBloguAnahtari, at: aralik.location, effectiveRange: nil) as? MetinBlogu
    }

    /// Yazım, görünüm işaretinin özniteliğini devralırsa kullanıcı metni kayıt dışında kalır.
    func blokYaziminiGuncelle() {
        guard let depo = textStorage else { return }
        var oznitelikler = typingAttributes
        let oncekiBlok = oznitelikler[kMetinBloguAnahtari] as? MetinBlogu
        oznitelikler.removeValue(forKey: kBlokIsaretiAnahtari)
        oznitelikler.removeValue(forKey: kBosKodSatiriAnahtari)
        // NSString deposu, her tuşta tüm belgeyi Swift String'e kopyalamayı önler.
        let aralik = depo.mutableString.paragraphRange(for: NSRange(location: selectedRange().location, length: 0))
        if let blok = blok(aralik) {
            oznitelikler.merge(blok.oznitelikler) { _, yeni in yeni }
            if oznitelikler[kUstuCiziliAnahtari] == nil { oznitelikler.removeValue(forKey: .strikethroughStyle) }
            oznitelikler[.foregroundColor] = kMetinRenk
            if blok.tur == .yapilacak, blok.tamamlandi {
                oznitelikler[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                oznitelikler[.foregroundColor] = kMetinRenk.withAlphaComponent(0.45)
            }
        } else {
            oznitelikler.removeValue(forKey: kMetinBloguAnahtari)
            oznitelikler.removeValue(forKey: kUyariKutusuAnahtari)
            if oncekiBlok != nil {
                oznitelikler.removeValue(forKey: .paragraphStyle)
                if oznitelikler[kUstuCiziliAnahtari] == nil { oznitelikler.removeValue(forKey: .strikethroughStyle) }
                oznitelikler[.foregroundColor] = kMetinRenk
            }
        }
        let baslik = aralik.location < depo.length
            ? depo.attribute(kBaslikSeviyesiAnahtari, at: aralik.location, effectiveRange: nil) as? Int : nil
        if let baslik {
            oznitelikler[kBaslikSeviyesiAnahtari] = baslik
        } else if oznitelikler[kBaslikSeviyesiAnahtari] != nil {
            oznitelikler.removeValue(forKey: kBaslikSeviyesiAnahtari)
            oznitelikler[.font] = varsayilanFont()
            oznitelikler.removeValue(forKey: kSayfaYaziOlcegiAnahtari)
        }
        let kod = aralik.location < depo.length
            ? depo.attribute(kKodBloguAnahtari, at: aralik.location, effectiveRange: nil) : nil
        if let kod {
            oznitelikler[kKodBloguAnahtari] = kod
            let font = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            oznitelikler[.font] = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            oznitelikler[.backgroundColor] = kMetinRenk.withAlphaComponent(0.08)
        } else if aralik.location < depo.length, oznitelikler[kKodBloguAnahtari] != nil {
            oznitelikler.removeValue(forKey: kKodBloguAnahtari)
            oznitelikler[.font] = varsayilanFont()
            oznitelikler.removeValue(forKey: kSayfaYaziOlcegiAnahtari)
            if oznitelikler[kVurguAnahtari] == nil, oznitelikler[kSatirIciKodAnahtari] == nil {
                oznitelikler.removeValue(forKey: .backgroundColor)
            }
        }
        typingAttributes = oznitelikler
        if selectedRange().length == 0, aralik.length > 0 {
            let isaret = blokIsaretiUzunlugu(depo, konum: aralik.location)
            if selectedRange().location < aralik.location + isaret {
                setSelectedRange(NSRange(location: aralik.location + isaret, length: 0))
                typingAttributes = oznitelikler
            }
        }
        yazimOlceginiGuncelle()
    }

    private var duzYazim: [NSAttributedString.Key: Any] {
        [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
    }

    /// Yalnızca yapısal değişimde komşu liste taranır; normal yazım bu yola girmez.
    private func listeAraliginiGenislet(_ aralik: NSRange) -> NSRange {
        guard let depo = textStorage else { return aralik }
        let ns = depo.mutableString
        var bas = aralik.location
        var son = NSMaxRange(aralik)
        while bas > 0 {
            let onceki = ns.paragraphRange(for: NSRange(location: bas - 1, length: 0))
            guard blok(onceki)?.listeMi == true else { break }
            bas = onceki.location
        }
        while son < ns.length {
            let sonraki = ns.paragraphRange(for: NSRange(location: son, length: 0))
            guard blok(sonraki)?.listeMi == true, sonraki.length > 0 else { break }
            son = NSMaxRange(sonraki)
        }
        return NSRange(location: bas, length: son - bas)
    }

    /// Metin, öznitelik, seçim ve yazım biçimi tek geri alma kaydıdır.
    func blokDuzenle(_ aralik: NSRange, yeni: NSAttributedString, secim: NSRange,
                             yazim: [NSAttributedString.Key: Any], numarala: Bool = false,
                             geriMetin: NSAttributedString? = nil, geriSecim: NSRange? = nil) {
        guard let depo = textStorage, NSMaxRange(aralik) <= depo.length else { return }
        let kapsam = numarala ? listeAraliginiGenislet(aralik) : aralik
        let eski = depo.attributedSubstring(from: kapsam)
        let eklenecek = NSMutableAttributedString(attributedString: eski)
        let yerel = NSRange(location: aralik.location - kapsam.location, length: aralik.length)
        eklenecek.replaceCharacters(in: yerel, with: yeni)
        var yeniSecim = NSRange(location: secim.location - kapsam.location, length: secim.length)
        if numarala { blokNumaralariniGuncelle(eklenecek, secim: &yeniSecim) }
        yeniSecim.location += kapsam.location
        let geri = NSMutableAttributedString(attributedString: eski)
        if let geriMetin { geri.replaceCharacters(in: yerel, with: geriMetin) }
        let eskiSecim = geriSecim ?? selectedRange()
        let eskiYazim = typingAttributes
        let yonetici = undoManager
        if yonetici?.isUndoing != true && yonetici?.isRedoing != true { breakUndoCoalescing() }
        yonetici?.disableUndoRegistration()
        blokDuzenleniyor = true
        let izin = shouldChangeText(in: kapsam, replacementString: eklenecek.string)
        if izin {
            depo.beginEditing()
            depo.replaceCharacters(in: kapsam, with: eklenecek)
            depo.endEditing()
            setSelectedRange(yeniSecim)
            typingAttributes = yazim
        }
        blokDuzenleniyor = false
        yonetici?.enableUndoRegistration()
        guard izin else { return }
        yonetici?.registerUndo(withTarget: self) { gorunum in
            gorunum.blokDuzenle(NSRange(location: kapsam.location, length: eklenecek.length),
                                yeni: geri, secim: eskiSecim, yazim: eskiYazim)
        }
        yonetici?.setActionName("Blok Biçimi")
        didChangeText()
        needsDisplay = true
    }

    func blokKisayolunuUygula(_ tamamlayici: String) -> Bool {
        guard isEditable, !blokDuzenleniyor, selectedRange().length == 0, let depo = textStorage else { return false }
        let paragraf = paragrafAraligi()
        guard blok(paragraf) == nil, typingAttributes[kKodBloguAnahtari] == nil, typingAttributes[kSatirIciKodAnahtari] == nil else { return false }
        let secim = selectedRange()
        let onEk = depo.mutableString.substring(with: NSRange(location: paragraf.location, length: secim.location - paragraf.location))
        let seviye = ["#": 1, "##": 2, "###": 3][onEk]
        let cozum = metinBlogunuCozumle(onEk + (tamamlayici == " " ? " " : ""))
        if tamamlayici == "\n" {
            guard cozum?.blok.tur == .ayirici,
                  depo.mutableString.substring(with: paragraf).trimmingCharacters(in: .newlines) == onEk else { return false }
        } else {
            guard seviye != nil || (cozum != nil && cozum!.uzunluk == (onEk as NSString).length + 1 && cozum!.blok.tur != .ayirici) else { return false }
        }
        blokTamamlayicisiniYaz(tamamlayici)
        guard selectedRange().location == secim.location + 1, selectedRange().length == 0 else { return true }
        if let seviye {
            baslikUygula(seviye, komutAraligi: NSRange(location: paragraf.location, length: (onEk as NSString).length + 1))
            return true
        }
        let tamamlanmisParagraf = NSRange(location: paragraf.location, length: paragraf.length + 1)
        let geri = depo.attributedSubstring(from: tamamlanmisParagraf)
        let yeni = NSMutableAttributedString(attributedString: geri)
        yeni.deleteCharacters(in: NSRange(location: 0, length: (onEk as NSString).length + (tamamlayici == " " ? 1 : 0)))
        var yazim = duzYazim
        var blok = cozum!.blok
        blok.kaynakOnEk = nil
        let isaret = blokIsaretiniUret(blok)
        blokBiciminiUygula(blok, metne: yeni, aralik: NSRange(location: 0, length: yeni.length))
        if blok.tur != .ayirici { yazim.merge(blok.oznitelikler) { _, yeni in yeni } }
        yeni.insert(isaret, at: 0)
        blokDuzenle(tamamlanmisParagraf, yeni: yeni,
                    secim: NSRange(location: paragraf.location + isaret.length + (tamamlayici == "\n" ? 1 : 0), length: 0),
                    yazim: yazim, numarala: cozum?.blok.listeMi == true)
        return true
    }

    func baslikUygula(_ seviye: Int, komutAraligi: NSRange? = nil, tamamlayici: String? = nil) {
        guard let depo = textStorage else { return }
        let paragraf = paragrafAraligi()
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: paragraf))
        var geriMetin: NSMutableAttributedString?
        var geriSecim: NSRange?
        var secim = selectedRange()
        if let komutAraligi {
            if let tamamlayici {
                geriMetin = NSMutableAttributedString(attributedString: yeni)
                geriMetin?.insert(NSAttributedString(string: tamamlayici, attributes: duzYazim),
                                  at: NSMaxRange(komutAraligi) - paragraf.location)
                geriSecim = NSRange(location: NSMaxRange(komutAraligi) + (tamamlayici as NSString).length, length: 0)
            }
            yeni.deleteCharacters(in: NSRange(location: komutAraligi.location - paragraf.location, length: komutAraligi.length))
            secim = NSRange(location: komutAraligi.location, length: 0)
        }
        var isaretler: [NSRange] = []
        yeni.enumerateAttribute(kBlokIsaretiAnahtari, in: NSRange(location: 0, length: yeni.length)) { deger, aralik, _ in
            if deger as? Bool == true { isaretler.append(aralik) }
        }
        for aralik in isaretler.reversed() {
            yeni.deleteCharacters(in: aralik)
            let bas = paragraf.location + aralik.location
            let son = bas + aralik.length
            func yeniKonum(_ konum: Int) -> Int { konum >= son ? konum - aralik.length : max(bas, konum) }
            let yeniBas = secim.location < bas ? secim.location : yeniKonum(secim.location)
            let yeniSon = NSMaxRange(secim) < bas ? NSMaxRange(secim) : yeniKonum(NSMaxRange(secim))
            secim = NSRange(location: yeniBas, length: yeniSon - yeniBas)
        }
        secim.length = min(secim.length, max(0, paragraf.location + yeni.length - secim.location))
        blokBiciminiKaldir(yeni)
        yeni.removeAttribute(kKodBloguAnahtari, range: NSRange(location: 0, length: yeni.length))
        yeni.removeAttribute(kSayfaYaziOlcegiAnahtari, range: NSRange(location: 0, length: yeni.length))
        var yazim = duzYazim
        if seviye > 0 {
            yazim[.font] = baslikFontu(seviye)
            yazim[kBaslikSeviyesiAnahtari] = seviye
            if yeni.length == 0 {
                var isaretOznitelikleri = yazim
                isaretOznitelikleri[kBlokIsaretiAnahtari] = true
                yeni.append(NSAttributedString(string: "\u{200B}", attributes: isaretOznitelikleri))
                secim.location += 1
            }
            yeni.addAttributes(yazim, range: NSRange(location: 0, length: yeni.length))
        } else {
            yeni.removeAttribute(kBaslikSeviyesiAnahtari, range: NSRange(location: 0, length: yeni.length))
            yeni.addAttribute(.font, value: varsayilanFont(), range: NSRange(location: 0, length: yeni.length))
        }
        blokDuzenle(paragraf, yeni: yeni, secim: secim, yazim: yazim, numarala: blok(paragraf)?.listeMi == true,
                    geriMetin: geriMetin, geriSecim: geriSecim)
    }

    func bloktaYeniSatir() -> Bool {
        guard let depo = textStorage else { return false }
        let paragraf = paragrafAraligi()
        let secim = selectedRange()
        let eski = depo.attributedSubstring(from: paragraf)
        if typingAttributes[kKodBloguAnahtari] != nil,
           eski.string.replacingOccurrences(of: "\u{200B}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blokDuzenle(paragraf, yeni: NSAttributedString(string: "\n", attributes: duzYazim),
                        secim: NSRange(location: paragraf.location + 1, length: 0), yazim: duzYazim)
            return true
        }
        let baslik = eski.length > 0 ? eski.attribute(kBaslikSeviyesiAnahtari, at: 0, effectiveRange: nil) as? Int : nil
        if baslik != nil || blok(paragraf)?.tur == .ayirici {
            let yeni = NSMutableAttributedString(attributedString: eski)
            let yerel = NSRange(location: secim.location - paragraf.location, length: secim.length)
            yeni.replaceCharacters(in: yerel, with: NSAttributedString(string: "\n", attributes: typingAttributes))
            let alt = NSRange(location: yerel.location + 1, length: yeni.length - yerel.location - 1)
            yeni.removeAttribute(kBaslikSeviyesiAnahtari, range: alt)
            yeni.removeAttribute(kBlokIsaretiAnahtari, range: alt)
            yeni.removeAttribute(kMetinBloguAnahtari, range: alt)
            yeni.removeAttribute(kUyariKutusuAnahtari, range: alt)
            yeni.removeAttribute(.paragraphStyle, range: alt)
            yeni.removeAttribute(kSayfaYaziOlcegiAnahtari, range: alt)
            yeni.addAttribute(.font, value: varsayilanFont(), range: alt)
            blokDuzenle(paragraf, yeni: yeni, secim: NSRange(location: secim.location + 1, length: 0), yazim: duzYazim)
            return true
        }
        guard var blok = blok(paragraf) else { return false }
        let isaret = blokIsaretiUzunlugu(eski)
        let govde = (eski.string as NSString).substring(from: isaret).trimmingCharacters(in: .whitespacesAndNewlines)
        if govde.isEmpty {
            let yeni = NSMutableAttributedString(attributedString: eski)
            yeni.deleteCharacters(in: NSRange(location: 0, length: isaret))
            blokBiciminiKaldir(yeni)
            if blok.tur == .uyari, !yeni.string.hasSuffix("\n") {
                yeni.append(NSAttributedString(string: "\n", attributes: duzYazim))
            }
            blokDuzenle(paragraf, yeni: yeni, secim: NSRange(location: paragraf.location, length: 0),
                        yazim: duzYazim, numarala: blok.listeMi)
            return true
        }
        let yeni = NSMutableAttributedString(attributedString: eski)
        let bas = max(isaret, secim.location - paragraf.location)
        let son = max(bas, NSMaxRange(secim) - paragraf.location)
        let yerel = NSRange(location: bas, length: son - bas)
        yeni.replaceCharacters(in: yerel, with: NSAttributedString(string: "\n", attributes: typingAttributes))
        blok.tamamlandi = false
        blok.kaynakOnEk = nil
        if blok.tur == .uyari { blok.devam = true }
        if blok.tur == .numarali { blok.numara = blok.numara == Int.max ? 1 : blok.numara + 1 }
        let yeniIsaret = blokIsaretiniUret(blok)
        let altBaslangic = yerel.location + 1
        yeni.insert(yeniIsaret, at: altBaslangic)
        let alt = NSRange(location: altBaslangic, length: yeni.length - altBaslangic)
        blokBiciminiUygula(blok, metne: yeni, aralik: alt)
        var yazim = typingAttributes
        yazim.removeValue(forKey: kBlokIsaretiAnahtari)
        yazim.removeValue(forKey: .strikethroughStyle)
        yazim[.foregroundColor] = kMetinRenk
        yazim.merge(blok.oznitelikler) { _, yeni in yeni }
        blokDuzenle(paragraf, yeni: yeni,
                    secim: NSRange(location: paragraf.location + altBaslangic + yeniIsaret.length, length: 0),
                    yazim: yazim, numarala: blok.listeMi)
        return true
    }

    func blokGirintisiniDegistir(_ fark: Int) -> Bool {
        guard let depo = textStorage else { return false }
        let paragraf = paragrafAraligi()
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: paragraf))
        var konum = 0
        var degisti = false
        var numarala = false
        var yazim = typingAttributes
        while konum < yeni.length {
            let alt = (yeni.string as NSString).paragraphRange(for: NSRange(location: konum, length: 0))
            if var blok = yeni.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil) as? MetinBlogu,
               blok.tur != .ayirici, blok.tur != .uyari {
                blok.seviye = max(0, blok.seviye + fark)
                blok.kaynakOnEk = nil
                blokBiciminiUygula(blok, metne: yeni, aralik: alt)
                degisti = true
                numarala = numarala || blok.listeMi
                if konum == 0 { yazim.merge(blok.oznitelikler) { _, yeni in yeni } }
            }
            konum = NSMaxRange(alt)
        }
        guard degisti else { return false }
        blokDuzenle(paragraf, yeni: yeni, secim: selectedRange(), yazim: yazim, numarala: numarala)
        return true
    }

    func satirBasindaBicimiKaldir() -> Bool {
        guard selectedRange().length == 0, let depo = textStorage else { return false }
        let paragraf = paragrafAraligi()
        let eski = depo.attributedSubstring(from: paragraf)
        guard selectedRange().location <= paragraf.location + blokIsaretiUzunlugu(eski) else { return false }
        if eski.length > 0, eski.attribute(kBaslikSeviyesiAnahtari, at: 0, effectiveRange: nil) != nil {
            baslikUygula(0)
            return true
        }
        guard let blok = blok(paragraf) else { return false }
        let yeni = NSMutableAttributedString(attributedString: eski)
        yeni.deleteCharacters(in: NSRange(location: 0, length: blokIsaretiUzunlugu(eski)))
        blokBiciminiKaldir(yeni)
        blokDuzenle(paragraf, yeni: yeni, secim: NSRange(location: paragraf.location, length: 0),
                    yazim: duzYazim, numarala: blok.listeMi)
        return true
    }

    func yapilacakKutusunuDegistir(noktada nokta: NSPoint) -> Bool {
        guard isEditable, let depo = textStorage else { return false }
        let konum = characterIndexForInsertion(at: nokta)
        let paragraf = depo.mutableString.paragraphRange(for: NSRange(location: min(konum, depo.length), length: 0))
        guard var blok = blok(paragraf), blok.tur == .yapilacak else { return false }
        guard let kare = guvenliKare(karakter: NSRange(location: paragraf.location, length: 1))?
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y).insetBy(dx: -3, dy: -2),
              kare.contains(nokta) else { return false }
        blok.tamamlandi.toggle()
        blok.kaynakOnEk = nil
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: paragraf))
        yeni.replaceCharacters(in: NSRange(location: 0, length: blokIsaretiUzunlugu(yeni)), with: blokIsaretiniUret(blok))
        blokBiciminiUygula(blok, metne: yeni, aralik: NSRange(location: 0, length: yeni.length))
        var yazim = typingAttributes
        if selectedRange().location >= paragraf.location, selectedRange().location < NSMaxRange(paragraf) {
            yazim.merge(blok.oznitelikler) { _, yeni in yeni }
            yazim[.foregroundColor] = blok.tamamlandi ? kMetinRenk.withAlphaComponent(0.45) : kMetinRenk
            yazim[.strikethroughStyle] = blok.tamamlandi ? NSUnderlineStyle.single.rawValue : nil
        }
        blokDuzenle(paragraf, yeni: yeni, secim: selectedRange(), yazim: yazim)
        return true
    }

    func blokCizgileriniCiz(_ kirliAlan: NSRect) {
        guard let depo = textStorage, let yerlesim = layoutManager, let kapsayici = textContainer else { return }
        let alan = kirliAlan.intersection(visibleRect).offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let glifler = yerlesim.glyphRange(forBoundingRect: alan, in: kapsayici)
        let karakterler = yerlesim.characterRange(forGlyphRange: glifler, actualGlyphRange: nil)
        var sonParagraf = -1
        depo.enumerateAttribute(kMetinBloguAnahtari, in: karakterler) { deger, aralik, _ in
            guard let blok = deger as? MetinBlogu, blok.tur == .alinti || blok.tur == .ayirici else { return }
            var konum = aralik.location
            while konum < NSMaxRange(aralik) {
                let paragraf = depo.mutableString.paragraphRange(for: NSRange(location: konum, length: 0))
                if paragraf.location != sonParagraf {
                    sonParagraf = paragraf.location
                    guard let kare = guvenliKare(karakter: paragraf)?
                        .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y) else { konum = NSMaxRange(paragraf); continue }
                    let cizgi = NSBezierPath()
                    kMetinRenk.withAlphaComponent(0.3).setStroke()
                    cizgi.lineWidth = blok.tur == .alinti ? 2 : 1
                    let x = textContainerOrigin.x + kapsayici.lineFragmentPadding + CGFloat(blok.seviye) * 24
                    if blok.tur == .alinti {
                        cizgi.move(to: NSPoint(x: x + 8, y: kare.minY))
                        cizgi.line(to: NSPoint(x: x + 8, y: kare.maxY))
                    } else {
                        cizgi.move(to: NSPoint(x: x, y: kare.midY))
                        cizgi.line(to: NSPoint(x: textContainerOrigin.x + kapsayici.size.width - kapsayici.lineFragmentPadding, y: kare.midY))
                    }
                    cizgi.stroke()
                }
                konum = NSMaxRange(paragraf)
            }
        }
    }
}

extension NotMetinGorunumu {
    /// Menü de ortak paragraf biçimi ve tek işlem undo yolunu kullanır.
    func menuBlogunuUygula(_ blok: MetinBlogu?, kod: Bool = false, komutAraligi: NSRange) {
        guard let depo = textStorage else { return }
        let paragraf = depo.mutableString.paragraphRange(for: selectedRange())
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: paragraf))
        yeni.deleteCharacters(in: NSRange(location: komutAraligi.location - paragraf.location, length: komutAraligi.length))
        var isaretler: [NSRange] = []
        yeni.enumerateAttribute(kBlokIsaretiAnahtari, in: NSRange(location: 0, length: yeni.length)) { deger, alt, _ in
            if deger as? Bool == true { isaretler.append(alt) }
        }
        for alt in isaretler.reversed() { yeni.deleteCharacters(in: alt) }
        blokBiciminiKaldir(yeni)
        let tumu = NSRange(location: 0, length: yeni.length)
        yeni.removeAttribute(kBaslikSeviyesiAnahtari, range: tumu)
        yeni.removeAttribute(kKodBloguAnahtari, range: tumu)
        yeni.removeAttribute(kSayfaYaziOlcegiAnahtari, range: tumu)
        yeni.addAttribute(.font, value: varsayilanFont(), range: tumu)
        var yazim: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        var isaretUzunlugu = 0
        if let blok {
            blokBiciminiUygula(blok, metne: yeni, aralik: tumu)
            let isaret = blokIsaretiniUret(blok)
            yeni.insert(isaret, at: 0)
            isaretUzunlugu = isaret.length
            if blok.tur != .ayirici { yazim.merge(blok.oznitelikler) { _, yeni in yeni } }
        } else if kod {
            yazim[.font] = NSFont.monospacedSystemFont(ofSize: kTabanPunto, weight: .regular)
            yazim[.backgroundColor] = kMetinRenk.withAlphaComponent(0.08)
            yazim[kKodBloguAnahtari] = ["acilis": "```\n", "kapanis": "```\n", "kimlik": UUID().uuidString]
            yeni.addAttributes(yazim, range: tumu)
            var isaret = yazim
            isaret[kBlokIsaretiAnahtari] = true
            yeni.insert(NSAttributedString(string: "\u{200B}", attributes: isaret), at: 0)
            isaretUzunlugu = 1
        }
        blokDuzenle(paragraf, yeni: yeni,
                    secim: NSRange(location: paragraf.location + isaretUzunlugu, length: 0),
                    yazim: yazim, numarala: blok?.listeMi == true)
    }
}

extension NotMetinGorunumu {
    /// Karakter aralığının kapsayıcı koordinatındaki kutusu; belge dışı/boş aralıkta nil.
    /// Geçersiz glif indeksi AppKit'e hiç iletilmez (konsol uyarısı + NSNotFound).
    func guvenliKare(karakter aralik: NSRange) -> NSRect? {
        guard let depo = textStorage, let yerlesim = layoutManager, let kapsayici = textContainer,
              aralik.location != NSNotFound else { return nil }
        let kirpilmis = NSIntersectionRange(aralik, NSRange(location: 0, length: depo.length))
        guard kirpilmis.length > 0 else { return nil }
        let glifler = yerlesim.glyphRange(forCharacterRange: kirpilmis, actualCharacterRange: nil)
        guard glifler.location != NSNotFound, NSMaxRange(glifler) <= yerlesim.numberOfGlyphs else { return nil }
        return yerlesim.boundingRect(forGlyphRange: glifler, in: kapsayici)
    }

    /// İmlecin ekran karesi. Belge sonunda firstRect(forCharacterRange:) var olmayan glif 14'ü
    /// sorguladığından orada extraLineFragmentRect / son satır kullanılır.
    func imlecEkranKaresi(_ konum: Int) -> NSRect {
        guard let depo = textStorage, let yerlesim = layoutManager, let kapsayici = textContainer,
              let pencere = window else { return .zero }
        guard konum >= depo.length else {
            return firstRect(forCharacterRange: NSRange(location: konum, length: 0), actualRange: nil)
        }
        yerlesim.ensureLayout(for: kapsayici)
        var kare = yerlesim.extraLineFragmentRect
        if kare.isEmpty, yerlesim.numberOfGlyphs > 0 {
            let son = yerlesim.lineFragmentUsedRect(forGlyphAt: yerlesim.numberOfGlyphs - 1, effectiveRange: nil)
            kare = NSRect(x: son.maxX, y: son.minY, width: 0, height: son.height)
        }
        kare = kare.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        kare.size.width = 0
        return pencere.convertToScreen(convert(kare, to: nil))
    }
}
