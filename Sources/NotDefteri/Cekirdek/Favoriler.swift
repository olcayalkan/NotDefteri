import Foundation

/// Sıra, notlar klasörüne göreli dosya yollarıyla saklanır; Markdown'a dokunmaz.
package final class Favoriler {
    private let kok: URL
    private let ayarlar: UserDefaults
    package private(set) var yollar: [String]
    package var sayfalar: [URL] { yollar.map { kok.appendingPathComponent($0) } }

    package init(kok: URL = notlarKlasoru(), ayarlar: UserDefaults = .standard) {
        self.kok = kok.standardizedFileURL
        self.ayarlar = ayarlar
        yollar = ayarlar.stringArray(forKey: "favoriSayfalar") ?? []
        olmayanlariDusur()
    }

    package func iceriyor(_ url: URL) -> Bool { goreliYol(url).map { yollar.contains($0) } ?? false }

    package func ekle(_ url: URL) {
        guard let yol = goreliYol(url), !yollar.contains(yol),
              FileManager.default.fileExists(atPath: url.path) else { return }
        yollar.append(yol)
        kaydet()
    }

    package func cikar(_ url: URL) {
        guard let yol = goreliYol(url), yollar.contains(yol) else { return }
        yollar.removeAll { $0 == yol }
        kaydet()
    }

    /// Hedef, çıkarılmadan önceki listede araya bırakma indeksidir.
    package func tasi(_ url: URL, hedef: Int) {
        guard let yol = goreliYol(url), let eski = yollar.firstIndex(of: yol) else { return }
        let yer = min(max(0, hedef), yollar.count)
        yollar.remove(at: eski)
        yollar.insert(yol, at: yer > eski ? yer - 1 : yer)
        kaydet()
    }

    package func yolGuncelle(_ donustur: (URL) -> URL) {
        var gorulen = Set<String>()
        yollar = sayfalar.compactMap { goreliYol(donustur($0)) }.filter { gorulen.insert($0).inserted }
        kaydet()
    }

    package func olmayanlariDusur() {
        var gorulen = Set<String>()
        let kalan = yollar.filter { yol in
            let url = kok.appendingPathComponent(yol).standardizedFileURL
            return goreliYol(url) == yol && gorulen.insert(yol).inserted
                && FileManager.default.fileExists(atPath: url.path)
        }
        guard kalan != yollar else { return }
        yollar = kalan
        kaydet()
    }

    private func goreliYol(_ url: URL) -> String? {
        let onek = kok.path + "/"
        let yol = url.standardizedFileURL.path
        return yol.hasPrefix(onek) ? String(yol.dropFirst(onek.count)) : nil
    }

    private func kaydet() { ayarlar.set(yollar, forKey: "favoriSayfalar") }
}
