import Foundation

/// Sayfa dosyasının ham baytlarına erişim. Hata `DosyaIstisnasi` olarak fırlatılır.
package protocol SayfaKaynagi {
    func oku(_ url: URL) throws -> String
}

package struct SayfaDosyaKaynagi: SayfaKaynagi {
    package init() {}

    package func oku(_ url: URL) throws -> String {
        do { return try String(contentsOf: url, encoding: .utf8) }
        catch { throw DosyaIstisnasi.okunamadi(url, neden: error.localizedDescription) }
    }
}
