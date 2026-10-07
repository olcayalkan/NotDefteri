import AppKit
import NotDefteriCekirdek

private final class KisayolNSWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 { close(); return true }
        return super.performKeyEquivalent(with: event)
    }
}

final class KisayolPenceresi: NSWindowController, NSSearchFieldDelegate {
    static let paylasilan = KisayolPenceresi()

    private let arama = NSSearchField()
    private let kaydirma = NSScrollView()
    private let liste = NSStackView()

    private init() {
        let pencere = KisayolNSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                                      styleMask: [.titled, .closable], backing: .buffered, defer: false)
        pencere.title = "Klavye kısayolları"
        pencere.isReleasedWhenClosed = false
        super.init(window: pencere)
        pencere.center()
        kur()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }

    private func kur() {
        guard let icerik = window?.contentView else { return }
        arama.placeholderString = "Kısayollarda ara"
        arama.delegate = self
        arama.setAccessibilityLabel("Klavye kısayollarında ara")
        icerik.addSubview(arama)
        arama.translatesAutoresizingMaskIntoConstraints = false
        kaydirma.hasVerticalScroller = true
        kaydirma.drawsBackground = false
        icerik.addSubview(kaydirma)
        kaydirma.translatesAutoresizingMaskIntoConstraints = false
        liste.orientation = .vertical
        liste.alignment = .leading
        liste.spacing = 5
        kaydirma.documentView = liste
        liste.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arama.leadingAnchor.constraint(equalTo: icerik.leadingAnchor, constant: 14),
            arama.trailingAnchor.constraint(equalTo: icerik.trailingAnchor, constant: -14),
            arama.topAnchor.constraint(equalTo: icerik.topAnchor, constant: 12),
            kaydirma.leadingAnchor.constraint(equalTo: icerik.leadingAnchor, constant: 10),
            kaydirma.trailingAnchor.constraint(equalTo: icerik.trailingAnchor, constant: -10),
            kaydirma.topAnchor.constraint(equalTo: arama.bottomAnchor, constant: 8),
            kaydirma.bottomAnchor.constraint(equalTo: icerik.bottomAnchor, constant: -10),
            liste.leadingAnchor.constraint(equalTo: kaydirma.contentView.leadingAnchor, constant: 6),
            liste.trailingAnchor.constraint(equalTo: kaydirma.contentView.trailingAnchor, constant: -6),
            liste.topAnchor.constraint(equalTo: kaydirma.contentView.topAnchor, constant: 6)
        ])
        yenile()
    }

    @objc func goster(_ sender: Any?) {
        yenile()
        showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(arama)
    }

    func controlTextDidChange(_ notification: Notification) { yenile() }

    private func yenile() {
        guard let window else { return }
        window.backgroundColor = aktifTema.arkaplan
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = aktifTema.arkaplan.cgColor
        liste.arrangedSubviews.forEach { liste.removeArrangedSubview($0); $0.removeFromSuperview() }
        let sorgu = aramaIcinSadelestir(arama.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        for (baslik, satirlar) in menuKisayollari() + [("Editör", editorKisayollari)] {
            let eslesenler = satirlar.filter { sorgu.isEmpty || aramaIcinSadelestir("\($0.0) \($0.1) \(baslik)").contains(sorgu) }
            guard !eslesenler.isEmpty else { continue }
            let baslikEtiketi = NSTextField(labelWithString: baslik)
            baslikEtiketi.font = .systemFont(ofSize: 13, weight: .semibold)
            baslikEtiketi.textColor = .secondaryLabelColor
            liste.addArrangedSubview(baslikEtiketi)
            for (ad, tus) in eslesenler {
                let etiket = NSTextField(labelWithString: "\(ad)    \(tus)")
                etiket.font = .systemFont(ofSize: 13)
                etiket.textColor = kMetinRenk
                liste.addArrangedSubview(etiket)
            }
        }
    }

    private var editorKisayollari: [(String, String)] {
        [("# ", "Başlık"), ("- ", "Madde listesi"), ("1. ", "Numaralı liste"), ("[] ", "Yapılacak"),
         ("> ", "Alıntı"), ("---", "Ayırıcı"), ("```", "Kod bloğu"), ("/", "Blok menüsü"),
         ("[[", "Sayfa bağlantısı"), ("Tab / ⇧Tab", "Girintiyi artır / azalt")]
    }

    private func menuKisayollari() -> [(String, [(String, String)])] {
        guard let menu = NSApp.mainMenu else { return [] }
        // Birinci menü uygulama menüsüdür; başlığı boş verildiğinde AppKit "NSMenuItem" yazar.
        return menu.items.enumerated().compactMap { sira, oge in
            guard let altMenu = oge.submenu else { return nil }
            let baslik = sira == 0 ? "Not Defteri" : altMenu.title.isEmpty ? oge.title : altMenu.title
            let satirlar = menuSatirlari(altMenu)
            return satirlar.isEmpty ? nil : (baslik, satirlar)
        }
    }

    private func menuSatirlari(_ menu: NSMenu) -> [(String, String)] {
        menu.items.flatMap { oge -> [(String, String)] in
            var satirlar: [(String, String)] = []
            if !oge.isSeparatorItem, !oge.isAlternate, !oge.keyEquivalent.isEmpty, !sistemKomutuMu(oge) {
                satirlar.append((oge.title, tusGosterimi(oge)))
            }
            if let altMenu = oge.submenu { satirlar += menuSatirlari(altMenu) }
            return satirlar
        }
    }

    /// AppKit'in Düzen menüsüne kendiliğinden eklediği öğeler (Dikte, Emoji) kısayol listesine girmez.
    private func sistemKomutuMu(_ oge: NSMenuItem) -> Bool {
        guard let eylem = oge.action else { return false }
        return ["startDictation:", "orderFrontCharacterPalette:"].contains(NSStringFromSelector(eylem))
    }

    private func tusGosterimi(_ oge: NSMenuItem) -> String {
        let bayraklar = oge.keyEquivalentModifierMask
        let simgeler: [(NSEvent.ModifierFlags, String)] = [(.command, "⌘"), (.shift, "⇧"), (.option, "⌥"), (.control, "⌃")]
        let onEk = simgeler.filter { bayraklar.contains($0.0) }.map(\.1).joined()
        let tus = ["\r": "↩", "\u{1b}": "Esc", "\t": "Tab", " ": "Space"][oge.keyEquivalent] ?? oge.keyEquivalent.uppercased()
        return onEk + tus
    }
}
