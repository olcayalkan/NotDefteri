import Foundation

/// Her klasördeki gizli sıra kaydı. Gizli olduğu için ağaç taraması onu sayfa saymaz.
let kSiraDosyaAdi = ".sira.json"

/// Kardeş sayfa adları (klasör adı ya da .md'siz dosya adı). `sabitler` hep en üstte durur.
package struct SayfaSirasi: Codable, Equatable {
    package var sabitler: [String]
    package var sira: [String]

    package init(sabitler: [String] = [], sira: [String] = []) {
        self.sabitler = sabitler
        self.sira = sira
    }

    private enum CodingKeys: String, CodingKey { case sabitler, sira }

    // Elle düzenlenmiş dosyada bir anahtar eksikse diğeri yine geçerli sayılır.
    package init(from kodCozucu: Decoder) throws {
        let kutu = try kodCozucu.container(keyedBy: CodingKeys.self)
        sabitler = try kutu.decodeIfPresent([String].self, forKey: .sabitler) ?? []
        sira = try kutu.decodeIfPresent([String].self, forKey: .sira) ?? []
    }

    package var bos: Bool { sabitler.isEmpty && sira.isEmpty }
}

/// Dosya yoksa ya da bozuksa nil (çökme yok; sonraki yazım dosyayı yeniden kurar).
func siraOku(_ klasor: URL) -> SayfaSirasi? {
    guard let veri = try? Data(contentsOf: klasor.appendingPathComponent(kSiraDosyaAdi)) else { return nil }
    return try? JSONDecoder().decode(SayfaSirasi.self, from: veri)
}

/// Önce sabitler (kayıt sırasıyla), sonra `sira`, en sonda kayıtta olmayanlar (gelen sırayla).
/// Diskte olmayan adlar sessizce düşer; sabit düğümler işaretlenir.
func siraUygula(_ dugumler: [AgacDugumu], _ kayit: SayfaSirasi?) -> [AgacDugumu] {
    guard let kayit else { return dugumler }
    var kalan = dugumler
    var sonuc: [AgacDugumu] = []
    for (ad, sabit) in kayit.sabitler.map({ ($0, true) }) + kayit.sira.map({ ($0, false) }) {
        guard let i = kalan.firstIndex(where: { $0.ad == ad }) else { continue }
        let dugum = kalan.remove(at: i)
        dugum.sabit = sabit
        sonuc.append(dugum)
    }
    return sonuc + kalan
}

/// Yalnızca değişiklik varsa, notlar klasörü içindeki klasöre atomik yazar.
/// Yazılamadıysa false (yol dışarıdaysa, sembolik bağsa, disk hatasında).
@discardableResult
package func siraYaz(_ yeni: SayfaSirasi, klasor: URL) -> Bool {
    let fm = FileManager.default
    let yol = klasor.standardizedFileURL
    let kok = notlarKlasoru().standardizedFileURL
    let cozulmus = yol.resolvingSymlinksInPath().path
    let kokCozulmus = kok.resolvingSymlinksInPath().path
    guard yol.path == kok.path || yol.path.hasPrefix(kok.path + "/"),
          cozulmus == kokCozulmus || cozulmus.hasPrefix(kokCozulmus + "/") else { return false }
    let dosya = yol.appendingPathComponent(kSiraDosyaAdi)
    let mevcut = (try? fm.attributesOfItem(atPath: dosya.path)) != nil
    if let tur = (try? fm.attributesOfItem(atPath: dosya.path))?[.type] as? FileAttributeType,
       tur == .typeSymbolicLink { return false }
    let eski = siraOku(yol)
    if eski == yeni { return true }
    if eski == nil, !mevcut, yeni.bos { return true }
    let kodlayici = JSONEncoder()
    kodlayici.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let veri = try? kodlayici.encode(yeni) else { return false }
    return (try? veri.write(to: dosya, options: .atomic)) != nil
}

/// Klasörün tüm kardeşlerini verilen sırayla kaydeder; `sabitler` içindekiler sabit kalır.
@discardableResult
package func siraKaydet(klasor: URL, adlar: [String], sabitler: Set<String>) -> Bool {
    siraYaz(SayfaSirasi(sabitler: adlar.filter { sabitler.contains($0) },
                        sira: adlar.filter { !sabitler.contains($0) }), klasor: klasor)
}

/// Yeniden adlandırmada adı günceller, taşıma/silmede (`yeni` nil) kayıttan çıkarır.
package func siraAdiniDegistir(klasor: URL, eski: String, yeni: String?) {
    guard var kayit = siraOku(klasor) else { return }
    func uygula(_ adlar: [String]) -> [String] { adlar.compactMap { $0 == eski ? yeni : $0 } }
    kayit.sabitler = uygula(kayit.sabitler)
    kayit.sira = uygula(kayit.sira)
    siraYaz(kayit, klasor: klasor)
}
