import AppKit
import NotDefteriCekirdek

// MARK: - Uygulama giriş noktası

final class UygulamaDelegesi: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var pencere: NotPenceresi?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        kagitGorunumunuUygula()
        NSApp.mainMenu = anaMenuyuOlustur(delege: self)
        let p = NotPenceresi()
        self.pencere = p
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let copKutusu = p.kenarPaneli.copKutusu
        DispatchQueue.global(qos: .utility).async {
            let hatalar = copKutusu.temizle(eskiOlanlar: true)
            guard !hatalar.isEmpty else { return }
            DispatchQueue.main.async {
                let uyari = NSAlert()
                uyari.messageText = "Eski çöp öğeleri temizlenemedi"
                uyari.informativeText = hatalar.joined(separator: "\n")
                uyari.runModal()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard pencere?.kapanistaGerekirseKaydet() != false else { return .terminateCancel }
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func girisKomutuTetiklendi(_ sender: NSMenuItem) {
        giristeAcmayiAyarla(!giristeAcikMi())
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let oge = menu.items.first(where: { $0.action == #selector(girisKomutuTetiklendi(_:)) }) {
            oge.state = giristeAcikMi() ? .on : .off
        }
    }
}

/// Kağıt temaları açık renklidir. Sistem koyu görünümdeyken dinamik renkler (etiketler,
/// ikincil yazılar, alt bilgi) beyaza dönüp açık zeminde okunmuyordu; uygulama açık görünümde sabitlenir.
func kagitGorunumunuUygula() {
    NSApp.appearance = NSAppearance(named: .aqua)
}

/// Ortak çalıştırıcının çağırdığı macOS giriş noktası.
package enum Ana {
    /// Delege uygulama ömrü boyunca yaşamalı; `app.run()` bloklasa da
    /// sahipliği açıkça burada tutuyoruz.
    static let delege = UygulamaDelegesi()

    package static func main() {
        let app = NSApplication.shared
        app.delegate = delege
        app.run()
    }
}
