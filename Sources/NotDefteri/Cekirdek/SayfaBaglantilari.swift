import Foundation

package func disBaglantiGecerliMi(_ url: URL) -> Bool {
    ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "")
}

package struct SayfaBagi {
    package let aralik: NSRange
    package let hedef: String
}

/// Kaçışlar ve kod ayıraçları atlanır; açılış/kayıtta veya yalnızca değişen paragrafta kullanılır.
package func sayfaBaglariniBul(_ metin: String) -> [SayfaBagi] {
    let ns = NSString(string: metin)
    var sonuc: [SayfaBagi] = []
    var i = 0
    while i < ns.length {
        if ns.character(at: i) == 92 { i += 2; continue }
        if ns.character(at: i) == 96 {
            var adet = 1
            while i + adet < ns.length, ns.character(at: i + adet) == 96 { adet += 1 }
            let satir = ns.lineRange(for: NSRange(location: i, length: 0))
            if i == satir.location, let ayirac = kodBloguAyiraci(ns.substring(with: satir)) {
                let kapanis = kodBloguKapanisi(metin, ayirac: ayirac, sonrasinda: NSMaxRange(satir))
                i = kapanis.map { NSMaxRange($0) } ?? ns.length
                continue
            }
            let ayirac = String(repeating: "`", count: adet)
            let satirSonu = NSMaxRange(ns.lineRange(for: NSRange(location: i, length: 0)))
            let son = ns.range(of: ayirac, range: NSRange(location: i + adet, length: satirSonu - i - adet))
            if son.location != NSNotFound { i = NSMaxRange(son); continue }
            i += adet
            continue
        }
        if i + 1 < ns.length, ns.character(at: i) == 91, ns.character(at: i + 1) == 91 {
            var son = i + 2
            while son < ns.length, ![10, 13, 91, 93].contains(ns.character(at: son)) { son += 1 }
            if son > i + 2, son + 1 < ns.length, ns.character(at: son) == 93, ns.character(at: son + 1) == 93 {
                let hedef = ns.substring(with: NSRange(location: i + 2, length: son - i - 2))
                if !hedef.trimmingCharacters(in: .whitespaces).isEmpty {
                    sonuc.append(SayfaBagi(aralik: NSRange(location: i, length: son + 2 - i), hedef: hedef))
                }
                i = son + 2
                continue
            }
        }
        // Normal Markdown bağlantısının etiketi/URL'si sayfa bağlantısı değildir.
        if ns.character(at: i) == 91 {
            var son = i + 1
            var derinlik = 1
            while son < ns.length, derinlik > 0, ![10, 13].contains(ns.character(at: son)) {
                let harf = ns.character(at: son)
                if harf == 92 { son += 2; continue }
                if harf == 91 { derinlik += 1 }
                if harf == 93 { derinlik -= 1 }
                son += 1
            }
            if derinlik == 0, son < ns.length, ns.character(at: son) == 40 {
                son += 1
                derinlik = 1
                while son < ns.length, derinlik > 0, ![10, 13].contains(ns.character(at: son)) {
                    let harf = ns.character(at: son)
                    if harf == 92 { son += 2; continue }
                    if harf == 40 { derinlik += 1 }
                    if harf == 41 { derinlik -= 1 }
                    son += 1
                }
                if derinlik == 0 { i = son; continue }
            }
        }
        i += 1
    }
    return sonuc
}

package struct SayfaSecenegi: Equatable {
    package let url: URL
    package let ad: String
    package let yol: String
    let sadeAd: String
    let sadeYol: String

    package init(url: URL) {
        self.url = url
        ad = sayfaAdi(url)
        yol = sayfaBagYolu(url)
        sadeAd = aramaIcinSadelestir(ad)
        sadeYol = aramaIcinSadelestir(yol)
    }
    package var ustYol: String { yol.split(separator: "/").dropLast().joined(separator: "/") }
}

