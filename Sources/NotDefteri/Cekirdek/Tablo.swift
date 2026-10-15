import Foundation

/// Markdown tablosunda bir satırın görünümdeki görevi. Değer String tutulur; iki
/// platformun da attributed-string köprülemesinde güvenle taşınır.
package enum TabloSatiriTuru: String {
    case cerceve
    case baslik
    case govde
    case govdeAlternatif
}

/// `/tablo` ile oluşturulan güvenli tablo boyutları. Başlık satırı da satır sayısına dahildir.
package let kTabloEnAzSatir = 2
package let kTabloEnCokSatir = 30
package let kTabloEnAzSutun = 2
package let kTabloEnCokSutun = 12

package func tabloBoyutuGecerliMi(satir: Int, sutun: Int) -> Bool {
    (kTabloEnAzSatir...kTabloEnCokSatir).contains(satir) &&
        (kTabloEnAzSutun...kTabloEnCokSutun).contains(sutun)
}

/// Başlık + ayırıcı + gövde satırlarından oluşan standart GFM Markdown tablosu.
package func tabloMarkdownUret(satir: Int, sutun: Int) -> String? {
    guard tabloBoyutuGecerliMi(satir: satir, sutun: sutun) else { return nil }
    func satirMetni(_ hucreler: [String]) -> String { "| " + hucreler.joined(separator: " | ") + " |\n" }
    var sonuc = satirMetni((1...sutun).map { "Başlık \($0)" })
    sonuc += satirMetni(Array(repeating: "---", count: sutun))
    for _ in 1..<satir { sonuc += satirMetni(Array(repeating: "Hücre", count: sutun)) }
    return sonuc
}

/// Dıştaki `|` isteğe bağlıdır. Kaçışlı boru işareti hücreyi bölmez.
package func tabloHucreleri(_ satir: String) -> [String]? {
    let temiz = satir.trimmingCharacters(in: .whitespacesAndNewlines)
    guard temiz.contains("|") else { return nil }
    var govde = temiz
    if govde.hasPrefix("|") { govde.removeFirst() }
    if govde.hasSuffix("|") {
        let kacisSayisi = govde.dropLast().reversed().prefix { $0 == "\\" }.count
        if kacisSayisi.isMultiple(of: 2) { govde.removeLast() }
    }
    var hucreler: [String] = []
    var hucre = ""
    var kacis = false
    for karakter in govde {
        if kacis { hucre.append(karakter); kacis = false }
        else if karakter == "\\" { hucre.append(karakter); kacis = true }
        else if karakter == "|" { hucreler.append(hucre.trimmingCharacters(in: .whitespaces)); hucre = "" }
        else { hucre.append(karakter) }
    }
    hucreler.append(hucre.trimmingCharacters(in: .whitespaces))
    return hucreler.count >= kTabloEnAzSutun ? hucreler : nil
}

package func tabloAyiracSatiriMi(_ satir: String, sutun: Int) -> Bool {
    guard let hucreler = tabloHucreleri(satir), hucreler.count == sutun else { return false }
    return hucreler.allSatisfy { hucre in
        let cizgi = hucre.trimmingCharacters(in: .whitespaces)
        let orta = cizgi.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return orta.count >= 3 && orta.allSatisfy { $0 == "-" }
    }
}

package func tabloAnahtariMi(_ satir: String, sonraki: String) -> Int? {
    guard let hucreler = tabloHucreleri(satir),
          tabloAyiracSatiriMi(sonraki, sutun: hucreler.count) else { return nil }
    return hucreler.count
}

package struct TabloGorsel {
    package let metin: String
    package let satirTurleri: [TabloSatiriTuru]
}

/// Monospace tabloda her hücrenin kapladığı sütun sayısı. Türkçe harfler tek hücredir;
/// CJK ve emoji gibi terminalde çift hücre kaplayan karakterler iki sütun sayılır.
package func tabloGoruntuGenisligi(_ metin: String) -> Int {
    metin.reduce(0) { toplam, karakter in
        guard let ilk = karakter.unicodeScalars.first else { return toplam }
        let genis = (0x1100...0x115F).contains(ilk.value) || (0x2E80...0xA4CF).contains(ilk.value) ||
            (0xAC00...0xD7A3).contains(ilk.value) || (0xF900...0xFAFF).contains(ilk.value) ||
            (0xFF00...0xFF60).contains(ilk.value) || (0x1F300...0x1FAFF).contains(ilk.value)
        return toplam + (genis ? 2 : 1)
    }
}

