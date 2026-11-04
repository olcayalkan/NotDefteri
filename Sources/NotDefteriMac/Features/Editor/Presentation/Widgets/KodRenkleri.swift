import AppKit
import NotDefteriCekirdek

func kodRengi(_ tur: KodTokenTuru, tema: Tema) -> NSColor {
    let zemin = tema.arkaplan.usingColorSpace(.genericRGB) ?? tema.arkaplan
    let koyu = 0.2126 * zemin.redComponent + 0.7152 * zemin.greenComponent + 0.0722 * zemin.blueComponent < 0.5
    let hex: UInt32
    switch (koyu, tur) {
    case (true, .anahtarKelime): hex = 0xFF7AB2
    case (true, .metin): hex = 0xA8CC8C
    case (true, .sayi): hex = 0xD9C97C
    case (true, .yorum): hex = 0x8B949E
    case (true, .tur): hex = 0x6BDFFF
    case (true, .fonksiyon): hex = 0x79C0FF
    case (true, .operator): hex = 0xD2A8FF
    case (false, .anahtarKelime): hex = 0x8E2CB1
    case (false, .metin): hex = 0xA52A2A
    case (false, .sayi): hex = 0x1769AA
    case (false, .yorum): hex = 0x66727F
    case (false, .tur): hex = 0x087A8C
    case (false, .fonksiyon): hex = 0x1769AA
    case (false, .operator): hex = 0x7A3FA3
    }
    return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                   green: CGFloat((hex >> 8) & 0xFF) / 255,
                   blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
