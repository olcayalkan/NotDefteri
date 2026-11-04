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
    /// Bloğun ekranda görünen karesi (metin görünümü koordinatlarında). Kod ve uyarı kutusunda
    /// çizilen çerçevedir; diğerlerinde paragraf boşlukları hariç metin satırlarıdır.
    func blokGorselKaresi(_ birim: NSRange) -> NSRect? {
        guard let depo = textStorage, let kapsayici = textContainer, birim.length > 0,
              NSMaxRange(birim) <= depo.length else { return nil }
        for anahtar in [kKodBloguAnahtari, kUyariKutusuAnahtari]
        where depo.attribute(anahtar, at: birim.location, effectiveRange: nil) != nil {
            return blokCerceveKaresi(birim, anahtar: anahtar)
        }
        guard let kare = guvenliKare(karakter: birim) else { return nil }
        let pay = kapsayici.lineFragmentPadding
        return NSRect(x: textContainerOrigin.x + pay, y: textContainerOrigin.y + kare.minY,
                      width: kapsayici.size.width - pay * 2, height: kare.height)
    }

    /// Bloğun ilk satırı; tutamaç bu satırın ortasına hizalanır.
    func blokIlkSatirKaresi(_ birim: NSRange) -> NSRect? {
        guard birim.length > 0, let kare = guvenliKare(karakter: NSRange(location: birim.location, length: 1)) else { return nil }
        return kare.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
    }

    /// Tutamacın yeri: kutuda çerçevenin, başlıkta katlama üçgeninin, listede madde işaretinin solu.
    func blokTutamacKaresi(_ birim: NSRange) -> NSRect? {
        guard let depo = textStorage, let kapsayici = textContainer,
              let gorsel = blokGorselKaresi(birim), let ilk = blokIlkSatirKaresi(birim) else { return nil }
        let boyut = BlokTutamaci.boyut
        let metinSolu = textContainerOrigin.x + kapsayici.lineFragmentPadding
        let kutu = [kKodBloguAnahtari, kUyariKutusuAnahtari].contains { depo.attribute($0, at: birim.location, effectiveRange: nil) != nil }
        let x: CGFloat
        if kutu {
            x = gorsel.minX - boyut.width - 4
        } else if depo.attribute(kBaslikSeviyesiAnahtari, at: birim.location, effectiveRange: nil) != nil {
            x = metinSolu - 40
        } else if let madde = blok(NSRange(location: birim.location, length: 0)), madde.listeMi {
            let girinti = (depo.attribute(.paragraphStyle, at: birim.location, effectiveRange: nil) as? NSParagraphStyle)?.firstLineHeadIndent ?? 0
            x = metinSolu + girinti - boyut.width - 6
        } else {
            x = metinSolu - boyut.width - 6
        }
        let satirOrtasi = kutu ? max(ilk.midY, gorsel.minY + boyut.height / 2 + 2) : ilk.midY
        return NSRect(x: max(visibleRect.minX, x), y: satirOrtasi - boyut.height / 2, width: boyut.width, height: boyut.height)
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
        guard birim.length > 0, let kare = blokTutamacKaresi(birim) else { blokTutamaci.isHidden = true; return }
        blokTutamaci.birim = birim
        blokTutamaci.frame = kare
        blokTutamaci.isHidden = false
    }

    /// Fare bırakılınca blok, imlecin en yakın olduğu blok sınırına gider. `y` çizginin yeri:
    /// iki bloğun görünen kenarlarının tam ortası (kutu çerçevesinin içine düşmez).
    func blokSiniri(noktada nokta: NSPoint, tasinan birim: NSRange) -> (konum: Int, y: CGFloat)? {
        guard let depo = textStorage, depo.length > 0, let yerlesim = layoutManager, let kapsayici = textContainer else { return nil }
        let kapNoktasi = NSPoint(x: 10, y: max(0, nokta.y - textContainerOrigin.y))
        var oran: CGFloat = 0
        let glif = yerlesim.glyphIndex(for: kapNoktasi, in: kapsayici, fractionOfDistanceThroughGlyph: &oran)
        let karakter = min(yerlesim.characterIndexForGlyph(at: glif), depo.length - 1)
        let hedefBirim = blokBirimi(karakter)
        guard hedefBirim.length > 0, let kare = blokGorselKaresi(hedefBirim) else { return nil }
        let konum = min(nokta.y < kare.midY ? hedefBirim.location : NSMaxRange(hedefBirim), depo.length)
        // Taşınan bloğun içi ya da kendi kenarı hedef olamaz.
        guard konum < birim.location || konum > NSMaxRange(birim) else { return nil }
        let ust = konum > 0 ? blokGorselKaresi(blokBirimi(konum - 1))?.maxY : nil
        let alt = konum < depo.length ? blokGorselKaresi(blokBirimi(konum))?.minY : nil
        switch (ust, alt) {
        case let (ust?, alt?): return (konum, (ust + alt) / 2)
        case let (ust?, nil): return (konum, ust + 4)
        case let (nil, alt?): return (konum, max(0, alt - 4))
        default: return nil
        }
    }

    func blokSurukle(_ birim: NSRange, olay: NSEvent) {
        guard let pencere = window, let kapsayici = textContainer else { return }
        let baslangic = olay.locationInWindow
        var surukleniyor = false
        var hedef: Int?
        var gorseller: BlokSuruklemeGorselleri?
        defer { gorseller?.kaldir() }
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        while let e = pencere.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if e.type == .leftMouseUp { break }
            if !surukleniyor, hypot(e.locationInWindow.x - baslangic.x, e.locationInWindow.y - baslangic.y) < 3 { continue }
            if !surukleniyor {
                surukleniyor = true
                blokTutamaci.isHidden = true
                gorseller = BlokSuruklemeGorselleri(editor: self, birim: birim, tutulan: convert(baslangic, from: nil))
            }
            autoscroll(with: e)
            let nokta = convert(e.locationInWindow, from: nil)
            gorseller?.hayaletiTasi(nokta)
            let sinir = blokSiniri(noktada: nokta, tasinan: birim)
            hedef = sinir?.konum
            gorseller?.cizgiyiGoster(sinir.map {
                NSRect(x: textContainerOrigin.x + kapsayici.lineFragmentPadding - 4, y: $0.y - 4,
                       width: kapsayici.size.width - kapsayici.lineFragmentPadding * 2 + 4, height: 8)
            })
        }
        blokTutamaci.isHidden = true
        guard surukleniyor else {
            // Tutamaca tıklamak bloğu seçer (Notion'daki gibi).
            pencere.makeFirstResponder(self)
            let satirSonu = (string as NSString).substring(with: birim).hasSuffix("\n") ? 1 : 0
            setSelectedRange(NSRange(location: birim.location, length: birim.length - satirSonu))
            return
        }
        gorseller?.kaldir()
        gorseller = nil
        if let hedef { bloguTasi(birim, hedef: hedef) }
    }
}

