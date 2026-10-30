import Foundation

/// [String: Any]: "tablo" (kimlik), "satir", "sutun", "sutunSayisi". Editörde her tablo
/// hücresi kendi paragrafıdır; macOS bunu yerel `NSTextTable` ızgarası olarak çizer.
/// Kutu karakterleri yoktur: hücreler sıradan metin gibi seçilir, silinir, düzenlenir.
/// Kayıtta hücreler yeniden Markdown tablosuna (`| a | b |`) döner.
package let kTabloHucresiAnahtari = NSAttributedString.Key("tabloHucresi")

package struct TabloHucresi: Equatable {
    package let tablo: String
    package let satir: Int
    package let sutun: Int
    package let sutunSayisi: Int

    package init(tablo: String, satir: Int, sutun: Int, sutunSayisi: Int) {
        self.tablo = tablo; self.satir = satir; self.sutun = sutun; self.sutunSayisi = sutunSayisi
    }

    package init?(oznitelik: Any?) {
        guard let s = oznitelik as? [String: Any], let tablo = s["tablo"] as? String,
              let satir = s["satir"] as? Int, let sutun = s["sutun"] as? Int,
              let sutunSayisi = s["sutunSayisi"] as? Int else { return nil }
        self.init(tablo: tablo, satir: satir, sutun: sutun, sutunSayisi: sutunSayisi)
    }

    package var oznitelikDegeri: [String: Any] {
        ["tablo": tablo, "satir": satir, "sutun": sutun, "sutunSayisi": sutunSayisi]
    }
}

/// Anlamsal belgedeki düz Markdown tablolarını hücre paragraflarına böler. Kod bloğundaki
/// `|` satırlarına dokunulmaz. Belgenin sonundaki tablonun arkasına boş satır eklenir;
/// yoksa tablodan sonra yazılan metin son hücreye girerdi.
package func tablolariHucrele(_ anlamsal: NSAttributedString) -> NSAttributedString {
    let ns = anlamsal.string as NSString
    func duzSatir(_ aralik: NSRange) -> String? {
        guard aralik.length > 0,
              anlamsal.attribute(kKodBloguAnahtari, at: aralik.location, effectiveRange: nil) == nil,
              anlamsal.attribute(kTabloHucresiAnahtari, at: aralik.location, effectiveRange: nil) == nil else { return nil }
        return ns.substring(with: aralik)
    }
    var degisiklikler: [(NSRange, NSAttributedString)] = []
    var konum = 0
    while konum < ns.length {
        let baslikAraligi = ns.lineRange(for: NSRange(location: konum, length: 0))
        konum = NSMaxRange(baslikAraligi)
        guard konum < ns.length, let baslikMetni = duzSatir(baslikAraligi) else { continue }
        let ayiracAraligi = ns.lineRange(for: NSRange(location: konum, length: 0))
        guard let ayiracMetni = duzSatir(ayiracAraligi),
              let sutun = tabloAnahtariMi(baslikMetni, sonraki: ayiracMetni),
              let baslik = tabloHucreleri(baslikMetni) else { continue }
        var satirlar = [baslik]
        var son = NSMaxRange(ayiracAraligi)
        while son < ns.length {
            let aralik = ns.lineRange(for: NSRange(location: son, length: 0))
            guard let metin = duzSatir(aralik), let hucreler = tabloHucreleri(metin), hucreler.count == sutun else { break }
            satirlar.append(hucreler)
            son = NSMaxRange(aralik)
        }
        let kapsam = NSRange(location: baslikAraligi.location, length: son - baslikAraligi.location)
        degisiklikler.append((kapsam, tabloHucreleriniUret(satirlar, belgeSonunda: son >= ns.length)))
        konum = son
    }
    guard !degisiklikler.isEmpty else { return anlamsal }
    let sonuc = NSMutableAttributedString(attributedString: anlamsal)
    for (aralik, yeni) in degisiklikler.reversed() { sonuc.replaceCharacters(in: aralik, with: yeni) }
    return sonuc
}