package struct DalBaglantisiSonucu {
    package let notlar: [URL]
    package let onbellek: [URL: OnbellekGirdisi]
    package let hedefler: [String: String]
    package let guncellenenMetinler: [URL: String]
    package let hatalar: [String]
}

/// Sayfa adları bir kez indekslenir; tuşlarda dosya okuma veya gövde tarama yoktur.
package final class SayfaBaglantilari {
    package init() {}

    package private(set) var sayfalar: [SayfaSecenegi] = []
    private var hedefler: [String: [URL]] = [:]
    private var urlIndeksi: [URL: SayfaSecenegi] = [:]
    package private(set) var sonAcilanlar = (gAyarlar.stringArray(forKey: "sonAcilanSayfalar") ?? []).map { URL(fileURLWithPath: $0) }

    private var sonAcilmaTarihleri = gAyarlar.dictionary(forKey: "sonAcilmaTarihleri") as? [String: Double] ?? [:]

    package func sonAcilmaTarihi(_ url: URL) -> Date? {
        sonAcilmaTarihleri[url.path].map { Date(timeIntervalSince1970: $0) }
    }

    package var sonAcilanlarDegisti: (() -> Void)?

    package func olmayanSonAcilanlariDusur() {
        let kalan = sonAcilanlar.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard kalan != sonAcilanlar else { return }
        sonAcilanlar = kalan
        sonAcilanlariKaydet()
    }

    private func sonAcilanlariKaydet() {
        gAyarlar.set(sonAcilanlar.map(\.path), forKey: "sonAcilanSayfalar")
        let yollar = Set(sonAcilanlar.map(\.path))
        sonAcilmaTarihleri = sonAcilmaTarihleri.filter { yollar.contains($0.key) }
        gAyarlar.set(sonAcilmaTarihleri, forKey: "sonAcilmaTarihleri")
        sonAcilanlarDegisti?()
    }

    package func guncelle(_ sayfalar: [SayfaSecenegi]) {
        self.sayfalar = sayfalar
        hedefler = [:]
        urlIndeksi = [:]
        for sayfa in sayfalar {
            urlIndeksi[sayfa.url] = sayfa
            for anahtar in Set([sayfa.ad, sayfa.yol, "./" + sayfa.yol]) { hedefler[anahtar, default: []].append(sayfa.url) }
        }
    }

    package func coz(_ hedef: String) -> URL? {
        let adaylar = hedefler[hedef.trimmingCharacters(in: .whitespaces)] ?? []
        return adaylar.count == 1 ? adaylar[0] : nil
    }
    package func belirsizMi(_ hedef: String) -> Bool { (hedefler[hedef]?.count ?? 0) > 1 }
    package func bagMetni(_ url: URL) -> String {
        guard let sayfa = urlIndeksi[url] else { return sayfaAdi(url) }
        return (hedefler[sayfa.ad]?.count ?? 0) == 1 ? sayfa.ad
            : (sayfa.yol.contains("/") ? sayfa.yol : "./" + sayfa.yol)
    }
    package func acildi(_ url: URL) {
        sonAcilmaTarihleri[url.path] = Date().timeIntervalSince1970
        sonAcilanlar.removeAll { $0 == url }
        sonAcilanlar.insert(url, at: 0)
        sonAcilanlar = Array(sonAcilanlar.prefix(30))
        sonAcilanlariKaydet()
    }
    package func yollariTasi(_ donustur: (URL) -> URL) {
        var yeniTarihler: [String: Double] = [:]
        for (yol, tarih) in sonAcilmaTarihleri {
            let yeni = donustur(URL(fileURLWithPath: yol)).path
            yeniTarihler[yeni] = max(yeniTarihler[yeni] ?? 0, tarih)
        }
        sonAcilmaTarihleri = yeniTarihler
        sonAcilanlar = sonAcilanlar.map(donustur)
        sonAcilanlariKaydet()
    }

    /// Taşıma tamamlandıktan sonra çağrılır. Favoriler/sonlar ve tüm not bağları aynı dönüşümü kullanır.
    package func daliGuncelle(eskiKlasor: URL, yeniKlasor: URL, eskiIcerik: URL?, yeniIcerik: URL?,
                             notlar: [URL], onbellek: [URL: OnbellekGirdisi], favoriler: Favoriler,
                             kok: URL = notlarKlasoru()) -> DalBaglantisiSonucu {
        func donustur(_ url: URL) -> URL {
            Self.tasinanURL(url, eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor,
                            eskiIcerik: eskiIcerik, yeniIcerik: yeniIcerik)
        }
        // Yol çözümü pahalı; konumu değişmeyen sayfanın seçeneği yeniden kurulmaz.
        let yeniSayfalar = sayfalar.map { sayfa -> SayfaSecenegi in
            let yeniURL = donustur(sayfa.url)
            return yeniURL == sayfa.url ? sayfa : SayfaSecenegi(url: yeniURL)
        }
        let yeniSecenekler = Dictionary(yeniSayfalar.map { ($0.url, $0) }, uniquingKeysWith: { ilk, _ in ilk })
        let yeniIndeks = SayfaBaglantilari()
        yeniIndeks.guncelle(yeniSayfalar)
        let hedefler = yenidenYazimlar(yeni: yeniIndeks, donustur: donustur)
        let yeniNotlar = notlar.map(donustur)
        var yeniOnbellek = Dictionary(onbellek.map { (donustur($0.key), $0.value) }, uniquingKeysWith: { ilk, _ in ilk })
        favoriler.yolGuncelle(donustur)
        yollariTasi(donustur)
        guncelle(yeniNotlar.map { yeniSecenekler[$0] ?? SayfaSecenegi(url: $0) })
        let yazim = bagDosyalariniYenidenYaz(notlar: yeniNotlar, onbellek: yeniOnbellek, hedefler: hedefler, kok: kok)
        for (url, metin) in yazim.metinler {
            yeniOnbellek[url] = onbellekGirdisiUret(metin, tarih: degistirilmeTarihi(url))
        }
        return DalBaglantisiSonucu(notlar: yeniNotlar, onbellek: yeniOnbellek, hedefler: hedefler,
                                  guncellenenMetinler: yazim.metinler, hatalar: yazim.hatalar)
    }

    /// Açık torunun URL'si de diskteki ve kayıtlardaki yollarla aynı şekilde dönüştürülür.
    package static func tasinanURL(_ url: URL, eskiKlasor: URL, yeniKlasor: URL,
                                  eskiIcerik: URL?, yeniIcerik: URL?) -> URL {
        if url == eskiIcerik, let yeniIcerik { return yeniIcerik }
        let eski = eskiKlasor.standardizedFileURL.path
        let yol = url.standardizedFileURL.path
        if yol == eski || yol.hasPrefix(eski + "/") {
            return URL(fileURLWithPath: yeniKlasor.standardizedFileURL.path + yol.dropFirst(eski.count))
        }
        return url
    }

    private func bagDosyalariniYenidenYaz(notlar: [URL], onbellek: [URL: OnbellekGirdisi],
                                        hedefler: [String: String], kok: URL) -> (metinler: [URL: String], hatalar: [String]) {
        var metinler: [URL: String] = [:]
        var hatalar: [String] = []
        for url in notlar {
            if let girdi = onbellek[url], girdi.tarih == degistirilmeTarihi(url),
               !girdi.bagHedefleri.contains(where: { hedefler[$0.trimmingCharacters(in: .whitespaces)] != nil }) { continue }
            do {
                try notlarYolunuDogrula(url, kok: kok)
                let metin = try String(contentsOf: url, encoding: .utf8)
                let sayfa = sayfaUstbilgisiniAyir(metin)
                let yeni = sayfa.bilgi.kaynak + sayfaBaglariniDegistir(sayfa.govde, hedefler: hedefler)
                if yeni != metin {
                    try notlarYolunuDogrula(url, kok: kok)
                    try yeni.write(to: url, atomically: true, encoding: .utf8)
                }
                metinler[url] = yeni
            } catch { hatalar.append("\(sayfaBagYolu(url)): \(error.localizedDescription)") }
        }
        return (metinler, hatalar)
    }

    package func ara(_ sorgu: String) -> [SayfaSecenegi] {
        let sade = aramaIcinSadelestir(sorgu.trimmingCharacters(in: .whitespacesAndNewlines))
        if sade.isEmpty { return sonAcilanlar.compactMap { urlIndeksi[$0] } }
        return sayfalar.compactMap { sayfa -> (SayfaSecenegi, Int)? in
            guard let puan = bulanikPuan(sayfa.sadeAd, sorgu: sade) ?? bulanikPuan(sayfa.sadeYol, sorgu: sade).map({ $0 + 100 }) else { return nil }
            return (sayfa, puan)
        }.sorted {
            $0.1 == $1.1 ? $0.0.yol.localizedStandardCompare($1.0.yol) == .orderedAscending : $0.1 < $1.1
        }.prefix(30).map { $0.0 }
    }

    /// Eski hedefler, taşınan dal ve yeni ad çakışmaları birlikte değerlendirilir.
    package func yenidenYazimlar(yeni: SayfaBaglantilari, donustur: (URL) -> URL) -> [String: String] {
        var sonuc: [String: String] = [:]
        for (hedef, adaylar) in hedefler where adaylar.count == 1 {
            let eskiURL = adaylar[0]
            let yeniURL = donustur(eskiURL)
            if eskiURL != yeniURL || yeni.coz(hedef) != yeniURL {
                let yol = sayfaBagYolu(yeniURL)
                let yeniHedef = hedef.contains("/") ? (yol.contains("/") ? yol : "./" + yol) : yeni.bagMetni(yeniURL)
                if yeniHedef != hedef { sonuc[hedef] = yeniHedef }
            }
        }
        return sonuc
    }
}

