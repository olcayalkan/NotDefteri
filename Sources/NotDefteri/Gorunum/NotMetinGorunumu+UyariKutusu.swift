import AppKit
import NotDefteriCekirdek

extension NotMetinGorunumu {
    func uyariKutulariniCiz(_ kirliAlan: NSRect) {
        cerceveliBloklariCiz(kirliAlan, anahtar: kUyariKutusuAnahtari)
    }

    /// Kirli aralık yalnızca adayları bulur; geometri her zaman tam bloktan gelir.
    func cerceveliBlokAraliklari(_ aralik: NSRange, anahtar: NSAttributedString.Key) -> [NSRange] {
        guard let depo = textStorage else { return [] }
        let tumu = NSRange(location: 0, length: depo.length)
        var sonuc: [NSRange] = [], gorulen = Set<Int>()
        depo.enumerateAttribute(anahtar, in: NSIntersectionRange(aralik, tumu)) { deger, alt, _ in
            guard deger != nil else { return }
            var blok = NSRange()
            _ = depo.attribute(anahtar, at: alt.location, longestEffectiveRange: &blok, in: tumu)
            if gorulen.insert(blok.location).inserted { sonuc.append(blok) }
        }
        return sonuc
    }

    func blokCerceveKaresi(_ aralik: NSRange, anahtar: NSAttributedString.Key) -> NSRect? {
        guard let depo = textStorage, let kapsayici = textContainer,
              let kare = guvenliKare(karakter: aralik) else { return nil }
        let blok = MetinBlogu(oznitelik: depo.attribute(kMetinBloguAnahtari, at: aralik.location, effectiveRange: nil))
        let girinti = anahtar == kKodBloguAnahtari ? 0 : CGFloat(blok?.seviye ?? 0) * 24
        return NSRect(x: textContainerOrigin.x + kapsayici.lineFragmentPadding + girinti,
                      y: textContainerOrigin.y + kare.minY - 3,
                      width: max(0, kapsayici.size.width - kapsayici.lineFragmentPadding * 2 - girinti),
                      height: kare.height + 6)
    }

