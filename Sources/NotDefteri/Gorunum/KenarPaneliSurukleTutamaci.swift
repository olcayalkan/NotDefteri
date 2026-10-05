import AppKit
import NotDefteriCekirdek

// MARK: - Kenar panelin genişliğini fare ile ayarlamak için sürükle tutamacı

final class KenarPaneliSurukleTutamaci: NSView {

    var surukleniyor: ((NSEvent) -> Void)?
    private var izlemeAlani: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let izlemeAlani { removeTrackingArea(izlemeAlani) }
        let yeni = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate], owner: self, userInfo: nil)
        addTrackingArea(yeni)
        izlemeAlani = yeni
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDragged(with event: NSEvent) {
        surukleniyor?(event)
    }
}
