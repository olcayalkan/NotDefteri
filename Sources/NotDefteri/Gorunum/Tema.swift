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

let temaListesi: [Tema] = [
    Tema(ad: "Sepya",
         arkaplan: NSColor(calibratedRed: 0.84, green: 0.81, blue: 0.73, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.78, green: 0.74, blue: 0.65, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.80, green: 0.77, blue: 0.69, alpha: 1.0),
         metin: .black),
    Tema(ad: "Terminal",
         arkaplan: NSColor(calibratedRed: 23 / 255, green: 20 / 255, blue: 33 / 255, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 16 / 255, green: 14 / 255, blue: 24 / 255, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 33 / 255, green: 29 / 255, blue: 43 / 255, alpha: 1.0),
         metin: NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.97, alpha: 1.0)),
    Tema(ad: "Yeşilimsi Kağıt",
         arkaplan: NSColor(calibratedRed: 0.79, green: 0.83, blue: 0.76, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.72, green: 0.77, blue: 0.70, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.75, green: 0.80, blue: 0.73, alpha: 1.0),
         metin: .black),
    Tema(ad: "Gri Kağıt",
         arkaplan: NSColor(calibratedRed: 0.80, green: 0.80, blue: 0.80, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.73, green: 0.73, blue: 0.73, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.76, green: 0.76, blue: 0.76, alpha: 1.0),
         metin: .black),
    Tema(ad: "Krem",
         arkaplan: NSColor(calibratedRed: 0.86, green: 0.83, blue: 0.76, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.80, green: 0.76, blue: 0.67, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.82, green: 0.79, blue: 0.71, alpha: 1.0),
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

/// Başlık simgeleri ve ikincil metinler için tema zeminine uygun ön plan rengi.
func temaSimgeRengi() -> NSColor { aktifTema.koyuMu ? aktifTema.metin.withAlphaComponent(0.72) : .darkGray }

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
