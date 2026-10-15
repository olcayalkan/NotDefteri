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

/// Uyarı kutusu renkleri (0–1 RGB). Doygun sistem renkleri yerine kağıtta göz yormayan
/// koyu tonlar; koyulaşan tema zemininde açık tonlar seçilmiyordu.
package let kUyariRenkleri: [String: (r: Double, g: Double, b: Double)] = [
    "gri": (0.42, 0.42, 0.44), "mavi": (0.24, 0.40, 0.62), "sarı": (0.62, 0.47, 0.10),
    "kırmızı": (0.64, 0.26, 0.24), "yeşil": (0.24, 0.48, 0.31)]

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
