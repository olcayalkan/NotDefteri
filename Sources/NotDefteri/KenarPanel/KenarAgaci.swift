import AppKit

// MARK: - Kenar panel sayfa ağacı

/// Her tıklama, sayısıyla birlikte panele bildirilir. Üçüncü tıklama sayfayı içerik
/// penceresinde açar; çift tıklamanın başlattığı ad düzenlemesi o an iptal edilir.
final class KenarAgaci: NSOutlineView {
    /// Tıklama sayısı ve satır; `true` dönerse olay ağaca iletilmez.
    var tiklamaGeldi: ((_ sayi: Int, _ satir: Int) -> Bool)?

    override func mouseDown(with event: NSEvent) {
        let satir = row(at: convert(event.locationInWindow, from: nil))
        if tiklamaGeldi?(event.clickCount, satir) == true { return }
        super.mouseDown(with: event)
    }
}
