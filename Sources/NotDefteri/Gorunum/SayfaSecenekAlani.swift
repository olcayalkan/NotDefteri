import AppKit
import NotDefteriCekirdek

/// Editörün üstündeki ince şerit; fare üzerindeyken "•••" sayfa seçenekleri düğmesini gösterir.
final class SayfaSecenekAlani: NSView {
    static let yukseklik: CGFloat = 36
    let dugme = NSButton(title: "•••", target: nil, action: nil)
    private var izleme: NSTrackingArea?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        dugme.toolTip = "Sayfa seçenekleri"
        dugme.isBordered = false
        dugme.refusesFirstResponder = true
        dugme.isHidden = true
        addSubview(dugme)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        dugme.frame = NSRect(x: 8, y: bounds.height - 30, width: 40, height: 26)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let izleme { removeTrackingArea(izleme) }
        let yeni = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(yeni)
        izleme = yeni
    }

    override func mouseEntered(with event: NSEvent) { dugme.isHidden = false }
    override func mouseExited(with event: NSEvent) { dugme.isHidden = true }
}
