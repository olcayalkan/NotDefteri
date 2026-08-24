import AppKit

// MARK: - SF Symbol boyama

/// Bir SF Symbol'ü verilen renkle (varsayılan tonlama/gölge olmadan) yeniden boyar.
///
/// `contentTintColor` yerine bu gerekiyor: şablon olmayan bir görsel üretip
/// rengi `.sourceAtop` ile bastığımız için sistemin gri tonlaması devreye girmiyor.
func renklendirilmisSembol(_ ad: String, renk: NSColor, boyut: CGFloat = 12) -> NSImage? {
    guard let taban = NSImage(systemSymbolName: ad, accessibilityDescription: nil) else { return nil }
    let yapilandirma = NSImage.SymbolConfiguration(pointSize: boyut, weight: .regular)
    guard let yapilandirilmis = taban.withSymbolConfiguration(yapilandirma) else { return nil }
    let sonuc = NSImage(size: yapilandirilmis.size)
    sonuc.lockFocus()
    yapilandirilmis.draw(at: .zero, from: NSRect(origin: .zero, size: yapilandirilmis.size), operation: .sourceOver, fraction: 1.0)
    renk.set()
    NSRect(origin: .zero, size: yapilandirilmis.size).fill(using: .sourceAtop)
    sonuc.unlockFocus()
    sonuc.isTemplate = false
    return sonuc
}
