import AppKit
import NotDefteriCekirdek

extension NotPenceresi {
    private func sayfaSecenekDugmesiniHazirla() {
        let dugme = sayfaSecenekAlani.dugme
        guard dugme.target == nil else { return }
        dugme.target = self
        dugme.action = #selector(sayfaSecenekMenusunuAc(_:))
    }

    @objc private func sayfaSecenekMenusunuAc(_ sender: NSButton) {
        let menu = NSMenu(title: "Sayfa seçenekleri")
        for (ad, eylem) in [("Tam genişlik", #selector(tamGenislikKomutu(_:))), ("Küçük yazı", #selector(kucukYaziKomutu(_:)))] {
            menu.addItem(withTitle: ad, action: eylem, keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        let aktar = NSMenu(title: "Dışa aktar")
        for (ad, eylem) in [("PDF", #selector(disaAktarPDF(_:))), ("HTML", #selector(disaAktarHTML(_:))), ("Markdown", #selector(disaAktarMarkdown(_:)))] {
            aktar.addItem(withTitle: ad, action: eylem, keyEquivalent: "").target = self
        }
        let oge = menu.addItem(withTitle: "Dışa aktar", action: nil, keyEquivalent: "")
        oge.submenu = aktar
        menu.addItem(withTitle: "Markdown olarak kopyala", action: #selector(markdownOlarakKopyala(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Sayfa geçmişi…", action: #selector(sayfaGecmisiKomutu(_:)), keyEquivalent: "").target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY), in: sender)
    }

    @objc func sayfaGecmisiKomutu(_ sender: Any?) {
        guard anaSayfa.isHidden, attachedSheet == nil else { return }
        otomatikKayitBekleyeniIptalEt()
        if let url = mevcutDosyaURL { guard kaydetURLe(url, panelYenile: false) else { return } }
        else if !metinGorunumu.string.isEmpty { guard kaydetURLe(benzersizDosyaURL(taban: otomatikBaslikUret(icerik: metinGorunumu.string))) else { return } }
        guard let url = mevcutDosyaURL else { return }
        let sayfa = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        sayfa.title = "Sayfa geçmişi"
        sayfa.contentViewController = GecmisPaneli(sayfaURL: url,
            geriYukle: { [weak self] govde in self?.surumuGeriYukle(govde, url: url) },
            kapat: { [weak self, weak sayfa] in if let sayfa { self?.endSheet(sayfa) } })
        beginSheet(sayfa)
    }

    /// Önce mevcut hâl sürüm olarak saklanır; sonra editör tek undo adımıyla değişir ve kaydedilir.
    /// Üstbilgi (genişlik/yazı ve bilinmeyen alanlar) mevcut hâliyle kalır; yalnızca gövde döner.
    private func surumuGeriYukle(_ govde: String, url: URL) {
        guard anaSayfa.isHidden, mevcutDosyaURL == url, let depo = metinGorunumu.textStorage else { return }
        SayfaGecmisi.kaydet(metin: sayfaMarkdownunuUret(depo, ustbilgi: sayfaUstbilgisi), icerikURL: url, zorla: true)
        metinGorunumu.blokDuzenle(NSRange(location: 0, length: depo.length),
                                  yeni: MacBelgeAdaptoru.markdownuAc(govde, taban: sayfaKlasoru(url)),
                                  secim: NSRange(location: 0, length: 0), yazim: metinGorunumu.typingAttributes)
        metinGorunumu.undoManager?.setActionName("Sürümü geri yükle")
        kaydetURLe(url, panelYenile: false)
        icindekileriTazele()
        gecmisDugmeleriniGuncelle()
    }

    @objc func tamGenislikKomutu(_ sender: Any?) {
        var bilgi = sayfaUstbilgisi
        bilgi.genislik = bilgi.genislik == "tam" ? "" : "tam"
        sayfaUstbilgisiniDegistir(bilgi)
    }

    @objc func kucukYaziKomutu(_ sender: Any?) {
        var bilgi = sayfaUstbilgisi
        bilgi.yazi = bilgi.yazi == "kucuk" ? "" : "kucuk"
        sayfaUstbilgisiniDegistir(bilgi)
    }

    func sayfaSecenekleriniUygula() {
        sayfaSecenekDugmesiniHazirla()
        sayfaGenisliginiUygula()
        metinGorunumu.sayfaYaziOlceginiUygula(kucuk: sayfaUstbilgisi.yazi == "kucuk")
    }

    @objc func sayfaGenisliginiUygula() {
        guard let kapsayici = metinGorunumu.textContainer else { return }
        // Mevcut ortak yerleşim 26 puan alt bilgi payı bırakır. Dosyalar bu payın
        // üstüne gelir; genişlik/kenar panel animasyonu da bu yolu çağırır.
        let alanYuksekligi = max(0, icerikGorunum.bounds.height - kBaslikYuksekligi)
        let editorUstu = max(26, alanYuksekligi - min(SayfaSecenekAlani.yukseklik, alanYuksekligi))
        sayfaDosyalariAlani.isHidden = !anaSayfa.isHidden || sayfaDosyalariAlani.dosyaSayisi == 0
        let dosyaYuksekligi = sayfaDosyalariAlani.isHidden ? 0 : min(sayfaDosyalariAlani.hedefYukseklik, max(0, editorUstu - 26) * 0.4)
        var editorKare = kaydirmaGorunumu.frame
        editorKare.origin.y = 26 + dosyaYuksekligi
        editorKare.size.height = max(0, editorUstu - editorKare.minY)
        if kaydirmaGorunumu.frame != editorKare { kaydirmaGorunumu.frame = editorKare }
        let clip = kaydirmaGorunumu.contentView
        let genislik = clip.bounds.width
        // Çok dar editörde bile mevcut görselin asgari eni için yer bırak.
        let yanPay = min(48, max(0, (genislik - kEnKucukResimEni - kapsayici.lineFragmentPadding * 2) / 2))
        let kullanilabilir = max(1, genislik - yanPay * 2)
        let kapGenisligi = sayfaUstbilgisi.genislik == "tam" ? kullanilabilir : min(760, kullanilabilir)
        let inset = NSSize(width: max(0, (genislik - kapGenisligi) / 2), height: 12)
        if metinGorunumu.textContainerInset != inset { metinGorunumu.textContainerInset = inset }
        // Boy veya yalnızca merkez değiştiğinde bütün belgeyi yeniden dizme.
        if kapsayici.size.width != kapGenisligi {
            kapsayici.size = NSSize(width: kapGenisligi, height: CGFloat.greatestFiniteMagnitude)
        }
        let sol = clip.convert(NSPoint(x: clip.bounds.minX, y: 0), to: icerikGorunum).x + inset.width
        let baslikPayi = min(14, inset.width)
        sayfaSecenekAlani.frame.origin.x = sol - baslikPayi
        sayfaSecenekAlani.frame.size.width = kapGenisligi + baslikPayi * 2
        sayfaAltBilgisi.frame.origin.x = sol + kapsayici.lineFragmentPadding
        sayfaAltBilgisi.frame.size.width = max(0, kapGenisligi - kapsayici.lineFragmentPadding * 2)
        sayfaDosyalariAlani.frame = NSRect(x: sayfaAltBilgisi.frame.minX, y: 26,
            width: sayfaAltBilgisi.frame.width, height: dosyaYuksekligi)
        metinGorunumu.needsDisplay = true
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if !anaSayfa.isHidden {
            let editorKomutlari: [Selector] = [#selector(tamGenislikKomutu(_:)), #selector(kucukYaziKomutu(_:)),
                #selector(kaydetKomutu(_:)), #selector(geriAlKomutu(_:)), #selector(ileriAlKomutu(_:)),
                #selector(kalinKomutu(_:)), #selector(italikKomutu(_:)), #selector(ustuCiziliKomutu(_:)),
                #selector(satirIciKodKomutu(_:)), #selector(vurguKomutu(_:)), #selector(baglantiKomutu(_:)),
                #selector(yaziBuyutKomutu(_:)), #selector(yaziKucultKomutu(_:)), #selector(bulKomutu(_:)),
                #selector(hamYapistirKomutu(_:)), #selector(disaAktarPDF(_:)), #selector(disaAktarHTML(_:)),
                #selector(disaAktarMarkdown(_:)), #selector(markdownOlarakKopyala(_:)), #selector(sayfaGecmisiKomutu(_:))]
            if let action = menuItem.action, editorKomutlari.contains(action) { return false }
        }
        switch menuItem.action {
        case #selector(acilistaAnaSayfaKomutu(_:)):
            menuItem.state = gAcilistaAnaSayfa ? .on : .off
        case #selector(tamGenislikKomutu(_:)):
            menuItem.state = sayfaUstbilgisi.genislik == "tam" ? .on : .off
        case #selector(kucukYaziKomutu(_:)):
            menuItem.state = sayfaUstbilgisi.yazi == "kucuk" ? .on : .off
        default: return super.validateMenuItem(menuItem)
        }
        return true
    }

    func altBilgiyiGuncellemeyiPlanla() {
        altBilgiZamanlayicisi?.invalidate()
        let zamanlayici = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in self?.altBilgiyiGuncelle() }
        altBilgiZamanlayicisi = zamanlayici
        RunLoop.main.add(zamanlayici, forMode: .common)
    }

    func altBilgiyiGuncelle() {
        altBilgiZamanlayicisi?.invalidate()
        altBilgiZamanlayicisi = nil
        let bicim = DateFormatter()
        bicim.locale = Locale(identifier: "tr_TR")
        bicim.dateFormat = Calendar.current.isDateInToday(sonDuzenleme) ? "'bugün' HH:mm" : "d MMM yyyy HH:mm"
        sayfaAltBilgisi.stringValue = "\(metinGorunumu.kelimeSayisi) kelime · Son düzenleme: \(bicim.string(from: sonDuzenleme))"
    }
}
