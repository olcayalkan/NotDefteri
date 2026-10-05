import Foundation

/// Arama önbelleğinin bir girdisi: notun normalleştirilmiş metni ve okunduğu andaki
/// değiştirilme tarihi. Tarih aynıysa dosya yeniden okunmaz.
package struct OnbellekGirdisi {
    package let tarih: Date
    package let aranabilirMetin: String
    package let bagHedefleri: Set<String>
    package let hamMarkdown: String
    /// Girdiyle birlikte bir kez taranır; Ana Sayfa her açılışta tüm metinleri yeniden taramaz.
    package let yapilacaklar: [YapilacakSatiri]

    package init(tarih: Date, aranabilirMetin: String, bagHedefleri: Set<String> = [], hamMarkdown: String = "") {
        self.tarih = tarih
        self.aranabilirMetin = aramaIcinSadelestir(aranabilirMetin)
        self.bagHedefleri = bagHedefleri
        self.hamMarkdown = hamMarkdown
        yapilacaklar = yapilacakSatirlariniBul(hamMarkdown)
    }
}

/// Yalnızca Foundation kullanır; arka plan kuyruğunda da güvenle üretilir.
package func onbellekGirdisiUret(_ metin: String, tarih: Date) -> OnbellekGirdisi {
    let sayfa = sayfaUstbilgisiniAyir(metin)
    return OnbellekGirdisi(tarih: tarih, aranabilirMetin: isaretlemeleriTemizle(sayfa.govde),
                           bagHedefleri: Set(sayfaBaglariniBul(sayfa.govde).map(\.hedef)), hamMarkdown: metin)
}

package typealias YapilacakSatiri = (govdeKonumu: Int, kutuKonumu: Int, satir: String, metin: String)

/// Konum gövdeye görelidir; frontmatter ve biçim işaretleri satır hedefini kaydırmaz.
package struct BekleyenYapilacak {
    package let url: URL
    package let govdeKonumu: Int
    package let kutuKonumu: Int
    package let satir: String
    package let metin: String
}

/// Ana Sayfa yalnızca girdilerde hazır duran satırları sıralar; metin taranmaz, disk okunmaz.
package func bekleyenYapilacaklariBul(_ onbellek: [URL: OnbellekGirdisi]) -> [BekleyenYapilacak] {
    // Ad ve yol sayfa başına bir kez çıkarılır; karşılaştırmada URL işlemi yapılmaz.
    let yollar = onbellek.filter { !$0.value.yapilacaklar.isEmpty }.keys
        .map { (url: $0, ad: sayfaAdi($0), yol: $0.path) }
        .sorted {
            let sira = $0.ad.localizedStandardCompare($1.ad)
            return sira == .orderedSame ? $0.yol < $1.yol : sira == .orderedAscending
        }.map(\.url)
    return yollar.flatMap { url in
        onbellek[url]!.yapilacaklar.map {
            BekleyenYapilacak(url: url, govdeKonumu: $0.govdeKonumu, kutuKonumu: $0.kutuKonumu, satir: $0.satir, metin: $0.metin)
        }
    }
}

/// Kod bloğu ve frontmatter dışındaki boş olmayan `- [ ]` satırları; konumlar gövdeye görelidir.
private func yapilacakSatirlariniBul(_ hamMarkdown: String) -> [YapilacakSatiri] {
    var sonuc: [YapilacakSatiri] = []
    guard hamMarkdown.contains("[ ]") else { return sonuc }
    let govde = sayfaUstbilgisiniAyir(hamMarkdown).govde
    let ns = NSString(string: govde)
    var konum = 0
    while konum < ns.length {
        let aralik = ns.lineRange(for: NSRange(location: konum, length: 0))
        let satir = ns.substring(with: aralik)
        if let ayirac = kodBloguAyiraci(satir) {
            konum = kodBloguKapanisi(govde, ayirac: ayirac, sonrasinda: NSMaxRange(aralik)).map { NSMaxRange($0) } ?? ns.length
            continue
        }
        let sade = satir.trimmingCharacters(in: .newlines)
        if let cozum = metinBlogunuCozumle(sade), cozum.blok.tur == .yapilacak,
           !cozum.blok.tamamlandi, cozum.blok.kaynakOnEk?.hasSuffix("- [ ] ") == true {
            let metin = NSString(string: sade).substring(from: cozum.uzunluk)
            guard !metin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                konum = NSMaxRange(aralik)
                continue
            }
            sonuc.append((govdeKonumu: konum, kutuKonumu: konum + cozum.uzunluk - 3, satir: satir, metin: metin))
        }
        konum = NSMaxRange(aralik)
    }
    return sonuc
}