/// Sürüklerken nereye gideceği açıkça görünsün: taşınan blok çerçeveyle işaretlenir, yarı saydam
/// kopyası fareyle gelir, bırakılacak yerde başında nokta olan kalın çizgi durur.
final class BlokSuruklemeGorselleri {
    private let kaynak = NSView()
    private let hayalet = NSImageView()
    private let cizgi = BirakmaCizgisi()
    private let tutmaFarki: CGFloat

    init(editor: NotMetinGorunumu, birim: NSRange, tutulan: NSPoint) {
        let gorsel = editor.blokGorselKaresi(birim) ?? .zero
        let kare = gorsel.insetBy(dx: -6, dy: -3)
        // Kopya yalnızca bloğun kendi yüksekliğinden alınır; payla üst satırın harf kuyrukları da giriyordu.
        let kopyaKaresi = gorsel.insetBy(dx: -6, dy: 0)
        tutmaFarki = tutulan.y - kopyaKaresi.minY
        // Kopya, çerçeve eklenmeden önce alınır; yoksa çerçeve de kopyaya girerdi.
        if kopyaKaresi.width > 0, kopyaKaresi.height > 0, let temsil = editor.bitmapImageRepForCachingDisplay(in: kopyaKaresi) {
            editor.cacheDisplay(in: kopyaKaresi, to: temsil)
            let resim = NSImage(size: kopyaKaresi.size)
            resim.addRepresentation(temsil)
            hayalet.image = resim
        }
        hayalet.imageScaling = .scaleNone
        hayalet.alphaValue = 0.45
        hayalet.wantsLayer = true
        hayalet.layer?.shadowOpacity = 0.25
        hayalet.layer?.shadowRadius = 6
        hayalet.frame = kopyaKaresi.offsetBy(dx: 12, dy: 0)
        kaynak.wantsLayer = true
        kaynak.layer?.borderColor = NSColor.controlAccentColor.cgColor
        kaynak.layer?.borderWidth = 2
        kaynak.layer?.cornerRadius = 6
        kaynak.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        kaynak.frame = kare
        cizgi.isHidden = true
        // Çizgi en üstte: kopya üstünden geçerken bırakma yeri gizlenmesin.
        editor.addSubview(kaynak)
        editor.addSubview(hayalet)
        editor.addSubview(cizgi)
    }

    func hayaletiTasi(_ nokta: NSPoint) { hayalet.frame.origin.y = nokta.y - tutmaFarki }

    func cizgiyiGoster(_ kare: NSRect?) {
        guard let kare else { cizgi.isHidden = true; return }
        cizgi.frame = kare
        cizgi.isHidden = false
    }

    func kaldir() {
        kaynak.removeFromSuperview()
        cizgi.removeFromSuperview()
        hayalet.removeFromSuperview()
    }
}

/// Bırakma yeri: solunda içi boş halka, sağa uzanan 3 pt çizgi. Çevresindeki zemin renkli hale
/// kutular yakınken çizgiyi kutu kenarından ayırır; yoksa çizgi çerçeveye karışıyordu.
final class BirakmaCizgisi: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        aktifTema.arkaplan.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
        NSColor.controlAccentColor.set()
        let halka = NSRect(x: 1.5, y: bounds.midY - 3.5, width: 7, height: 7)
        let yol = NSBezierPath(ovalIn: halka)
        yol.lineWidth = 2
        yol.stroke()
        NSBezierPath(roundedRect: NSRect(x: halka.maxX, y: bounds.midY - 1.5, width: bounds.width - halka.maxX, height: 3),
                     xRadius: 1.5, yRadius: 1.5).fill()
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
