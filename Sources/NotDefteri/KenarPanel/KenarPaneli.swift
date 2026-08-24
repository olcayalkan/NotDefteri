import AppKit

// MARK: - Kenar panel (arama + not ağacı + punto kısayolu)

/// Arama önbelleğinin bir girdisi: notun aranabilir metni ve okunduğu andaki
/// değiştirilme tarihi. Tarih aynıysa dosya yeniden okunmaz.
struct OnbellekGirdisi {
    let tarih: Date
    let aranabilirMetin: String
}

final class KenarPaneli: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate, NSMenuDelegate {

    /// Ağacın görüntülenen (arama filtresinden geçmiş) hâli.
    var kokDugumler: [AgacDugumu] = []
    /// Ağacın filtrelenmemiş hâli.
    var tumKokDugumler: [AgacDugumu] = []
    var icerikOnbellek: [URL: OnbellekGirdisi] = [:]
    var acikNotURL: URL?

    /// Görüntülenen sıradaki notlar (klasörler hariç).
    /// Yalnızca `filtreUygula()` yazar; dışarıdan değiştirilmemeli.
    var notListesi: [URL] = []
    var tumNotlar: [URL] = []
    /// Cmd+[ / Cmd+] ile gezinme gibi, arama filtresinden etkilenmemesi gereken durumlar için tüm notlar.
    var tumNotUrlListesi: [URL] { tumNotlar }

    var notSecildi: ((URL) -> Void)?
    var notSilindi: ((URL) -> Void)?
    var notYenidenAdlandirildi: ((URL, URL) -> Void)?
    /// Kenar paneldeki punto kısayolu (A- / A+) tıklandığında tetiklenir.
    var puntoDegistirIstendi: ((CGFloat) -> Void)?
    /// Verilen klasörün içine yeni bir sayfa oluşturulması istendiğinde tetiklenir.
    var yeniSayfaIstendi: ((URL) -> Void)?
    /// Başlık düğmelerine (B1/B2/B3/Aa) basıldığında tetiklenir; 0 = normal metin.
    var baslikSeviyesiIstendi: ((Int) -> Void)?

