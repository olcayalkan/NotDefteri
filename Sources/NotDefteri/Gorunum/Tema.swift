import AppKit
import NotDefteriCekirdek

// MARK: - Tema

/// Bir temanın zemin, başlık, panel ve metin renk takımı.
struct Tema {
    let ad: String
    let arkaplan: NSColor
    let baslikCubugu: NSColor
    let kenarPanel: NSColor
    let metin: NSColor

    var koyuMu: Bool {
        let renk = arkaplan.usingColorSpace(.genericRGB) ?? arkaplan
        return 0.2126 * renk.redComponent + 0.7152 * renk.greenComponent + 0.0722 * renk.blueComponent < 0.45
    }
}

/// Değerler main'deki kağıt renkleridir; hepsi `kTemaZeminParlakligi` ile aynı oranda koyulaşır.
private func zemin(_ kirmizi: CGFloat, _ yesil: CGFloat, _ mavi: CGFloat,
                   oran: CGFloat = CGFloat(kTemaZeminParlakligi)) -> NSColor {
    NSColor(calibratedRed: kirmizi * oran, green: yesil * oran, blue: mavi * oran, alpha: 1.0)
}

/// Kağıt temasının başlık çubuğu ve kenar paneli: editörden ayrışsın diye ek koyulaşır.
private func cerceve(_ kirmizi: CGFloat, _ yesil: CGFloat, _ mavi: CGFloat) -> NSColor {
    zemin(kirmizi, yesil, mavi, oran: CGFloat(kTemaZeminParlakligi * kTemaCerceveParlakligi))
}

/// Sıra kayıtlı indekstir (bkz. `temaSeciminiYukle`); değiştirmek seçimleri kaydırır.
let temaListesi: [Tema] = [
    Tema(ad: "Sepya",
         arkaplan: zemin(0.84, 0.81, 0.73),
         baslikCubugu: cerceve(0.78, 0.74, 0.65),
         kenarPanel: cerceve(0.80, 0.77, 0.69),
         metin: .black),
    Tema(ad: "Terminal",
         arkaplan: zemin(23 / 255, 20 / 255, 33 / 255),
         baslikCubugu: zemin(16 / 255, 14 / 255, 24 / 255),
         kenarPanel: zemin(33 / 255, 29 / 255, 43 / 255),
         metin: NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.97, alpha: 1.0)),
    Tema(ad: "Yeşilimsi Kağıt",
         arkaplan: zemin(0.79, 0.83, 0.76),
         baslikCubugu: cerceve(0.72, 0.77, 0.70),
         kenarPanel: cerceve(0.75, 0.80, 0.73),
         metin: .black),
    Tema(ad: "Gri Kağıt",
         arkaplan: zemin(0.80, 0.80, 0.80),
         baslikCubugu: cerceve(0.73, 0.73, 0.73),
         kenarPanel: cerceve(0.76, 0.76, 0.76),
         metin: .black),
]

/// O an seçili tema. Seçim `gTemaIndex` üzerinden yapılır (bkz. `Ayarlar.swift`).
var aktifTema: Tema {
    if !temaListesi.indices.contains(gTemaIndex) { gTemaIndex = 0 }
    return temaListesi[gTemaIndex]
}

// MARK: - Temadan türetilen renkler

/// Kenar paneldeki, üzerinde çalışılan (seçili) notun dış kaplama rengi: panel renginin koyusu.
func secimVurguRengi() -> NSColor { aktifTema.kenarPanel.tonFarki(0.14, koyuTema: aktifTema.koyuMu) }
/// Arama kutusunun, panelden ayrışması için biraz koyulaştırılmış rengi.
func aramaKutuRengi() -> NSColor { aktifTema.kenarPanel.tonFarki(0.07, koyuTema: aktifTema.koyuMu) }
/// Arama kutusuna odaklanıldığında kullanılan, biraz daha koyu vurgu rengi.
func aramaOdakRengi() -> NSColor { aktifTema.kenarPanel.tonFarki(0.16, koyuTema: aktifTema.koyuMu) }

/// Sayfa bağı ve dış bağlantı rengi: kağıtta koyu, mürekkep mavisi; koyu temada açık mavi.
func bagRengi() -> NSColor {
    aktifTema.koyuMu ? NSColor(srgbRed: 0.56, green: 0.72, blue: 0.92, alpha: 1)
                     : NSColor(srgbRed: 0.18, green: 0.37, blue: 0.50, alpha: 1)
}

/// Tamamlanan görev kutusunun dolgusu; beyaz tik bu zeminde okunur.
func tamamlananGorevRengi() -> NSColor { NSColor(srgbRed: 0.25, green: 0.42, blue: 0.27, alpha: 1) }

/// Bağlantıların ortak görünümü (dış bağlantı `linkTextAttributes`, sayfa bağı geçici öznitelik).
func bagOznitelikleri() -> [NSAttributedString.Key: Any] {
    [.foregroundColor: bagRengi(), .underlineStyle: NSUnderlineStyle.single.rawValue]
}

/// Başlık simgeleri ve ikincil metinler için tema zeminine uygun ön plan rengi. Açık
/// temada main'in `.darkGray`'inden koyudur: panel koyulaşınca kontrast main düzeyinde kalır.
func temaSimgeRengi() -> NSColor { aktifTema.koyuMu ? aktifTema.metin.withAlphaComponent(0.72) : kAcikTemaSimgeRengi }
let kAcikTemaSimgeRengi = NSColor(calibratedWhite: 0.2, alpha: 1)

extension NSColor {
    /// Main'deki açık tema davranışı ve API'si korunur.
    func koyulastir(_ miktar: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.genericRGB) else { return self }
        return NSColor(calibratedRed: max(rgb.redComponent - miktar, 0),
                       green: max(rgb.greenComponent - miktar, 0),
                       blue: max(rgb.blueComponent - miktar, 0),
                       alpha: rgb.alphaComponent)
    }

    /// Açık temada koyulaştırır, koyu temada açar; benzer koyu tonların birbirine karışmasını önler.
    func tonFarki(_ miktar: CGFloat, koyuTema: Bool) -> NSColor {
        if !koyuTema { return koyulastir(miktar) }
        guard let rgb = usingColorSpace(.genericRGB) else { return self }
        let yon: (CGFloat) -> CGFloat = { bilesen in
            koyuTema ? min(bilesen + miktar, 1) : max(bilesen - miktar, 0)
        }
        return NSColor(calibratedRed: yon(rgb.redComponent),
                        green: yon(rgb.greenComponent),
                        blue: yon(rgb.blueComponent),
                        alpha: rgb.alphaComponent)
    }
}
