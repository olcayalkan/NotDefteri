import Foundation

package struct MetinBlogu: Hashable {
    package enum Tur: String { case madde, numarali, yapilacak, alinti, ayirici, uyari }
    package var tur: Tur
    package var seviye = 0
    package var numara = 1
    package var tamamlandi = false
    package var emoji = "💡"
    package var renk = "sarı"
    package var devam = false
    package var uyariKimligi = ""
    // Açılan dosyanın yıldız/numara/girinti seçimi düzenlenene kadar korunur.
    package var kaynakOnEk: String?

    package init(tur: Tur, seviye: Int = 0, numara: Int = 1, tamamlandi: Bool = false,
                 emoji: String = "💡", renk: String = "sarı", devam: Bool = false,
                 uyariKimligi: String = "", kaynakOnEk: String? = nil) {
        self.tur = tur
        self.seviye = seviye
        self.numara = numara
        self.tamamlandi = tamamlandi
        self.emoji = emoji
        self.renk = renk
        self.devam = devam
        self.uyariKimligi = uyariKimligi
        self.kaynakOnEk = kaynakOnEk
    }

    package var listeMi: Bool { tur == .madde || tur == .numarali || tur == .yapilacak }
    package var isaret: String {
        switch tur {
        case .madde: return "•\t"
        case .numarali: return "\(numara).\t"
        case .yapilacak: return tamamlandi ? "☑\t" : "☐\t"
        case .alinti, .ayirici, .uyari: return "\u{200B}"
        }
    }
    package var markdownOnEki: String {
        if let kaynakOnEk { return kaynakOnEk }
        let girinti = String(repeating: "  ", count: seviye)
        switch tur {
        case .madde: return girinti + "- "
        case .numarali: return girinti + "\(numara). "
        case .yapilacak: return girinti + (tamamlandi ? "- [x] " : "- [ ] ")
        case .alinti: return girinti + "> "
        case .ayirici: return girinti + "---"
        case .uyari: return girinti + (devam ? "> " : "> [!\(emoji) \(renk)] ")
        }
    }
    package var oznitelikler: [NSAttributedString.Key: Any] {
        var sonuc: [NSAttributedString.Key: Any] = [
            kMetinBloguAnahtari: anlamsalDeger,
            kParagrafGeometrisiAnahtari: paragrafGeometrisi]
        if tur == .uyari {
            sonuc[kUyariKutusuAnahtari] = uyariKimligi
            sonuc[kBlokKimligiAnahtari] = uyariKimligi
        }
        return sonuc
    }

    /// NSAttributedString içinde Swift modeli değil, Foundation sözlüğü taşınır.
    package var anlamsalDeger: [String: Any] {
        var deger: [String: Any] = ["tur": tur.rawValue, "seviye": seviye, "numara": numara,
            "tamamlandi": tamamlandi, "emoji": emoji, "renk": renk, "devam": devam,
            "uyariKimligi": uyariKimligi]
        deger["kaynakOnEk"] = kaynakOnEk
        return deger
    }

    /// Numara genişliği platform fontuyla ölçülür; diğer ölçüler taban punto uzayındadır.
    package var paragrafGeometrisi: [String: Any] {
        let girinti = Double(seviye) * 24
        return ["ilkSatirGirintisi": girinti + (tur == .alinti || tur == .uyari ? 24 : 0),
                "govdeGirintisi": girinti + (listeMi || tur == .alinti || tur == .uyari ? 24 : 0),
                "sekmeAraligi": 24.0, "enAzSatirYuksekligi": tur == .ayirici ? 20.0 : 0.0,
                "paragrafBoslugu": tur == .uyari ? 4.0 : 0.0,
                "numaraMetni": tur == .numarali ? "\(numara)." : "",
                "isaretEnAzGenisligi": 24.0, "isaretSonuBoslugu": 8.0]
    }

}