    let tablo = NSOutlineView()
    let kaydirmaGorunumu = NSScrollView()
    let aramaKutusu = NSView()
    let aramaIkonu = NSImageView()
    let aramaAlani = NSTextField()
    let aramaTemizleButonu = NSButton()
    let baslikCubugu = NSView()
    var baslikButonlari: [NSButton] = []
    let puntoCubugu = NSView()
    let puntoAzaltButonu = NSButton()
    let puntoArttirButonu = NSButton()
    let puntoEtiketi = NSTextField(labelWithString: "")
    var programatikSecimYapiliyor = false
    /// `yenile()` içindeyken tekrar çağrılmasını engeller (iç içe reloadData).
    var yenilemeSuruyor = false
    /// Adı yerinde düzenlenen düğüm (çift tıklama ile açılır).
    var duzenlenenDugum: AgacDugumu?
    var adDuzenlemesiIptal = false
    /// Açık bırakılan klasörler oturumlar arasında hatırlanır.
    var acikKlasorYollari: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "acikKlasorler") ?? [])

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = aktifTema.kenarPanel.cgColor

        aramaKutusu.wantsLayer = true
        aramaKutusu.layer?.cornerRadius = 7
        aramaKutusu.layer?.backgroundColor = aramaKutuRengi().cgColor
        addSubview(aramaKutusu)

        aramaIkonu.image = renklendirilmisSembol("magnifyingglass", renk: NSColor.black.withAlphaComponent(0.65), boyut: 12)
        aramaIkonu.imageScaling = .scaleProportionallyDown
        aramaKutusu.addSubview(aramaIkonu)

        aramaAlani.delegate = self
        aramaAlani.font = NSFont.systemFont(ofSize: 12)
        aramaAlani.isBezeled = false
        aramaAlani.isBordered = false
        aramaAlani.drawsBackground = false
        aramaAlani.focusRingType = .none
        aramaAlani.textColor = .black
        aramaAlani.usesSingleLineMode = true
        aramaAlani.lineBreakMode = .byTruncatingTail
        aramaAlani.placeholderAttributedString = NSAttributedString(
            string: "Notlarda ara...",
            attributes: [.foregroundColor: NSColor.black.withAlphaComponent(0.45), .font: NSFont.systemFont(ofSize: 12)]
        )
        aramaKutusu.addSubview(aramaAlani)

        aramaTemizleButonu.image = renklendirilmisSembol("xmark.circle.fill", renk: NSColor.black.withAlphaComponent(0.55), boyut: 13)
        aramaTemizleButonu.isBordered = false
        aramaTemizleButonu.imageScaling = .scaleProportionallyDown
        aramaTemizleButonu.target = self
        aramaTemizleButonu.action = #selector(aramaTemizleTiklandi)
        aramaTemizleButonu.isHidden = true
        aramaKutusu.addSubview(aramaTemizleButonu)

        let sutun = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NotSutunu"))
        sutun.width = max(gKenarPanelGenislik - 8, 60)
        tablo.addTableColumn(sutun)
        tablo.outlineTableColumn = sutun
        tablo.headerView = nil
        tablo.backgroundColor = .clear
        tablo.rowHeight = 26
        tablo.dataSource = self
        tablo.delegate = self
        tablo.selectionHighlightStyle = .regular
        tablo.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tablo.intercellSpacing = NSSize(width: 0, height: 2)
        tablo.indentationPerLevel = 13
        tablo.indentationMarkerFollowsCell = true
        tablo.autoresizesOutlineColumn = false
        tablo.target = self
        tablo.doubleAction = #selector(cifteTiklandi)

        let sagTikMenusu = NSMenu()
        let altSayfaOgesi = NSMenuItem(title: "Alt Sayfa Ekle", action: #selector(altSayfaEkleTiklandi), keyEquivalent: "")
        altSayfaOgesi.target = self
        sagTikMenusu.addItem(altSayfaOgesi)
        let kardesSayfaOgesi = NSMenuItem(title: "Yanına Sayfa Ekle", action: #selector(kardesSayfaEkleTiklandi), keyEquivalent: "")
        kardesSayfaOgesi.target = self
        sagTikMenusu.addItem(kardesSayfaOgesi)
        sagTikMenusu.addItem(NSMenuItem.separator())
        let yenidenAdlandirOgesi = NSMenuItem(title: "Yeniden Adlandır", action: #selector(yenidenAdlandirTiklandi), keyEquivalent: "")
        yenidenAdlandirOgesi.target = self
        sagTikMenusu.addItem(yenidenAdlandirOgesi)
        let silOgesi = NSMenuItem(title: "Sil", action: #selector(silTiklandi), keyEquivalent: "")
        silOgesi.target = self
        sagTikMenusu.addItem(silOgesi)
        let donusturOgesi = NSMenuItem(title: "Sayfa Klasörüne Dönüştür", action: #selector(klasoreDonusturTiklandi), keyEquivalent: "")
        donusturOgesi.target = self
        sagTikMenusu.addItem(NSMenuItem.separator())
        sagTikMenusu.addItem(donusturOgesi)
        sagTikMenusu.delegate = self
        tablo.menu = sagTikMenusu

        kaydirmaGorunumu.documentView = tablo
        kaydirmaGorunumu.hasVerticalScroller = true
        kaydirmaGorunumu.drawsBackground = false
        kaydirmaGorunumu.borderType = .noBorder
        addSubview(kaydirmaGorunumu)

        baslikCubuguKur()
        puntoCubuguKur()
    }

    /// Punto çubuğunun üstündeki başlık düzeyi kısayolları: B1 / B2 / B3 / Aa
    private func baslikCubuguKur() {
        baslikCubugu.wantsLayer = true
        baslikCubugu.layer?.cornerRadius = 7
        baslikCubugu.layer?.backgroundColor = aramaKutuRengi().cgColor
        addSubview(baslikCubugu)

        let tanimlar: [(String, Int, String)] = [
            ("B1", 1, "En büyük başlık (satır başında /1 + boşluk)"),
            ("B2", 2, "Alt başlık (/2 + boşluk)"),
            ("B3", 3, "Küçük başlık (/3 + boşluk)"),
            ("Aa", 0, "Normal metin (/0 + boşluk)")
        ]
        for (yazi, seviye, ipucu) in tanimlar {
            let buton = NSButton()
            buton.title = yazi
            buton.isBordered = false
            buton.bezelStyle = .inline
            buton.refusesFirstResponder = true
            buton.toolTip = ipucu
            buton.tag = seviye
            buton.attributedTitle = NSAttributedString(
                string: yazi,
                attributes: [.foregroundColor: NSColor.black.withAlphaComponent(0.7),
                             .font: NSFont.systemFont(ofSize: 11.5, weight: seviye == 0 ? .regular : .semibold)]
            )
            buton.target = self
            buton.action = #selector(baslikButonunaTiklandi(_:))
            baslikCubugu.addSubview(buton)
            baslikButonlari.append(buton)
        }
    }

    @objc private func baslikButonunaTiklandi(_ gonderen: NSButton) {
        baslikSeviyesiIstendi?(gonderen.tag)
    }

    /// Panelin altındaki punto kısayolu: A-  /  14 pt  /  A+
    private func puntoCubuguKur() {
        puntoCubugu.wantsLayer = true
        puntoCubugu.layer?.cornerRadius = 7
        puntoCubugu.layer?.backgroundColor = aramaKutuRengi().cgColor
        addSubview(puntoCubugu)

        puntoAzaltButonu.title = "A−"
        puntoAzaltButonu.toolTip = "Seçili yazının puntosunu küçült (⌘−)"
        puntoArttirButonu.title = "A+"
        puntoArttirButonu.toolTip = "Seçili yazının puntosunu büyüt (⌘*)"

        for (buton, puntoBoyutu) in [(puntoAzaltButonu, CGFloat(11)), (puntoArttirButonu, CGFloat(13))] {
            buton.isBordered = false
            buton.bezelStyle = .inline
            buton.refusesFirstResponder = true   // Odak, yazı alanından kaçmasın.
            buton.font = NSFont.systemFont(ofSize: puntoBoyutu, weight: .semibold)
            buton.contentTintColor = .darkGray
            buton.attributedTitle = NSAttributedString(
                string: buton.title,
                attributes: [.foregroundColor: NSColor.black.withAlphaComponent(0.7),
                             .font: NSFont.systemFont(ofSize: puntoBoyutu, weight: .semibold)]
            )
            buton.target = self
            puntoCubugu.addSubview(buton)
        }
        puntoAzaltButonu.action = #selector(puntoAzaltTiklandi)
        puntoArttirButonu.action = #selector(puntoArttirTiklandi)

        puntoEtiketi.font = NSFont.systemFont(ofSize: 11.5)
        puntoEtiketi.textColor = NSColor.black.withAlphaComponent(0.6)
        puntoEtiketi.alignment = .center
        puntoCubugu.addSubview(puntoEtiketi)

        puntoyuGoster(gYaziBoyutu)
    }

    /// Punto göstergesini günceller (imlecin bulunduğu ya da seçili metnin puntosu).
    func puntoyuGoster(_ boyut: CGFloat) {
        puntoEtiketi.stringValue = "\(boyutMetni(boyut)) pt"
    }

    @objc private func puntoAzaltTiklandi() { puntoDegistirIstendi?(-1) }
    @objc private func puntoArttirTiklandi() { puntoDegistirIstendi?(1) }

    required init?(coder: NSCoder) { fatalError() }

    func temayiUygula() {
        layer?.backgroundColor = aktifTema.kenarPanel.cgColor
        aramaKutusu.layer?.backgroundColor = aramaKutuRengi().cgColor
        baslikCubugu.layer?.backgroundColor = aramaKutuRengi().cgColor
        puntoCubugu.layer?.backgroundColor = aramaKutuRengi().cgColor
        for satirIndex in 0..<tablo.numberOfRows {
            (tablo.rowView(atRow: satirIndex, makeIfNecessary: false) as? NotSatirGorunumu)?.temayiUygula()
        }
    }

    override func layout() {
        super.layout()
        let aramaAlaniYuksekligi: CGFloat = 24
        let ustBosluk: CGFloat = 8
        aramaKutusu.frame = NSRect(x: 8, y: bounds.height - aramaAlaniYuksekligi - ustBosluk, width: bounds.width - 16, height: aramaAlaniYuksekligi)

        let ikonBoyutu: CGFloat = 13
        aramaIkonu.frame = NSRect(x: 6, y: (aramaAlaniYuksekligi - ikonBoyutu) / 2, width: ikonBoyutu, height: ikonBoyutu)

        let temizleBoyutu: CGFloat = 14
        aramaTemizleButonu.frame = NSRect(x: aramaKutusu.bounds.width - temizleBoyutu - 6, y: (aramaAlaniYuksekligi - temizleBoyutu) / 2, width: temizleBoyutu, height: temizleBoyutu)

        let alaniX = aramaIkonu.frame.maxX + 5
        let alaniGenislik = max(0, aramaTemizleButonu.frame.minX - 4 - alaniX)
        aramaAlani.frame = NSRect(x: alaniX, y: 3, width: alaniGenislik, height: aramaAlaniYuksekligi - 6)

        let puntoCubuguYuksekligi: CGFloat = 26
        let altBosluk: CGFloat = 8
        puntoCubugu.frame = NSRect(x: 8, y: altBosluk, width: max(0, bounds.width - 16), height: puntoCubuguYuksekligi)

        let butonGenisligi: CGFloat = 30
        puntoAzaltButonu.frame = NSRect(x: 0, y: 0, width: butonGenisligi, height: puntoCubuguYuksekligi)
        puntoArttirButonu.frame = NSRect(x: puntoCubugu.bounds.width - butonGenisligi, y: 0, width: butonGenisligi, height: puntoCubuguYuksekligi)
        puntoEtiketi.frame = NSRect(x: butonGenisligi, y: (puntoCubuguYuksekligi - 14) / 2,
                                     width: max(0, puntoCubugu.bounds.width - butonGenisligi * 2), height: 14)

        let baslikCubuguYuksekligi: CGFloat = 24
        baslikCubugu.frame = NSRect(x: 8, y: puntoCubugu.frame.maxY + 6,
                                     width: max(0, bounds.width - 16), height: baslikCubuguYuksekligi)
        let dilimGenisligi = baslikCubugu.bounds.width / CGFloat(max(1, baslikButonlari.count))
        for (sira, buton) in baslikButonlari.enumerated() {
            buton.frame = NSRect(x: dilimGenisligi * CGFloat(sira), y: 0, width: dilimGenisligi, height: baslikCubuguYuksekligi)
        }

        let listeUstu = bounds.height - aramaAlaniYuksekligi - ustBosluk * 2
        let listeAlti = baslikCubugu.frame.maxY + altBosluk
        kaydirmaGorunumu.frame = NSRect(x: 0, y: listeAlti, width: bounds.width, height: max(0, listeUstu - listeAlti))
    }

    /// Arama kutusuna odaklanma/odak kaybı durumunda rengi yumuşak geçişle koyulaştırır.
    private func aramaOdakDegisti(odakta: Bool) {
        let eskiRenk = aramaKutusu.layer?.backgroundColor
        let hedefRenk = odakta ? aramaOdakRengi() : aramaKutuRengi()
        let animasyon = CABasicAnimation(keyPath: "backgroundColor")
        animasyon.fromValue = eskiRenk
        animasyon.toValue = hedefRenk.cgColor
        animasyon.duration = 0.18
        animasyon.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        aramaKutusu.layer?.add(animasyon, forKey: "arkaplanRengi")
        aramaKutusu.layer?.backgroundColor = hedefRenk.cgColor
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        if (obj.object as AnyObject?) === aramaAlani { aramaOdakDegisti(odakta: true) }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if (obj.object as AnyObject?) === aramaAlani {
            aramaOdakDegisti(odakta: false)
            return
        }
        guard let alan = obj.object as? NSTextField else { return }
        adDuzenlemesiniBitir(alan)
    }

    /// Esc: değişiklikten vazgeç.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control !== aramaAlani, commandSelector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        adDuzenlemesiIptal = true
        window?.makeFirstResponder(tablo)
        return true
    }
}
