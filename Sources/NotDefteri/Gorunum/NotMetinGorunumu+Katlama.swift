import AppKit
import NotDefteriCekirdek

/// Katlama bilgisi metin deposuna öznitelik olarak bile yazılmaz.
final class KatlamaDurumu {
    struct Baslik {
        var girdi: IcindekilerPaneli.Girdi
        var paragraf: NSRange
        var bolum: NSRange
        var katli: Bool
    }

    var basliklar: [Baslik] = []
    var gizliAraliklar: [NSRange] = []
    var yerlesimdekiGizliAraliklar: [NSRange] = []
    var gorunenBasliklar: [Int] = []
    var metinUzunlugu = 0
    var fare: NSPoint?
    var fareBaslikKonumu: Int?
    var fareKenarKaresi: NSRect?
    var yol: String?
    var yuklenecek: Set<String>?
    static var sayfalar: [String: [String]] = [:]

    func gizliMi(_ konum: Int) -> Bool {
        let sira = gizliAraliklar.partitionIndex { NSMaxRange($0) <= konum }
        return sira < gizliAraliklar.count && NSLocationInRange(konum, gizliAraliklar[sira])
    }

    func kesisiyor(_ aralik: NSRange) -> Bool {
        if aralik.length == 0 {
            return gizliMi(aralik.location) || gizliAraliklar.last.map { secimiIceriyor(aralik, bolum: $0) } == true
        }
        let sira = gizliAraliklar.partitionIndex { NSMaxRange($0) <= aralik.location }
        return sira < gizliAraliklar.count && gizliAraliklar[sira].location < NSMaxRange(aralik)
    }

    func secimiIceriyor(_ secim: NSRange, bolum: NSRange) -> Bool {
        guard bolum.length > 0 else { return false }
        if secim.length > 0 { return NSIntersectionRange(secim, bolum).length > 0 }
        return NSLocationInRange(secim.location, bolum)
            || (secim.location == metinUzunlugu && NSMaxRange(bolum) == metinUzunlugu)
    }

    func gorunurluguGuncelle() {
        gizliAraliklar = []
        gorunenBasliklar = []
        for (sira, baslik) in basliklar.enumerated() {
            if let son = gizliAraliklar.last, NSLocationInRange(baslik.girdi.konum, son) { continue }
            gorunenBasliklar.append(sira)
            if baslik.katli, baslik.bolum.length > 0 { gizliAraliklar.append(baslik.bolum) }
        }
    }

    func anahtarlar(_ girdiler: [IcindekilerPaneli.Girdi]) -> [String] {
        var adetler: [String: Int] = [:]
        return girdiler.map {
            let temel = "\($0.seviye):\($0.metin.utf8.count):\($0.metin)"
            let adet = adetler[temel, default: 0]
            adetler[temel] = adet + 1
            return "\(temel):\(adet)"
        }
    }

    func sakla() {
        guard let yol else { return }
        let anahtarlar = anahtarlar(basliklar.map(\.girdi))
        let katlilar = basliklar.indices.filter { basliklar[$0].katli }.map { anahtarlar[$0] }
        Self.sayfalar[yol] = katlilar
        UserDefaults.standard.set(katlilar, forKey: "baslikKatlama." + yol)
    }
}

private extension Array {
    /// Sıralı aralıklarda/başlıklarda görünür bölgeye O(log n) erişim.
    func partitionIndex(_ once: (Element) -> Bool) -> Int {
        var alt = 0
        var ust = count
        while alt < ust {
            let orta = alt + (ust - alt) / 2
            if once(self[orta]) { alt = orta + 1 } else { ust = orta }
        }
        return alt
    }
}

extension NotMetinGorunumu {
    func katlamaSayfasiniAc(_ url: URL?) {
        katlama.sakla()
        katlama.basliklar = []
        katlama.gizliAraliklar = []
        katlama.gorunenBasliklar = []
        katlama.fare = nil
        katlama.fareBaslikKonumu = nil
        katlama.fareKenarKaresi = nil
        katlama.metinUzunlugu = 0
        let onek = notlarKlasoru().standardizedFileURL.path + "/"
        katlama.yol = url.flatMap { url in
            let yol = url.standardizedFileURL.path
            return yol.hasPrefix(onek) ? String(yol.dropFirst(onek.count)) : nil
        }
        katlama.yuklenecek = Set(katlama.yol.map {
            KatlamaDurumu.sayfalar[$0] ?? UserDefaults.standard.stringArray(forKey: "baslikKatlama." + $0) ?? []
        } ?? [])
        katlamaYerlesiminiGuncelle()
    }

