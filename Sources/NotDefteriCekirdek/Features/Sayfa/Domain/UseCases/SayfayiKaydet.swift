import Foundation

/// Sayfayı yazar; yazıldıysa sürüm geçmişine ekler. Kaydedici pencereye özeldir (otomatik
/// kayıt durumu), bu yüzden girdiyle gelir.
package struct SayfayiKaydet: UseCase {
    package struct Girdi {
        package let metin: String
        package let url: URL
        package let mevcutURL: URL?
        package let kaydedici: NotKaydedici
        package init(metin: String, url: URL, mevcutURL: URL?, kaydedici: NotKaydedici) {
            self.metin = metin; self.url = url; self.mevcutURL = mevcutURL; self.kaydedici = kaydedici
        }
    }

    private let gecmiseEkle: (String, URL) -> Void
    package init(gecmiseEkle: @escaping (String, URL) -> Void = { SayfaGecmisi.kaydet(metin: $0, icerikURL: $1) }) {
        self.gecmiseEkle = gecmiseEkle
    }

    package func callAsFunction(_ girdi: Girdi) -> NotKaydedici.Sonuc {
        let sonuc = girdi.kaydedici.yaz(metin: girdi.metin, url: girdi.url, mevcutURL: girdi.mevcutURL)
        if sonuc == .yazildi { gecmiseEkle(girdi.metin, girdi.url) }
        return sonuc
    }
}
