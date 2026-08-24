import AppKit

// MARK: - Ana pencere

final class NotPenceresi: NSWindow, NSTextViewDelegate {

    private let metinGorunumu = NotMetinGorunumu()
    private let baslikCubugu = BaslikCubugu()
    private let kenarPaneli = KenarPaneli(frame: .zero)
    private let icerikGorunum = NSView()
    private let kaydirmaGorunumu = NSScrollView()
    private let surukleTutamaci = KenarPaneliSurukleTutamaci()

    private var mevcutDosyaURL: URL? {
        didSet { UserDefaults.standard.set(mevcutDosyaURL?.path, forKey: "sonNotYolu") }
    }
    private var duzenlendiMi = false
    private var kenarPanelGizli = UserDefaults.standard.bool(forKey: "kenarPanelGizli")
    /// Otomatik kayıt: yalnızca bekleyen bir değişiklik varken kurulur, tetiklenince kendini bırakır.
    private var otomatikKayitZamanlayici: Timer?
    /// Diske en son yazılan metin; aynı içeriği tekrar yazmamak için karşılaştırılır.
    private var sonYazilanIcerik: String?
    /// Dosya adı kullanıcı tarafından değil, ilk satırdan otomatik üretildiyse doğrudur.
    private var otomatikAdlandirildiMi = false