    func katlamaYolunuDegistir(_ url: URL) {
        let onek = notlarKlasoru().standardizedFileURL.path + "/"
        let yol = url.standardizedFileURL.path
        let yeni = yol.hasPrefix(onek) ? String(yol.dropFirst(onek.count)) : nil
        guard katlama.yol != yeni else { return }
        katlama.sakla()
        let eski = katlama.yol
        katlama.yol = yeni
        katlama.sakla()
        if let eski, eski != katlama.yol {
            KatlamaDurumu.sayfalar.removeValue(forKey: eski)
            UserDefaults.standard.removeObject(forKey: "baslikKatlama." + eski)
        }
    }

    /// İçindekilerin mevcut debounce sonucunu kullanır; ayrı belge taraması yoktur.
    func katlamaBasliklariniGuncelle(_ girdiler: [IcindekilerPaneli.Girdi]) {
        guard let depo = textStorage,
              katlama.yuklenecek != nil || girdiler != katlama.basliklar.map(\.girdi) else { return }
        katlama.metinUzunlugu = depo.length
        let eski = Dictionary(katlama.basliklar.map { ($0.girdi.konum, $0) }, uniquingKeysWith: { ilk, _ in ilk })
        let anahtarlar = katlama.anahtarlar(girdiler)
        katlama.basliklar = girdiler.enumerated().map { sira, girdi in
            let paragraf = depo.mutableString.paragraphRange(for: NSRange(location: girdi.konum, length: 0))
            let katli = katlama.yuklenecek.map { $0.contains(anahtarlar[sira]) }
                ?? (eski[girdi.konum].map { $0.girdi.seviye == girdi.seviye && $0.katli } ?? false)
            return KatlamaDurumu.Baslik(girdi: girdi, paragraf: paragraf,
                                       bolum: NSRange(location: NSMaxRange(paragraf), length: 0), katli: katli)
        }
        katlama.yuklenecek = nil
        var acik: [Int] = []
        for sira in katlama.basliklar.indices {
            while let ust = acik.last, girdiler[ust].seviye >= girdiler[sira].seviye {
                katlamaBolumunuBitir(acik.removeLast(), son: girdiler[sira].konum)
            }
            acik.append(sira)
        }
        for sira in acik { katlamaBolumunuBitir(sira, son: depo.length) }
        katlama.gorunurluguGuncelle()
        katlama.sakla()
        katlamaYerlesiminiGuncelle()
        katliAraligiAc(selectedRange())
    }

    private func katlamaBolumunuBitir(_ sira: Int, son: Int) {
        katlama.basliklar[sira].bolum.length = max(0, son - katlama.basliklar[sira].bolum.location)
    }

