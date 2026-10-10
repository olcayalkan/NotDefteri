import Foundation

package struct YapiEnterDegisimi {
    package let aralik: NSRange
    package let metin: NSAttributedString
    package let imlec: Int
    package let yazim: [NSAttributedString.Key: Any]
}

/// Yalnızca ilgili paragraf/blok ve komşu liste okunur; girdi değiştirilmez.
/// Boş satırın işareti depoda kalır: karar yazım özniteliklerine bağlı değildir.
package func yapiEnterKurali(_ belge: NSAttributedString, imlec: NSRange, koddanCik: Bool = false) -> YapiEnterDegisimi? {
    guard imlec.location >= 0, imlec.length >= 0, imlec.location <= belge.length,
          imlec.length <= belge.length - imlec.location, belge.length > 0 else { return nil }
    let ns = (belge as? NSMutableAttributedString)?.mutableString ?? (belge.string as NSString)
    let paragraf = ns.paragraphRange(for: NSRange(location: imlec.location, length: 0))
    let konum = min(paragraf.location, belge.length - 1)
    let kod = belge.attribute(kKodBloguAnahtari, at: konum, effectiveRange: nil) as? [String: String]
    if koddanCik {
        // Açık çıkış her konumdan kutunun altına gider; gövdeyi ve boş satırları korur.
        guard var kod, imlec.length == 0 else { return nil }
        var tam = NSRange()
        _ = belge.attribute(kKodBloguAnahtari, at: konum, longestEffectiveRange: &tam,
                            in: NSRange(location: 0, length: belge.length))
        let yeni = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: tam))
        if (kod["kapanis"] ?? "").isEmpty {
            kod["kapanis"] = (kodBloguAyiraci(kod["acilis"] ?? "") ?? "```") + "\n"
            yeni.addAttribute(kKodBloguAnahtari, value: kod, range: NSRange(location: 0, length: yeni.length))
        }
        if !yeni.string.hasSuffix("\n") {
            yeni.append(NSAttributedString(string: "\n", attributes: yeni.attributes(at: yeni.length - 1, effectiveRange: nil)))
        }
        let hedef = tam.location + yeni.length
        yeni.append(NSAttributedString(string: "\n"))
        return YapiEnterDegisimi(aralik: tam, metin: yeni, imlec: hedef, yazim: [:])
    }
    let blok = MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil))
    let baslik = paragraf.length > 0 ? belge.attribute(kBaslikSeviyesiAnahtari, at: konum, effectiveRange: nil) : nil
    guard kod != nil || blok != nil || baslik != nil else { return nil }
    // Seçim başka paragrafa taşarsa normal seçim değiştirme yolu kullanılır.
    guard NSMaxRange(imlec) <= NSMaxRange(paragraf) else { return nil }
    let eski = belge.attributedSubstring(from: paragraf)
    let isaret = blokIsaretiUzunlugu(eski)
    let bos = kodBloguGovdesi(eski).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let cik = kod == nil && bos && baslik == nil && blok?.tur != .ayirici
    var kapsam = paragraf
    if kod != nil || blok?.tur == .uyari {
        var tam = NSRange()
        _ = belge.attribute(kod != nil ? kKodBloguAnahtari : kUyariKutusuAnahtari,
                            at: konum, longestEffectiveRange: &tam,
                            in: NSRange(location: 0, length: belge.length))
        if cik { kapsam = NSUnionRange(kapsam, tam) }
    }
    if blok?.listeMi == true { kapsam = enterListeAraligi(belge, ns: ns, paragraf: paragraf) }
    let yeni = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: kapsam))
    var hedef: Int
    var yazim: [NSAttributedString.Key: Any] = [:]
    if cik {
        let yerel = NSRange(location: paragraf.location - kapsam.location, length: paragraf.length)
        // Tek normal boş paragraf; yapının içinde fazladan satır bırakılmaz.
        yeni.replaceCharacters(in: yerel, with: NSAttributedString(string: "\n"))
        hedef = yerel.location
        enterAltYapiyiAyir(yeni, bas: hedef + 1, kod: kod, blok: blok, kimlikEki: "-enter-\(paragraf.location)")
        if let kod, hedef > 0 {
            var sinirlar = kod
            if (sinirlar["kapanis"] ?? "").isEmpty { sinirlar["kapanis"] = "```\n" }
            yeni.addAttribute(kKodBloguAnahtari, value: sinirlar, range: NSRange(location: 0, length: hedef))
        }
    } else {
        let bas = max(isaret, imlec.location - paragraf.location)
        let son = max(bas, NSMaxRange(imlec) - paragraf.location)
        let yerel = NSRange(location: paragraf.location - kapsam.location + bas, length: son - bas)
        yazim = enterYazimOznitelikleri(belge.attributes(at: min(max(konum, imlec.location - 1), belge.length - 1), effectiveRange: nil))
        if let kod {
            yazim[kKodBloguAnahtari] = kod
            yazim[kKodBloguDiliAnahtari] = kodBloguDilEtiketi(kod)
            yazim[kBlokKimligiAnahtari] = kod["kimlik"] ?? ""
        } else if let blok { yazim.merge(blok.oznitelikler) { _, yeni in yeni } }
        let ek = NSMutableAttributedString(string: "\n", attributes: yazim)
        var altYazim = yazim
        if baslik != nil || blok?.tur == .ayirici {
            altYazim = [:]
        } else if var devam = blok {
            devam.kaynakOnEk = nil
            devam.tamamlandi = false
            if devam.tur == .uyari { devam.devam = true }
            if devam.tur == .numarali { devam.numara = devam.numara == Int.max ? 1 : devam.numara + 1 }
            altYazim.merge(devam.oznitelikler) { _, yeni in yeni }
            ek.append(blokIsaretiniUret(devam))
        } else if kod != nil {
            var isaretYazimi = altYazim
            isaretYazimi[kBlokIsaretiAnahtari] = true
            ek.append(NSAttributedString(string: "\u{200B}", attributes: isaretYazimi))
        }
        yeni.replaceCharacters(in: yerel, with: ek)
        hedef = yerel.location + ek.length
        let altBas = yerel.location + 1
        let altSon = NSMaxRange(paragraf) - kapsam.location + ek.length - yerel.length
        // Kuyruk yeni paragrafın anlamını alır; eski işaret/kaynak yazımı taşınmaz.
        let alt = NSRange(location: altBas, length: max(0, altSon - altBas))
        if baslik != nil || blok?.tur == .ayirici {
            for anahtar in enterYapiAnahtarlari + [kKalinAnahtari, kItalikAnahtari, kPuntoOlcegiAnahtari] {
                yeni.removeAttribute(anahtar, range: alt)
            }
        } else {
            yeni.removeAttribute(kMarkdownKaynakAnahtari, range: alt)
            yeni.addAttributes(altYazim, range: alt)
        }
        yazim = altYazim
    }
    var secim = NSRange(location: hedef, length: 0)
    if blok?.listeMi == true {
        blokNumaralariniGuncelle(yeni, secim: &secim)
        if !cik, secim.location < yeni.length,
           let devam = MetinBlogu(oznitelik: yeni.attribute(kMetinBloguAnahtari, at: secim.location, effectiveRange: nil)) {
            yazim.merge(devam.oznitelikler) { _, yeni in yeni }
        }
    }
    return YapiEnterDegisimi(aralik: kapsam, metin: yeni, imlec: kapsam.location + secim.location, yazim: yazim)
}