    convenience init() {
        let boyut = NSRect(x: 0, y: 0, width: 680, height: 520)
        self.init(contentRect: boyut,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)

        title = "Not Defteri"
        isReleasedWhenClosed = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        backgroundColor = aktifTema.arkaplan
        minSize = NSSize(width: 460, height: 320)
        // Yerel tam ekran (yeşil buton gizli olsa da toggleFullScreen çalışsın).
        collectionBehavior.insert(.fullScreenPrimary)

        icerikGorunum.frame = boyut
        icerikGorunum.wantsLayer = true
        icerikGorunum.layer?.backgroundColor = aktifTema.arkaplan.cgColor

        baslikCubugu.frame = NSRect(x: 0, y: boyut.height - kBaslikYuksekligi, width: boyut.width, height: kBaslikYuksekligi)
        baslikCubugu.autoresizingMask = [.width, .minYMargin]
        baslikCubugu.pencere = self
        baslikCubugu.yeniNotTiklandi = { [weak self] in self?.yeniNotOlustur() }
        baslikCubugu.kapatTiklandi = { [weak self] in self?.close() }
        baslikCubugu.kenarPaneliDegistirTiklandi = { [weak self] in self?.kenarPaneliniAcKapa() }
        baslikCubugu.geriAlTiklandi = { [weak self] in self?.geriAl() }
        baslikCubugu.ileriAlTiklandi = { [weak self] in self?.ileriAl() }

        let kenarPanelBaslangicGenislik: CGFloat = kenarPanelGizli ? 0 : gKenarPanelGenislik
        kenarPaneli.frame = NSRect(x: 0, y: 0, width: kenarPanelBaslangicGenislik, height: boyut.height - kBaslikYuksekligi)
        kenarPaneli.autoresizingMask = [.maxXMargin, .height]
        kenarPaneli.isHidden = kenarPanelGizli
        kenarPaneli.notSecildi = { [weak self] url in self?.notuAc(url) }
        kenarPaneli.notSilindi = { [weak self] url in self?.notSilindiIsleyici(url) }
        kenarPaneli.notYenidenAdlandirildi = { [weak self] eski, yeni in self?.notYenidenAdlandirildiIsleyici(eski: eski, yeni: yeni) }
        kenarPaneli.yeniSayfaIstendi = { [weak self] klasor in self?.yeniSayfaOlustur(klasor: klasor) }
        kenarPaneli.baslikSeviyesiIstendi = { [weak self] seviye in self?.baslikSeviyesiUygula(seviye) }
        kenarPaneli.puntoDegistirIstendi = { [weak self] fark in
            guard let self else { return }
            self.yaziBoyutunuDegistir(fark: fark)
            self.makeFirstResponder(self.metinGorunumu)
        }


        surukleTutamaci.frame = NSRect(x: kenarPanelBaslangicGenislik - 3, y: 0, width: 6, height: boyut.height - kBaslikYuksekligi)
        surukleTutamaci.autoresizingMask = [.height]
        surukleTutamaci.isHidden = kenarPanelGizli
        surukleTutamaci.surukleniyor = { [weak self] event in self?.kenarPaneliSurukleniyor(event) }

        kaydirmaGorunumu.frame = NSRect(x: kenarPanelBaslangicGenislik, y: 0, width: boyut.width - kenarPanelBaslangicGenislik, height: boyut.height - kBaslikYuksekligi)
        kaydirmaGorunumu.autoresizingMask = [.width, .height]
        kaydirmaGorunumu.hasVerticalScroller = true
        kaydirmaGorunumu.hasHorizontalScroller = false
        kaydirmaGorunumu.drawsBackground = false
        kaydirmaGorunumu.borderType = .noBorder

        metinGorunumu.frame = NSRect(origin: .zero, size: kaydirmaGorunumu.contentSize)
        // Genişlik kaydırma görünümünü takip eder; yükseklik içerik kadar uzar.
        metinGorunumu.autoresizingMask = [.width]
        metinGorunumu.minSize = NSSize(width: 0, height: kaydirmaGorunumu.contentSize.height)
        metinGorunumu.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        metinGorunumu.isRichText = true
        metinGorunumu.font = varsayilanFont()
        metinGorunumu.textColor = kMetinRenk
        metinGorunumu.backgroundColor = aktifTema.arkaplan
        metinGorunumu.insertionPointColor = kMetinRenk
        metinGorunumu.textContainerInset = NSSize(width: 14, height: 12)
        metinGorunumu.isEditable = true
        metinGorunumu.isVerticallyResizable = true
        metinGorunumu.isHorizontallyResizable = false
        // Satırlar pencere genişliğine göre kırılsın, yana taşmasın.
        metinGorunumu.textContainer?.widthTracksTextView = true
        metinGorunumu.textContainer?.heightTracksTextView = false
        metinGorunumu.textContainer?.size = NSSize(width: kaydirmaGorunumu.contentSize.width,
                                                    height: CGFloat.greatestFiniteMagnitude)
        metinGorunumu.isAutomaticQuoteSubstitutionEnabled = false
        metinGorunumu.isAutomaticDashSubstitutionEnabled = false
        metinGorunumu.isAutomaticTextReplacementEnabled = false
        metinGorunumu.allowsUndo = true
        metinGorunumu.importsGraphics = true   // Görsel yapıştırma/sürükleme kabul edilsin.
        metinGorunumu.gorselEklenecek = { [weak self] gorsel, bolumBasligi in
            self?.gorseliDiskeYaz(gorsel, bolumBasligi: bolumBasligi)
        }
        metinGorunumu.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.delegate = self

        kaydirmaGorunumu.documentView = metinGorunumu

        icerikGorunum.addSubview(kaydirmaGorunumu)
        icerikGorunum.addSubview(kenarPaneli)
        icerikGorunum.addSubview(surukleTutamaci)
        icerikGorunum.addSubview(baslikCubugu)
        contentView = icerikGorunum

        kenarPaneli.yenile(secili: nil)
        onceki_notu_ac_gerekirse()
        center()
    }

    private func onceki_notu_ac_gerekirse() {
        if let yol = UserDefaults.standard.string(forKey: "sonNotYolu") {
            let url = URL(fileURLWithPath: yol)
            if FileManager.default.fileExists(atPath: url.path) {
                notuAc(url)
                return
            }
        }
        if let ilkNot = kenarPaneli.notListesi.first {
            notuAc(ilkNot)
        }
    }

    // MARK: Not açma / oluşturma

    private func notuAc(_ url: URL) {
        if mevcutDosyaURL != url {
            mevcutNotuKaybolmayacakSekildeKaydet()
        }
        guard let icerik = try? String(contentsOf: url, encoding: .utf8) else { return }
        metinGorunumu.textStorage?.setAttributedString(markdowndenAttributedStringUret(icerik, taban: sayfaKlasoru(url)))
        mevcutDosyaURL = url
        sonYazilanIcerik = icerik
        otomatikAdlandirildiMi = false
        duzenlendiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        kenarPaneli.yenile(secili: url)
        puntoGostergesiniGuncelle()
    }