    /// Depo bildiriminde yalnızca önbellekteki konumlar kaydırılır. Yapı hesabı
    /// içindekilerden gelir. Undo/redo'nun değiştirdiği eski aralık da açılır.
    @objc func katlamaDeposuDegisti(_ bildirim: Notification) {
        guard !katlama.basliklar.isEmpty, !sayfaYukleniyor, !yaziOlcegiUygulaniyor,
              let depo = bildirim.object as? NSTextStorage, depo.editedRange.location != NSNotFound else { return }
        let yeni = depo.editedRange
        let fark = depo.editedMask.contains(.editedCharacters) ? depo.changeInLength : 0
        let eski = NSRange(location: yeni.location, length: max(0, yeni.length - fark))
        if !baglarGuncelleniyor { katliAraligiAc(eski) }
        guard depo.editedMask.contains(.editedCharacters) else { return }
        func kaydir(_ konum: Int) -> Int {
            if konum < eski.location { return konum }
            if konum >= NSMaxRange(eski) { return max(0, konum + fark) }
            return yeni.location
        }
        let eskiAdet = katlama.basliklar.count
        katlama.basliklar = katlama.basliklar.compactMap { baslik in
            if eski.length > 0,
               NSIntersectionRange(eski, baslik.paragraf) == baslik.paragraf
                || (baslik.girdi.konum > eski.location && baslik.girdi.konum < NSMaxRange(eski)) { return nil }
            var yeniBaslik = baslik
            let basinaYaziliyor = eski.length == 0 && eski.location == baslik.girdi.konum
            let konum = basinaYaziliyor ? baslik.girdi.konum : kaydir(baslik.girdi.konum)
            yeniBaslik.girdi = .init(metin: baslik.girdi.metin, seviye: baslik.girdi.seviye, konum: konum)
            let son = kaydir(NSMaxRange(baslik.paragraf))
            yeniBaslik.paragraf = NSRange(location: konum, length: max(0, son - konum))
            let bas = kaydir(baslik.bolum.location)
            yeniBaslik.bolum = NSRange(location: bas, length: max(0, kaydir(NSMaxRange(baslik.bolum)) - bas))
            return yeniBaslik
        }
        katlama.metinUzunlugu = depo.length
        katlama.gorunurluguGuncelle()
        if katlama.basliklar.count != eskiAdet { katlama.sakla() }
        // Düzenlemeyle kayan glifler AppKit tarafından taşınır. Başlık silinmesi
        // gibi gizli kapsamı ayrıca değiştiren işlemler yeniden yerleşim ister.
        // Yerleşimin gerçekte tuttuğu aralık kaydırılır: yukarıdaki açma işlem sonuna
        // ertelendiyse fark kaybolmaz.
        katlama.yerlesimdekiGizliAraliklar = katlama.yerlesimdekiGizliAraliklar.compactMap { aralik in
            let bas = kaydir(aralik.location)
            let uzunluk = max(0, kaydir(NSMaxRange(aralik)) - bas)
            return uzunluk > 0 ? NSRange(location: bas, length: uzunluk) : nil
        }
        katlamaYerlesiminiGuncelle()
    }

    func katliAraligiAc(_ aralik: NSRange, basligiDaAc: Bool = false) {
        guard aralik.location != NSNotFound, !sayfaYukleniyor,
              basligiDaAc || katlama.kesisiyor(aralik) else { return }
        var degisti = false
        for sira in katlama.basliklar.indices where katlama.basliklar[sira].katli {
            let baslik = katlama.basliklar[sira]
            let iceride = katlama.secimiIceriyor(aralik, bolum: baslik.bolum)
            if iceride || (basligiDaAc && NSLocationInRange(aralik.location, baslik.paragraf)) {
                katlama.basliklar[sira].katli = false
                degisti = true
            }
        }
        guard degisti else { return }
        katlama.gorunurluguGuncelle()
        katlama.sakla()
        katlamaYerlesiminiGuncelle()
    }

    private func katlamaYerlesiminiGuncelle() {
        guard let depo = textStorage, let yerlesim = layoutManager,
              katlama.yerlesimdekiGizliAraliklar != katlama.gizliAraliklar else { return }
        // Depo düzenlemesi sürerken yerleşim yöneticisi eski uzunluktadır; tüm metni
        // geçersiz kılmak var olmayan glifi sorgular. İşlem bitince yeniden denenir.
        guard depo.editedMask.isEmpty else {
            DispatchQueue.main.async { [weak self] in self?.katlamaYerlesiminiGuncelle() }
            return
        }
        katlama.yerlesimdekiGizliAraliklar = katlama.gizliAraliklar
        kodAraclari.isHidden = true
        resimTutamaclariniGuncelle(nil)
        let aralik = NSRange(location: 0, length: depo.length)
        yerlesim.invalidateGlyphs(forCharacterRange: aralik, changeInLength: 0, actualCharacterRange: nil)
        yerlesim.invalidateLayout(forCharacterRange: aralik, actualCharacterRange: nil)
        needsDisplay = true
    }

    /// Başlık sonunda Enter, imleci bölümün yeni ilk paragrafına taşır.
    /// Toplu paragraf değişimi başlamadan aç; yeni satır gizli sınıra kaymasın.
    func katlamaYeniSatirOncesi() {
        let secim = selectedRange()
        guard !hasMarkedText(), secim.length == 0, let depo = textStorage,
              secim.location <= depo.length else { return }
        var son = 0
        depo.mutableString.getParagraphStart(nil, end: nil, contentsEnd: &son, for: secim)
        guard secim.location == son else { return }
        katliAraligiAc(secim, basligiDaAc: true)
    }