private let enterYapiAnahtarlari = [kBaslikSeviyesiAnahtari, kMetinBloguAnahtari, kKodBloguAnahtari,
    kKodBloguDiliAnahtari, kBlokKimligiAnahtari, kUyariKutusuAnahtari, kParagrafGeometrisiAnahtari,
    kBlokIsaretiAnahtari, kBosKodSatiriAnahtari, kMarkdownKaynakAnahtari]

private func enterYazimOznitelikleri(_ o: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
    let anahtarlar = [kKalinAnahtari, kItalikAnahtari, kUstuCiziliAnahtari, kSatirIciKodAnahtari,
        kVurguAnahtari, kPuntoOlcegiAnahtari, kBaslikSeviyesiAnahtari]
    return o.filter { anahtarlar.contains($0.key) }
}

private func enterListeAraligi(_ belge: NSAttributedString, ns: NSString, paragraf: NSRange) -> NSRange {
    var bas = paragraf.location, son = NSMaxRange(paragraf)
    while bas > 0 {
        let p = ns.paragraphRange(for: NSRange(location: bas - 1, length: 0))
        guard MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: p.location, effectiveRange: nil))?.listeMi == true else { break }
        bas = p.location
    }
    while son < belge.length {
        let p = ns.paragraphRange(for: NSRange(location: son, length: 0))
        guard MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: son, effectiveRange: nil))?.listeMi == true else { break }
        son = NSMaxRange(p)
    }
    return NSRange(location: bas, length: son - bas)
}

