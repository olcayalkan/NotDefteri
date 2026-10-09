import AppKit
import NotDefteriCekirdek

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
    let copOgesi = dosyaMenu.addItem(withTitle: "Çöp kutusu", action: #selector(UygulamaDelegesi.copKutusuKomutu), keyEquivalent: "")
    copOgesi.target = delege
    let aktarOgesi = NSMenuItem(title: "Dışa aktar", action: nil, keyEquivalent: "")
    let aktarMenu = NSMenu(title: "Dışa aktar")
    let pdfOgesi = aktarMenu.addItem(withTitle: "PDF", action: #selector(NotPenceresi.disaAktarPDF(_:)), keyEquivalent: "e")
    pdfOgesi.keyEquivalentModifierMask = [.command, .shift]
    aktarMenu.addItem(withTitle: "HTML", action: #selector(NotPenceresi.disaAktarHTML(_:)), keyEquivalent: "")
    aktarMenu.addItem(withTitle: "Markdown", action: #selector(NotPenceresi.disaAktarMarkdown(_:)), keyEquivalent: "")
    aktarOgesi.submenu = aktarMenu
    dosyaMenu.addItem(aktarOgesi)
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
    // ⌘V yapıştırdığını notun yazım biçimine uydurur; bu komut kaynak biçimini korur.
    let hamYapistirOgesi = NSMenuItem(title: "Kaynak Biçimiyle Yapıştır",
                                       action: #selector(NotPenceresi.hamYapistirKomutu(_:)),
                                       keyEquivalent: "V")
    hamYapistirOgesi.keyEquivalentModifierMask = [.command, .shift]
    duzenMenu.addItem(hamYapistirOgesi)
    duzenMenu.addItem(withTitle: "Markdown olarak kopyala", action: #selector(NotPenceresi.markdownOlarakKopyala(_:)), keyEquivalent: "")
    duzenMenu.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    let bulOgesi = NSMenuItem(title: "Bul", action: nil, keyEquivalent: "")
    let bulMenu = NSMenu(title: "Bul")
    let bulKomutlari: [(String, NSTextFinder.Action, String, NSEvent.ModifierFlags)] = [
        ("Bul…", .showFindInterface, "f", .command),
        ("Bul ve Değiştir…", .showReplaceInterface, "f", [.command, .option]),
        ("Sonrakini Bul", .nextMatch, "g", .command),
        ("Öncekini Bul", .previousMatch, "g", [.command, .shift])]
    for (ad, eylem, tus, bayraklar) in bulKomutlari {
        let oge = bulMenu.addItem(withTitle: ad, action: #selector(NotPenceresi.bulKomutu(_:)), keyEquivalent: tus)
        oge.tag = eylem.rawValue
        oge.keyEquivalentModifierMask = bayraklar
    }
    bulOgesi.submenu = bulMenu
    duzenMenu.addItem(bulOgesi)
    duzenMenuOgesi.submenu = duzenMenu
    anaMenu.addItem(duzenMenuOgesi)

    let bicimMenuOgesi = NSMenuItem()
    let bicimMenu = NSMenu(title: "Biçim")
    bicimMenu.addItem(withTitle: "Kalın", action: #selector(NotPenceresi.kalinKomutu(_:)), keyEquivalent: "b")
    let satirIciKomutlar: [(String, Selector, String, NSEvent.ModifierFlags)] = [
        ("İtalik", #selector(NotPenceresi.italikKomutu(_:)), "i", .command),
        ("Üstü Çizili", #selector(NotPenceresi.ustuCiziliKomutu(_:)), "x", [.command, .shift]),
        ("Satır İçi Kod", #selector(NotPenceresi.satirIciKodKomutu(_:)), "e", .command),
        ("Vurgu", #selector(NotPenceresi.vurguKomutu(_:)), "h", [.command, .option]),
        ("Bağlantı", #selector(NotPenceresi.baglantiKomutu(_:)), "k", .command)]
    for (ad, komut, tus, bayraklar) in satirIciKomutlar {
        let oge = NSMenuItem(title: ad, action: komut, keyEquivalent: tus)
        oge.keyEquivalentModifierMask = bayraklar
        bicimMenu.addItem(oge)
    }
    bicimMenuOgesi.submenu = bicimMenu
    anaMenu.addItem(bicimMenuOgesi)

    let gorunumMenuOgesi = NSMenuItem()
    let gorunumMenu = NSMenu(title: "Görünüm")
    gorunumMenu.addItem(withTitle: "Açılışta Ana Sayfa", action: #selector(NotPenceresi.acilistaAnaSayfaKomutu(_:)), keyEquivalent: "")
    // Tam ekran: menüden ⌃⌘F; ayrıca Fn+F (performKeyEquivalent içinde).
    let tamEkranOgesi = NSMenuItem(title: "Tam Ekran", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
    tamEkranOgesi.keyEquivalentModifierMask = [.command, .control]
    gorunumMenu.addItem(tamEkranOgesi)
    gorunumMenu.addItem(withTitle: "Tam genişlik", action: #selector(NotPenceresi.tamGenislikKomutu(_:)), keyEquivalent: "")
    gorunumMenu.addItem(withTitle: "Küçük yazı", action: #selector(NotPenceresi.kucukYaziKomutu(_:)), keyEquivalent: "")
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
        oge.state = index == gTemaIndex ? .on : .off
        temaAltMenu.addItem(oge)
    }
    temaMenuOgesi.submenu = temaAltMenu
    gorunumMenu.addItem(temaMenuOgesi)
    gorunumMenu.addItem(NSMenuItem.separator())
    let katlamaKomutlari: [(String, String, NSEvent.ModifierFlags)] = [
        ("Bölümü katla", "[", [.command, .option]),
        ("Bölümü aç", "]", [.command, .option]),
        ("Tümünü katla", "[", [.command, .option, .shift]),
        ("Tümünü aç", "]", [.command, .option, .shift])]
    for (tag, komut) in katlamaKomutlari.enumerated() {
        let oge = gorunumMenu.addItem(withTitle: komut.0, action: #selector(NotMetinGorunumu.katlamaKomutu(_:)), keyEquivalent: komut.1)
        oge.tag = tag
        oge.keyEquivalentModifierMask = komut.2
    }
    gorunumMenuOgesi.submenu = gorunumMenu
    anaMenu.addItem(gorunumMenuOgesi)

    let notMenuOgesi = NSMenuItem()
    let notMenu = NSMenu(title: "Not")
    notMenu.addItem(withTitle: "Hızlı Sayfa Bulucu", action: #selector(NotPenceresi.hizliBulucuKomutu(_:)), keyEquivalent: "p")
    let gecmisOgesi = notMenu.addItem(withTitle: "Sayfa geçmişi…", action: #selector(NotPenceresi.sayfaGecmisiKomutu(_:)), keyEquivalent: "y")
    gecmisOgesi.keyEquivalentModifierMask = [.command, .option]
    notMenu.addItem(NSMenuItem.separator())
    notMenu.addItem(withTitle: "Önceki Not", action: #selector(NotPenceresi.oncekiNotKomutu(_:)), keyEquivalent: "[")
    notMenu.addItem(withTitle: "Sonraki Not", action: #selector(NotPenceresi.sonrakiNotKomutu(_:)), keyEquivalent: "]")
    notMenuOgesi.submenu = notMenu
    anaMenu.addItem(notMenuOgesi)

    let gitMenuOgesi = NSMenuItem()
    let gitMenu = NSMenu(title: "Git")
    let anaSayfaOgesi = gitMenu.addItem(withTitle: "Ana Sayfa", action: #selector(NotPenceresi.anaSayfaKomutu(_:)), keyEquivalent: "h")
    anaSayfaOgesi.keyEquivalentModifierMask = [.command, .shift]
    gitMenuOgesi.submenu = gitMenu
    anaMenu.addItem(gitMenuOgesi)

    let yardimMenuOgesi = NSMenuItem()
    let yardimMenu = NSMenu(title: "Yardım")
    let kisayollarOgesi = yardimMenu.addItem(withTitle: "Klavye kısayolları", action: #selector(KisayolPenceresi.goster(_:)), keyEquivalent: "/")
    kisayollarOgesi.keyEquivalentModifierMask = [.command]
    kisayollarOgesi.target = KisayolPenceresi.paylasilan
    yardimMenuOgesi.submenu = yardimMenu
    anaMenu.addItem(yardimMenuOgesi)

    return anaMenu
}

extension UygulamaDelegesi {
    @objc func copKutusuKomutu() {
        guard let pencere else { return }
        if pencere.kenarPanelGizli {
            pencere.kenarPaneliniAcKapa()
            pencere.icerikBoyutuDegisti()
        }
        // Gizli panelin yerleşimi tamamlanınca popover doğru düğmeye bağlanır.
        DispatchQueue.main.async { pencere.kenarPaneli.copKutusuTiklandi() }
    }
}
