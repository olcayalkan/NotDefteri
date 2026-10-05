import Foundation

// MARK: - Arama için metin normalleştirme

/// Türkçe karakter/büyük-küçük harf duyarsız arama için metni sadeleştirir
/// (ör. "İ"/"I"/"ı"/"i" birbiriyle ve "ö"/"ü"/"ş"/"ç"/"ğ" sade karşılıklarıyla eşleşir).
///
/// Noktalı/noktasız i ailesi önce tek harfe indirgenir. Aksi hâlde
/// `.diacriticInsensitive` "İ"nin noktasını silip "I" yapıyor, ardından
/// tr_TR küçültmesi onu "ı"ya çeviriyordu; sonuçta "istanbul" araması
/// "İstanbul" başlıklı notu bulamıyordu.
package func aramaIcinSadelestir(_ metin: String) -> String {
    var sade = metin
    for harf in ["İ", "I", "ı"] {
        sade = sade.replacingOccurrences(of: harf, with: "i")
    }
    return sade.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
}