/// Bölünen alt kutu kendi başlangıcını taşır; dil ve renk korunur.
private func enterAltYapiyiAyir(_ yeni: NSMutableAttributedString, bas: Int, kod: [String: String]?,
                              blok: MetinBlogu?, kimlikEki: String) {
    guard bas < yeni.length else { return }
    if var kod {
        kod["kimlik"] = (kod["kimlik"] ?? "kod") + kimlikEki
        if (kod["kapanis"] ?? "").isEmpty { kod["kapanis"] = "```\n" }
        let alt = NSRange(location: bas, length: yeni.length - bas)
        yeni.removeAttribute(kMarkdownKaynakAnahtari, range: alt)
        yeni.addAttributes([kKodBloguAnahtari: kod, kBlokKimligiAnahtari: kod["kimlik"]!], range: alt)
        let isaret: [NSAttributedString.Key: Any] = [kKodBloguAnahtari: kod,
            kKodBloguDiliAnahtari: kodBloguDilEtiketi(kod), kBlokKimligiAnahtari: kod["kimlik"]!, kBlokIsaretiAnahtari: true]
        // Aynı anlamsal gövde, bağımsız bloğun görünmez başlangıcını alır.
        yeni.insert(NSAttributedString(string: "\u{200B}", attributes: isaret), at: bas)
    } else if var blok, blok.tur == .uyari {
        blok.uyariKimligi += kimlikEki
        var konum = bas
        var ilk = true
        while konum < yeni.length {
            let p = yeni.mutableString.paragraphRange(for: NSRange(location: konum, length: 0))
            blok.devam = !ilk
            blok.kaynakOnEk = nil
            yeni.removeAttribute(kMarkdownKaynakAnahtari, range: p)
            blokBiciminiUygula(blok, metne: yeni, aralik: p)
            konum = NSMaxRange(p)
            ilk = false
        }
    } else if blok?.tur == .numarali,
              var ilk = MetinBlogu(oznitelik: yeni.attribute(kMetinBloguAnahtari, at: bas, effectiveRange: nil)), ilk.tur == .numarali {
        ilk.numara = 1
        ilk.kaynakOnEk = nil
        var p = yeni.mutableString.paragraphRange(for: NSRange(location: bas, length: 0))
        let eskiIsaret = blokIsaretiUzunlugu(yeni, konum: bas)
        let isaret = blokIsaretiniUret(ilk)
        yeni.replaceCharacters(in: NSRange(location: bas, length: eskiIsaret), with: isaret)
        p.length += isaret.length - eskiIsaret
        blokBiciminiUygula(ilk, metne: yeni, aralik: p)
    }
}

