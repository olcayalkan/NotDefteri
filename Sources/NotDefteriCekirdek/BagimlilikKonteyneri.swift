import Foundation

/// Bağımlılıkların tek kurulduğu yer (injection container). Sunum katmanı somut sınıfları
/// değil, buradan aldığı kullanım senaryolarını kullanır; testte sahte depo verilebilir.
package final class BagimlilikKonteyneri {
    package static let paylasilan = BagimlilikKonteyneri()

    private let sayfaDeposu: SayfaDeposu

    package init(sayfaDeposu: SayfaDeposu = SayfaDeposuImpl()) {
        self.sayfaDeposu = sayfaDeposu
    }

    package var sayfayiAc: SayfayiAc { SayfayiAc(depo: sayfaDeposu) }
    package var sayfayiKaydet: SayfayiKaydet { SayfayiKaydet() }
}
