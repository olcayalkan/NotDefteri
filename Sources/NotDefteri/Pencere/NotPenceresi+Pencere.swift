import AppKit
import NotDefteriCekirdek

// MARK: - NotPenceresi: Gezinme, kenar panel, klavye, kapatma

extension NotPenceresi {

    // MARK: Notlar arasında gezinme (Cmd+[ / Cmd+])

    @objc func oncekiNotKomutu(_ sender: Any?) { notGezin(yon: -1) }
    @objc func sonrakiNotKomutu(_ sender: Any?) { notGezin(yon: 1) }

    private func notGezin(yon: Int) {
        // Arama filtresi aktifken de gezinme tüm notlar arasında çalışsın diye filtrelenmemiş listeyi kullanır.
        let liste = kenarPaneli.tumNotUrlListesi
        guard !liste.isEmpty else { return }
        guard let mevcut = mevcutDosyaURL, let index = liste.firstIndex(of: mevcut) else {
            notuAc(liste[0])
            return
        }
        let yeniIndex = index + yon
        guard yeniIndex >= 0, yeniIndex < liste.count else { return }
        notuAc(liste[yeniIndex])
    }

    // MARK: Kenar paneli göster/gizle

    func kenarPaneliniAcKapa() {
        kenarPanelGizli.toggle()
        UserDefaults.standard.set(kenarPanelGizli, forKey: "kenarPanelGizli")
        kenarPaneliYerlesiminiUygula(animasyonlu: true)
    }

    /// Resize eski ölçülere giden animasyonu iptal eder; son hedef geçerlidir.
    @objc func icerikBoyutuDegisti() {
        hizliBulucu.yerlesiminiGuncelle()
        kenarPaneliYerlesiminiUygula(animasyonlu: false)
    }

    private func kenarPaneliYerlesiminiUygula(animasyonlu: Bool) {
        kenarPanelGecisNesli &+= 1
        let nesil = kenarPanelGecisNesli
        kenarPanelGecisiSuruyor = animasyonlu
        if !kenarPanelGizli {
            // Hızlı yön değiştirmede henüz kayan outline'ı yeniden kurma.
            if kenarPaneli.isHidden || !animasyonlu { kenarPaneli.gorunumGuncellemeleriniAyarla(true) }
            kenarPaneli.isHidden = false
            // Birikmiş değişiklikleri kaymadan önce bir kez göster; geçişte ağacı dondur.
            kenarPaneli.needsLayout = true
            kenarPaneli.layoutSubtreeIfNeeded()
        }
        kenarPaneli.gorunumGuncellemeleriniAyarla(false)
        surukleTutamaci.isHidden = true
        if kenarPanelGizli, let odak = firstResponder as? NSView,
           odak.isDescendant(of: kenarPaneli) || kenarPaneli.aramaAlani.currentEditor() === odak || kenarPaneli.duzenlenenDugum != nil {
            // Gizlenen arama/ad alanının editörü ve bekleyen debounce'u açık kalmasın.
            makeFirstResponder(metinGorunumu)
        }

        let hedefGenislik: CGFloat = kenarPanelGizli ? 0 : gKenarPanelGenislik
        let toplamGenislik = icerikGorunum.bounds.width
        let yukseklik = max(0, icerikGorunum.bounds.height - kBaslikYuksekligi)
        let baslikYuksekligi = min(SayfaSecenekAlani.yukseklik, yukseklik)
        sayfaAltBilgisi.frame.origin.y = 5
        sayfaAltBilgisi.frame.size.height = 16
        sayfaSecenekAlani.frame.origin.y = yukseklik - baslikYuksekligi
        sayfaSecenekAlani.frame.size.height = baslikYuksekligi
        let tamamla = { [weak self] in
            guard let self, self.kenarPanelGecisNesli == nesil else { return }
            self.kenarPanelGecisiSuruyor = false
            self.kenarPaneli.isHidden = self.kenarPanelGizli
            self.surukleTutamaci.isHidden = self.kenarPanelGizli
            self.kenarPaneli.gorunumGuncellemeleriniAyarla(!self.kenarPanelGizli)
            self.sayfaGenisliginiUygula()
        }

        NSAnimationContext.runAnimationGroup({ baglam in
            // Sıfır süre, resize/sürüklemede önceki animator hedeflerini de iptal eder.
            baglam.duration = animasyonlu ? 0.2 : 0
            baglam.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            kenarPaneli.animator().frame = NSRect(x: hedefGenislik - gKenarPanelGenislik, y: 0, width: gKenarPanelGenislik, height: yukseklik)
            surukleTutamaci.animator().frame = NSRect(x: hedefGenislik - 3, y: 0, width: 6, height: yukseklik)
            let metinGenisligi = max(0, toplamGenislik - hedefGenislik)
            anaSayfa.animator().frame = NSRect(x: hedefGenislik, y: 0, width: metinGenisligi, height: yukseklik)
            let altBilgiYuksekligi: CGFloat = 26
            kaydirmaGorunumu.animator().frame = NSRect(x: hedefGenislik, y: altBilgiYuksekligi, width: metinGenisligi,
                                                       height: max(0, yukseklik - baslikYuksekligi - altBilgiYuksekligi))
        }, completionHandler: animasyonlu ? tamamla : nil)
        if !animasyonlu { tamamla() }
    }

