import Foundation

/// Arama önbelleğinin bir girdisi: notun normalleştirilmiş metni ve okunduğu andaki
/// değiştirilme tarihi. Tarih aynıysa dosya yeniden okunmaz.
struct OnbellekGirdisi {
    let tarih: Date
    let aranabilirMetin: String
    let bagHedefleri: Set<String>
    let hamMarkdown: String
    /// Girdiyle birlikte bir kez taranır; Ana Sayfa her açılışta tüm metinleri yeniden taramaz.
    let yapilacaklar: [YapilacakSatiri]

    init(tarih: Date, aranabilirMetin: String, bagHedefleri: Set<String> = [], hamMarkdown: String = "") {
        self.tarih = tarih
        self.aranabilirMetin = aramaIcinSadelestir(aranabilirMetin)
        self.bagHedefleri = bagHedefleri
        self.hamMarkdown = hamMarkdown
        yapilacaklar = yapilacakSatirlariniBul(hamMarkdown)
    }
}

/// Yalnızca Foundation kullanır; arka plan kuyruğunda da güvenle üretilir.
func onbellekGirdisiUret(_ metin: String, tarih: Date) -> OnbellekGirdisi {
    let sayfa = sayfaUstbilgisiniAyir(metin)
    return OnbellekGirdisi(tarih: tarih, aranabilirMetin: isaretlemeleriTemizle(sayfa.govde),
                           bagHedefleri: Set(sayfaBaglariniBul(sayfa.govde).map(\.hedef)), hamMarkdown: metin)
}

typealias YapilacakSatiri = (govdeKonumu: Int, kutuKonumu: Int, satir: String, metin: String)

/// Konum gövdeye görelidir; frontmatter ve biçim işaretleri satır hedefini kaydırmaz.
struct BekleyenYapilacak {
    let url: URL
    let govdeKonumu: Int
    let kutuKonumu: Int
    let satir: String
    let metin: String
}

/// Ana Sayfa yalnızca girdilerde hazır duran satırları sıralar; metin taranmaz, disk okunmaz.
func bekleyenYapilacaklariBul(_ onbellek: [URL: OnbellekGirdisi]) -> [BekleyenYapilacak] {
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
    let ns = govde as NSString
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
            let metin = (sade as NSString).substring(from: cozum.uzunluk)
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
