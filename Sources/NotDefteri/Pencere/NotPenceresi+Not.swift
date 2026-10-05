import AppKit
import NotDefteriCekirdek

// MARK: - NotPenceresi: Not açma ve oluşturma

extension NotPenceresi {

    // MARK: Not açma / oluşturma

    func notuAc(_ url: URL, panelYenile: Bool = true, yenidenYukle: Bool = false) {
        if mevcutDosyaURL == url, !yenidenYukle {
            sayfaDosyalariniTazele()
            if !anaSayfa.isHidden {
                anaSayfayiGizle()
                kenarPaneli.acikNotuBildir(url)
                kenarPaneli.sayfaBaglantilari.acildi(url)
                makeFirstResponder(metinGorunumu)
            }
            return
        }
        let adsizNotAcikti = mevcutDosyaURL == nil
        guard mevcutNotuKaybolmayacakSekildeKaydet() else { return }
        if adsizNotAcikti, mevcutDosyaURL != nil, !panelYenile {
            // Yeni dosyayı seçim delegesi tamamlandıktan sonra ağaca ekle.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.kenarPaneli.yenile(secili: self.mevcutDosyaURL)
            }
        }
        guard let icerik = try? String(contentsOf: url, encoding: .utf8) else { return }
        anaSayfayiGizle()
        let sayfa = sayfaUstbilgisiniAyir(icerik)
        hizliBulucu.gizle()
        metinGorunumu.yuzerGorunumleriGizle()
        metinGorunumu.bagTamamlamaAraligi = nil
        metinGorunumu.slashAraligi = nil
        sayfaUstbilgisi = sayfa.bilgi
        metinGorunumu.katlamaSayfasiniAc(url)
        metinGorunumu.sayfaYukleniyor = true
        metinGorunumu.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc(sayfa.govde, taban: sayfaKlasoru(url)))
        metinGorunumu.sayfaYukleniyor = false
        metinGorunumu.setSelectedRange(NSRange(location: 0, length: 0))
        if metinGorunumu.string.isEmpty { metinGorunumu.typingAttributes = [:] }
        mevcutDosyaURL = url
        if yenidenYukle { sayfaDosyalariniTazele() }
        sonDuzenleme = degistirilmeTarihi(url)
        metinGorunumu.kelimeSayisiniHazirla()
        altBilgiyiGuncelle()
        sayfaBasliginiGuncelle()
        metinGorunumu.scrollRangeToVisible(NSRange(location: 0, length: 0))
        kaydedici.sifirla(sonYazilan: icerik)
        otomatikAdlandirildiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        icindekileriTazele()
        // Panelden seçilerek açıldıysa ağaç zaten güncel; yeniden kurmak
        // hem gereksiz disk okuması hem de iç içe reloadData kaynağı.
        if panelYenile { kenarPaneli.yenile(secili: url) } else { kenarPaneli.acikNotuBildir(url) }
        kenarPaneli.icerikOnbelleginiIste()
        kenarPaneli.notIceriginiGuncelle(url, metin: icerik)
        kenarPaneli.sayfaBaglantilari.acildi(url)
        metinGorunumu.sayfaBaglariniBoya()
        geriBaglantilariTazele()
        puntoGostergesiniGuncelle()
    }

    /// Başlık çubuğundaki "Yeni Not" düğmesi.
    ///
    /// Dosyayı HEMEN oluşturur ki kenar panelde anında görünsün. Eskiden
    /// yalnızca editör boşaltılıyor, dosya ilk otomatik kayıtta doğuyordu;
    /// o ana kadar not listede yoktu ve kullanıcı kaybolduğunu sanıyordu.
    func yeniNotOlustur() {
        yeniSayfaOlustur(klasor: kenarPaneli.hedefKlasor())
    }

    func yeniSayfaOlustur(klasor: URL) {
        guard mevcutNotuKaybolmayacakSekildeKaydet() else { return }
        let url = benzersizSayfaURL(taban: "Yeni Sayfa", klasor: klasor)
        // Sayfa = kendi klasörü + içindeki index.md
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? "".write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        notuAc(url)
        otomatikAdlandirildiMi = true
        makeFirstResponder(metinGorunumu)
    }

    func notSilindiIsleyici(_ url: URL) {
        guard mevcutDosyaURL == url else { return }
        metinGorunumu.katlamaSayfasiniAc(nil)
        let bosOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: bosOznitelik))
        metinGorunumu.typingAttributes = [:]
        mevcutDosyaURL = nil
        geriBaglantilariTazele()
        sayfaUstbilgisi = SayfaUstbilgisi()
        sonDuzenleme = Date()
        metinGorunumu.kelimeSayisiniHazirla()
        altBilgiyiGuncelle()
        sayfaBasliginiGuncelle()
        kaydedici.sifirla(sonYazilan: nil)
        otomatikAdlandirildiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        icindekileriTazele()
    }

    func notYenidenAdlandirildiIsleyici(eski: URL, yeni: URL) {
        guard mevcutDosyaURL == eski else { return }
        icindekileriTazele()
        metinGorunumu.katlamaYolunuDegistir(yeni)
        mevcutDosyaURL = yeni
        sayfaBasliginiGuncelle()
        otomatikAdlandirildiMi = false  // Adı artık kullanıcı belirledi.
        baslikEtiketiniGuncelle()
        icindekileriTazele()
    }

    /// Not değiştirilmeden önce, yazılmış ama kaydedilmemiş içeriği otomatik olarak kaydeder.
    /// Mevcut bir dosya açıksa üzerine yazar; yeni/boş bir nottaysa içerikten otomatik bir isim üretip yeni dosya oluşturur.
    func mevcutNotuKaybolmayacakSekildeKaydet() -> Bool {
        guard kaydedici.duzenlendiMi else { return true }
        otomatikKayitBekleyeniIptalEt()
        // Kullanıcının geçiş/kapatma denemesinde hata yeniden görünür olsun.
        kayitHatasiBildirildi = false
        let icerik = metinGorunumu.string
        if let url = mevcutDosyaURL {
            return kaydetURLe(url, panelYenile: false)
        } else {
            guard !icerik.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !sayfaUstbilgisi.markdown.isEmpty else { return true }
            let hedefURL = benzersizDosyaURL(taban: otomatikBaslikUret(icerik: icerik))
            return kaydetURLe(hedefURL, panelYenile: false)
        }
    }

    func baslikEtiketiniGuncelle() {
        if !anaSayfa.isHidden {
            baslikCubugu.notAdiEtiketi.stringValue = "Ana Sayfa"
            baslikCubugu.sayfaYolunuGoster([])
            title = "Ana Sayfa"
            return
        }
        let ad = mevcutDosyaURL.map { sayfaAdi($0) } ?? "Yeni Sayfa"
        baslikCubugu.notAdiEtiketi.stringValue = ad
        baslikCubugu.sayfaYolunuGoster(mevcutDosyaURL.map { sayfaYolu($0) } ?? [])
        title = ad
    }

    func sayfaBasliginiGuncelle() {
        sayfaSecenekleriniUygula()
        icerikBoyutuDegisti()
    }

    func sayfaUstbilgisiniDegistir(_ bilgi: SayfaUstbilgisi) {
        guard bilgi != sayfaUstbilgisi else { return }
        let eski = sayfaUstbilgisi
        metinGorunumu.breakUndoCoalescing()
        metinGorunumu.undoManager?.registerUndo(withTarget: self) { $0.sayfaUstbilgisiniDegistir(eski) }
        metinGorunumu.undoManager?.setActionName("Sayfa seçenekleri")
        sayfaUstbilgisi = bilgi
        sayfaBasliginiGuncelle()
        icerikDegisti()
        if let url = mevcutDosyaURL { kaydetURLe(url, panelYenile: false) }
        gecmisDugmeleriniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    // MARK: Sayfa dosyaları

    func sayfaDosyalariniTazele() {
        sayfaDosyalariNesli &+= 1
        let nesil = sayfaDosyalariNesli
        sayfaDosyalariAlani.guncelle([])
        guard let url = mevcutDosyaURL else { return }
        let klasor = sayfaKlasoru(url), kok = notlarKlasoru()
        sayfaDosyalariKuyrugu.async { [weak self] in
            let dosyalar = SayfaDosyalari.topla(sayfaKlasoru: klasor, kok: kok)
            DispatchQueue.main.async {
                guard let self, self.sayfaDosyalariNesli == nesil, self.mevcutDosyaURL == url else { return }
                self.sayfaDosyalariAlani.guncelle(dosyalar)
            }
        }
    }

    func sayfaDosyasiniGoster(_ dosya: SayfaDosyasi) {
        guard anaSayfa.isHidden, attachedSheet == nil else { return }
        let kok = notlarKlasoru()
        if dosya.metinMi {
            let sayfa = NSWindow(contentRect: .zero, styleMask: [.titled, .resizable], backing: .buffered, defer: false)
            sayfa.title = dosya.goreliYol
            sayfa.minSize = NSSize(width: 720, height: 320)
            sayfa.contentViewController = KodGoruntuleyici(url: dosya.url, kok: kok,
                kapat: { [weak self, weak sayfa] in if let sayfa { self?.endSheet(sayfa) } })
            beginSheet(sayfa)
            return
        }
        let nesil = sayfaDosyalariNesli
        sayfaDosyalariKuyrugu.async { [weak self] in
            let sonuc = Result { try SayfaDosyalari.dogrula(dosya.url, kok: kok) }
            DispatchQueue.main.async {
                guard let self, self.sayfaDosyalariNesli == nesil, self.anaSayfa.isHidden else { return }
                switch sonuc {
                case .success: NSWorkspace.shared.activateFileViewerSelecting([dosya.url])
                case .failure(let hata):
                    let uyari = NSAlert(error: hata)
                    uyari.beginSheetModal(for: self)
                }
            }
        }
    }

    // MARK: İçindekiler paneli

    /// Başlıklar değişmiş olabilir; paneli yeniden kurar ve yerine oturtur.
    func icindekileriTazele() {
        icindekiler.basliklarGuncellendi = { [weak self] girdiler in
            guard let self else { return }
            self.metinGorunumu.katlamaBasliklariniGuncelle(girdiler)
            if let url = self.mevcutDosyaURL { self.metinGorunumu.katlamaYolunuDegistir(url) }
        }
        icindekiler.icerigiGuncelle(metinGorunumu.textStorage)
        icindekiler.frame = icindekiler.hedefKare()
        icindekiler.etkinBasligiGuncelle(imlecKonumu: metinGorunumu.selectedRange().location)
    }

    /// İçindekilerden bir başlığa tıklanınca metni oraya kaydırır ve imleci koyar.
    func basligaGit(_ konum: Int) {
        guard let depo = metinGorunumu.textStorage, konum < depo.length else { return }
        let paragraf = (depo.string as NSString).paragraphRange(for: NSRange(location: konum, length: 0))
        metinGorunumu.katliAraligiAc(paragraf, basligiDaAc: true)
        metinGorunumu.scrollRangeToVisible(paragraf)
        metinGorunumu.setSelectedRange(NSRange(location: paragraf.location, length: 0))
        makeFirstResponder(metinGorunumu)
        icindekiler.etkinBasligiGuncelle(imlecKonumu: paragraf.location)
    }
}