    /// Kenar panelin genişliğini fare ile sürükleyerek ayarlar.
    func kenarPaneliSurukleniyor(_ event: NSEvent) {
        guard !kenarPanelGizli, !kenarPanelGecisiSuruyor else { return }
        let nokta = icerikGorunum.convert(event.locationInWindow, from: nil)
        let yeniGenislik = min(max(nokta.x, kKenarPanelMinGenislik), kKenarPanelMaksGenislik)
        gKenarPanelGenislik = yeniGenislik
        UserDefaults.standard.set(Double(yeniGenislik), forKey: "kenarPanelGenislik")

        kenarPaneliYerlesiminiUygula(animasyonlu: false)
    }

    // MARK: Kapatma

    /// Menü eşleşmeleri klavye düzenine göre kaçabildiği için (⌘* Türkçe Q'da
    /// shift'siz, ABD düzeninde shift'li üretilir) punto kısayollarını burada
    /// düzenden bağımsız olarak yakalarız.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let bayraklar = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let karakterKucuk = event.charactersIgnoringModifiers?.lowercased()

        if bayraklar == [.command, .shift], karakterKucuk == "h" {
            anaSayfayiGoster()
            return true
        }
        if !anaSayfa.isHidden, bayraklar.subtracting(.shift) == .command,
           ["y", "z", "*", "+", "=", "-", "_"].contains(karakterKucuk ?? "") {
            return true
        }

        if bayraklar == .command, karakterKucuk == "p" {
            hizliBulucuKomutu(nil)
            return true
        }

        // Tam ekran: Fn+F veya standart ⌃⌘F.
        if karakterKucuk == "f",
           bayraklar.contains(.function) || bayraklar.isSuperset(of: [.command, .control]) {
            toggleFullScreen(nil)
            return true
        }

        let tuslar = bayraklar.subtracting(.shift)  // Shift'i yok say: "*" bazı düzenlerde shift ister.
        if tuslar == .command, let karakter = event.charactersIgnoringModifiers {
            switch karakter.lowercased() {
            case "y":
                ileriAl()
                return true
            case "z":
                // ⌘Z menüden gelir; buraya asıl ⇧⌘Z (yinele) düşer.
                if event.modifierFlags.contains(.shift) { ileriAl() } else { geriAl() }
                return true
            case "*", "+", "=":
                yaziBoyutunuDegistir(fark: 1)
                return true
            case "-", "_":
                yaziBoyutunuDegistir(fark: -1)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Pencere odağı kaybettiğinde bekleyen değişikliği hemen yazar.
    override func resignKey() {
        hizliBulucu.gizle()
        metinGorunumu.yuzerGorunumleriGizle()
        super.resignKey()
        if kaydedici.duzenlendiMi { otomatikKaydet() }
    }

    /// Kayıt başarısızsa pencere KAPANMAZ. Kullanıcı uyarıyı görür ve
    /// yazdıklarını kurtarma şansı bulur; sessizce kaybetmez.
    override func close() {
        guard kapanistaGerekirseKaydet() else { return }
        hizliBulucu.gizle()
        geriBagZamanlayicisi?.invalidate()
        altBilgiZamanlayicisi?.invalidate()
        metinGorunumu.yuzerGorunumleriGizle()
        super.close()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