extension MetinBlogu {
    package init?(oznitelik: Any?) {
        guard let deger = oznitelik as? [String: Any], let ad = deger["tur"] as? String,
              let tur = Tur(rawValue: ad) else { return nil }
        self.init(tur: tur, seviye: deger["seviye"] as? Int ?? 0,
                  numara: deger["numara"] as? Int ?? 1, tamamlandi: deger["tamamlandi"] as? Bool ?? false,
                  emoji: deger["emoji"] as? String ?? "💡", renk: deger["renk"] as? String ?? "sarı",
                  devam: deger["devam"] as? Bool ?? false, uyariKimligi: deger["uyariKimligi"] as? String ?? "",
                  kaynakOnEk: deger["kaynakOnEk"] as? String)
    }
}

private let kBlokOnEkDeseni = try! NSRegularExpression(
    pattern: #"^( *)(- \[[ xX]\] |\[ \] |\[\] |[-*] |[0-9]+\. |> |---$)"#)
private let kUyariOnEkDeseni = try! NSRegularExpression(
    pattern: #"^( *)> \[!([^\]\s]+) (gri|mavi|sarı|kırmızı|yeşil)\](?: |$)"#)

package func emojiGecerliMi(_ deger: String) -> Bool {
    let tusEmojisi = deger.unicodeScalars.contains { $0.value == 0x20E3 }
    return deger.count == 1 && deger.unicodeScalars.contains {
        $0.properties.isEmoji && ($0.value > 127 || tusEmojisi)
    }
}

package func metinBlogunuCozumle(_ satir: String) -> (blok: MetinBlogu, uzunluk: Int)? {
    let ns = NSString(string: satir)
    if let eslesme = kUyariOnEkDeseni.firstMatch(in: satir, range: NSRange(location: 0, length: ns.length)),
       eslesme.range(at: 1).length % 2 == 0 {
        let emoji = ns.substring(with: eslesme.range(at: 2))
        if emojiGecerliMi(emoji) {
            var blok = MetinBlogu(tur: .uyari, seviye: eslesme.range(at: 1).length / 2,
                                 emoji: emoji, renk: ns.substring(with: eslesme.range(at: 3)), uyariKimligi: UUID().uuidString)
            blok.kaynakOnEk = ns.substring(with: eslesme.range)
            return (blok, eslesme.range.length)
        }
    }
    guard let eslesme = kBlokOnEkDeseni.firstMatch(in: satir, range: NSRange(location: 0, length: ns.length)) else { return nil }
    let bosluklar = eslesme.range(at: 1).length
    guard bosluklar % 2 == 0 else { return nil }
    let onEk = ns.substring(with: eslesme.range(at: 2))
    var blok: MetinBlogu
    if onEk == "---" { blok = MetinBlogu(tur: .ayirici) }
    else if onEk == "> " { blok = MetinBlogu(tur: .alinti) }
    else if onEk.contains("[") {
        blok = MetinBlogu(tur: .yapilacak, tamamlandi: onEk.lowercased().contains("x"))
    } else if onEk == "- " || onEk == "* " { blok = MetinBlogu(tur: .madde) }
    else {
        guard let numara = Int(onEk.dropLast(2)), numara > 0 else { return nil }
        blok = MetinBlogu(tur: .numarali, numara: numara)
    }
    blok.seviye = bosluklar / 2
    blok.kaynakOnEk = ns.substring(with: eslesme.range)
    return (blok, eslesme.range.length)
}

package func blokIsaretiniUret(_ blok: MetinBlogu) -> NSAttributedString {
    var oznitelikler = blok.oznitelikler
    oznitelikler[kBlokIsaretiAnahtari] = true
    return NSAttributedString(string: blok.isaret, attributes: oznitelikler)
}

package func blokBiciminiUygula(_ blok: MetinBlogu, metne metin: NSMutableAttributedString, aralik: NSRange) {
    guard aralik.length > 0 else { return }
    metin.addAttributes(blok.oznitelikler, range: aralik)
    if blok.tur != .uyari {
        metin.removeAttribute(kUyariKutusuAnahtari, range: aralik)
        metin.removeAttribute(kBlokKimligiAnahtari, range: aralik)
    }
    metin.removeAttribute(kBaslikSeviyesiAnahtari, range: aralik)
}

package func blokBiciminiKaldir(_ metin: NSMutableAttributedString) {
    let aralik = NSRange(location: 0, length: metin.length)
    for anahtar in [kMetinBloguAnahtari, kBlokIsaretiAnahtari, kUyariKutusuAnahtari,
                   kBlokKimligiAnahtari, kParagrafGeometrisiAnahtari] {
        metin.removeAttribute(anahtar, range: aralik)
    }
}

package func blokIsaretiUzunlugu(_ metin: NSAttributedString, konum: Int = 0) -> Int {
    guard konum < metin.length else { return 0 }
    var aralik = NSRange()
    guard metin.attribute(kBlokIsaretiAnahtari, at: konum, effectiveRange: &aralik) as? Bool == true else { return 0 }
    return NSMaxRange(aralik) - konum
}


package func blokNumaralariniGuncelle(_ metin: NSMutableAttributedString, secim: inout NSRange) {
    var sayaclar: [Int: Int] = [:]
    var konum = 0
    while konum < metin.length {
        var paragraf = NSString(string: metin.string).paragraphRange(for: NSRange(location: konum, length: 0))
        guard var blok = MetinBlogu(oznitelik: metin.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil)),
              blok.listeMi else {
            sayaclar.removeAll()
            konum = NSMaxRange(paragraf)
            continue
        }
        sayaclar = sayaclar.filter { $0.key <= blok.seviye }
        if blok.tur == .numarali {
            let onceki = sayaclar[blok.seviye]
            let numara = onceki.map { $0 == Int.max ? Int.max : $0 + 1 } ?? blok.numara
            sayaclar[blok.seviye] = numara
            if blok.numara != numara {
                let eskiUzunluk = blokIsaretiUzunlugu(metin, konum: konum)
                blok.numara = numara
                blok.kaynakOnEk = nil
                let isaret = blokIsaretiniUret(blok)
                metin.replaceCharacters(in: NSRange(location: konum, length: eskiUzunluk), with: isaret)
                let fark = isaret.length - eskiUzunluk
                if secim.location >= konum + eskiUzunluk { secim.location += fark }
                if NSMaxRange(secim) >= konum + eskiUzunluk, secim.location < konum + eskiUzunluk { secim.length += fark }
                paragraf.length += fark
                blokBiciminiUygula(blok, metne: metin, aralik: paragraf)
            }
        } else { sayaclar.removeValue(forKey: blok.seviye) }
        konum = NSMaxRange(paragraf)
    }
}

package func kodBloguSinirlari(acilis: String, kapanis: String) -> [String: String] {
    ["acilis": acilis, "kapanis": kapanis, "kimlik": UUID().uuidString]
}

/// Açılış satırı kayıtta aynen kalır; yalnızca görünüm için dil etiketi okunur.
package func kodBloguDilEtiketi(_ sinirlar: [String: String]) -> String {
    let acilis = sinirlar["acilis"] ?? ""
    return acilis.drop(while: { $0 == "`" }).split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
}

package func kodBloguGovdesi(_ metin: NSAttributedString) -> String {
    var sonuc = ""
    let ns = NSString(string: metin.string)
    metin.enumerateAttributes(in: NSRange(location: 0, length: metin.length)) { oznitelikler, alt, _ in
        if oznitelikler[kBlokIsaretiAnahtari] as? Bool != true,
           oznitelikler[kBosKodSatiriAnahtari] as? Bool != true { sonuc += ns.substring(with: alt) }
    }
    return sonuc
}
