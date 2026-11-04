import Foundation

/// `SayfaDeposu`nun dosya sistemi uygulaması: istisnaları `Basarisizlik`a çevirir.
package struct SayfaDeposuImpl: SayfaDeposu {
    private let kaynak: SayfaKaynagi
    package init(kaynak: SayfaKaynagi = SayfaDosyaKaynagi()) { self.kaynak = kaynak }

    package func oku(_ url: URL) -> Result<Sayfa, Basarisizlik> {
        do { return .success(Sayfa(url: url, ham: try kaynak.oku(url))) }
        catch let DosyaIstisnasi.okunamadi(_, neden) { return .failure(.dosya(neden)) }
        catch { return .failure(.dosya(error.localizedDescription)) }
    }
}
