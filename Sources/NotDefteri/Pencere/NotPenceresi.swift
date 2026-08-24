import AppKit

// MARK: - Ana pencere

final class NotPenceresi: NSWindow, NSTextViewDelegate {

    let metinGorunumu = NotMetinGorunumu()
    let baslikCubugu = BaslikCubugu()
    let kenarPaneli = KenarPaneli(frame: .zero)
    let icerikGorunum = NSView()
    let kaydirmaGorunumu = NSScrollView()
    let surukleTutamaci = KenarPaneliSurukleTutamaci()

    var mevcutDosyaURL: URL? {
        didSet { UserDefaults.standard.set(mevcutDosyaURL?.path, forKey: "sonNotYolu") }
    }
    var duzenlendiMi = false
    var kenarPanelGizli = UserDefaults.standard.bool(forKey: "kenarPanelGizli")
    /// Otomatik kayıt: yalnızca bekleyen bir değişiklik varken kurulur, tetiklenince kendini bırakır.
    var otomatikKayitZamanlayici: Timer?
    /// Diske en son yazılan metin; aynı içeriği tekrar yazmamak için karşılaştırılır.
    var sonYazilanIcerik: String?
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
}
