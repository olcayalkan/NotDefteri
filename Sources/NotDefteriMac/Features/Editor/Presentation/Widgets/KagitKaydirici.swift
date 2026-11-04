import AppKit

// MARK: - Kağıt zemininde kaydırma çubuğu

/// Oluk (knob slot) çizmeyen kaydırma çubuğu.
///
/// Sistem "kaydırma çubuklarını göster: otomatik" ayarında ve fare bağlıyken AppKit eski
/// stil çubuğu beyaz bir olukla çizer; kağıt zemininde editörün ve kenar panelin sağında
/// beyaz şerit görünüyordu. Tutamaç olduğu gibi kalır; ayar sonradan değişse de geçerlidir.
final class KagitKaydirici: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }
    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}
}

extension NSScrollView {
    /// Dikey çubuğu kağıt zeminine uygun hâle getirir (bkz. `KagitKaydirici`).
    func kagitKaydiriciKullan() {
        verticalScroller = KagitKaydirici()
    }
}
