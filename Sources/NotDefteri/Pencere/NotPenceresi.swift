import AppKit
import NotDefteriCekirdek

// MARK: - Ana pencere

final class NotPenceresi: NSWindow, NSTextViewDelegate {

    let anaSayfa = AnaSayfa(frame: .zero)
    let metinGorunumu = NotMetinGorunumu()
    let baslikCubugu = BaslikCubugu()
    let sayfaSecenekAlani = SayfaSecenekAlani()
    let sayfaDosyalariAlani = SayfaDosyalariAlani(frame: .zero)
    let sayfaDosyalariKuyrugu = DispatchQueue(label: "NotDefteri.sayfaDosyalari", qos: .userInitiated)
    var sayfaDosyalariNesli: UInt = 0
    var sayfaUstbilgisi = SayfaUstbilgisi()
    let kenarPaneli = KenarPaneli(frame: .zero)
    let icerikGorunum = NSView()
    let kaydirmaGorunumu = NSScrollView()
    let surukleTutamaci = KenarPaneliSurukleTutamaci()
    /// Sağ kenardaki içindekiler paneli (başlıklardan üretilir).
    let icindekiler = IcindekilerPaneli(frame: .zero)
    let hizliBulucu = HizliBulucu()
    var geriBagZamanlayicisi: Timer?
    let sayfaAltBilgisi = NSTextField(labelWithString: "")
    var altBilgiZamanlayicisi: Timer?
    var sonDuzenleme = Date()

    var mevcutDosyaURL: URL? {
        didSet {
            gAyarlar.set(mevcutDosyaURL?.path, forKey: "sonNotYolu")
            if oldValue != mevcutDosyaURL { sayfaDosyalariniTazele() }
        }
    }
    /// Kayıt mantığı ve otomatik kayıt zamanlayıcısı burada.
    let kaydedici = NotKaydedici()
    var kenarPanelGizli = gAyarlar.bool(forKey: "kenarPanelGizli")
    var kenarPanelGecisNesli: UInt = 0
    var kenarPanelGecisiSuruyor = false
    /// Diske en son yazılan metin; aynı içeriği tekrar yazmamak için karşılaştırılır.
    /// Dosya adı kullanıcı tarafından değil, ilk satırdan otomatik üretildiyse doğrudur.
    var otomatikAdlandirildiMi = false
    /// Kayıt hatası kullanıcıya bildirildi mi? Otomatik kayıt 5 saniyede bir
    /// denediği için, hata sürerken her turda uyarı çıkmasın diye tutulur.
    /// Başarılı bir kayıtta sıfırlanır.
    var kayitHatasiBildirildi = false

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
        // Sabit genişlikte kayan panel pencerenin sol kenarında kırpılır.
        icerikGorunum.layer?.masksToBounds = true
        icerikGorunum.layer?.backgroundColor = aktifTema.arkaplan.cgColor

        baslikCubugu.frame = NSRect(x: 0, y: boyut.height - kBaslikYuksekligi, width: boyut.width, height: kBaslikYuksekligi)
        baslikCubugu.autoresizingMask = [.width, .minYMargin]
        baslikCubugu.pencere = self
        baslikCubugu.yeniNotTiklandi = { [weak self] in self?.yeniNotOlustur() }
        baslikCubugu.kapatTiklandi = { [weak self] in self?.close() }
        baslikCubugu.kenarPaneliDegistirTiklandi = { [weak self] in self?.kenarPaneliniAcKapa() }
        baslikCubugu.geriAlTiklandi = { [weak self] in guard let self, self.anaSayfa.isHidden else { return }; self.geriAl() }
        baslikCubugu.ileriAlTiklandi = { [weak self] in guard let self, self.anaSayfa.isHidden else { return }; self.ileriAl() }
        baslikCubugu.sayfaYoluTiklandi = { [weak self] url in self?.notuAc(url) }

