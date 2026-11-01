import AppKit
import NotDefteriCekirdek

// MARK: - Notion gibi blok taşıma
//
// Enter'la ayrılan her paragraf bir bloktur. Kod bloğu, uyarı kutusu ve tablo bölünmez; liste
// maddesi altındaki daha girintili satırlarla birlikte taşınır. ⌘⇧↑/↓ ya da soldaki ⋮⋮
// tutamacı sürüklenerek blok başka yere alınır; taşıma tek adımda geri alınır.

extension NotMetinGorunumu {

    /// `konum`daki karakterin bloğu; her zaman paragraf sınırında başlar ve biter.
    func blokBirimi(_ konum: Int) -> NSRange {
        guard let depo = textStorage, depo.length > 0 else { return NSRange(location: 0, length: 0) }
        let ns = depo.string as NSString
        let tumu = NSRange(location: 0, length: depo.length)
        let paragraf = ns.paragraphRange(for: NSRange(location: min(max(0, konum), ns.length), length: 0))
        guard paragraf.length > 0 else { return paragraf }
        func paragraflari(_ aralik: NSRange) -> NSRange {
            NSUnionRange(ns.paragraphRange(for: NSRange(location: aralik.location, length: 0)),
                         ns.paragraphRange(for: NSRange(location: max(aralik.location, NSMaxRange(aralik) - 1), length: 0)))
        }
        var bolunmez = NSRange()
        for anahtar in [kKodBloguAnahtari, kUyariKutusuAnahtari]
        where depo.attribute(anahtar, at: paragraf.location, longestEffectiveRange: &bolunmez, in: tumu) != nil {
            return paragraflari(bolunmez)
        }
        if let hucre = TabloHucresi(oznitelik: depo.attribute(kTabloHucresiAnahtari, at: paragraf.location, effectiveRange: nil)) {
            func ayniTablo(_ konum: Int) -> Bool {
                konum >= 0 && konum < depo.length &&
                    TabloHucresi(oznitelik: depo.attribute(kTabloHucresiAnahtari, at: konum, effectiveRange: nil))?.tablo == hucre.tablo
            }
            var sonuc = paragraf
            while ayniTablo(sonuc.location - 1) { sonuc = NSUnionRange(sonuc, ns.paragraphRange(for: NSRange(location: sonuc.location - 1, length: 0))) }
            while ayniTablo(NSMaxRange(sonuc)) { sonuc = NSUnionRange(sonuc, ns.paragraphRange(for: NSRange(location: NSMaxRange(sonuc), length: 0))) }
            return sonuc
        }
        var sonuc = paragraf
        if let madde = blok(paragraf), madde.listeMi {
            // Alt maddeler üst maddeyle gider; yoksa taşınan madde çocuklarını başkasına bırakırdı.
            while NSMaxRange(sonuc) < ns.length {
                let sonraki = ns.paragraphRange(for: NSRange(location: NSMaxRange(sonuc), length: 0))
                guard let alt = blok(sonraki), alt.seviye > madde.seviye else { break }
                sonuc = NSUnionRange(sonuc, sonraki)
            }
        }
        return sonuc
    }

    /// Seçimin dokunduğu blokların tamamı.
    func secimBloklari() -> NSRange {
        let secim = selectedRange()
        let ilk = blokBirimi(secim.location)
        guard secim.length > 0 else { return ilk }
        return NSUnionRange(ilk, blokBirimi(NSMaxRange(secim) - 1))
    }

