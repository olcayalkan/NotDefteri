import Foundation

/// Veri katmanının (data source) fırlattığı hatalar. Depo bunları `Basarisizlik`a çevirir;
/// üst katmanlar yalnızca `Basarisizlik` görür.
package enum DosyaIstisnasi: Error, Equatable {
    case okunamadi(URL, neden: String)
    case yazilamadi(URL, neden: String)
}