        let kenarPanelBaslangicGenislik: CGFloat = kenarPanelGizli ? 0 : gKenarPanelGenislik
        kenarPaneli.frame = NSRect(x: kenarPanelBaslangicGenislik - gKenarPanelGenislik, y: 0, width: gKenarPanelGenislik, height: boyut.height - kBaslikYuksekligi)
        kenarPaneli.isHidden = kenarPanelGizli
        kenarPaneli.gorunumGuncellemeleriniAyarla(!kenarPanelGizli)
        kenarPaneli.notSecildi = { [weak self] url in self?.notuAc(url, panelYenile: false) }
        kenarPaneli.notSilindi = { [weak self] url in self?.notSilindiIsleyici(url) }
        kenarPaneli.notYenidenAdlandirildi = { [weak self] eski, yeni in self?.notYenidenAdlandirildiIsleyici(eski: eski, yeni: yeni) }
        kenarPaneli.tasinmadanOnce = { [weak self] in self?.mevcutNotuKaybolmayacakSekildeKaydet() ?? false }
        kenarPaneli.baglantiOnbellegiDegisti = { [weak self] in
            guard let self else { return }
            self.geriBaglantilariTazelemeyiPlanla()
            if !self.anaSayfa.isHidden { self.anaSayfayiTazele() }
        }
        kenarPaneli.sayfaIndeksiDegisti = { [weak self] in self?.metinGorunumu.sayfaBaglariniBoya() }
        kenarPaneli.baglarYenidenYazildi = { [weak self] hedefler in self?.acikNotunBaglariniYenidenYaz(hedefler) }
        kenarPaneli.yeniSayfaIstendi = { [weak self] klasor in self?.yeniSayfaOlustur(klasor: klasor) }
        kenarPaneli.baslikSeviyesiIstendi = { [weak self] seviye in
            guard let self, self.anaSayfa.isHidden else { return }
            self.baslikSeviyesiUygula(seviye)
        }
        kenarPaneli.puntoDegistirIstendi = { [weak self] fark in
            guard let self else { return }
            guard self.anaSayfa.isHidden else { return }
            self.yaziBoyutunuDegistir(fark: fark)
            self.makeFirstResponder(self.metinGorunumu)
        }


        surukleTutamaci.frame = NSRect(x: kenarPanelBaslangicGenislik - 3, y: 0, width: 6, height: boyut.height - kBaslikYuksekligi)
        surukleTutamaci.isHidden = kenarPanelGizli
        surukleTutamaci.surukleniyor = { [weak self] event in self?.kenarPaneliSurukleniyor(event) }

