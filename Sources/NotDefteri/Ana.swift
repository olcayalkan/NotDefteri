import AppKit

// MARK: - Uygulama giriş noktası

final class UygulamaDelegesi: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var pencere: NotPenceresi?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = anaMenuyuOlustur(delege: self)
        let p = NotPenceresi()
        self.pencere = p
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        pencere?.kapanistaGerekirseKaydet()
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

/// Giriş noktası. `@main` kullanılıyor çünkü top-level kod içeren bir dosya
/// (main.swift) test hedefinden `@testable import` ile alınamıyor.
@main
enum Ana {
    /// Delege uygulama ömrü boyunca yaşamalı; `app.run()` bloklasa da
    /// sahipliği açıkça burada tutuyoruz.
    static let delege = UygulamaDelegesi()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delege
        app.run()
    }
}