    private func yeniNotOlustur() {
        mevcutNotuKaybolmayacakSekildeKaydet()
        let bosOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: bosOznitelik))
        mevcutDosyaURL = nil
        sonYazilanIcerik = nil
        otomatikAdlandirildiMi = false
        duzenlendiMi = false
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
        kenarPaneli.tablo.deselectAll(nil)
        makeFirstResponder(metinGorunumu)
    }

    /// Kenar panelden istenen yeni sayfayı oluşturup açar. Adı "Yeni Sayfa"dır;
    /// ilk satırı yazdıkça dosya adı ona göre değişir.
    private func yeniSayfaOlustur(klasor: URL) {
        mevcutNotuKaybolmayacakSekildeKaydet()
        let url = benzersizSayfaURL(taban: "Yeni Sayfa", klasor: klasor)
        // Sayfa = kendi klasörü + içindeki index.md
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? "".write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        notuAc(url)
        otomatikAdlandirildiMi = true
        makeFirstResponder(metinGorunumu)
    }

    private func notSilindiIsleyici(_ url: URL) {
        guard mevcutDosyaURL == url else { return }
        let bosOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: bosOznitelik))
        mevcutDosyaURL = nil
        sonYazilanIcerik = nil
        otomatikAdlandirildiMi = false
        duzenlendiMi = false
        otomatikKayitBekleyeniIptalEt()
        gecmisiSifirla()
        baslikEtiketiniGuncelle()
    }

    private func notYenidenAdlandirildiIsleyici(eski: URL, yeni: URL) {
        guard mevcutDosyaURL == eski else { return }
        mevcutDosyaURL = yeni
        otomatikAdlandirildiMi = false  // Adı artık kullanıcı belirledi.
        baslikEtiketiniGuncelle()
    }

    /// Not değiştirilmeden önce, yazılmış ama kaydedilmemiş içeriği otomatik olarak kaydeder.
    /// Mevcut bir dosya açıksa üzerine yazar; yeni/boş bir nottaysa içerikten otomatik bir isim üretip yeni dosya oluşturur.
    private func mevcutNotuKaybolmayacakSekildeKaydet() {
        guard duzenlendiMi else { return }
        let icerik = metinGorunumu.string
        guard !icerik.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        } else {
            let hedefURL = benzersizDosyaURL(taban: otomatikBaslikUret(icerik: icerik))
            kaydetURLe(hedefURL)
        }
    }

    private func baslikEtiketiniGuncelle() {
        let ad = mevcutDosyaURL.map { sayfaAdi($0) } ?? "Yeni Sayfa"
        baslikCubugu.notAdiEtiketi.stringValue = ad
        title = ad
    }

    // MARK: Kaydetme (Cmd+S)

    @objc func kaydetKomutu(_ sender: Any?) { kaydet() }

    private func kaydet() {
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        } else {
            isimSorVeKaydet()
        }
    }

    private func kaydetURLe(_ url: URL, hazirMetin: String? = nil, panelYenile: Bool = true) {
        let metin = hazirMetin ?? markdownMetniUret(metinGorunumu.attributedString())
        // Aynı dosyaya aynı içeriği tekrar yazma (dosya diskte duruyorsa).
        guard metin != sonYazilanIcerik
                || url != mevcutDosyaURL
                || !FileManager.default.fileExists(atPath: url.path) else {
            duzenlendiMi = false
            return
        }
        // Sayfa klasörü henüz yoksa (yeni sayfa) oluşturulur.
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? metin.write(to: url, atomically: true, encoding: .utf8)
        sonYazilanIcerik = metin
        mevcutDosyaURL = url
        duzenlendiMi = false
        otomatikKayitBekleyeniIptalEt()
        baslikEtiketiniGuncelle()
        if panelYenile { kenarPaneli.yenile(secili: url) }
    }

    func textDidChange(_ notification: Notification) {
        icerikDegisti()
        gecmisDugmeleriniGuncelle()
    }

    // MARK: Eğik çizgi komutları (/1 /2 /3 /page) ve başlıklar

    /// Satır başında yazılıp boşluk veya Enter ile tamamlanan komutlar.
    private func egikCizgiKomutu(_ metin: String) -> String? {
        let komut = metin.trimmingCharacters(in: .whitespaces).lowercased()
        return ["/1", "/2", "/3", "/0", "/page", "/sayfa"].contains(komut) ? komut : nil
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let replacementString, replacementString == " " || replacementString == "\n" else { return true }
        let ns = textView.string as NSString

        // İmlecin bulunduğu satırın başından imlece kadarki metin komut mu?
        let satirAralik = ns.paragraphRange(for: NSRange(location: affectedCharRange.location, length: 0))
        let komutAralik = NSRange(location: satirAralik.location,
                                   length: max(0, affectedCharRange.location - satirAralik.location))
        if komutAralik.length > 0, let komut = egikCizgiKomutu(ns.substring(with: komutAralik)) {
            // Düzenlemeyi bu geri çağrının içinde yapmamak için bir sonraki döngüye bırak.
            DispatchQueue.main.async { [weak self] in self?.komutuCalistir(komut, aralik: komutAralik) }
            return false
        }

        // Başlık satırının sonunda Enter'a basılınca yeni satır normal biçimde başlasın.
        if replacementString == "\n", metinGorunumu.typingAttributes[kBaslikSeviyesiAnahtari] != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var oznitelikler = self.metinGorunumu.typingAttributes
                oznitelikler.removeValue(forKey: kBaslikSeviyesiAnahtari)
                oznitelikler[.font] = varsayilanFont()
                self.metinGorunumu.typingAttributes = oznitelikler
            }
        }
        return true
    }

    private func komutuCalistir(_ komut: String, aralik: NSRange) {
        guard let metinDeposu = metinGorunumu.textStorage,
              NSMaxRange(aralik) <= metinDeposu.length else { return }

        // Önce komut metnini sil.
        if metinGorunumu.shouldChangeText(in: aralik, replacementString: "") {
            metinDeposu.replaceCharacters(in: aralik, with: "")
            metinGorunumu.didChangeText()
        }
        metinGorunumu.setSelectedRange(NSRange(location: aralik.location, length: 0))

        switch komut {
        case "/1": baslikSeviyesiUygula(1)
        case "/2": baslikSeviyesiUygula(2)
        case "/3": baslikSeviyesiUygula(3)
        case "/0": baslikSeviyesiUygula(0)
        case "/page", "/sayfa": altSayfaKomutu()
        default: break
        }
    }

    /// İmlecin bulunduğu paragrafı başlığa çevirir; seviye 0 normal metne döndürür.
    func baslikSeviyesiUygula(_ seviye: Int) {
        guard let metinDeposu = metinGorunumu.textStorage else { return }
        let ns = metinDeposu.string as NSString
        let paragrafAralik = ns.paragraphRange(for: metinGorunumu.selectedRange())

        if paragrafAralik.length > 0, metinGorunumu.shouldChangeText(in: paragrafAralik, replacementString: nil) {
            metinDeposu.beginEditing()
            if seviye > 0 {
                metinDeposu.addAttributes([.font: baslikFontu(seviye), kBaslikSeviyesiAnahtari: seviye], range: paragrafAralik)
            } else {
                metinDeposu.removeAttribute(kBaslikSeviyesiAnahtari, range: paragrafAralik)
                metinDeposu.addAttribute(.font, value: varsayilanFont(), range: paragrafAralik)
            }
            metinDeposu.endEditing()
            metinGorunumu.didChangeText()
        }

        // Boş satırda komut verildiyse yazılacak metin başlık biçiminde başlasın.
        var oznitelikler = metinGorunumu.typingAttributes
        oznitelikler[.font] = seviye > 0 ? baslikFontu(seviye) : varsayilanFont()
        if seviye > 0 {
            oznitelikler[kBaslikSeviyesiAnahtari] = seviye
        } else {
            oznitelikler.removeValue(forKey: kBaslikSeviyesiAnahtari)
        }
        metinGorunumu.typingAttributes = oznitelikler
        icerikDegisti()
        puntoGostergesiniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    /// "/page": açık sayfanın altına yeni bir sayfa oluşturup açar.
    private func altSayfaKomutu() {
        // Sayfanın altına dal açabilmek için önce kendisinin diskte olması gerekir.
        if mevcutDosyaURL == nil {
            duzenlendiMi = true
            otomatikKaydet()
        }
        guard let ustSayfa = mevcutDosyaURL else {
            // Henüz hiç içeriği olmayan, kaydedilmemiş bir sayfadayız: yeni sayfayı
            // kardeş olarak oluştur, komut sessizce kaybolmasın.
            yeniSayfaOlustur(klasor: kenarPaneli.hedefKlasor())
            return
        }
        yeniSayfaOlustur(klasor: sayfaKlasoru(ustSayfa))
    }

    // MARK: Geri al / Yinele

    @objc func geriAlKomutu(_ sender: Any?) { geriAl() }
    @objc func ileriAlKomutu(_ sender: Any?) { ileriAl() }

    private func geriAl() {
        guard let yonetici = metinGorunumu.undoManager, yonetici.canUndo else { return }
        yonetici.undo()
        geriAlmaSonrasi()
    }

    private func ileriAl() {
        guard let yonetici = metinGorunumu.undoManager, yonetici.canRedo else { return }
        yonetici.redo()
        geriAlmaSonrasi()
    }

    /// Geri/ileri alma metni değiştirir; kaydı ve göstergeleri tazeler, odağı metne verir.
    private func geriAlmaSonrasi() {
        icerikDegisti()
        gecmisDugmeleriniGuncelle()
        puntoGostergesiniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    private func gecmisDugmeleriniGuncelle() {
        baslikCubugu.gecmisDurumunuGoster(geriAlinabilir: metinGorunumu.undoManager?.canUndo ?? false,
                                           ileriAlinabilir: metinGorunumu.undoManager?.canRedo ?? false)
    }

    /// Başka bir not açılırken geçmişi temizler; aksi halde ⌘Z önceki notun
    /// içeriğini şu anki notun üzerine geri getirebilir.
    private func gecmisiSifirla() {
        metinGorunumu.undoManager?.removeAllActions()
        gecmisDugmeleriniGuncelle()
    }

    // MARK: Görsel ekleme

    /// Yapıştırılan/sürüklenen görseli, sayfanın kendi klasöründeki "Görseller"
    /// altına PNG olarak yazar. Dosya adı, görselin eklendiği bölümün başlığıdır
    /// (ör. "Başlık1.png", ikincisi "Başlık1-2.png"); başlık yoksa "Görsel" olur.
    private func gorseliDiskeYaz(_ gorsel: NSImage, bolumBasligi: String?) -> ResimEki? {
        guard let tiff = gorsel.tiffRepresentation,
              let temsil = NSBitmapImageRep(data: tiff),
              let png = temsil.representation(using: .png, properties: [:]) else { return nil }

        // Sayfa henüz kaydedilmemişse görseller kök klasöre yazılır.
        let hedefKlasor = gorsellerKlasoru(mevcutDosyaURL.map { sayfaKlasoru($0) } ?? notlarKlasoru())
        var taban = (bolumBasligi ?? "Görsel")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if taban.isEmpty { taban = "Görsel" }
        if taban.count > 40 { taban = String(taban.prefix(40)) }

        var hedef = hedefKlasor.appendingPathComponent("\(taban).png")
        var sayac = 2
        while FileManager.default.fileExists(atPath: hedef.path) {
            hedef = hedefKlasor.appendingPathComponent("\(taban)-\(sayac).png")
            sayac += 1
        }
        guard (try? png.write(to: hedef)) != nil else { return nil }

        // Ek, ekrandaki piksel boyutunu değil görselin nokta boyutunu kullanır.
        let noktaBoyutu = NSSize(width: temsil.pixelsWide, height: temsil.pixelsHigh)
        let gercekGorsel = NSImage(size: noktaBoyutu)
        gercekGorsel.addRepresentation(temsil)
        return resimEkiUret(gorsel: gercekGorsel, dosyaURL: hedef,
                            bagYolu: "\(kGorsellerKlasorAdi)/\(hedef.lastPathComponent)")
    }

    // MARK: Otomatik kayıt

    /// İçerik değiştiğinde çağrılır; 5 saniyelik tek atımlık bir zamanlayıcı kurar.
    /// Zamanlayıcı zaten kuruluysa yenisi açılmaz, yani kesintisiz yazarken de
    /// en fazla 5 saniyede bir disk yazımı olur; boştayken hiç zamanlayıcı dönmez.
    private func icerikDegisti() {
        duzenlendiMi = true
        guard otomatikKayitZamanlayici == nil else { return }
        let zamanlayici = Timer(timeInterval: kOtomatikKayitAraligi, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.otomatikKayitZamanlayici = nil
            self.otomatikKaydet()
        }
        zamanlayici.tolerance = 1  // Sistemin uyandırmaları birleştirmesine izin verir (enerji dostu).
        RunLoop.main.add(zamanlayici, forMode: .common)  // Menü/kaydırma sırasında da işler.
        otomatikKayitZamanlayici = zamanlayici
    }

    private func otomatikKayitBekleyeniIptalEt() {
        otomatikKayitZamanlayici?.invalidate()
        otomatikKayitZamanlayici = nil
    }

    private func otomatikKaydet() {
        guard duzenlendiMi else { return }
        let metin = markdownMetniUret(metinGorunumu.attributedString())
        guard metin != sonYazilanIcerik else {
            duzenlendiMi = false
            return
        }
        guard !metinGorunumu.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard let mevcutURL = mevcutDosyaURL else {
            // Henüz kaydedilmemiş not: ilk satırdan bir ad üretip dosyayı oluşturur.
            otomatikAdlandirildiMi = true
            kaydetURLe(benzersizDosyaURL(taban: otomatikBaslikUret(icerik: metinGorunumu.string)), hazirMetin: metin)
            return
        }

        // Adı otomatik üretilmiş bir notun ilk satırı değiştiyse dosya adı da takip etsin.
        if otomatikAdlandirildiMi {
            let istenenAd = otomatikBaslikUret(icerik: metinGorunumu.string)
            if istenenAd != sayfaAdi(mevcutURL) {
                // Sayfa taşınırken alt sayfalarını tutan klasör de birlikte taşınır.
                if let yeniURL = sayfayiYenidenAdlandir(mevcutURL, yeniAd: istenenAd), yeniURL != mevcutURL {
                    kaydetURLe(yeniURL, hazirMetin: metin)
                    return
                }
            }
        }

        // Normal durum: aynı dosyanın üzerine yaz, kenar paneli boşuna tazeleme
        // (panel tüm notları yeniden okuduğu için asıl maliyet orada).
        kaydetURLe(mevcutURL, hazirMetin: metin, panelYenile: false)
    }

    private func isimSorVeKaydet() {
        let uyari = NSAlert()
        uyari.messageText = "Notu Kaydet"
        uyari.informativeText = "Not için bir isim girin:"
        uyari.addButton(withTitle: "Kaydet")
        uyari.addButton(withTitle: "Vazgeç")
        let girisAlani = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        girisAlani.placeholderString = "Örn: Alışveriş Listesi"
        uyari.accessoryView = girisAlani
        uyari.window.initialFirstResponder = girisAlani

        guard uyari.runModal() == .alertFirstButtonReturn else { return }

        var isim = girisAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if isim.isEmpty { isim = "Adsız Not" }
        isim = isim.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")

        let hedefURL = benzersizDosyaURL(taban: isim)
        otomatikAdlandirildiMi = false
        kaydetURLe(hedefURL)
    }

    /// Yeni sayfayı, kenar panelde seçili olanın yanında oluşturur.
    private func benzersizDosyaURL(taban: String, klasor verilenKlasor: URL? = nil) -> URL {
        benzersizSayfaURL(taban: taban, klasor: verilenKlasor ?? kenarPaneli.hedefKlasor())
    }

    /// Uygulama tamamen kapanırken (Cmd+Q gibi) mevcut dosyayı üzerine kaydeder.
    func kapanistaGerekirseKaydet() {
        otomatikKayitBekleyeniIptalEt()
        if let url = mevcutDosyaURL {
            kaydetURLe(url)
        }
    }

    // MARK: Kalın yazı (Cmd+B)

    @objc func kalinKomutu(_ sender: Any?) { kalinYap() }

    private func kalinYap() {
        guard let textStorage = metinGorunumu.textStorage else { return }
        let secilen = metinGorunumu.selectedRange()

        if secilen.length == 0 {
            var oznitelikler = metinGorunumu.typingAttributes
            let mevcutFont = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            let kalinMi = NSFontManager.shared.traits(of: mevcutFont).contains(.boldFontMask)
            oznitelikler[.font] = kalinMi
                ? NSFontManager.shared.convert(mevcutFont, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(mevcutFont, toHaveTrait: .boldFontMask)
            metinGorunumu.typingAttributes = oznitelikler
            return
        }

        var tumuKalin = true
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, _, durdur in
            let font = (deger as? NSFont) ?? varsayilanFont()
            if !NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                tumuKalin = false
                durdur.pointee = true
            }
        }

        // shouldChangeText/didChangeText çifti, öznitelik değişikliğini geri alma
        // yığınına kaydeder ve textDidChange'i tetikler.
        guard metinGorunumu.shouldChangeText(in: secilen, replacementString: nil) else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, altAralik, _ in
            let font = (deger as? NSFont) ?? varsayilanFont()
            let yeniFont = tumuKalin
                ? NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: yeniFont, range: altAralik)
        }
        textStorage.endEditing()
        metinGorunumu.didChangeText()
    }

    // MARK: Punto (Cmd+* büyüt / Cmd+- küçült)

    @objc func yaziBuyutKomutu(_ sender: Any?) { yaziBoyutunuDegistir(fark: 1) }
    @objc func yaziKucultKomutu(_ sender: Any?) { yaziBoyutunuDegistir(fark: -1) }

    /// Seçili metnin puntosunu değiştirir. Seçim yoksa, bundan sonra yazılacak
    /// metnin (ve varsayılan) puntosu değişir.
    private func yaziBoyutunuDegistir(fark: CGFloat) {
        guard let textStorage = metinGorunumu.textStorage else { return }
        let secilen = metinGorunumu.selectedRange()

        if secilen.length == 0 {
            var oznitelikler = metinGorunumu.typingAttributes
            let mevcutFont = (oznitelikler[.font] as? NSFont) ?? varsayilanFont()
            let yeniBoyut = boyutSinirla(mevcutFont.pointSize + fark)
            guard yeniBoyut != mevcutFont.pointSize else { return }
            oznitelikler[.font] = fontUret(boyut: yeniBoyut, kalin: kalinMi(mevcutFont))
            metinGorunumu.typingAttributes = oznitelikler
            // Yalnızca imlecin o anki yazım puntosu; kalıcı DEĞİL (kayma olmasın).
            gYaziBoyutu = yeniBoyut
            puntoGostergesiniGuncelle()
            return
        }

        guard metinGorunumu.shouldChangeText(in: secilen, replacementString: nil) else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: secilen, options: []) { deger, altAralik, _ in
            let eskiFont = (deger as? NSFont) ?? varsayilanFont()
            let yeniBoyut = boyutSinirla(eskiFont.pointSize + fark)
            textStorage.addAttribute(.font, value: fontUret(boyut: yeniBoyut, kalin: kalinMi(eskiFont)), range: altAralik)
        }
        textStorage.endEditing()
        metinGorunumu.didChangeText()
        puntoGostergesiniGuncelle()
    }

    /// İmlecin/seçimin bulunduğu yerin puntosunu kenar paneldeki göstergeye yazar.
    private func puntoGostergesiniGuncelle() {
        kenarPaneli.puntoyuGoster(mevcutPunto())
    }

    private func mevcutPunto() -> CGFloat {
        let secilen = metinGorunumu.selectedRange()
        if secilen.length > 0, let textStorage = metinGorunumu.textStorage,
           secilen.location < textStorage.length,
           let font = textStorage.attribute(.font, at: secilen.location, effectiveRange: nil) as? NSFont {
            return font.pointSize
        }
        return ((metinGorunumu.typingAttributes[.font] as? NSFont) ?? varsayilanFont()).pointSize
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        puntoGostergesiniGuncelle()
    }

    // MARK: Tema (Görünüm menüsü)

    @objc func temaSecKomutu(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, temaListesi.indices.contains(index) else { return }
        gTemaIndex = index
        UserDefaults.standard.set(index, forKey: "temaIndex")
        temaUygulaTumUI()
    }

    private func temaUygulaTumUI() {
        backgroundColor = aktifTema.arkaplan
        icerikGorunum.layer?.backgroundColor = aktifTema.arkaplan.cgColor
        metinGorunumu.backgroundColor = aktifTema.arkaplan
        baslikCubugu.temayiUygula()
        kenarPaneli.temayiUygula()
    }

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

    private func kenarPaneliniAcKapa() {
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
    private func kenarPaneliSurukleniyor(_ event: NSEvent) {
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

    override func close() {
        kapanistaGerekirseKaydet()
        super.close()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