    func katlamaKisayolunuUygula(_ olay: NSEvent) -> Bool {
        let bayraklar = olay.modifierFlags.intersection([.command, .option, .control, .shift])
        guard bayraklar.subtracting(.shift) == [.command, .option], !hasMarkedText(), isEditable else { return false }
        let karakter = olay.charactersIgnoringModifiers ?? ""
        let katla: Bool
        // Donanım kodları Option/Shift ile karakteri değişen klavyeleri de kapsar.
        if karakter == "[" || karakter == "{" || olay.keyCode == 33 { katla = true }
        else if karakter == "]" || karakter == "}" || olay.keyCode == 30 { katla = false }
        else { return false }
        let tumu = bayraklar.contains(.shift)
        let konum = selectedRange().location
        let hedef = katlama.basliklar.lastIndex { $0.girdi.konum <= konum }
        katlamaDurumunuDegistir(katla, siralar: tumu ? Array(katlama.basliklar.indices) : hedef.map { [$0] } ?? [])
        return true
    }

    @objc func katlamaKomutu(_ sender: NSMenuItem) {
        guard isEditable, !katlama.basliklar.isEmpty else { return }
        let hedef = katlama.basliklar.lastIndex { $0.girdi.konum <= selectedRange().location }
        katlamaDurumunuDegistir(sender.tag % 2 == 0,
                               siralar: sender.tag >= 2 ? Array(katlama.basliklar.indices) : hedef.map { [$0] } ?? [])
    }

    private func katlamaDurumunuDegistir(_ katla: Bool, siralar: [Int]) {
        let hedefler = siralar.filter { katlama.basliklar[$0].bolum.length > 0 }
        if katla, let ust = hedefler.first(where: {
            let aralik = katlama.basliklar[$0].bolum
            let secim = selectedRange()
            return katlama.secimiIceriyor(secim, bolum: aralik)
        }) {
            setSelectedRange(NSRange(location: katlama.basliklar[ust].girdi.konum, length: 0))
        }
        for sira in hedefler { katlama.basliklar[sira].katli = katla }
        katlama.gorunurluguGuncelle()
        katlama.sakla()
        katlamaYerlesiminiGuncelle()
    }

    func katlamaFaresiniGuncelle(_ nokta: NSPoint?) {
        katlama.fare = nokta
        let sira = nokta.flatMap { nokta in
            visibleRect.contains(nokta) ? gorunenKatlamaBasliklari().first {
                katlama.basliklar[$0].bolum.length > 0
                    && katlamaBaslikKaresi($0).insetBy(dx: -22, dy: 0).contains(nokta)
            } : nil
        }
        let konum = sira.map { katlama.basliklar[$0].girdi.konum }
        let kare = sira.map { sira in
            let baslik = katlamaBaslikKaresi(sira)
            return NSRect(x: baslik.minX - 22, y: baslik.minY, width: 22, height: baslik.height)
        }
        guard katlama.fareBaslikKonumu != konum || katlama.fareKenarKaresi != kare else { return }
        if let eski = katlama.fareKenarKaresi { setNeedsDisplay(eski) }
        katlama.fareBaslikKonumu = konum
        katlama.fareKenarKaresi = kare
        if let kare { setNeedsDisplay(kare) }
    }

    private func gorunenKatlamaBasliklari() -> ArraySlice<Int> {
        guard let yerlesim = layoutManager, let kapsayici = textContainer else { return [] }
        let kare = visibleRect.offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let glifler = yerlesim.glyphRange(forBoundingRect: kare, in: kapsayici)
        let aralik = yerlesim.characterRange(forGlyphRange: glifler, actualGlyphRange: nil)
        let siralar = katlama.gorunenBasliklar
        let bas = siralar.partitionIndex { NSMaxRange(katlama.basliklar[$0].paragraf) <= aralik.location }
        let son = siralar.partitionIndex { katlama.basliklar[$0].girdi.konum < NSMaxRange(aralik) }
        return siralar[bas..<max(bas, son)]
    }

