import AppKit

// MARK: - Ölçü ve sınır sabitleri
//
// Uygulama genelinde kullanılan, çalışma anında değişmeyen değerler.
// Değişebilen (kullanıcı tercihi olan) durumlar için `Ayarlar.swift`e bakın.

/// Metin rengi. Kağıt temalarının hepsi açık zeminli olduğu için sabit siyah.
let kMetinRenk = NSColor.black

// Kenar panel
let kKenarPanelMinGenislik: CGFloat = 140
let kKenarPanelMaksGenislik: CGFloat = 360

/// Özel başlık çubuğunun yüksekliği.
let kBaslikYuksekligi: CGFloat = 34

/// Otomatik kaydın bekleme süresi. Kesintisiz yazarken bile en fazla
/// bu aralıkta bir disk yazımı olur.
let kOtomatikKayitAraligi: TimeInterval = 5

// Punto sınırları
let kMinYaziBoyutu: CGFloat = 10
let kMaksYaziBoyutu: CGFloat = 28

/// Sabit taban punto. Etiketsiz metnin ve başlıkların ölçüsü buna göre belirlenir;
/// hiçbir zaman değişmez, böylece kaydedilen puntolar yeniden açışta/derlemede kaymaz.
let kTabanPunto: CGFloat = 14
