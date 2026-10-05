import AppKit
import NotDefteriCekirdek

// MARK: - Tema

/// Bir kağıt temasının renk takımı.
struct Tema {
    let ad: String
    let arkaplan: NSColor
    let baslikCubugu: NSColor
    let kenarPanel: NSColor
}

let temaListesi: [Tema] = [
    Tema(ad: "Sepya",
         arkaplan: NSColor(calibratedRed: 0.84, green: 0.81, blue: 0.73, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.78, green: 0.74, blue: 0.65, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.80, green: 0.77, blue: 0.69, alpha: 1.0)),
    Tema(ad: "Yeşilimsi Kağıt",
         arkaplan: NSColor(calibratedRed: 0.79, green: 0.83, blue: 0.76, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.72, green: 0.77, blue: 0.70, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.75, green: 0.80, blue: 0.73, alpha: 1.0)),
    Tema(ad: "Gri Kağıt",
         arkaplan: NSColor(calibratedRed: 0.80, green: 0.80, blue: 0.80, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.73, green: 0.73, blue: 0.73, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.76, green: 0.76, blue: 0.76, alpha: 1.0)),
    Tema(ad: "Krem",
         arkaplan: NSColor(calibratedRed: 0.86, green: 0.83, blue: 0.76, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.80, green: 0.76, blue: 0.67, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.82, green: 0.79, blue: 0.71, alpha: 1.0)),
]

/// O an seçili tema. Seçim `gTemaIndex` üzerinden yapılır (bkz. `Ayarlar.swift`).
var aktifTema: Tema {
    if !temaListesi.indices.contains(gTemaIndex) { gTemaIndex = 0 }
    return temaListesi[gTemaIndex]
}

// MARK: - Temadan türetilen renkler

/// Kenar paneldeki, üzerinde çalışılan (seçili) notun dış kaplama rengi: panel renginin koyusu.
func secimVurguRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.14) }
/// Arama kutusunun, panelden ayrışması için biraz koyulaştırılmış rengi.
func aramaKutuRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.07) }
/// Arama kutusuna odaklanıldığında kullanılan, biraz daha koyu vurgu rengi.
func aramaOdakRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.16) }

extension NSColor {
    /// Rengi belirtilen miktar kadar koyulaştırır (0-1 arası).
    func koyulastir(_ miktar: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.genericRGB) else { return self }
        return NSColor(calibratedRed: max(rgb.redComponent - miktar, 0),
                        green: max(rgb.greenComponent - miktar, 0),
                        blue: max(rgb.blueComponent - miktar, 0),
                        alpha: rgb.alphaComponent)
    }
}
