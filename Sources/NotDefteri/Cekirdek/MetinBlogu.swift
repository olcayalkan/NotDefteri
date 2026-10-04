import AppKit

let kMetinBloguAnahtari = NSAttributedString.Key("metinBlogu")
// Görünen işaret metne dahildir; Markdown'a yalnızca blok öneki yazılır.
let kBlokIsaretiAnahtari = NSAttributedString.Key("blokIsareti")
let kUyariKutusuAnahtari = NSAttributedString.Key("uyariKutusu")

struct MetinBlogu: Hashable {
    enum Tur { case madde, numarali, yapilacak, alinti, ayirici, uyari }
    var tur: Tur
    var seviye = 0
    var numara = 1
    var tamamlandi = false
    var emoji = "💡"
    var renk = "sarı"
    var devam = false
    var uyariKimligi = ""
    // Açılan dosyanın yıldız/numara/girinti seçimi düzenlenene kadar korunur.
    var kaynakOnEk: String?

    var listeMi: Bool { tur == .madde || tur == .numarali || tur == .yapilacak }
    var isaret: String {
        switch tur {
        case .madde: return "•\t"
        case .numarali: return "\(numara).\t"
        case .yapilacak: return tamamlandi ? "☑\t" : "☐\t"
        case .alinti, .ayirici: return "\u{200B}"
        case .uyari: return devam ? "\u{200B}" : emoji + "\t"
        }
    }
    var markdownOnEki: String {
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
    var oznitelikler: [NSAttributedString.Key: Any] {
        let stil = NSMutableParagraphStyle()
        let girinti = CGFloat(seviye) * 24
        let isaretGenisligi = tur == .numarali
            ? max(24, ("\(numara)." as NSString).size(withAttributes: [.font: varsayilanFont()]).width + 8) : 24
        stil.firstLineHeadIndent = tur == .alinti ? girinti + 24 : girinti
        stil.headIndent = listeMi || tur == .alinti ? girinti + isaretGenisligi : girinti
        stil.tabStops = [NSTextTab(textAlignment: .left, location: stil.headIndent)]
        stil.defaultTabInterval = 24
        if tur == .ayirici { stil.minimumLineHeight = 20 }
        if tur == .uyari {
            stil.firstLineHeadIndent = girinti + (devam ? 40 : 8)
            stil.headIndent = girinti + 40
            stil.tabStops = [NSTextTab(textAlignment: .left, location: stil.headIndent)]
            stil.paragraphSpacingBefore = 4
            stil.paragraphSpacing = 4
        }
        var sonuc: [NSAttributedString.Key: Any] = [kMetinBloguAnahtari: self, .paragraphStyle: stil]
        if tur == .uyari { sonuc[kUyariKutusuAnahtari] = uyariKimligi }
        return sonuc
    }
}

private let kBlokOnEkDeseni = try! NSRegularExpression(
    pattern: #"^( *)(- \[[ xX]\] |\[ \] |\[\] |[-*] |[0-9]+\. |> |---$)"#)
private let kUyariOnEkDeseni = try! NSRegularExpression(
    pattern: #"^( *)> \[!([^\]\s]+) (gri|mavi|sarı|kırmızı|yeşil)\](?: |$)"#)

func emojiGecerliMi(_ deger: String) -> Bool {
    let tusEmojisi = deger.unicodeScalars.contains { $0.value == 0x20E3 }
    return deger.count == 1 && deger.unicodeScalars.contains {
        $0.properties.isEmoji && ($0.value > 127 || tusEmojisi)
    }
}

func metinBlogunuCozumle(_ satir: String) -> (blok: MetinBlogu, uzunluk: Int)? {
    let ns = satir as NSString
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

func blokIsaretiniUret(_ blok: MetinBlogu) -> NSAttributedString {
    var oznitelikler = blok.oznitelikler
    oznitelikler[.font] = varsayilanFont()
    oznitelikler[.foregroundColor] = kMetinRenk
    oznitelikler[kBlokIsaretiAnahtari] = true
    return NSAttributedString(string: blok.isaret, attributes: oznitelikler)
}

func blokBiciminiUygula(_ blok: MetinBlogu, metne metin: NSMutableAttributedString, aralik: NSRange) {
    guard aralik.length > 0 else { return }
    metin.addAttributes(blok.oznitelikler, range: aralik)
    if blok.tur != .uyari { metin.removeAttribute(kUyariKutusuAnahtari, range: aralik) }
    metin.removeAttribute(kBaslikSeviyesiAnahtari, range: aralik)
    metin.removeAttribute(.strikethroughStyle, range: aralik)
    metin.enumerateAttribute(kUstuCiziliAnahtari, in: aralik) { deger, alt, _ in
        if deger as? Bool == true { metin.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: alt) }
    }
    metin.addAttribute(.foregroundColor, value: kMetinRenk, range: aralik)
    if blok.tur == .yapilacak, blok.tamamlandi {
        metin.enumerateAttribute(kBlokIsaretiAnahtari, in: aralik) { isaret, alt, _ in
            guard isaret == nil else { return }
            metin.addAttributes([.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                 .foregroundColor: kMetinRenk.withAlphaComponent(0.45)], range: alt)
        }
    }
}

func blokBiciminiKaldir(_ metin: NSMutableAttributedString) {
    let aralik = NSRange(location: 0, length: metin.length)
    for anahtar in [kMetinBloguAnahtari, kBlokIsaretiAnahtari, kUyariKutusuAnahtari, .paragraphStyle, .strikethroughStyle] {
        metin.removeAttribute(anahtar, range: aralik)
    }
    metin.addAttribute(.foregroundColor, value: kMetinRenk, range: aralik)
    metin.enumerateAttribute(kUstuCiziliAnahtari, in: aralik) { deger, alt, _ in
        if deger as? Bool == true { metin.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: alt) }
    }
}

func blokIsaretiUzunlugu(_ metin: NSAttributedString, konum: Int = 0) -> Int {
    guard konum < metin.length else { return 0 }
    var aralik = NSRange()
    guard metin.attribute(kBlokIsaretiAnahtari, at: konum, effectiveRange: &aralik) as? Bool == true else { return 0 }
    return NSMaxRange(aralik) - konum
}


func blokNumaralariniGuncelle(_ metin: NSMutableAttributedString, secim: inout NSRange) {
    var sayaclar: [Int: Int] = [:]
    var konum = 0
    while konum < metin.length {
        var paragraf = (metin.string as NSString).paragraphRange(for: NSRange(location: konum, length: 0))
        guard var blok = metin.attribute(kMetinBloguAnahtari, at: konum, effectiveRange: nil) as? MetinBlogu,
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

func kodBloguSinirlari(acilis: String, kapanis: String) -> [String: String] {
    ["acilis": acilis, "kapanis": kapanis, "kimlik": UUID().uuidString]
}

/// Açılış satırı kayıtta aynen kalır; yalnızca görünüm için dil etiketi okunur.
func kodBloguDilEtiketi(_ sinirlar: [String: String]) -> String {
    let acilis = sinirlar["acilis"] ?? ""
    return acilis.drop(while: { $0 == "`" }).split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
}

func kodBloguGovdesi(_ metin: NSAttributedString) -> String {
    var sonuc = ""
    let ns = metin.string as NSString
    metin.enumerateAttributes(in: NSRange(location: 0, length: metin.length)) { oznitelikler, alt, _ in
        if oznitelikler[kBlokIsaretiAnahtari] as? Bool != true,
           oznitelikler[kBosKodSatiriAnahtari] as? Bool != true { sonuc += ns.substring(with: alt) }
    }
    return sonuc
}
