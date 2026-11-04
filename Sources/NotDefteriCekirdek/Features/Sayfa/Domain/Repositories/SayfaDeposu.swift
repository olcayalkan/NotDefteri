import Foundation

/// Sayfaların kalıcı deposu. Domain yalnızca bu arayüzü bilir; dosya sistemi Data katmanındadır.
package protocol SayfaDeposu {
    func oku(_ url: URL) -> Result<Sayfa, Basarisizlik>
}
