import Foundation

// MARK: - Güvenli dosya adı üretimi

/// Markdown bağında ve dosya sisteminde sorun çıkaran karakterler.
///
/// Parantez özellikle kritik: bağ biçimi `![](yol)` olduğu için yolda geçen
/// bir `)` bağı erken bitiriyor ve görsel bir daha okunamıyordu
/// (ör. "User-Agent- () { -; }; nslookup {whoami}.png" yazıldı ama
/// "Görseller/User-Agent- (" olarak okundu — görsel kayboldu).
private let kTehlikeliKarakterler = CharacterSet(charactersIn: "/:()[]{}#?*|<>\"\\'`!$&;=+,%\n\r\t")

/// Bir başlığı/metni güvenli bir dosya adı tabanına çevirir.
///
/// - Tehlikeli karakterler tireye dönüşür, arka arkaya gelenler tekleşir.
/// - Baş/son tireler ve boşluklar kırpılır.
/// - En fazla `enFazlaUzunluk` karakter (uzun başlıklar dosya adını şişirmesin).
/// - Sonuç boş kalırsa `varsayilan` kullanılır.
func guvenliDosyaAdi(_ metin: String,
                     varsayilan: String = "Görsel",
                     enFazlaUzunluk: Int = 40) -> String {
    // Tehlikeli karakterleri tireye çevir.
    var temiz = String(metin.unicodeScalars.map {
        kTehlikeliKarakterler.contains($0) ? "-" : Character($0)
    })
    // Arka arkaya tire/boşlukları tekle.
    while temiz.contains("--") { temiz = temiz.replacingOccurrences(of: "--", with: "-") }
    while temiz.contains("  ") { temiz = temiz.replacingOccurrences(of: "  ", with: " ") }

    temiz = temiz.trimmingCharacters(in: CharacterSet(charactersIn: " -._"))
    if temiz.count > enFazlaUzunluk {
        temiz = String(temiz.prefix(enFazlaUzunluk))
            .trimmingCharacters(in: CharacterSet(charactersIn: " -._"))
    }
    // macOS'ta nokta ile başlayan dosya gizlidir; istemeden gizlenmesin.
    while temiz.hasPrefix(".") { temiz.removeFirst() }

    return temiz.isEmpty ? varsayilan : temiz
}

/// Verilen klasörde adı çakışmayan bir dosya yolu üretir.
/// "Ad.png" doluysa "Ad-2.png", "Ad-3.png" diye devam eder.
func benzersizDosyaYolu(klasor: URL, taban: String, uzanti: String) -> URL {
    var aday = klasor.appendingPathComponent("\(taban).\(uzanti)")
    var sayac = 2
    while FileManager.default.fileExists(atPath: aday.path) {
        aday = klasor.appendingPathComponent("\(taban)-\(sayac).\(uzanti)")
        sayac += 1
    }
    return aday
}

/// Bir görsel dosyasını hedef klasöre, adı çakışmayacak biçimde kopyalar.
///
/// Kaynak olduğu yerde kalır: aynı görsel iki sayfada kullanılınca özgün
/// sayfa dosyasını kaybetmemeli. Bayt bayt kopyalanır — yeniden kodlanmadığı
/// için JPEG/HEIC gibi biçimler kalitesini yitirmez.
/// `taban` verilmezse kaynağın kendi adı kullanılır.
func gorselDosyasiniKopyala(_ kaynak: URL, hedefKlasor: URL, taban: String? = nil) -> URL? {
    let fm = FileManager.default
    guard fm.fileExists(atPath: kaynak.path) else { return nil }
    try? fm.createDirectory(at: hedefKlasor, withIntermediateDirectories: true)

    let uzanti = kaynak.pathExtension.isEmpty ? "png" : kaynak.pathExtension
    let ad = guvenliDosyaAdi(taban ?? kaynak.deletingPathExtension().lastPathComponent)
    let hedef = benzersizDosyaYolu(klasor: hedefKlasor, taban: ad, uzanti: uzanti)
    guard (try? fm.copyItem(at: kaynak, to: hedef)) != nil else { return nil }
    return hedef
}
