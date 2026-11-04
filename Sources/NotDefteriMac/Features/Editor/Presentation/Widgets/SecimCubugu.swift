import AppKit
import NotDefteriCekirdek

final class SecimCubugu: NSView {
    private lazy var panel = YuzerPanel(gorunum: self)
    private var dugmeler: [NSButton] = []

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 350, height: 34))
        let komutlar: [(String, Selector)] = [
            ("Kalın", #selector(NotPenceresi.kalinKomutu(_:))),
            ("İtalik", #selector(NotPenceresi.italikKomutu(_:))),
            ("Çizili", #selector(NotPenceresi.ustuCiziliKomutu(_:))),
            ("Kod", #selector(NotPenceresi.satirIciKodKomutu(_:))),
            ("Vurgu", #selector(NotPenceresi.vurguKomutu(_:))),
            ("Bağlantı", #selector(NotPenceresi.baglantiKomutu(_:)))]
        for (sira, komut) in komutlar.enumerated() {
            let dugme = NSButton(title: komut.0, target: nil, action: komut.1)
            dugme.frame = NSRect(x: 4 + CGFloat(sira) * 57, y: 4, width: 57, height: 26)
            dugme.isBordered = false
            dugme.refusesFirstResponder = true
            dugme.font = NSFont.systemFont(ofSize: 12)
            dugme.toolTip = komut.0
            addSubview(dugme)
            dugmeler.append(dugme)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }
    func goster(_ kare: NSRect, pencere: NSWindow) {
        dugmeler.forEach { $0.target = pencere; $0.contentTintColor = kMetinRenk }
        panel.goster(kare, ustunde: true, pencere: pencere)
    }
    func gizle() { panel.gizle() }
}
