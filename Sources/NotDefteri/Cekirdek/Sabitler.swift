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

/// Uyarı kutusu renkleri (0–1 RGB). Doygun sistem renkleri yerine kağıtta göz yormayan yumuşak tonlar.
package let kUyariRenkleri: [String: (r: Double, g: Double, b: Double)] = [
    "gri": (0.56, 0.56, 0.58), "mavi": (0.36, 0.53, 0.78), "sarı": (0.80, 0.64, 0.20),
    "kırmızı": (0.80, 0.38, 0.36), "yeşil": (0.36, 0.62, 0.43)]

/// Kutu (kod/uyarı) içi çerçeve rengiyle doldurulur; uyarı çizgisi de soluk tutulur.
package let kKutuDolguOpakligi = 0.07
package let kUyariCizgiOpakligi = 0.45
