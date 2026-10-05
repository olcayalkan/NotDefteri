import AppKit
import NotDefteriCekirdek

extension NotMetinGorunumu {
    func uyariKutulariniCiz(_ kirliAlan: NSRect) {
        guard let depo = textStorage, let yerlesim = layoutManager, let kapsayici = textContainer else { return }
        let alan = kirliAlan.intersection(visibleRect).offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let glifler = yerlesim.glyphRange(forBoundingRect: alan, in: kapsayici)
        let karakterler = yerlesim.characterRange(forGlyphRange: glifler, actualGlyphRange: nil)
        // Her bitişik paragraf grubu ayrı çizilir; bölünen/kopyalanan kimlikler atlanmaz.
        // Yalnızca görünür aralık ölçülür; belge taranmaz.
        depo.enumerateAttribute(kUyariKutusuAnahtari, in: karakterler) { deger, aralik, _ in
            guard let kimlik = deger as? String,
                  let blok = MetinBlogu(oznitelik: depo.attribute(kMetinBloguAnahtari, at: aralik.location, effectiveRange: nil)) else { return }
            guard let kare = guvenliKare(karakter: aralik)?
                .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y) else { return }
            let x = textContainerOrigin.x + kapsayici.lineFragmentPadding + CGFloat(blok.seviye) * 24
            let oncekiAyni = aralik.location > 0 && depo.attribute(kUyariKutusuAnahtari, at: aralik.location - 1, effectiveRange: nil) as? String == kimlik
            let sonrakiAyni = NSMaxRange(aralik) < depo.length && depo.attribute(kUyariKutusuAnahtari, at: NSMaxRange(aralik), effectiveRange: nil) as? String == kimlik
            let ustPay: CGFloat = oncekiAyni ? 12 : 3
            let altPay: CGFloat = sonrakiAyni ? 12 : 3
            let arkaplan = NSRect(x: x, y: kare.minY - ustPay,
                                  width: max(0, kapsayici.size.width - kapsayici.lineFragmentPadding * 2 - CGFloat(blok.seviye) * 24),
                                  height: kare.height + ustPay + altPay)
            let renk: NSColor
            switch blok.renk {
            case "mavi": renk = .systemBlue
            case "sarı": renk = .systemYellow
            case "kırmızı": renk = .systemRed
            case "yeşil": renk = .systemGreen
            default: renk = .systemGray
            }
            renk.withAlphaComponent(0.14).setFill()
            NSBezierPath(roundedRect: arkaplan, xRadius: 6, yRadius: 6).fill()
            if !blok.devam, depo.mutableString.character(at: aralik.location) == 0x200B {
                (blok.emoji as NSString).draw(at: NSPoint(x: x + 8, y: kare.minY),
                    withAttributes: [.font: NSFont.systemFont(ofSize: kTabanPunto * (kucukYazi ? 0.85 : 1))])
            }
        }
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
            // Başı gizli işaretle kalan kutunun girintisini MacBelgeAdaptoru hizalar.
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

    func uyariEmojisiniTikla(noktada nokta: NSPoint) -> Bool {
        guard isEditable, let depo = textStorage, let kapsayici = textContainer else { return false }
        let konum = min(characterIndexForInsertion(at: nokta), depo.length)
        let paragraf = depo.mutableString.paragraphRange(for: NSRange(location: konum, length: 0))
        guard let blok = blok(paragraf), blok.tur == .uyari, !blok.devam else { return false }
        let isaretUzunlugu = blokIsaretiUzunlugu(depo, konum: paragraf.location)
        let gizliIsaret = depo.mutableString.character(at: paragraf.location) == 0x200B
        let aralik = NSRange(location: paragraf.location, length: gizliIsaret ? 1 : (blok.emoji as NSString).length)
        guard var kare = guvenliKare(karakter: aralik)?
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y).insetBy(dx: -4, dy: -3) else { return false }
        if gizliIsaret {
            kare.origin.x = textContainerOrigin.x + kapsayici.lineFragmentPadding + CGFloat(blok.seviye) * 24 + 4
            kare.size.width = 28
        }
        guard kare.contains(nokta) else { return false }
        setSelectedRange(NSRange(location: paragraf.location + isaretUzunlugu, length: 0))
        yuzerGorunumleriGizle()
        let uyari = NSAlert()
        uyari.messageText = "Uyarı kutusu emojisi"
        uyari.informativeText = "Emoji paletinden bir emoji seçin."
        uyari.addButton(withTitle: "Uygula")
        uyari.addButton(withTitle: "Vazgeç")
        let alan = NSTextField(string: blok.emoji)
        alan.font = NSFont.systemFont(ofSize: 28)
        let palet = NSButton(title: "Emoji paletini aç", target: self, action: #selector(uyariEmojiPaletiniAc))
        let kutu = NSStackView(views: [alan, palet])
        kutu.orientation = .vertical
        kutu.frame = NSRect(x: 0, y: 0, width: 240, height: 80)
        alan.widthAnchor.constraint(equalToConstant: 220).isActive = true
        uyari.accessoryView = kutu
        uyari.window.initialFirstResponder = alan
        uyariEmojiAlani = alan
        DispatchQueue.main.async { [weak self] in self?.uyariEmojiPaletiniAc() }
        let sonuc = uyari.runModal()
        uyariEmojiAlani = nil
        if sonuc == .alertFirstButtonReturn {
            let emoji = alan.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if emojiGecerliMi(emoji) { uyariKutusuDegistir(emoji: emoji) } else { NSSound.beep() }
        }
        window?.makeFirstResponder(self)
        return true
    }

    @objc private func uyariEmojiPaletiniAc() {
        guard let alan = uyariEmojiAlani else { return }
        alan.window?.makeFirstResponder(alan)
        alan.currentEditor()?.selectAll(nil)
        NSApp.orderFrontCharacterPalette(nil)
    }
}
