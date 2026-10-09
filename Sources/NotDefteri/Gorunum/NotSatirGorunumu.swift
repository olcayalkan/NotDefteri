import AppKit
import NotDefteriCekirdek

// MARK: - Not satırı (seçili notun dış kaplamasını animasyonlu şekilde vurgular)

final class NotSatirGorunumu: NSTableRowView {

    private let vurguGorunumu = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        vurguGorunumu.wantsLayer = true
        vurguGorunumu.layer?.cornerRadius = 6
        vurguGorunumu.layer?.backgroundColor = secimVurguRengi().cgColor
        vurguGorunumu.alphaValue = 0
        addSubview(vurguGorunumu, positioned: .below, relativeTo: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        vurguGorunumu.frame = bounds.insetBy(dx: 4, dy: 1)
    }

    override var isSelected: Bool {
        get { super.isSelected }
        set {
            let degisti = super.isSelected != newValue
            super.isSelected = newValue
            guard degisti else { return }
            NSAnimationContext.runAnimationGroup { baglam in
                baglam.duration = 0.16
                baglam.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                vurguGorunumu.animator().alphaValue = newValue ? 1 : 0
            }
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        // Varsayılan mavi seçim çizimi yerine kendi vurgu view'ımızı kullanıyoruz.
    }

    /// Sürüklenen sayfanın bırakılacağı satır: sistem mavisi yerine temanın
    /// kendi koyu tonuyla çerçeve.
    override func drawDraggingDestinationFeedback(in dirtyRect: NSRect) {
        let cerceve = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 6, yRadius: 6)
        secimVurguRengi().withAlphaComponent(0.35).setFill()
        cerceve.fill()
        secimVurguRengi().tonFarki(0.12, koyuTema: aktifTema.koyuMu).setStroke()
        cerceve.lineWidth = 1.5
        cerceve.stroke()
    }

    func temayiUygula() {
        vurguGorunumu.layer?.backgroundColor = secimVurguRengi().cgColor
    }
}