        kaydirmaGorunumu.frame = NSRect(x: kenarPanelBaslangicGenislik, y: 0, width: boyut.width - kenarPanelBaslangicGenislik, height: boyut.height - kBaslikYuksekligi)
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
        // Kap genişliği sayfa seçeneğine göre hesaplanır; görünüm yalnızca ortalanabilir.
        metinGorunumu.textContainer?.widthTracksTextView = false
        metinGorunumu.textContainer?.heightTracksTextView = false
        metinGorunumu.textContainer?.size = NSSize(width: kaydirmaGorunumu.contentSize.width,
                                                    height: CGFloat.greatestFiniteMagnitude)
        metinGorunumu.isAutomaticQuoteSubstitutionEnabled = false
        metinGorunumu.isAutomaticDashSubstitutionEnabled = false
        metinGorunumu.isAutomaticTextReplacementEnabled = false
        metinGorunumu.linkTextAttributes = [.foregroundColor: kMetinRenk, .underlineStyle: NSUnderlineStyle.single.rawValue]
        metinGorunumu.allowsUndo = true
        metinGorunumu.usesFindBar = true
        metinGorunumu.isIncrementalSearchingEnabled = true
        metinGorunumu.importsGraphics = true   // Görsel yapıştırma/sürükleme kabul edilsin.
        metinGorunumu.gorselEklenecek = { [weak self] gorsel, bolumBasligi in
            self?.gorseliDiskeYaz(gorsel, bolumBasligi: bolumBasligi)
        }
        metinGorunumu.icerikEklenecek = { [weak self] markdown, kaynakTaban in
            self?.kopyalananIcerigiHazirla(markdown: markdown, kaynakTaban: kaynakTaban)
        }
        metinGorunumu.sayfaTabanKlasoru = { [weak self] in self?.mevcutDosyaURL.map { sayfaKlasoru($0) } }
        metinGorunumu.typingAttributes = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]
        metinGorunumu.delegate = self
        metinGorunumu.textStorage?.delegate = metinGorunumu
        metinGorunumu.altBilgiDegisti = { [weak self] in self?.altBilgiyiGuncellemeyiPlanla() }

        kaydirmaGorunumu.documentView = metinGorunumu

        icindekiler.autoresizingMask = [.minXMargin, .minYMargin]  // sağ üste sabit
        icindekiler.sayfayaGitIstendi = { [weak self] url in self?.notuAc(url) }
        icindekiler.basligaGitIstendi = { [weak self] konum in self?.basligaGit(konum) }

        icerikGorunum.addSubview(kaydirmaGorunumu)
        sayfaAltBilgisi.font = NSFont.systemFont(ofSize: 11)
        sayfaAltBilgisi.textColor = .secondaryLabelColor
        sayfaAltBilgisi.lineBreakMode = .byTruncatingTail
        icerikGorunum.addSubview(sayfaAltBilgisi)
        icerikGorunum.addSubview(sayfaSecenekAlani)
        sayfaDosyalariAlani.boyutDegisti = { [weak self] in self?.sayfaGenisliginiUygula() }
        sayfaDosyalariAlani.dosyaSecildi = { [weak self] in self?.sayfaDosyasiniGoster($0) }
        icerikGorunum.addSubview(sayfaDosyalariAlani)
        icerikGorunum.addSubview(icindekiler)
        anaSayfa.isHidden = true
        anaSayfa.sayfaAc = { [weak self] in self?.notuAc($0) }
        anaSayfa.yapilacagaGit = { [weak self] in self?.yapilacagaGit($0) }
        anaSayfa.yapilacagiTamamla = { [weak self] in self?.yapilacagiTamamla($0) }
        anaSayfa.yeniSayfa = { [weak self] in self?.yeniNotOlustur() }
        anaSayfa.gunlukNot = { [weak self] in self?.gunlukNotuAc() }
        anaSayfa.sablonSec = { [weak self] in self?.sablondanSayfaOlustur() }
        kenarPaneli.anaSayfaIstendi = { [weak self] in self?.anaSayfayiGoster() }
        icerikGorunum.addSubview(anaSayfa)
        icerikGorunum.addSubview(kenarPaneli)
        icerikGorunum.addSubview(surukleTutamaci)
        icerikGorunum.addSubview(baslikCubugu)
        contentView = icerikGorunum
        // Panel, tutamaç ve editörün ölçülerini yalnızca ortak yerleşim yolu yazar.
        icerikGorunum.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(icerikBoyutuDegisti),
                                                name: NSView.frameDidChangeNotification, object: icerikGorunum)
        // Clip genişliği kaydırma çubuğuyla da değişebilir; panel animasyonunu da izle.
        for gorunum in [kaydirmaGorunumu as NSView, kaydirmaGorunumu.contentView] {
            gorunum.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(sayfaGenisliginiUygula),
                                                    name: NSView.frameDidChangeNotification, object: gorunum)
        }

        kenarPaneli.yenile(secili: nil)
        if gAcilistaAnaSayfa { anaSayfayiGoster() } else { onceki_notu_ac_gerekirse() }
        sayfaBasliginiGuncelle()
        altBilgiyiGuncelle()
        center()
    }

    private func onceki_notu_ac_gerekirse() {
        if let yol = gAyarlar.string(forKey: "sonNotYolu") {
            let url = URL(fileURLWithPath: yol)
            if FileManager.default.fileExists(atPath: url.path) {
                notuAc(url)
                return
            }
        }
        if let ilkNot = kenarPaneli.tumNotUrlListesi.first {
            notuAc(ilkNot)
        }
    }
}
