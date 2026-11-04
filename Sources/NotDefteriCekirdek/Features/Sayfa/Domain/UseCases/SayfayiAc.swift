import Foundation

/// Sayfayı depodan okur. macOS ve Linux editörü aynı yoldan açar.
package struct SayfayiAc: UseCase {
    private let depo: SayfaDeposu
    package init(depo: SayfaDeposu) { self.depo = depo }

    package func callAsFunction(_ url: URL) -> Result<Sayfa, Basarisizlik> { depo.oku(url) }
}
