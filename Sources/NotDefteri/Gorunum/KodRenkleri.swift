import AppKit
import NotDefteriCekirdek

func kodRengi(_ tur: KodTokenTuru, tema: Tema) -> NSColor {
    let zemin = tema.arkaplan.usingColorSpace(.genericRGB) ?? tema.arkaplan
    let koyu = 0.2126 * zemin.redComponent + 0.7152 * zemin.greenComponent + 0.0722 * zemin.blueComponent < 0.5
    let renk: NSColor
    switch tur {
    case .anahtarKelime: renk = koyu ? .systemPink : .systemPurple
    case .metin: renk = koyu ? .systemGreen : .systemRed
    case .sayi: renk = koyu ? .systemOrange : .systemBlue
    case .yorum: renk = koyu ? .lightGray : .darkGray
    case .tur: renk = .systemTeal
    case .fonksiyon: renk = .systemBlue
    case .operator: renk = koyu ? .white : .black
    }
    // Tema tonu korunur; koyu zeminde kontrast için renk beyaza yaklaştırılır.
    let belirgin = renk.blended(withFraction: koyu ? 0.25 : 0.2, of: koyu ? .white : .black) ?? renk
    return belirgin.blended(withFraction: 0.08, of: zemin) ?? belirgin
}