    func cerceveliBloklariCiz(_ kirliAlan: NSRect, anahtar: NSAttributedString.Key) {
        guard let depo = textStorage, let yerlesim = layoutManager, let kapsayici = textContainer else { return }
        let kirpma = kirliAlan.intersection(visibleRect)
        guard !kirpma.isEmpty else { return }
        let alan = kirpma.insetBy(dx: -7, dy: -7).offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let glifler = yerlesim.glyphRange(forBoundingRect: alan, in: kapsayici)
        var karakterler = yerlesim.characterRange(forGlyphRange: glifler, actualGlyphRange: nil)
        if glifler.length == 0, depo.length > 0,
           yerlesim.extraLineFragmentRect.insetBy(dx: -7, dy: -7).intersects(alan) {
            karakterler = NSRange(location: depo.length - 1, length: 1)
        }
        // Belge sonunun extra-line alanında glif yoktur; son karakterin kutusu
        // alt kenarı yine de kapsar. Komşu karakterler yalnızca aday bulur.
        let bas = max(0, karakterler.location - 1)
        let son = min(depo.length, NSMaxRange(karakterler) + 1)
        let adaylar = NSRange(location: bas, length: max(0, son - bas))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: kirpma).addClip()
        for aralik in cerceveliBlokAraliklari(adaylar, anahtar: anahtar) {
            guard let kare = blokCerceveKaresi(aralik, anahtar: anahtar), kare.intersects(kirpma) else { continue }
            let blok = MetinBlogu(oznitelik: depo.attribute(kMetinBloguAnahtari, at: aralik.location, effectiveRange: nil))
            let renkler: [String: NSColor] = ["mavi": .systemBlue, "sarı": .systemYellow,
                "kırmızı": .systemRed, "yeşil": .systemGreen]
            let renk = anahtar == kKodBloguAnahtari ? kMetinRenk : renkler[blok?.renk ?? ""] ?? .systemGray
            blokCercevesiniCiz(kare, renk: renk)
        }
    }

    func blokCercevesiniCiz(_ kare: NSRect, renk: NSColor) {
        let cerceve = NSBezierPath(roundedRect: kare.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        renk.withAlphaComponent(0.03).setFill()
        cerceve.fill()
        renk.withAlphaComponent(0.7).setStroke()
        cerceve.lineWidth = 1
        cerceve.stroke()
    }

    /// Eski ve yeni kutu kenarları da kirlenir; yalnızca değişimin komşuları okunur.
    func blokCerceveleriniKirlet(_ aralik: NSRange) {
        guard let depo = textStorage else { return }
        let bas = max(0, aralik.location - 1)
        let son = min(depo.length, NSMaxRange(aralik) + 1)
        guard son > bas else { return }
        for anahtar in [kKodBloguAnahtari, kUyariKutusuAnahtari] {
            for blok in cerceveliBlokAraliklari(NSRange(location: bas, length: son - bas), anahtar: anahtar) {
                if let kare = blokCerceveKaresi(blok, anahtar: anahtar) { setNeedsDisplay(kare.insetBy(dx: -1, dy: -1)) }
            }
        }
    }

    func uyariBasindaSil() -> Bool {
        guard isEditable, let depo = textStorage, selectedRange().length == 0 else { return false }
        let paragraf = paragrafAraligi()
        guard let mevcut = blok(paragraf), mevcut.tur == .uyari,
              selectedRange().location <= paragraf.location + blokIsaretiUzunlugu(depo, konum: paragraf.location) else { return false }
        let eski = depo.attributedSubstring(from: paragraf)
        if kodBloguGovdesi(eski).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            menuBlogunuUygula(nil, komutAraligi: NSRange(location: paragraf.location, length: 0))
            return true
        }
        guard paragraf.location > 0,
              depo.attribute(kUyariKutusuAnahtari, at: paragraf.location - 1, effectiveRange: nil) as? String == mevcut.uyariKimligi else { return true }
        let onceki = depo.mutableString.paragraphRange(for: NSRange(location: paragraf.location - 1, length: 0))
        guard let oncekiBlok = blok(onceki) else { return true }
        let kapsam = NSUnionRange(onceki, paragraf)
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: kapsam))
        let oncekiGovdeSonu = (depo.mutableString.substring(with: onceki).trimmingCharacters(in: .newlines) as NSString).length
        let silinecek = NSRange(location: oncekiGovdeSonu, length: onceki.length - oncekiGovdeSonu + blokIsaretiUzunlugu(eski))
        yeni.deleteCharacters(in: silinecek)
        blokBiciminiUygula(oncekiBlok, metne: yeni, aralik: NSRange(location: 0, length: yeni.length))
        blokDuzenle(kapsam, yeni: yeni, secim: NSRange(location: onceki.location + oncekiGovdeSonu, length: 0), yazim: oncekiBlok.oznitelikler)
        return true
    }

    /// Yerel silme/kesme kutunun başını kaldırabilir; yalnızca değişen ve komşu paragraf denetlenir.
    func uyariSinirlariniGuncelle(_ depo: NSTextStorage, aralik: NSRange) {
        guard depo.length > 0 else { return }
        let ns = depo.mutableString
        let kapsam = ns.paragraphRange(for: NSIntersectionRange(aralik, NSRange(location: 0, length: depo.length)))
        var son = NSMaxRange(kapsam)
        // Komşunun tüm metnini ancak kutu başı/devamı gerçekten değişecekse ölç.
        if son < depo.length, let sonraki = MetinBlogu(oznitelik: depo.attribute(kMetinBloguAnahtari, at: son, effectiveRange: nil)),
           sonraki.tur == .uyari {
            let devam = son > 0 && depo.attribute(kUyariKutusuAnahtari, at: son - 1, effectiveRange: nil) as? String == sonraki.uyariKimligi
            if sonraki.devam != devam { son = NSMaxRange(ns.paragraphRange(for: NSRange(location: son, length: 0))) }
        }
        var konum = kapsam.location
        while konum < son {
            let paragraf = ns.paragraphRange(for: NSRange(location: konum, length: 0))
            // Baş/devam bilgisi kayıtta korunur; görsel girinti ikisinde de aynıdır.
            if var blok = MetinBlogu(oznitelik: depo.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil)), blok.tur == .uyari {
                let devam = konum > 0 && depo.attribute(kUyariKutusuAnahtari, at: konum - 1, effectiveRange: nil) as? String == blok.uyariKimligi
                if blok.devam != devam {
                    blok.devam = devam
                    blok.kaynakOnEk = nil
                    depo.addAttributes(blok.oznitelikler, range: paragraf)
                }
            }
            konum = NSMaxRange(paragraf)
        }
    }

    func uyariRenkMenusu() -> NSMenu {
        let menu = NSMenu(title: "Uyarı kutusu")
        let mevcut = blok(paragrafAraligi())?.renk
        for renk in ["gri", "mavi", "sarı", "kırmızı", "yeşil"] {
            let oge = menu.addItem(withTitle: renk.capitalized(with: Locale(identifier: "tr_TR")),
                                   action: #selector(uyariRenginiSec(_:)), keyEquivalent: "")
            oge.target = self
            oge.representedObject = renk
            oge.state = mevcut == renk ? .on : .off
        }
        return menu
    }

    @objc private func uyariRenginiSec(_ sender: NSMenuItem) {
        guard let renk = sender.representedObject as? String else { return }
        uyariKutusuDegistir(renk: renk)
    }

    func uyariKutusuDegistir(emoji: String? = nil, renk: String? = nil) {
        guard let depo = textStorage, let mevcut = blok(paragrafAraligi()), mevcut.tur == .uyari else { return }
        var kapsam = NSRange()
        _ = depo.attribute(kUyariKutusuAnahtari, at: paragrafAraligi().location,
                           longestEffectiveRange: &kapsam, in: NSRange(location: 0, length: depo.length))
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: kapsam))
        var konum = 0
        var secim = selectedRange()
        while konum < yeni.length {
            var paragraf = yeni.mutableString.paragraphRange(for: NSRange(location: konum, length: 0))
            guard var blok = MetinBlogu(oznitelik: yeni.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil)) else { break }
            if let emoji { blok.emoji = emoji }
            if let renk { blok.renk = renk }
            blok.kaynakOnEk = nil
            let uzunluk = blokIsaretiUzunlugu(yeni, konum: konum)
            let isaret = blokIsaretiniUret(blok)
            yeni.replaceCharacters(in: NSRange(location: konum, length: uzunluk), with: isaret)
            let fark = isaret.length - uzunluk
            if secim.location >= kapsam.location + konum + uzunluk { secim.location += fark }
            paragraf.length += fark
            blokBiciminiUygula(blok, metne: yeni, aralik: paragraf)
            konum = NSMaxRange(paragraf)
        }
        blokDuzenle(kapsam, yeni: yeni, secim: secim, yazim: typingAttributes)
        blokYaziminiGuncelle()
    }
}
