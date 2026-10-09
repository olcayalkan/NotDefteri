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

/// Kod bloğu ve uyarı kutusunun üstünde/altında bırakılan görünüm boşluğu. Çerçeve metnin
/// 3 pt dışına çizildiği için kutu ile komşu paragraf arasında yaklaşık yarım satır kalır.
/// Yalnızca görünümdür; Markdown'a satır yazılmaz.
package let kKutuDisBoslugu: CGFloat = (kTabanPunto * 0.6).rounded() + 3