private func bulanikPuan(_ metin: String, sorgu: String) -> Int? {
    if metin == sorgu { return 0 }
    if metin.hasPrefix(sorgu) { return 1 }
    if metin.contains(sorgu) { return 2 }
    let harfler = Array(sorgu)
    var sira = 0
    var bosluk = 0
    for harf in metin {
        if harf == harfler[sira] { sira += 1; if sira == harfler.count { return 10 + bosluk } }
        else { bosluk += 1 }
    }
    return nil
}

package func sayfaBaglariniDegistir(_ metin: String, hedefler: [String: String]) -> String {
    let sonuc = NSMutableString(string: metin)
    for bag in sayfaBaglariniBul(metin).reversed() {
        if let yeni = hedefler[bag.hedef.trimmingCharacters(in: .whitespaces)] {
            sonuc.replaceCharacters(in: bag.aralik, with: "[[\(yeni)]]")
        }
    }
    return String(sonuc)
}

/// Çevirici ve bağlantı indeksi kodun kapsamı konusunda aynı kuralları kullanır.
func kodBloguAyiraci(_ satir: String) -> String? {
    let ayirac = String(satir.prefix { $0 == "`" })
    return ayirac.count >= 3 && !satir.dropFirst(ayirac.count).contains("`") ? ayirac : nil
}

func kodBloguKapanisi(_ metin: String, ayirac: String, sonrasinda: Int) -> NSRange? {
    let desen = try! NSRegularExpression(pattern: "(?m)^" + ayirac + "[ \t]*(?:\r?\n|$)")
    return desen.firstMatch(in: metin, range: NSRange(location: sonrasinda, length: NSString(string: metin).length - sonrasinda))?.range
}
