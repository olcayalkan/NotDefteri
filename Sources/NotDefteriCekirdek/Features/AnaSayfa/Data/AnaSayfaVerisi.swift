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
            konum = kodBloguKapanisi(ns, ayirac: ayirac, sonrasinda: NSMaxRange(aralik)).map { NSMaxRange($0) } ?? ns.length
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

/// Önbellek, disk, varsa açık belge ve UTF-16 satır/kutu konumları aynı kaynağı göstermeli.
package func yapilacakGecerliMi(_ gorev: BekleyenYapilacak, metin: String,
                              onbellekMetni: String?, acikSayfaMi: Bool, acikSayfaMetni: String?) -> Bool {
    guard onbellekMetni == metin, !acikSayfaMi || acikSayfaMetni == metin else { return false }
    return yapilacakSatiriGecerliMi(gorev, metin: metin)
}

private func yapilacakSatiriGecerliMi(_ gorev: BekleyenYapilacak, metin: String) -> Bool {
    let govde = sayfaUstbilgisiniAyir(metin).govde as NSString
    guard gorev.govdeKonumu >= 0, gorev.govdeKonumu < govde.length else { return false }
    let aralik = govde.lineRange(for: NSRange(location: gorev.govdeKonumu, length: 0))
    guard aralik.location == gorev.govdeKonumu, govde.substring(with: aralik) == gorev.satir,
          let cozum = metinBlogunuCozumle(gorev.satir.trimmingCharacters(in: .newlines)),
          cozum.blok.tur == .yapilacak, !cozum.blok.tamamlandi,
          cozum.blok.kaynakOnEk?.hasSuffix("- [ ] ") == true else { return false }
    return gorev.kutuKonumu == gorev.govdeKonumu + cozum.uzunluk - 3
}

package func yapilacagiTamamlayanMetin(_ gorev: BekleyenYapilacak, metin: String) throws -> (markdown: String, satir: String) {
    guard yapilacakSatiriGecerliMi(gorev, metin: metin) else { throw CocoaError(.fileReadUnknown) }
    let sayfa = sayfaUstbilgisiniAyir(metin)
    let yeni = NSMutableString(string: metin)
    yeni.replaceCharacters(in: NSRange(location: (sayfa.bilgi.kaynak as NSString).length + gorev.kutuKonumu, length: 1), with: "x")
    let satir = NSMutableString(string: gorev.satir)
    satir.replaceCharacters(in: NSRange(location: gorev.kutuKonumu - gorev.govdeKonumu, length: 1), with: "x")
    return (yeni as String, satir as String)
}

/// Mevcut günlük yeni veya eski düzende varsa açılır; yoksa oluşturulacak içerik yolu döner.
package func gunlukNotURL(_ tarih: Date = Date(), kok: URL = notlarKlasoru()) throws -> URL {
    let klasor = kok.appendingPathComponent("Günlük", isDirectory: true)
    let ad = gunlukSayfaAdi(tarih)
    let url = klasor.appendingPathComponent(ad).appendingPathComponent(kIcerikDosyaAdi)
    try notlarYolunuDogrula(url, kok: kok)
    if dosyaYoluVarMi(url) { return url }
    for uzanti in ["md", "MD", "Md", "mD"] {
        let eski = klasor.appendingPathComponent(ad).appendingPathExtension(uzanti)
        if dosyaYoluVarMi(eski) {
            try notlarYolunuDogrula(eski, kok: kok)
            return eski
        }
    }
    return url
}

/// Tamamlanan dosyayı aynı klasörde taşıyarak yayımlar; mevcut notun üzerine yazmaz.
package func icerikleSayfaOlustur(url: URL, metin: String, kok: URL = notlarKlasoru()) throws {
    try notlarYolunuDogrula(url, kok: kok)
    let fm = FileManager.default
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let gecici = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
    try notlarYolunuDogrula(gecici, kok: kok)
    defer {
        if (try? notlarYolunuDogrula(gecici, kok: kok)) != nil { try? fm.removeItem(at: gecici) }
    }
    try Data(metin.utf8).write(to: gecici, options: .withoutOverwriting)
    try notlarYolunuDogrula(url, kok: kok)
    try fm.moveItem(at: gecici, to: url)
}