/// Devam satırının işareti ve önceki satır sonu birlikte silinir; ilk işaret kalır.
/// Enter'ın değişim modeli kullanılır: iki platform da aynı anlamı tek undo ile uygular.
package func yapiDevamindaGeriSil(_ belge: NSAttributedString, imlec: NSRange) -> YapiEnterDegisimi? {
    guard imlec.length == 0, imlec.location > 0, imlec.location <= belge.length else { return nil }
    let ns = (belge as? NSMutableAttributedString)?.mutableString ?? (belge.string as NSString)
    let paragraf = ns.paragraphRange(for: imlec)
    guard paragraf.location > 0, paragraf.length > 0 else { return nil }
    var isaret = NSRange()
    let isaretli = belge.attribute(kBlokIsaretiAnahtari, at: paragraf.location,
                                   longestEffectiveRange: &isaret, in: paragraf) as? Bool == true
    let isaretUzunlugu = isaretli ? isaret.length : 0
    guard imlec.location <= paragraf.location + isaretUzunlugu else { return nil }
    let onceki = ns.paragraphRange(for: NSRange(location: paragraf.location - 1, length: 0))
    let ust = MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: onceki.location, effectiveRange: nil))
    let alt = MetinBlogu(oznitelik: belge.attribute(kMetinBloguAnahtari, at: paragraf.location, effectiveRange: nil))
    let kod = belge.attribute(kKodBloguAnahtari, at: paragraf.location, effectiveRange: nil) as? [String: String]
    if let kod {
        guard belge.attribute(kKodBloguAnahtari, at: onceki.location, effectiveRange: nil) as? [String: String] == kod else { return nil }
    } else {
        guard let ust, let alt, ust.tur == alt.tur, ust.seviye == alt.seviye,
              ust.listeMi || ust.tur == .alinti || (ust.tur == .uyari && ust.uyariKimligi == alt.uyariKimligi) else { return nil }
    }
    let kapsam = ust?.listeMi == true && kod == nil
        ? enterListeAraligi(belge, ns: ns, paragraf: paragraf) : NSUnionRange(onceki, paragraf)
    let yeni = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: kapsam))
    let govdeSonu = (ns.substring(with: onceki).trimmingCharacters(in: .newlines) as NSString).length
    let silinecek = NSRange(location: onceki.location - kapsam.location + govdeSonu,
                           length: onceki.length - govdeSonu + isaretUzunlugu)
    yeni.deleteCharacters(in: silinecek)
    let birlesen = NSRange(location: onceki.location - kapsam.location,
                           length: onceki.length + paragraf.length - silinecek.length)
    // Enter geri birleşince özgün satır sonları da korunur. Yazıcı yalnızca
    // kanonik içerik hâlâ eşitse kaynağı kullanır; değişen gövde eski kayda dönmez.
    if let kaynak = belge.attribute(kMarkdownKaynakAnahtari, at: onceki.location, effectiveRange: nil) {
        yeni.addAttribute(kMarkdownKaynakAnahtari, value: kaynak, range: birlesen)
    }
    if let ust, kod == nil { blokBiciminiUygula(ust, metne: yeni, aralik: birlesen) }
    var secim = NSRange(location: silinecek.location, length: 0)
    if ust?.listeMi == true, kod == nil { blokNumaralariniGuncelle(yeni, secim: &secim) }
    var yazim = enterYazimOznitelikleri(belge.attributes(at: max(onceki.location, onceki.location + govdeSonu - 1), effectiveRange: nil))
    if let kod {
        yazim[kKodBloguAnahtari] = kod
        yazim[kKodBloguDiliAnahtari] = kodBloguDilEtiketi(kod)
        yazim[kBlokKimligiAnahtari] = kod["kimlik"] ?? ""
    } else if let ust {
        let guncel = MetinBlogu(oznitelik: yeni.attribute(kMetinBloguAnahtari, at: min(secim.location, yeni.length - 1), effectiveRange: nil)) ?? ust
        yazim.merge(guncel.oznitelikler) { _, yeni in yeni }
    }
    return YapiEnterDegisimi(aralik: kapsam, metin: yeni, imlec: kapsam.location + secim.location, yazim: yazim)
}
