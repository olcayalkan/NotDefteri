import AppKit

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

        if !kenarPanelGizli {
            kenarPaneli.isHidden = false
            surukleTutamaci.isHidden = false
        }

        let hedefGenislik: CGFloat = kenarPanelGizli ? 0 : gKenarPanelGenislik
        let toplamGenislik = icerikGorunum.bounds.width
        let yukseklik = kenarPaneli.frame.height

        NSAnimationContext.runAnimationGroup({ baglam in
            baglam.duration = 0.2
            baglam.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            kenarPaneli.animator().frame = NSRect(x: 0, y: 0, width: hedefGenislik, height: yukseklik)
            surukleTutamaci.animator().frame = NSRect(x: hedefGenislik - 3, y: 0, width: 6, height: yukseklik)
            kaydirmaGorunumu.animator().frame = NSRect(x: hedefGenislik, y: 0, width: max(0, toplamGenislik - hedefGenislik), height: yukseklik)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.kenarPaneli.isHidden = self.kenarPanelGizli
            self.surukleTutamaci.isHidden = self.kenarPanelGizli
        })
    }

    /// Kenar panelin genişliğini fare ile sürükleyerek ayarlar.
    func kenarPaneliSurukleniyor(_ event: NSEvent) {
        guard !kenarPanelGizli else { return }
        let nokta = icerikGorunum.convert(event.locationInWindow, from: nil)
        let yeniGenislik = min(max(nokta.x, kKenarPanelMinGenislik), kKenarPanelMaksGenislik)
        gKenarPanelGenislik = yeniGenislik
        UserDefaults.standard.set(Double(yeniGenislik), forKey: "kenarPanelGenislik")

        var panelKare = kenarPaneli.frame
        panelKare.size.width = yeniGenislik
        kenarPaneli.frame = panelKare

        surukleTutamaci.frame.origin.x = yeniGenislik - 3

        var editorKare = kaydirmaGorunumu.frame
        editorKare.origin.x = yeniGenislik
        editorKare.size.width = max(0, icerikGorunum.bounds.width - yeniGenislik)
        kaydirmaGorunumu.frame = editorKare
    }

    // MARK: Kapatma

    /// Menü eşleşmeleri klavye düzenine göre kaçabildiği için (⌘* Türkçe Q'da
    /// shift'siz, ABD düzeninde shift'li üretilir) punto kısayollarını burada
    /// düzenden bağımsız olarak yakalarız.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let bayraklar = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let karakterKucuk = event.charactersIgnoringModifiers?.lowercased()

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
        super.resignKey()
        if duzenlendiMi { otomatikKaydet() }
    }

    /// Kayıt başarısızsa pencere KAPANMAZ. Kullanıcı uyarıyı görür ve
    /// yazdıklarını kurtarma şansı bulur; sessizce kaybetmez.
    override func close() {
        guard kapanistaGerekirseKaydet() else { return }
        super.close()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
