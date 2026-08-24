import AppKit

// MARK: - Menü

func anaMenuyuOlustur(delege: UygulamaDelegesi) -> NSMenu {
    let anaMenu = NSMenu()

    let uygulamaMenuOgesi = NSMenuItem()
    let uygulamaMenu = NSMenu()
    uygulamaMenu.delegate = delege
    uygulamaMenu.addItem(withTitle: "Not Defteri Hakkında", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    uygulamaMenu.addItem(NSMenuItem.separator())
    let girisOgesi = NSMenuItem(title: "Girişte Otomatik Başlat", action: #selector(UygulamaDelegesi.girisKomutuTetiklendi(_:)), keyEquivalent: "")
    girisOgesi.target = delege
    uygulamaMenu.addItem(girisOgesi)
    uygulamaMenu.addItem(NSMenuItem.separator())
    uygulamaMenu.addItem(withTitle: "Not Defteri'nden Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    uygulamaMenuOgesi.submenu = uygulamaMenu
    anaMenu.addItem(uygulamaMenuOgesi)

    let dosyaMenuOgesi = NSMenuItem()
    let dosyaMenu = NSMenu(title: "Dosya")
    dosyaMenu.addItem(withTitle: "Kaydet", action: #selector(NotPenceresi.kaydetKomutu(_:)), keyEquivalent: "s")
    dosyaMenuOgesi.submenu = dosyaMenu
    anaMenu.addItem(dosyaMenuOgesi)

    let duzenMenuOgesi = NSMenuItem()
    let duzenMenu = NSMenu(title: "Düzen")
    duzenMenu.addItem(withTitle: "Geri Al", action: #selector(NotPenceresi.geriAlKomutu(_:)), keyEquivalent: "z")
    let yineleOgesi = NSMenuItem(title: "Yinele", action: #selector(NotPenceresi.ileriAlKomutu(_:)), keyEquivalent: "y")
    duzenMenu.addItem(yineleOgesi)  // ⇧⌘Z de yineler (performKeyEquivalent içinde).
    duzenMenu.addItem(NSMenuItem.separator())
    duzenMenu.addItem(withTitle: "Kes", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    duzenMenu.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    duzenMenu.addItem(withTitle: "Yapıştır", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    duzenMenu.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    duzenMenuOgesi.submenu = duzenMenu
    anaMenu.addItem(duzenMenuOgesi)

    let bicimMenuOgesi = NSMenuItem()
    let bicimMenu = NSMenu(title: "Biçim")
    bicimMenu.addItem(withTitle: "Kalın", action: #selector(NotPenceresi.kalinKomutu(_:)), keyEquivalent: "b")
    bicimMenuOgesi.submenu = bicimMenu
    anaMenu.addItem(bicimMenuOgesi)

    let gorunumMenuOgesi = NSMenuItem()
    let gorunumMenu = NSMenu(title: "Görünüm")
    // Tam ekran: menüden ⌃⌘F; ayrıca Fn+F (performKeyEquivalent içinde).
    let tamEkranOgesi = NSMenuItem(title: "Tam Ekran", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
    tamEkranOgesi.keyEquivalentModifierMask = [.command, .control]
    gorunumMenu.addItem(tamEkranOgesi)
    gorunumMenu.addItem(NSMenuItem.separator())
    let puntoArttirOgesi = NSMenuItem(title: "Puntoyu Büyüt", action: #selector(NotPenceresi.yaziBuyutKomutu(_:)), keyEquivalent: "*")
    puntoArttirOgesi.keyEquivalentModifierMask = [.command]
    gorunumMenu.addItem(puntoArttirOgesi)
    gorunumMenu.addItem(withTitle: "Puntoyu Küçült", action: #selector(NotPenceresi.yaziKucultKomutu(_:)), keyEquivalent: "-")
    gorunumMenu.addItem(NSMenuItem.separator())
    let temaMenuOgesi = NSMenuItem(title: "Tema", action: nil, keyEquivalent: "")
    let temaAltMenu = NSMenu(title: "Tema")
    for (index, tema) in temaListesi.enumerated() {
        let oge = NSMenuItem(title: tema.ad, action: #selector(NotPenceresi.temaSecKomutu(_:)), keyEquivalent: "")
        oge.representedObject = index
        temaAltMenu.addItem(oge)
    }
    temaMenuOgesi.submenu = temaAltMenu
    gorunumMenu.addItem(temaMenuOgesi)
    gorunumMenuOgesi.submenu = gorunumMenu
    anaMenu.addItem(gorunumMenuOgesi)

    let notMenuOgesi = NSMenuItem()
    let notMenu = NSMenu(title: "Not")
    notMenu.addItem(withTitle: "Önceki Not", action: #selector(NotPenceresi.oncekiNotKomutu(_:)), keyEquivalent: "[")
    notMenu.addItem(withTitle: "Sonraki Not", action: #selector(NotPenceresi.sonrakiNotKomutu(_:)), keyEquivalent: "]")
    notMenuOgesi.submenu = notMenu
    anaMenu.addItem(notMenuOgesi)

    return anaMenu
}
