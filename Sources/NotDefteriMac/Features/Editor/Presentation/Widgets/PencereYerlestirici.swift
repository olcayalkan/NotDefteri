import AppKit

/// Ekran kenarına bırakılan pencerenin alacağı yer.
enum Yerlesim: Equatable {
    case doldur, sol, sag, solUst, sagUst, solAlt, sagAlt

    /// Kenara bu kadar yaklaşan fare yerleşim sayılır.
    static let kenarEsigi: CGFloat = 6
    /// Yan kenarda üst/alt köşeye bu kadar yakınsa çeyrek yerleşim olur.
    static let koseEsigi: CGFloat = 80

    /// Farenin ekranda değdiği kenara göre yerleşim; kenara değmiyorsa nil.
    static func bul(fare: NSPoint, ekran: NSRect) -> Yerlesim? {
        let sol = fare.x <= ekran.minX + kenarEsigi
        let sag = fare.x >= ekran.maxX - kenarEsigi
        guard sol || sag else { return fare.y >= ekran.maxY - kenarEsigi ? .doldur : nil }
        if fare.y >= ekran.maxY - koseEsigi { return sol ? .solUst : .sagUst }
        if fare.y <= ekran.minY + koseEsigi { return sol ? .solAlt : .sagAlt }
        return sol ? .sol : .sag
    }

    /// Ekranın kullanılabilir alanında hedef çerçeve.
    func cerceve(_ alan: NSRect) -> NSRect {
        let yariGenislik = (alan.width / 2).rounded(.down)
        let yariYukseklik = (alan.height / 2).rounded(.down)
        let solX = alan.minX, sagX = alan.minX + yariGenislik
        let altY = alan.minY, ustY = alan.minY + yariYukseklik
        let sagGenislik = alan.width - yariGenislik, ustYukseklik = alan.height - yariYukseklik
        switch self {
        case .doldur: return alan
        case .sol:    return NSRect(x: solX, y: altY, width: yariGenislik, height: alan.height)
        case .sag:    return NSRect(x: sagX, y: altY, width: sagGenislik, height: alan.height)
        case .solUst: return NSRect(x: solX, y: ustY, width: yariGenislik, height: ustYukseklik)
        case .sagUst: return NSRect(x: sagX, y: ustY, width: sagGenislik, height: ustYukseklik)
        case .solAlt: return NSRect(x: solX, y: altY, width: yariGenislik, height: yariYukseklik)
        case .sagAlt: return NSRect(x: sagX, y: altY, width: sagGenislik, height: yariYukseklik)
        }
    }
}

/// Başlık çubuğundan pencere taşıma: kenara bırakınca yarıya/çeyreğe yerleşir, üst kenarda
/// ekranı doldurur. Çift tık ekranı doldurur, ikinci çift tık eski yerine ve boyutuna döndürür.
/// Yerleşik pencere sürüklenince de eski boyutuna döner.
@MainActor
final class PencereYerlestirici {

    /// Yerleşmeden önceki çerçeve.
    private var oncekiCerceve: NSRect?
    /// Yerleştirdiğimiz çerçeve; kullanıcı elle boyutlandırınca pencere artık yerleşik sayılmaz.
    private var yerlesikCerceve: NSRect?
    private var onizleme: NSWindow?

    private func yerlesikMi(_ pencere: NSWindow) -> Bool {
        yerlesikCerceve != nil && yerlesikCerceve == pencere.frame
    }

    func ciftTiklandi(_ pencere: NSWindow) {
        if pencere.styleMask.contains(.fullScreen) { pencere.toggleFullScreen(nil); return }
        if yerlesikMi(pencere), let onceki = oncekiCerceve {
            sifirla()
            pencere.setFrame(onceki, display: true, animate: true)
        } else {
            yerles(pencere, .doldur, ekran: pencere.screen)
        }
    }

