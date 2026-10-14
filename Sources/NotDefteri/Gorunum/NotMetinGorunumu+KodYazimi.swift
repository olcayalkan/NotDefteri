import AppKit
import NotDefteriCekirdek

// MARK: - Kod bloğunda eşli karakterler ve Tab kalıpları (bkz. `KodYazimYardimi.swift`)

extension NotMetinGorunumu {
    /// Basılı tutulan geri silme tuşu boşalan kutuda durur; kutuyu kaldırmak ayrı bir basış
    /// ister. Yoksa yazıyı silerken kutu da gidiyordu. Klavye dışı olayda tekrar sorulmaz.
    var geriSilmeTekrari: Bool {
        guard let olay = NSApp.currentEvent, olay.type == .keyDown else { return false }
        return olay.isARepeat
    }

    /// İmleç kod bloğundaysa bloğun dil etiketi ("" etiketsiz). Bloğun son satırında imleç
    /// satır sonunun önündedir; belgenin sonunda soldaki karaktere bakılır, ama bloktan
    /// sonraki boş paragraf koda sayılmaz.
    func koddakiDil(_ konum: Int) -> String? {
        guard let depo = textStorage, depo.length > 0 else { return nil }
        let ns = depo.string as NSString
        let bakilan = konum < depo.length ? konum : konum - 1
        guard bakilan >= 0, konum < depo.length || ns.character(at: bakilan) != 10,
              depo.attribute(kKodBloguAnahtari, at: bakilan, effectiveRange: nil) != nil else { return nil }
        return depo.attribute(kKodBloguDiliAnahtari, at: bakilan, effectiveRange: nil) as? String ?? ""
    }

    /// Tek karakterlik yazımın kod bloğundaki eş davranışı; kod dışında `nil`.
    func kodEsiEylemi(_ metin: String, replacementRange: NSRange) -> KodEsiEylemi? {
        let secim = selectedRange()
        guard isEditable, !hasMarkedText(), replacementRange.location == NSNotFound || replacementRange == secim,
              koddakiDil(secim.location) != nil else { return nil }
        let ns = string as NSString
        let onceki = secim.location > 0 ? ns.substring(with: NSRange(location: secim.location - 1, length: 1)).first : nil
        let sonraki = NSMaxRange(secim) < ns.length ? ns.substring(with: NSRange(location: NSMaxRange(secim), length: 1)).first : nil
        return NotDefteriCekirdek.kodEsiEylemi(metin, onceki: onceki, sonraki: sonraki, secimVar: secim.length > 0)
    }

    /// İmleç boş bir eşin ortasındaysa ("(|)") silinecek iki karakterlik aralık.
    func birlikteSilinecekKodEsi() -> NSRange? {
        let secim = selectedRange()
        let ns = string as NSString
        guard isEditable, !hasMarkedText(), secim.length == 0, secim.location > 0, secim.location < ns.length,
              koddakiDil(secim.location) != nil,
              kodEsiBirlikteSilinirMi(onceki: ns.substring(with: NSRange(location: secim.location - 1, length: 1)).first,
                                      sonraki: ns.substring(with: NSRange(location: secim.location, length: 1)).first)
        else { return nil }
        return NSRange(location: secim.location - 1, length: 2)
    }

    /// Satırda yalnızca anahtar kelime varken Tab, dilin kalıbını açar ("try" → try/catch).
    /// Yazım normal metin yolundan geçer: tek geri alma adımıdır, kod öznitelikleri korunur.
    func kodKalibiniAc() -> Bool {
        let secim = selectedRange()
        guard isEditable, !hasMarkedText(), secim.length == 0, let dil = koddakiDil(secim.location),
              let depo = textStorage else { return false }
        let ns = depo.string as NSString
        let satir = ns.lineRange(for: NSRange(location: secim.location, length: 0))
        let sagda = ns.substring(with: NSRange(location: secim.location, length: NSMaxRange(satir) - secim.location))
        guard sagda.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        // Bloğun ilk satırındaki görünmez blok işareti girintiden ya da kelimeden sayılmaz.
        let solda = ns.substring(with: NSRange(location: satir.location, length: secim.location - satir.location))
            .replacingOccurrences(of: "\u{200B}", with: "")
        let girinti = String(solda.prefix { $0 == " " || $0 == "\t" })
        let kelime = String(solda.dropFirst(girinti.count))
        guard !kelime.isEmpty, kelime.allSatisfy({ $0.isLetter }),
              let kalip = kodKalibi(kelime, dil: dil, girinti: girinti, birim: kodGirintiBirimi(secim.location))
        else { return false }
        let aralik = NSRange(location: secim.location - (kelime as NSString).length, length: (kelime as NSString).length)
        insertText(kalip.metin, replacementRange: aralik)
        setSelectedRange(NSRange(location: aralik.location + kalip.imlec, length: 0))
        return true
    }

    /// Kalıp, bloğun mevcut girintisine uyar; girintisiz blokta Tab tuşunun eklediği sekme kullanılır.
    private func kodGirintiBirimi(_ konum: Int) -> String {
        guard let depo = textStorage else { return "\t" }
        var blok = NSRange()
        _ = depo.attribute(kKodBloguAnahtari, at: min(konum, depo.length - 1), longestEffectiveRange: &blok,
                           in: NSRange(location: 0, length: depo.length))
        for satir in (depo.string as NSString).substring(with: blok).components(separatedBy: "\n") {
            if satir.hasPrefix("\t") { return "\t" }
            if satir.hasPrefix("  ") { return "    " }
        }
        return "\t"
    }
}
