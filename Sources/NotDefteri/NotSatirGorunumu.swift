import AppKit

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

    func temayiUygula() {
        vurguGorunumu.layer?.backgroundColor = secimVurguRengi().cgColor
    }
}