/// Markdown hücrelerini gerçek bir ızgara hissi veren, düzenlenebilir Unicode kutu çizgilerine dönüştürür.
package func tabloGorunumunuUret(baslik: [String], govde: [[String]]) -> TabloGorsel {
    let tumSatirlar = [baslik] + govde
    let genislikler = baslik.indices.map { sutun in
        max(4, tumSatirlar.map { satir in
            guard satir.indices.contains(sutun) else { return 0 }
            return tabloGoruntuGenisligi(satir[sutun].trimmingCharacters(in: .whitespaces))
        }.max() ?? 0)
    }
    func cizgi(_ sol: Character, _ ara: Character, _ sag: Character) -> String {
        String(sol) + genislikler.map { String(repeating: "─", count: $0 + 2) }.joined(separator: String(ara)) + String(sag) + "\n"
    }
    func hucreSatiri(_ hucreler: [String]) -> String {
        let metinler = genislikler.indices.map { sutun -> String in
            let hucre = sutun < hucreler.count ? hucreler[sutun].trimmingCharacters(in: .whitespaces) : ""
            let bosluk = max(0, genislikler[sutun] - tabloGoruntuGenisligi(hucre))
            return " " + hucre + String(repeating: " ", count: bosluk) + " "
        }
        return "│" + metinler.joined(separator: "│") + "│\n"
    }
    var metin = cizgi("┌", "┬", "┐")
    var turler: [TabloSatiriTuru] = [.cerceve]
    metin += hucreSatiri(baslik); turler.append(.baslik)
    metin += cizgi("├", "┼", "┤"); turler.append(.cerceve)
    for (sira, satir) in govde.enumerated() {
        metin += hucreSatiri(satir)
        turler.append(sira.isMultiple(of: 2) ? .govde : .govdeAlternatif)
    }
    metin += cizgi("└", "┴", "┘"); turler.append(.cerceve)
    return TabloGorsel(metin: metin, satirTurleri: turler)
}

/// Kutulu editör görünümünü standart Markdown tablosuna çevirir. Çerçeve zarar görürse
/// boş dönüş yapılır; böylece kullanıcının metni sessizce kaybolmaz.
package func tabloGorselindenMarkdownUret(_ metin: String) -> String? {
    let hamSatirlar = metin.split(separator: "\n", omittingEmptySubsequences: false)
    let gorunenSatirlar = hamSatirlar.last?.isEmpty == true ? hamSatirlar.dropLast() : hamSatirlar[...]
    guard gorunenSatirlar.count >= 5 else { return nil }

    func cerceveMi(_ satir: Substring, sol: Character, ara: Character, sag: Character) -> Bool {
        guard satir.first == sol, satir.last == sag else { return false }
        return satir.dropFirst().dropLast().allSatisfy { $0 == "─" || $0 == ara }
    }
    guard cerceveMi(gorunenSatirlar.first!, sol: "┌", ara: "┬", sag: "┐"),
          cerceveMi(gorunenSatirlar[gorunenSatirlar.startIndex + 2], sol: "├", ara: "┼", sag: "┤"),
          cerceveMi(gorunenSatirlar.last!, sol: "└", ara: "┴", sag: "┘") else { return nil }

    var satirlar: [[String]] = []
    for (sira, satir) in gorunenSatirlar.enumerated() {
        if sira == 0 || sira == 2 || sira == gorunenSatirlar.count - 1 { continue }
        guard satir.first == "│", satir.last == "│" else { return nil }
        let ic = satir.dropFirst().dropLast().split(separator: "│", omittingEmptySubsequences: false)
        let hucreler = ic.map { String($0).trimmingCharacters(in: .whitespaces) }
        guard hucreler.count >= kTabloEnAzSutun else { return nil }
        satirlar.append(hucreler)
    }
    guard let baslik = satirlar.first, satirlar.dropFirst().allSatisfy({ $0.count == baslik.count }) else { return nil }
    func satirMetni(_ hucreler: [String]) -> String { "| " + hucreler.joined(separator: " | ") + " |\n" }
    var sonuc = satirMetni(baslik)
    sonuc += satirMetni(Array(repeating: "---", count: baslik.count))
    for satir in satirlar.dropFirst() { sonuc += satirMetni(satir) }
    return sonuc
}

/// İlk başlığı seçer; kullanıcı yazmaya başlayınca tablo doğrudan adlandırılabilir.
package func tabloIlkHucreAraligi(sutun: Int) -> NSRange {
    let gorsel = tabloGorunumunuUret(baslik: (1...sutun).map { "Başlık \($0)" },
                                     govde: [Array(repeating: "Hücre", count: sutun)]).metin as NSString
    return gorsel.range(of: "Başlık 1")
}
