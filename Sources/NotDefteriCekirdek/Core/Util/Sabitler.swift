import Foundation

// MARK: - Ölçü ve sınır sabitleri
//
// Uygulama genelinde kullanılan, çalışma anında değişmeyen değerler.
// Değişebilen (kullanıcı tercihi olan) durumlar için `Ayarlar.swift`e bakın.

// Kenar panel
package let kKenarPanelMinGenislik: CGFloat = 140
package let kKenarPanelMaksGenislik: CGFloat = 360

/// Özel başlık çubuğunun yüksekliği.
package let kBaslikYuksekligi: CGFloat = 34

/// Editör yerleşimi: yazıya olabildiğince yer kalsın diye kenar payları küçük tutulur.
/// En geniş metin satırı; geniş pencerede satır okunmaz uzunluğa çıkmasın.
package let kEnGenisMetin: CGFloat = 1200
/// Metnin iki yanında kalan en az pay; solda blok tutamacı (⋮⋮) ve başlık katlama üçgeni durur.
package let kEditorYanPayi: CGFloat = 24
/// Metnin üstünde ve altında editörün iç boşluğu.
package let kEditorDikeyBoslugu: CGFloat = 4
/// Editör altındaki kelime sayısı şeridi.
package let kAltBilgiYuksekligi: CGFloat = 22

/// Otomatik kaydın bekleme süresi. Kesintisiz yazarken bile en fazla
/// bu aralıkta bir disk yazımı olur.
package let kOtomatikKayitAraligi: TimeInterval = 5

// Punto sınırları
package let kMinYaziBoyutu: CGFloat = 10
package let kMaksYaziBoyutu: CGFloat = 28

/// Sabit taban punto. Etiketsiz metnin ve başlıkların ölçüsü buna göre belirlenir;
/// hiçbir zaman değişmez, böylece kaydedilen puntolar yeniden açışta/derlemede kaymaz.
package let kTabanPunto: CGFloat = 14

/// Kutu çerçevesinin metnin üstünde/altında bıraktığı iç boşluk.
package let kKutuIcBoslugu: CGFloat = 8

/// Kod bloğu ve uyarı kutusunun üstünde/altında bırakılan görünüm boşluğu. Çerçeve metnin
/// kKutuIcBoslugu kadar dışına çizildiği için kutu ile komşu paragraf arasında yaklaşık yarım
/// satır kalır. Yalnızca görünümdür; Markdown'a satır yazılmaz.
package let kKutuDisBoslugu: CGFloat = (kTabanPunto * 0.6).rounded() + kKutuIcBoslugu

/// macOS'ta kutunun altındaki boşluk (üstte boş satır ya da kutu varsa üstteki de). Çerçevenin
/// dışında 2 pt kalır; kutudan sonraki yazı ve alttaki kutu kopuk duruyordu. Çerçeve yazıya
/// değmesin diye iç boşluktan küçük olamaz.
package let kKutuAltBoslugu: CGFloat = kKutuIcBoslugu + 2

/// macOS'ta doğrudan başka bir kutunun altındaki kutunun üst boşluğu. Üstteki kutunun alt boşluğuyla
/// toplanır; toplam iki çerçevenin taşmasına eşit olunca kutular arada boşluk kalmadan bitişir.
package let kKutuBitisikUstBoslugu: CGFloat = kKutuIcBoslugu * 2 - kKutuAltBoslugu

/// macOS'ta iki kutu arasındaki tek boş satırın yüksekliği. Satır kalır (tıklanıp yazılabilir,
/// kayıtta boş satır), yalnızca kutular arası boşluğu tam satır kadar açmaz.
package let kKutularArasiBosSatirYuksekligi: CGFloat = 6

/// macOS'ta bitişik alıntı ile uyarı kutusu arasına kayıtta yazılan boş satırın yüksekliği;
/// düzenlerken bitişik görünen ikili, yeniden açılınca da bitişik görünür.
package let kAyracSatiriYuksekligi: CGFloat = 1

/// Uyarı kutusunun bir rengi. Menüler, `/` kısayolları, çizim ve dışa aktarım yalnızca bu
/// tabloyu okur: her renk aynı yeteneklere sahiptir, renge özel kod yazılmaz.
package struct UyariRengi {
    /// Kayıttaki ad (`> [!💡 mavi]`).
    package let ad: String
    /// Ekran rengi (0–1 RGB). Doygun sistem renkleri yerine kağıtta göz yormayan koyu tonlar;
    /// koyulaşan tema zemininde açık tonlar seçilmiyordu.
    package let ekran: (r: Double, g: Double, b: Double)
    /// HTML dışa aktarımındaki `r,g,b`; beyaz sayfada okunacak kadar doygun.
    package let html: String
    /// `/` ile yazılıp Enter'la uygulanan kısayollar.
    package let kisayollar: [String]
}

/// Sıra menülerdeki sıradır.
package let kUyariRenkTanimlari: [UyariRengi] = [
    UyariRengi(ad: "gri", ekran: (0.42, 0.42, 0.44), html: "128,128,128", kisayollar: ["gri", "gray"]),
    UyariRengi(ad: "mavi", ekran: (0.24, 0.40, 0.62), html: "40,120,220", kisayollar: ["mavi", "blue"]),
    UyariRengi(ad: "sarı", ekran: (0.62, 0.47, 0.10), html: "230,180,20", kisayollar: ["sari", "yellow"]),
    UyariRengi(ad: "kırmızı", ekran: (0.64, 0.26, 0.24), html: "220,60,60", kisayollar: ["kirmizi", "red"]),
    UyariRengi(ad: "yeşil", ekran: (0.24, 0.48, 0.31), html: "40,160,80", kisayollar: ["yesil", "green", "info"])]

/// Ad ile arama; tanınmayan renk griye düşer.
package func uyariRengi(_ ad: String) -> UyariRengi {
    kUyariRenkTanimlari.first { $0.ad == ad } ?? kUyariRenkTanimlari[0]
}

/// Kod kutusu içi metin rengiyle hafifçe doldurulur. Uyarı kutusu kendi rengiyle daha
/// belirgin doldurulur, çizgisi de koyu tutulur; böylece koyu kağıtta da renk okunur.
package let kKutuDolguOpakligi = 0.07
package let kUyariDolguOpakligi = 0.16
package let kUyariCizgiOpakligi = 0.75

/// Tema zeminlerinin (arka plan, başlık, panel) main renklerine göre parlaklık oranı.
/// Uzun kullanımda göz yormasın diye hepsi aynı oranda koyulaşır; tek oran temalar
/// arasındaki ton ilişkisini korur. macOS `Tema.swift` ile `LinuxTema` aynı değeri kullanır.
package let kTemaZeminParlakligi = 0.87

/// Kağıt temalarında başlık çubuğu ve kenar panelin ek parlaklık oranı. Main'de panel
/// kağıttan yalnızca ~0.04 koyuydu, editörle sınırı seçilmiyordu; çerçeve koyulaşınca
/// yazı alanı ayrışır. Koyu temada panel zaten zeminden açık olduğu için uygulanmaz.
package let kTemaCerceveParlakligi = 0.92