    /// Bloğu `hedef` sınırına taşır. `hedef` bir blok sınırı olmalı ve bloğun içinde olmamalı.
    func bloguTasi(_ birim: NSRange, hedef: Int) {
        guard isEditable, let depo = textStorage, birim.length > 0, NSMaxRange(birim) <= depo.length,
              hedef >= 0, hedef <= depo.length, hedef < birim.location || hedef > NSMaxRange(birim) else { return }
        let yukari = hedef < birim.location
        let kapsam = yukari ? NSRange(location: hedef, length: NSMaxRange(birim) - hedef)
                            : NSRange(location: birim.location, length: hedef - birim.location)
        let diger = yukari ? NSRange(location: hedef, length: birim.location - hedef)
                           : NSRange(location: NSMaxRange(birim), length: hedef - NSMaxRange(birim))
        var ilk = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: yukari ? diger : birim))
        var ikinci = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: yukari ? birim : diger))
        // Belgenin son satırında satır sonu yoksa yer değiştiren satırlar birbirine yapışırdı;
        // geçici satır sonu eklenir, sonuçtaki son satır sonu atılır (belge sonu aynı kalır).
        let sonSatirSonuYok = !ikinci.string.hasSuffix("\n")
        if sonSatirSonuYok {
            let oznitelik = ikinci.length > 0 ? ikinci.attributes(at: ikinci.length - 1, effectiveRange: nil) : typingAttributes
            ikinci.append(NSAttributedString(string: "\n", attributes: oznitelik))
        }
        swap(&ilk, &ikinci)
        let yeni = NSMutableAttributedString(attributedString: ilk)
        yeni.append(ikinci)
        if sonSatirSonuYok { yeni.deleteCharacters(in: NSRange(location: yeni.length - 1, length: 1)) }
        // Numaralı liste başlangıcını ilk maddeden alır; başa gelen madde eski başlangıcı almazsa
        // "1. a / 2. b" taşınınca "2. b / 3. a" oluyordu.
        var numaraFarki = 0
        if let eskiIlk = MetinBlogu(oznitelik: depo.attribute(kMetinBloguAnahtari, at: kapsam.location, effectiveRange: nil)),
           eskiIlk.tur == .numarali, yeni.length > 0,
           var yeniIlk = MetinBlogu(oznitelik: yeni.attribute(kMetinBloguAnahtari, at: 0, effectiveRange: nil)),
           yeniIlk.tur == .numarali, yeniIlk.seviye == eskiIlk.seviye, yeniIlk.numara != eskiIlk.numara {
            let eskiUzunluk = blokIsaretiUzunlugu(yeni, konum: 0)
            yeniIlk.numara = eskiIlk.numara
            yeniIlk.kaynakOnEk = nil
            let isaret = blokIsaretiniUret(yeniIlk)
            yeni.replaceCharacters(in: NSRange(location: 0, length: eskiUzunluk), with: isaret)
            numaraFarki = isaret.length - eskiUzunluk
            blokBiciminiUygula(yeniIlk, metne: yeni, aralik: (yeni.string as NSString).paragraphRange(for: NSRange(location: 0, length: 0)))
        }
        let yeniBas = (yukari ? hedef : hedef - birim.length) + (yukari ? 0 : numaraFarki)
        let secim = selectedRange()
        let gorece = NSIntersectionRange(secim, birim).length > 0 || NSLocationInRange(secim.location, birim)
            ? secim.location - birim.location : 0
        let yeniSecim = NSRange(location: min(yeniBas + gorece, yeniBas + birim.length),
                                length: min(secim.length, max(0, birim.length - gorece)))
        blokDuzenle(kapsam, yeni: yeni, secim: yeniSecim, yazim: typingAttributes, numarala: true)
        undoManager?.setActionName("Bloğu Taşı")
        scrollRangeToVisible(NSRange(location: yeniBas, length: 0))
    }

    /// ⌘⇧↑ / ⌘⇧↓: imlecin ya da seçimin bloklarını bir blok yukarı/aşağı taşır.
    @discardableResult
    func secimiBirBlokTasi(yukari: Bool) -> Bool {
        guard isEditable, let depo = textStorage else { return false }
        let birim = secimBloklari()
        guard birim.length > 0 else { NSSound.beep(); return true }
        if yukari {
            guard birim.location > 0 else { NSSound.beep(); return true }
            bloguTasi(birim, hedef: blokBirimi(birim.location - 1).location)
        } else {
            guard NSMaxRange(birim) < depo.length else { NSSound.beep(); return true }
            let sonraki = blokBirimi(NSMaxRange(birim))
            guard sonraki.length > 0 else { NSSound.beep(); return true }
            bloguTasi(birim, hedef: NSMaxRange(sonraki))
        }
        return true
    }

    func blokTasimaKisayolunuUygula(_ event: NSEvent) -> Bool {
        guard isEditable, !hasMarkedText(), [125, 126].contains(event.keyCode),
              event.modifierFlags.intersection([.command, .control, .option, .shift]) == [.command, .shift] else { return false }
        blokTutamaci.isHidden = true
        return secimiBirBlokTasi(yukari: event.keyCode == 126)
    }

    // MARK: ⋮⋮ tutamacı

    /// Bloğun ilk satırının ekrandaki karesi (metin görünümü koordinatlarında).
    func blokIlkSatirKaresi(_ birim: NSRange) -> NSRect? {
        guard let yerlesim = layoutManager, let kapsayici = textContainer, birim.length > 0 else { return nil }
        let glif = yerlesim.glyphIndexForCharacter(at: birim.location)
        guard glif < yerlesim.numberOfGlyphs else { return nil }
        var satir = yerlesim.lineFragmentUsedRect(forGlyphAt: glif, effectiveRange: nil)
        guard !satir.isEmpty || satir.height > 0 else { return nil }
        satir.origin.x = kapsayici.lineFragmentPadding
        return satir.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
    }

    func blokTutamaciniGuncelle(noktada nokta: NSPoint?) {
        guard isEditable, let nokta, visibleRect.contains(nokta), let depo = textStorage, depo.length > 0,
              let yerlesim = layoutManager, let kapsayici = textContainer else { blokTutamaci.isHidden = true; return }
        // Metnin sağ kenarının ötesi bloğa ait sayılmaz; tutamacın kendi alanı sayılır.
        let solSinir = textContainerOrigin.x - 48
        let sagSinir = textContainerOrigin.x + kapsayici.size.width
        guard nokta.x >= solSinir, nokta.x <= sagSinir else { blokTutamaci.isHidden = true; return }
        let kapNoktasi = NSPoint(x: max(0, nokta.x - textContainerOrigin.x), y: nokta.y - textContainerOrigin.y)
        var oran: CGFloat = 0
        let glif = yerlesim.glyphIndex(for: kapNoktasi, in: kapsayici, fractionOfDistanceThroughGlyph: &oran)
        let karakter = yerlesim.characterIndexForGlyph(at: glif)
        guard karakter < depo.length else { blokTutamaci.isHidden = true; return }
        // Son satırın altındaki boşlukta tutamaç son bloğa yapışmasın.
        let satir = yerlesim.lineFragmentRect(forGlyphAt: glif, effectiveRange: nil).offsetBy(dx: 0, dy: textContainerOrigin.y)
        guard nokta.y <= satir.maxY + 4 else { blokTutamaci.isHidden = true; return }
        let birim = blokBirimi(karakter)
        guard birim.length > 0, let kare = blokIlkSatirKaresi(birim) else { blokTutamaci.isHidden = true; return }
        // Başlığın solunda katlama üçgeni durur; tutamaç onun da solunda.
        let baslik = depo.attribute(kBaslikSeviyesiAnahtari, at: birim.location, effectiveRange: nil) != nil
        let girinti = (depo.attribute(.paragraphStyle, at: birim.location, effectiveRange: nil) as? NSParagraphStyle)?.firstLineHeadIndent ?? 0
        let boyut = BlokTutamaci.boyut
        let x = max(visibleRect.minX, kare.minX + girinti - (baslik ? 40 : 22))
        let y = kare.minY + max(0, (min(kare.height, 28) - boyut.height) / 2)
        blokTutamaci.birim = birim
        blokTutamaci.frame = NSRect(x: x, y: y, width: boyut.width, height: boyut.height)
        blokTutamaci.isHidden = false
    }

    /// Fare bırakılınca blok, imlecin en yakın olduğu blok sınırına gider.
    func blokSiniri(noktada nokta: NSPoint, tasinan birim: NSRange) -> (konum: Int, y: CGFloat)? {
        guard let depo = textStorage, depo.length > 0, let yerlesim = layoutManager, let kapsayici = textContainer else { return nil }
        let kapNoktasi = NSPoint(x: 10, y: max(0, nokta.y - textContainerOrigin.y))
        var oran: CGFloat = 0
        let glif = yerlesim.glyphIndex(for: kapNoktasi, in: kapsayici, fractionOfDistanceThroughGlyph: &oran)
        let karakter = min(yerlesim.characterIndexForGlyph(at: glif), depo.length - 1)
        let hedefBirim = blokBirimi(karakter)
        guard hedefBirim.length > 0 else { return nil }
        let glifler = yerlesim.glyphRange(forCharacterRange: hedefBirim, actualCharacterRange: nil)
        let kare = yerlesim.boundingRect(forGlyphRange: glifler, in: kapsayici).offsetBy(dx: 0, dy: textContainerOrigin.y)
        var konum = nokta.y < kare.midY ? hedefBirim.location : NSMaxRange(hedefBirim)
        // Taşınan bloğun içi ya da kendi kenarı hedef olamaz.
        if konum >= birim.location && konum <= NSMaxRange(birim) { return (birim.location, -1) }
        konum = min(konum, depo.length)
        let y = konum == hedefBirim.location ? kare.minY : kare.maxY
        return (konum, y)
    }

    func blokSurukle(_ birim: NSRange, olay: NSEvent) {
        guard let pencere = window, let kapsayici = textContainer else { return }
        let cizgi = NSView()
        cizgi.wantsLayer = true
        cizgi.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        cizgi.layer?.cornerRadius = 1
        cizgi.isHidden = true
        addSubview(cizgi)
        defer { cizgi.removeFromSuperview() }
        let baslangic = olay.locationInWindow
        var surukleniyor = false
        var hedef: Int?
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        while let e = pencere.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if e.type == .leftMouseUp { break }
            if !surukleniyor, hypot(e.locationInWindow.x - baslangic.x, e.locationInWindow.y - baslangic.y) < 3 { continue }
            surukleniyor = true
            autoscroll(with: e)
            let nokta = convert(e.locationInWindow, from: nil)
            guard let sinir = blokSiniri(noktada: nokta, tasinan: birim), sinir.y >= 0 else {
                hedef = nil; cizgi.isHidden = true; continue
            }
            hedef = sinir.konum
            cizgi.frame = NSRect(x: textContainerOrigin.x + kapsayici.lineFragmentPadding, y: sinir.y - 1,
                                 width: kapsayici.size.width - kapsayici.lineFragmentPadding * 2, height: 2)
            cizgi.isHidden = false
        }
        blokTutamaci.isHidden = true
        guard surukleniyor else {
            // Tutamaca tıklamak bloğu seçer (Notion'daki gibi).
            pencere.makeFirstResponder(self)
            let satirSonu = (string as NSString).substring(with: birim).hasSuffix("\n") ? 1 : 0
            setSelectedRange(NSRange(location: birim.location, length: birim.length - satirSonu))
            return
        }
        if let hedef { bloguTasi(birim, hedef: hedef) }
    }
}

/// Bloğun solunda fare üzerindeyken görünen ⋮⋮; sürüklenince bloğu taşır.
final class BlokTutamaci: NSView {
    static let boyut = NSSize(width: 16, height: 22)
    var birim = NSRange(location: 0, length: 0)

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        kMetinRenk.withAlphaComponent(0.4).setFill()
        let cap: CGFloat = 3
        for sutun in 0..<2 {
            for satir in 0..<3 {
                let x = bounds.midX - 3.5 + CGFloat(sutun) * 5 - cap / 2
                let y = bounds.midY - 5 + CGFloat(satir) * 5 - cap / 2
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: cap, height: cap)).fill()
            }
        }
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func mouseDown(with event: NSEvent) {
        (superview as? NotMetinGorunumu)?.blokSurukle(birim, olay: event)
    }
}