    /// Fare bırakılana kadar pencereyi taşır.
    func surukle(_ pencere: NSWindow) {
        guard !pencere.styleMask.contains(.fullScreen) else { return }
        var fareBaslangic = NSEvent.mouseLocation
        var cerceveBaslangic = pencere.frame
        var tasiniyor = false
        var hedef: (yerlesim: Yerlesim, ekran: NSScreen)?

        while let olay = pencere.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]),
              olay.type == .leftMouseDragged {
            let fare = NSEvent.mouseLocation
            if !tasiniyor {
                guard hypot(fare.x - fareBaslangic.x, fare.y - fareBaslangic.y) > 3 else { continue }
                tasiniyor = true
                if yerlesikMi(pencere), let onceki = oncekiCerceve {
                    // Eski boyuta dön; fare başlıkta aynı orandaki noktada kalsın.
                    let oran = (fareBaslangic.x - cerceveBaslangic.minX) / cerceveBaslangic.width
                    cerceveBaslangic = NSRect(x: fareBaslangic.x - onceki.width * oran,
                                              y: cerceveBaslangic.maxY - onceki.height,
                                              width: onceki.width, height: onceki.height)
                    pencere.setFrame(cerceveBaslangic, display: true)
                    sifirla()
                }
                fareBaslangic = fare
                continue
            }

            let ekran = NSScreen.screens.first { NSMouseInRect(fare, $0.frame, false) } ?? pencere.screen
            var konum = NSPoint(x: cerceveBaslangic.minX + fare.x - fareBaslangic.x,
                                y: cerceveBaslangic.minY + fare.y - fareBaslangic.y)
            if let ekran {  // Başlık menü çubuğunun altına kaçmasın.
                konum.y = min(konum.y, ekran.visibleFrame.maxY - cerceveBaslangic.height)
            }
            pencere.setFrameOrigin(konum)

            hedef = ekran.flatMap { e in Yerlesim.bul(fare: fare, ekran: e.frame).map { ($0, e) } }
            onizlemeyiGoster(hedef.map { $0.yerlesim.cerceve($0.ekran.visibleFrame) }, ustunde: pencere)
        }

        onizlemeyiGoster(nil, ustunde: pencere)
        if let hedef { yerles(pencere, hedef.yerlesim, ekran: hedef.ekran) }
    }

    private func yerles(_ pencere: NSWindow, _ yerlesim: Yerlesim, ekran: NSScreen?) {
        guard let ekran = ekran ?? pencere.screen else { return }
        if !yerlesikMi(pencere) { oncekiCerceve = pencere.frame }
        pencere.setFrame(yerlesim.cerceve(ekran.visibleFrame), display: true, animate: true)
        yerlesikCerceve = pencere.frame
    }

    private func sifirla() {
        oncekiCerceve = nil
        yerlesikCerceve = nil
    }

    // MARK: Önizleme

    private func onizlemeyiGoster(_ cerceve: NSRect?, ustunde pencere: NSWindow) {
        guard let cerceve else { onizleme?.orderOut(nil); return }
        let gosterge = onizleme ?? Self.onizlemeOlustur()
        onizleme = gosterge
        gosterge.level = pencere.level
        if gosterge.frame != cerceve { gosterge.setFrame(cerceve, display: true) }
        if !gosterge.isVisible { gosterge.order(.below, relativeTo: pencere.windowNumber) }
    }

    private static func onizlemeOlustur() -> NSWindow {
        let gosterge = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        gosterge.isOpaque = false
        gosterge.backgroundColor = .clear
        gosterge.hasShadow = false
        gosterge.ignoresMouseEvents = true
        gosterge.isReleasedWhenClosed = false
        let alan = NSView()
        alan.wantsLayer = true
        alan.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
        alan.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
        alan.layer?.borderWidth = 1
        alan.layer?.cornerRadius = 10
        gosterge.contentView = alan
        return gosterge
    }
}
