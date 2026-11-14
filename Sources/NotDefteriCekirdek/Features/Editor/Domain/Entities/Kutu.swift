import Foundation

/// Kod bloğu ve uyarı kutusu aynı kutudur: sınırı, Enter'ı, üçüncü Enter'da ve Ctrl+Enter'la çıkışı
/// ortak kuraldır. Tür yalnızca farkını override eder; iki kutu ayrı yollarda farklılaşmasın.
package protocol Kutu {
    /// Kutunun metne yayılan özniteliği; kutunun sınırı bu özniteliğin kesintisiz aralığıdır.
    static var anahtar: NSAttributedString.Key { get }
    /// Gövde kısaldığında türe özgü kapanış (kod: kapanmamış çit kapatılır). Varsayılanı yoktur.
    func kapat(_ govde: NSMutableAttributedString)
}

package extension Kutu {
    func kapat(_ govde: NSMutableAttributedString) {}

    /// Konumu içeren kutunun tamamı.
    func aralik(_ belge: NSAttributedString, konum: Int) -> NSRange {
        var tam = NSRange()
        _ = belge.attribute(Self.anahtar, at: konum, longestEffectiveRange: &tam,
                            in: NSRange(location: 0, length: belge.length))
        return tam
    }

    /// `kapsam` gövdeye iner; imleç kutunun altındaki boş düz satıra geçer, yoksa o satır açılır.
    func disariCik(_ belge: NSAttributedString, kapsam: NSRange, govde: NSRange) -> YapiEnterDegisimi {
        let ns = belge.string as NSString
        let yeni = NSMutableAttributedString(attributedString: belge.attributedSubstring(from: govde))
        kapat(yeni)
        if yeni.length > 0, !yeni.string.hasSuffix("\n") {
            // Kutuyu kapatan satır sonu görünmez işaretin parçası değildir.
            var oz = yeni.attributes(at: yeni.length - 1, effectiveRange: nil)
            oz[kBlokIsaretiAnahtari] = nil
            yeni.append(NSAttributedString(string: "\n", attributes: oz))
        }
        let alt = NSMaxRange(kapsam)
        let altBosDuz = alt < belge.length && ns.character(at: alt) == 10 &&
            !(kKutuAnahtarlari + [kMetinBloguAnahtari, kBaslikSeviyesiAnahtari]).contains {
                belge.attribute($0, at: alt, effectiveRange: nil) != nil }
        let hedef = kapsam.location + yeni.length
        if !altBosDuz { yeni.append(NSAttributedString(string: "\n")) }
        return YapiEnterDegisimi(aralik: kapsam, metin: yeni, imlec: hedef, yazim: [:])
    }

    /// Kutunun son iki satırı boşken Enter (içerikten sonra üçüncü) kutudan çıkar; boş satırlar atılır.
    /// Ortadaki boş satırlar kutuda kalır: kodda art arda boş satır sık yazılır.
    func sonBosSatirlardanCik(_ belge: NSAttributedString, paragraf: NSRange) -> YapiEnterDegisimi? {
        let ns = belge.string as NSString
        let tam = aralik(belge, konum: min(paragraf.location, belge.length - 1))
        guard NSMaxRange(paragraf) >= NSMaxRange(tam), paragraf.location > tam.location else { return nil }
        let onceki = ns.paragraphRange(for: NSRange(location: paragraf.location - 1, length: 0))
        guard onceki.location > tam.location, kutuSatiriBosMu(belge.attributedSubstring(from: onceki)) else { return nil }
        return disariCik(belge, kapsam: NSUnionRange(tam, paragraf),
                         govde: NSRange(location: tam.location, length: onceki.location - tam.location))
    }
}

package struct KodKutusu: Kutu {
    package static let anahtar = kKodBloguAnahtari
    package let kod: [String: String]

    /// Kapanmamış çit kapatılır: kutunun altına yazılan metin koda karışmasın.
    package func kapat(_ govde: NSMutableAttributedString) {
        guard (kod["kapanis"] ?? "").isEmpty, govde.length > 0 else { return }
        var kod = kod
        kod["kapanis"] = (kodBloguAyiraci(kod["acilis"] ?? "") ?? "```") + "\n"
        govde.addAttribute(kKodBloguAnahtari, value: kod, range: NSRange(location: 0, length: govde.length))
    }
}

package struct UyariKutusu: Kutu {
    package static let anahtar = kUyariKutusuAnahtari
}

package let kKutuAnahtarlari = [KodKutusu.anahtar, UyariKutusu.anahtar]

/// Konumdaki kutu; kod bloğu uyarının içinde olamaz, önce o bakılır.
package func kutuyuBul(_ belge: NSAttributedString, konum: Int) -> (any Kutu)? {
    guard konum >= 0, konum < belge.length else { return nil }
    if let kod = belge.attribute(kKodBloguAnahtari, at: konum, effectiveRange: nil) as? [String: String] {
        return KodKutusu(kod: kod)
    }
    return belge.attribute(kUyariKutusuAnahtari, at: konum, effectiveRange: nil) != nil ? UyariKutusu() : nil
}

/// Görünmez işaret ve boşluklar dışında içeriği olmayan satır.
package func kutuSatiriBosMu(_ satir: NSAttributedString) -> Bool {
    kodBloguGovdesi(satir).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
