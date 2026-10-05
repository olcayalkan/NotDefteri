import Foundation

/// Notun diske yazılmasını ve otomatik kayıt zamanlayıcısını yöneten tip.
///
/// Pencereden bağımsızdır: metni dışarıdan alır, sonucu döndürür. Uyarı
/// göstermek, kenar paneli tazelemek gibi arayüz tepkileri çağıranın işidir.
/// Böylece kayıt mantığı arayüz kurmadan test edilebiliyor.
package final class NotKaydedici {

    package enum Sonuc: Equatable {
        /// Dosya diske yazıldı.
        case yazildi
        /// Aynı içerik zaten diskte; yazmaya gerek yoktu.
        case gerekmedi
        /// Yazma başarısız. Durum güncellenmedi, yeniden denenebilir.
        case basarisiz(String)
    }

    /// Diske en son yazılan metin. Aynı içeriği tekrar yazmamak için tutulur.
    package private(set) var sonYazilanIcerik: String?

    /// Kaydedilmemiş değişiklik var mı?
    package private(set) var duzenlendiMi = false

    private var zamanlayici: ZamanlayiciIptal?
    private let aralik: TimeInterval
    private let dosyaYoneticisi: FileManager

    package init(aralik: TimeInterval = kOtomatikKayitAraligi,
         dosyaYoneticisi: FileManager = .default) {
        self.aralik = aralik
        self.dosyaYoneticisi = dosyaYoneticisi
    }

    deinit { zamanlayici?() }

    // MARK: Durum

    /// Başka bir not açıldığında/oluşturulduğunda çağrılır.
    package func sifirla(sonYazilan: String?) {
        sonYazilanIcerik = sonYazilan
        duzenlendiMi = false
        bekleyeniIptalEt()
    }

    package func degisiklikIsaretle() {
        duzenlendiMi = true
    }

    /// İçerik diskle aynı olduğu anlaşıldığında; yazmadan "temiz" işaretler.
    package func temizIsaretle() {
        duzenlendiMi = false
    }

    // MARK: Yazma

    /// Bu metnin bu URL'ye yazılması gerekiyor mu?
    ///
    /// Aynı dosyaya aynı içeriği tekrar yazmayız. Ama hedef değiştiyse ya da
    /// dosya diskten silinmişse yazmak gerekir.
    package func yazmakGerekli(metin: String, url: URL, mevcutURL: URL?) -> Bool {
        metin != sonYazilanIcerik
            || url != mevcutURL
            || !dosyaYoneticisi.fileExists(atPath: url.path)
    }

    /// Metni diske yazar ve durumu günceller.
    ///
    /// Başarısızlıkta `sonYazilanIcerik` ve `duzenlendiMi` **değişmez**;
    /// aksi hâlde not kaydedilmediği hâlde "kaydedildi" sayılıyor, sonraki
    /// otomatik kayıtlar da atlıyordu.
    package func yaz(metin: String, url: URL, mevcutURL: URL?) -> Sonuc {
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
    package func zamanlayiciKur(_ eylem: @escaping () -> Void) {
        guard zamanlayici == nil else { return }
        zamanlayici = Platform.zamanlayici(aralik) { [weak self] in
            self?.zamanlayici = nil
            eylem()
        }
    }

    package func bekleyeniIptalEt() {
        zamanlayici?()
        zamanlayici = nil
    }

    /// Yalnızca test/tanı için: bekleyen zamanlayıcı var mı?
    var zamanlayiciKurulu: Bool { zamanlayici != nil }
}
