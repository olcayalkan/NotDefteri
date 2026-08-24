import Foundation

/// Notun diske yazılmasını ve otomatik kayıt zamanlayıcısını yöneten tip.
///
/// Pencereden bağımsızdır: metni dışarıdan alır, sonucu döndürür. Uyarı
/// göstermek, kenar paneli tazelemek gibi arayüz tepkileri çağıranın işidir.
/// Böylece kayıt mantığı arayüz kurmadan test edilebiliyor.
final class NotKaydedici {

    enum Sonuc: Equatable {
        /// Dosya diske yazıldı.
        case yazildi
        /// Aynı içerik zaten diskte; yazmaya gerek yoktu.
        case gerekmedi
        /// Yazma başarısız. Durum güncellenmedi, yeniden denenebilir.
        case basarisiz(String)
    }

    /// Diske en son yazılan metin. Aynı içeriği tekrar yazmamak için tutulur.
    private(set) var sonYazilanIcerik: String?

    /// Kaydedilmemiş değişiklik var mı?
    private(set) var duzenlendiMi = false

    private var zamanlayici: Timer?
    private let aralik: TimeInterval
    private let dosyaYoneticisi: FileManager

    init(aralik: TimeInterval = kOtomatikKayitAraligi,
         dosyaYoneticisi: FileManager = .default) {
        self.aralik = aralik
        self.dosyaYoneticisi = dosyaYoneticisi
    }

    deinit { zamanlayici?.invalidate() }

    // MARK: Durum

    /// Başka bir not açıldığında/oluşturulduğunda çağrılır.
    func sifirla(sonYazilan: String?) {
        sonYazilanIcerik = sonYazilan
        duzenlendiMi = false
        bekleyeniIptalEt()
    }

    func degisiklikIsaretle() {
        duzenlendiMi = true
    }

    /// İçerik diskle aynı olduğu anlaşıldığında; yazmadan "temiz" işaretler.
    func temizIsaretle() {
        duzenlendiMi = false
    }

    // MARK: Yazma

    /// Bu metnin bu URL'ye yazılması gerekiyor mu?
    ///
    /// Aynı dosyaya aynı içeriği tekrar yazmayız. Ama hedef değiştiyse ya da
    /// dosya diskten silinmişse yazmak gerekir.
    func yazmakGerekli(metin: String, url: URL, mevcutURL: URL?) -> Bool {
        metin != sonYazilanIcerik
            || url != mevcutURL
            || !dosyaYoneticisi.fileExists(atPath: url.path)
    }

    /// Metni diske yazar ve durumu günceller.
    ///
    /// Başarısızlıkta `sonYazilanIcerik` ve `duzenlendiMi` **değişmez**;
    /// aksi hâlde not kaydedilmediği hâlde "kaydedildi" sayılıyor, sonraki
    /// otomatik kayıtlar da atlıyordu.
    func yaz(metin: String, url: URL, mevcutURL: URL?) -> Sonuc {
        guard yazmakGerekli(metin: metin, url: url, mevcutURL: mevcutURL) else {
            duzenlendiMi = false
            return .gerekmedi
        }
        do {
            // Sayfa klasörü henüz yoksa (yeni sayfa) oluşturulur.
            try dosyaYoneticisi.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
            try metin.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return .basarisiz(error.localizedDescription)
        }
        sonYazilanIcerik = metin
        duzenlendiMi = false
        bekleyeniIptalEt()
        return .yazildi
    }

    // MARK: Otomatik kayıt zamanlayıcısı

    /// Tek atımlık zamanlayıcı kurar. Zaten kuruluysa yenisi açılmaz, yani
    /// kesintisiz yazarken de en fazla `aralik` saniyede bir disk yazımı olur;
    /// boştayken hiç zamanlayıcı dönmez.
    func zamanlayiciKur(_ eylem: @escaping () -> Void) {
        guard zamanlayici == nil else { return }
        let yeni = Timer(timeInterval: aralik, repeats: false) { [weak self] _ in
            self?.zamanlayici = nil
            eylem()
        }
        yeni.tolerance = 1  // Sistemin uyandırmaları birleştirmesine izin verir (enerji dostu).
        RunLoop.main.add(yeni, forMode: .common)  // Menü/kaydırma sırasında da işler.
        zamanlayici = yeni
    }

    func bekleyeniIptalEt() {
        zamanlayici?.invalidate()
        zamanlayici = nil
    }

    /// Yalnızca test/tanı için: bekleyen zamanlayıcı var mı?
    var zamanlayiciKurulu: Bool { zamanlayici != nil }
}
