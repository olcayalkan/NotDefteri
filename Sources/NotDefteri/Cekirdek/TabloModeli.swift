import Foundation

/// Hücre düzenlemesi yalnızca ilgili kaynak aralığını değiştirir; hizalama, diğer
/// hücrelerin Markdown yazılışı ve satır sonları aynen korunur. Satır sıfır başlıktır.
package struct TabloModeli {
    private var kaynak: String
    private var araliklar: [[NSRange]]

    package init?(markdown: String) {
        let ns = markdown as NSString
        var satirlar: [String] = [], konumlar: [Int] = []
        var konum = 0
        while konum < ns.length {
            let aralik = ns.lineRange(for: NSRange(location: konum, length: 0))
            satirlar.append(ns.substring(with: aralik)); konumlar.append(konum)
            konum = NSMaxRange(aralik)
        }
        guard satirlar.count >= 3,
              let baslik = Self.hucreAraliklari(satirlar[0]),
              baslik.count >= 2, tabloAyiracSatiriMi(satirlar[1], sutun: baslik.count) else { return nil }
        var sonuc: [[NSRange]] = []
        for satir in satirlar.indices where satir != 1 {
            guard let hucreler = Self.hucreAraliklari(satirlar[satir]), hucreler.count == baslik.count else { return nil }
            sonuc.append(hucreler.map { NSRange(location: $0.location + konumlar[satir], length: $0.length) })
        }
        kaynak = markdown; araliklar = sonuc
    }

    package init?(oznitelik: Any?) {
        guard let sozluk = oznitelik as? [String: String], let markdown = sozluk["markdown"] else { return nil }
        self.init(markdown: markdown)
    }

    package var oznitelikDegeri: [String: String] { ["markdown": kaynak] }
    package var satirSayisi: Int { araliklar.count }
    package var sutunSayisi: Int { araliklar.first?.count ?? 0 }
    package func markdown() -> String { kaynak }

    package func hucre(satir: Int, sutun: Int) -> String? {
        guard araliklar.indices.contains(satir), araliklar[satir].indices.contains(sutun) else { return nil }
        return Self.coz((kaynak as NSString).substring(with: araliklar[satir][sutun]))
    }

    /// Gerçek boru ve ters eğik çizgi kaçışlanır. Yapıştırılan CR/LF tek bir `<br>`
    /// olur; hucre() bunu tekrar yeni satır olarak döndürür. Diğer satır içi Markdown
    /// ham metin kalır. Mevcut `<br>` de editörde yeni satır olarak gösterilir.
    /// GFM hücre kenarındaki boşluk/tabı yok sayar; bunlar kaynak paddingine
    /// eklenmez. Yerel hücre editörü yazım sürerken sondaki boşluğu koruyabilir.
    package mutating func hucreyiGuncelle(satir: Int, sutun: Int, metin: String) -> Bool {
        guard let eski = hucre(satir: satir, sutun: sutun) else { return false }
        let temiz = metin.trimmingCharacters(in: .whitespaces)
        if eski == temiz { return true }
        let yeni = temiz.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
        let duzenlenen = (kaynak as NSString).replacingCharacters(in: araliklar[satir][sutun], with: yeni)
        guard let model = Self(markdown: duzenlenen) else { return false }
        self = model
        return true
    }

    private var gorunenHucreler: [[String]] {
        araliklar.indices.map { satir in
            araliklar[satir].indices.map { sutun in
                (hucre(satir: satir, sutun: sutun) ?? "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\n", with: "<br>")
            }
        }
    }

    package func gorsel() -> TabloGorsel {
        let hucreler = gorunenHucreler
        return tabloGorunumunuUret(baslik: hucreler[0], govde: Array(hucreler.dropFirst()))
    }

    /// Görsel içindeki hücre içeriğinin UTF-16 aralığı; sınır/padding içermez.
    /// Hücredeki gerçek `│` karakterleri yapısal ayıraç olarak kullanılmaz.
    package func hucreAraligi(satir: Int, sutun: Int) -> NSRange? {
        guard araliklar.indices.contains(satir), araliklar[satir].indices.contains(sutun) else { return nil }
        let hucreler = gorunenHucreler
        let genislikler = (0..<sutunSayisi).map { s in max(4, hucreler.map { tabloGoruntuGenisligi($0[s]) }.max() ?? 0) }
        let gorselSatirlari = gorsel().metin.components(separatedBy: "\n")
        let gorselSatir = satir == 0 ? 1 : satir + 2
        var baslangic = gorselSatirlari.prefix(gorselSatir).reduce(0) { $0 + ($1 as NSString).length + 1 } + 2
        for s in 0..<sutun {
            let hucre = hucreler[satir][s]
            baslangic += (hucre as NSString).length + max(0, genislikler[s] - tabloGoruntuGenisligi(hucre)) + 3
        }
        return NSRange(location: baslangic, length: (hucreler[satir][sutun] as NSString).length)
    }

    private static func coz(_ metin: String) -> String {
        var sonuc = "", indis = metin.startIndex
        while indis < metin.endIndex {
            let karakter = metin[indis], sonraki = metin.index(after: indis)
            if karakter == "\\", sonraki < metin.endIndex, metin[sonraki] == "\\" || metin[sonraki] == "|" {
                sonuc.append(metin[sonraki]); indis = metin.index(after: sonraki)
            } else { sonuc.append(karakter); indis = sonraki }
        }
        return sonuc.replacingOccurrences(of: "<br>", with: "\n")
    }

    private static func hucreAraliklari(_ satir: String) -> [NSRange]? {
        let ns = satir as NSString
        var bas = 0, son = ns.length
        let bosluk = CharacterSet.whitespacesAndNewlines
        func bosMu(_ i: Int) -> Bool { UnicodeScalar(ns.character(at: i)).map { bosluk.contains($0) } ?? false }
        while bas < son && bosMu(bas) { bas += 1 }
        while son > bas && bosMu(son - 1) { son -= 1 }
        var ayiraclar: [Int] = [], kacis = false
        for i in bas..<son {
            let c = ns.character(at: i)
            if kacis { kacis = false }
            else if c == 92 { kacis = true }
            else if c == 124 { ayiraclar.append(i) }
        }
        guard !ayiraclar.isEmpty else { return nil }
        if ayiraclar.first == bas { bas += 1; ayiraclar.removeFirst() }
        if ayiraclar.last == son - 1 { son -= 1; ayiraclar.removeLast() }
        var sonuc: [NSRange] = [], onceki = bas
        for sinir in ayiraclar + [son] {
            var a = onceki, b = sinir
            while a < b && bosMu(a) { a += 1 }
            while b > a && bosMu(b - 1) { b -= 1 }
            sonuc.append(NSRange(location: a, length: b - a)); onceki = sinir + 1
        }
        return sonuc
    }
}