/// Hücre metnindeki `\|` kaçışı ekranda `|` olur; kayıtta yeniden kaçışlanır.
private func tabloHucreleriniUret(_ satirlar: [[String]], belgeSonunda: Bool) -> NSAttributedString {
    let kimlik = UUID().uuidString
    let sutunSayisi = satirlar.map(\.count).max() ?? 0
    let sonuc = NSMutableAttributedString()
    for (satir, hucreler) in satirlar.enumerated() {
        for sutun in 0..<sutunSayisi {
            let metin = (sutun < hucreler.count ? hucreler[sutun] : "").replacingOccurrences(of: "\\|", with: "|")
            var oznitelikler: [NSAttributedString.Key: Any] = [
                kTabloHucresiAnahtari: TabloHucresi(tablo: kimlik, satir: satir, sutun: sutun, sutunSayisi: sutunSayisi).oznitelikDegeri]
            if satir == 0 { oznitelikler[kKalinAnahtari] = true }
            sonuc.append(NSAttributedString(string: metin + "\n", attributes: oznitelikler))
        }
    }
    if belgeSonunda { sonuc.append(NSAttributedString(string: "\n")) }
    return sonuc
}

/// `konum`da başlayan hücre tablosunun aralığı ve Markdown karşılığı. Kopyalanan ya da
/// silinerek eksilen tablo da yazılır: eksik hücre boş kalır, tek satır kalırsa düz satırdır.
package func tabloHucrelerindenMarkdown(_ metin: NSAttributedString, konum: Int) -> (aralik: NSRange, markdown: String)? {
    guard let ilk = TabloHucresi(oznitelik: metin.attribute(kTabloHucresiAnahtari, at: konum, effectiveRange: nil)) else { return nil }
    let ns = metin.string as NSString
    var hucreler: [Int: [Int: String]] = [:]
    var son = konum
    while son < ns.length,
          let hucre = TabloHucresi(oznitelik: metin.attribute(kTabloHucresiAnahtari, at: son, effectiveRange: nil)),
          hucre.tablo == ilk.tablo {
        let paragraf = ns.paragraphRange(for: NSRange(location: son, length: 0))
        let bas = max(son, paragraf.location)
        let yazi = ns.substring(with: NSRange(location: bas, length: NSMaxRange(paragraf) - bas))
            .trimmingCharacters(in: .newlines)
        let onceki = hucreler[hucre.satir]?[hucre.sutun] ?? ""
        hucreler[hucre.satir, default: [:]][hucre.sutun] = [onceki, yazi].filter { !$0.isEmpty }.joined(separator: " ")
        son = NSMaxRange(paragraf)
    }
    let satirlar = hucreler.keys.sorted().map { sira -> [String] in
        let satir = hucreler[sira] ?? [:]
        return (0..<max(ilk.sutunSayisi, (satir.keys.max() ?? 0) + 1)).map { satir[$0] ?? "" }
    }
    let markdown = disTablodanMarkdownUret(satirlar) ?? satirlar
        .map { "| " + $0.map { $0.replacingOccurrences(of: "|", with: "\\|") }.joined(separator: " | ") + " |\n" }
        .joined()
    return (NSRange(location: konum, length: son - konum), markdown)
}

/// Sekmeyle ayrılmış en az iki satırlık blok (tablo uygulamasından ya da düz metin olarak
/// kopyalanan web tablosu) Markdown tablosuna çevrilir; ilk satır başlıktır.
package func sekmeliMetniTabloyaCevir(_ metin: String) -> String {
    guard metin.contains("\t") else { return metin }
    let satirlar = metin.components(separatedBy: "\n")
    var sonuc: [String] = []
    var sira = 0
    func alanlar(_ satir: String) -> [String] {
        satir.trimmingCharacters(in: CharacterSet(charactersIn: "\r")).components(separatedBy: "\t")
    }
    while sira < satirlar.count {
        let sutun = alanlar(satirlar[sira]).count
        var son = sira
        while son < satirlar.count, sutun >= kTabloEnAzSutun, alanlar(satirlar[son]).count == sutun { son += 1 }
        if son - sira >= kTabloEnAzSatir,
           let tablo = disTablodanMarkdownUret(satirlar[sira..<son].map { alanlar($0).map { $0.trimmingCharacters(in: .whitespaces) } }) {
            if let onceki = sonuc.last, !onceki.isEmpty { sonuc.append("") }
            sonuc.append(contentsOf: tablo.split(separator: "\n").map(String.init))
            if son < satirlar.count, !satirlar[son].isEmpty { sonuc.append("") }
            sira = son
        } else {
            sonuc.append(satirlar[sira])
            sira += 1
        }
    }
    return sonuc.joined(separator: "\n")
}