    private func katlamaBaslikKaresi(_ sira: Int) -> NSRect {
        guard katlama.basliklar.indices.contains(sira), let depo = textStorage,
              let yerlesim = layoutManager else { return .zero }
        let konum = katlama.basliklar[sira].girdi.konum
        guard konum >= 0, konum < depo.length, !katlama.gizliMi(konum) else { return .zero }
        let glif = yerlesim.glyphIndexForCharacter(at: konum)
        guard glif < yerlesim.numberOfGlyphs else { return .zero }
        return yerlesim.lineFragmentUsedRect(forGlyphAt: glif, effectiveRange: nil)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
    }

    func katlamaIsaretleriniCiz(_ kirli: NSRect) {
        let fare = window.flatMap { $0.isKeyWindow ? convert($0.mouseLocationOutsideOfEventStream, from: nil) : nil }
            ?? katlama.fare
        let yazi: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14),
                                                   .foregroundColor: kMetinRenk.withAlphaComponent(0.45)]
        for sira in gorunenKatlamaBasliklari() {
            let baslik = katlama.basliklar[sira]
            guard baslik.bolum.length > 0 else { continue }
            let kare = katlamaBaslikKaresi(sira)
            guard kare.insetBy(dx: -22, dy: 0).intersects(kirli) else { continue }
            if let fare, visibleRect.contains(fare), kare.insetBy(dx: -22, dy: 0).contains(fare) {
                ((baslik.katli ? "▸" : "▾") as NSString).draw(at: NSPoint(x: kare.minX - 18, y: kare.minY), withAttributes: yazi)
            }
            if baslik.katli { katlamaUcNoktasiniCiz(baslik, yazi: yazi) }
        }
    }

    private func katlamaUcNoktasiniCiz(_ baslik: KatlamaDurumu.Baslik, yazi: [NSAttributedString.Key: Any]) {
        guard let depo = textStorage, let kapsayici = textContainer else { return }
        var son = min(NSMaxRange(baslik.paragraf), depo.length) - 1
        guard son >= 0, son >= baslik.paragraf.location, son < depo.length else { return }
        while son > baslik.paragraf.location, CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(depo.mutableString.character(at: son)) ?? " ") { son -= 1 }
        guard let kare = guvenliKare(karakter: NSRange(location: son, length: 1))?
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y) else { return }
        ("…" as NSString).draw(at: NSPoint(x: min(kare.maxX + 5, textContainerOrigin.x + kapsayici.size.width - 16), y: kare.minY), withAttributes: yazi)
    }

    func katlamaIsaretiniTikla(_ nokta: NSPoint) -> Bool {
        for sira in gorunenKatlamaBasliklari() where katlama.basliklar[sira].bolum.length > 0 {
            let kare = katlamaBaslikKaresi(sira)
            let dugme = NSRect(x: kare.minX - 22, y: kare.minY, width: 22, height: kare.height)
            if dugme.contains(nokta) {
                katlamaDurumunuDegistir(!katlama.basliklar[sira].katli, siralar: [sira])
                return true
            }
        }
        return false
    }

    func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties: UnsafePointer<NSLayoutManager.GlyphProperty>, characterIndexes: UnsafePointer<Int>,
                       font: NSFont, forGlyphRange glyphRange: NSRange) -> Int {
        guard glyphRange.length > 0, !katlama.gizliAraliklar.isEmpty else { return 0 }
        var sira = katlama.gizliAraliklar.partitionIndex { NSMaxRange($0) <= characterIndexes[0] }
        var yeni = Array(UnsafeBufferPointer(start: properties, count: glyphRange.length))
        var degisti = false
        for i in 0..<glyphRange.length {
            let konum = characterIndexes[i]
            while sira < katlama.gizliAraliklar.count, NSMaxRange(katlama.gizliAraliklar[sira]) <= konum { sira += 1 }
            if sira < katlama.gizliAraliklar.count, NSLocationInRange(konum, katlama.gizliAraliklar[sira]) {
                yeni[i] = .null
                degisti = true
            }
        }
        guard degisti else { return 0 }
        layoutManager.setGlyphs(glyphs, properties: &yeni, characterIndexes: characterIndexes, font: font, forGlyphRange: glyphRange)
        return glyphRange.length
    }

    func layoutManager(_ layoutManager: NSLayoutManager, shouldUse action: NSLayoutManager.ControlCharacterAction,
                       forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        katlama.gizliMi(charIndex) ? .zeroAdvancement : action
    }
}
