import AppKit

// MARK: - Kenar panel (arama + not ağacı + punto kısayolu)

final class KenarPaneli: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate, NSMenuDelegate {

    /// Ağacın görüntülenen (arama filtresinden geçmiş) hâli.
    private var kokDugumler: [AgacDugumu] = []
    /// Ağacın filtrelenmemiş hâli.
    private var tumKokDugumler: [AgacDugumu] = []
    private var icerikOnbellek: [URL: String] = [:]
    private var acikNotURL: URL?

    /// Görüntülenen sıradaki notlar (klasörler hariç).
    private(set) var notListesi: [URL] = []
    private var tumNotlar: [URL] = []
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
    private let kaydirmaGorunumu = NSScrollView()
    private let aramaKutusu = NSView()
    private let aramaIkonu = NSImageView()
    private let aramaAlani = NSTextField()
    private let aramaTemizleButonu = NSButton()
    private let baslikCubugu = NSView()
    private var baslikButonlari: [NSButton] = []
    private let puntoCubugu = NSView()
    private let puntoAzaltButonu = NSButton()
    private let puntoArttirButonu = NSButton()
    private let puntoEtiketi = NSTextField(labelWithString: "")
    private var programatikSecimYapiliyor = false
    /// Adı yerinde düzenlenen düğüm (çift tıklama ile açılır).
    private var duzenlenenDugum: AgacDugumu?
    private var adDuzenlemesiIptal = false
    /// Açık bırakılan klasörler oturumlar arasında hatırlanır.
    private var acikKlasorYollari: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "acikKlasorler") ?? [])

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

    // MARK: Ağacı yükleme / filtreleme

    func yenile(secili: URL?) {
        if let secili { acikNotURL = secili }
        tumKokDugumler = agaciYukle()
        tumNotlar = notlariDuzlestir(tumKokDugumler)
        icerikOnbellek = Dictionary(uniqueKeysWithValues: tumNotlar.compactMap { url in
            (try? String(contentsOf: url, encoding: .utf8)).map { (url, isaretlemeleriTemizle($0)) }
        })
        filtreUygula()
    }

    /// Ağacı, görüntülenme sırasına göre düz bir not listesine çevirir.
    private func notlariDuzlestir(_ dugumler: [AgacDugumu]) -> [URL] {
        var sonuc: [URL] = []
        for dugum in dugumler {
            if let icerik = dugum.icerikURL { sonuc.append(icerik) }
            sonuc += notlariDuzlestir(dugum.cocuklar)
        }
        return sonuc
    }

    /// Arama sorgusuna uyan notları ve onları içeren klasörleri bırakır.
    private func suzulmusAgac(_ dugumler: [AgacDugumu], sorgu: String) -> [AgacDugumu] {
        var sonuc: [AgacDugumu] = []
        for dugum in dugumler {
            let kendisiEsliyor = aramaIcinSadelestir(dugum.ad).contains(sorgu)
                || (dugum.icerikURL.map { notEsliyor($0, sorgu: sorgu) } ?? false)
            if kendisiEsliyor {
                // Eşleşen sayfa tüm alt dallarıyla birlikte görünsün.
                sonuc.append(dugum)
                continue
            }
            let kalanCocuklar = suzulmusAgac(dugum.cocuklar, sorgu: sorgu)
            if !kalanCocuklar.isEmpty {
                sonuc.append(AgacDugumu(icerikURL: dugum.icerikURL, klasorURL: dugum.klasorURL, cocuklar: kalanCocuklar))
            }
        }
        return sonuc
    }

    private func notEsliyor(_ url: URL, sorgu: String) -> Bool {
        if let icerik = icerikOnbellek[url] { return aramaIcinSadelestir(icerik).contains(sorgu) }
        return false
    }

    private func filtreUygula() {
        let sorgu = aramaIcinSadelestir(aramaAlani.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        kokDugumler = sorgu.isEmpty ? tumKokDugumler : suzulmusAgac(tumKokDugumler, sorgu: sorgu)
        notListesi = notlariDuzlestir(kokDugumler)
        tablo.reloadData()

        programatikSecimYapiliyor = true
        if sorgu.isEmpty {
            acikKlasorleriGeriYukle(kokDugumler)
        } else {
            // Arama sırasında eşleşmeler görünsün diye tüm klasörler açılır.
            tablo.expandItem(nil, expandChildren: true)
        }

        // Filtre değiştiğinde, üzerinde çalışılan not ağaçta hâlâ varsa doğru satırı
        // yeniden seç; yoksa eski (artık alakasız) bir satır seçili görünmesin.
        if let acikNotURL, let dugum = dugumBul(acikNotURL, kokDugumler) {
            atalariAc(acikNotURL)
            let satir = tablo.row(forItem: dugum)
            if satir >= 0 {
                tablo.selectRowIndexes(IndexSet(integer: satir), byExtendingSelection: false)
            }
        } else {
            tablo.deselectAll(nil)
        }
        programatikSecimYapiliyor = false
    }

    private func dugumBul(_ url: URL, _ dugumler: [AgacDugumu]) -> AgacDugumu? {
        for dugum in dugumler {
            if dugum.icerikURL == url { return dugum }
            if let bulunan = dugumBul(url, dugum.cocuklar) { return bulunan }
        }
        return nil
    }

    /// Verilen notun bulunduğu klasörleri kökten aşağıya doğru açar.
    private func atalariAc(_ url: URL) {
        var atalar: [URL] = []
        var klasor = url.deletingLastPathComponent()
        let kok = notlarKlasoru()
        while klasor.path.hasPrefix(kok.path), klasor != kok {
            atalar.insert(klasor, at: 0)
            klasor = klasor.deletingLastPathComponent()
        }
        // Ata klasörlerin karşılığı olan sayfaları kökten aşağıya doğru aç.
        for ata in atalar {
            if let dugum = klasoreGoreDugumBul(ata, kokDugumler) { tablo.expandItem(dugum) }
        }
    }

    /// Alt sayfalarını verilen klasörde tutan düğümü bulur.
    private func klasoreGoreDugumBul(_ klasor: URL, _ dugumler: [AgacDugumu]) -> AgacDugumu? {
        for dugum in dugumler {
            if dugum.cocuklarKlasoru == klasor { return dugum }
            if let bulunan = klasoreGoreDugumBul(klasor, dugum.cocuklar) { return bulunan }
        }
        return nil
    }

    private func acikKlasorleriGeriYukle(_ dugumler: [AgacDugumu]) {
        for dugum in dugumler where !dugum.cocuklar.isEmpty {
            if acikKlasorYollari.contains(dugum.cocuklarKlasoru.path) {
                tablo.expandItem(dugum)
                acikKlasorleriGeriYukle(dugum.cocuklar)
            }
        }
    }

    private func acikKlasorleriKaydet() {
        UserDefaults.standard.set(Array(acikKlasorYollari), forKey: "acikKlasorler")
    }

    func controlTextDidChange(_ obj: Notification) {
        aramaTemizleButonu.isHidden = aramaAlani.stringValue.isEmpty
        filtreUygula()
    }

    @objc private func aramaTemizleTiklandi() {
        aramaAlani.stringValue = ""
        aramaTemizleButonu.isHidden = true
        filtreUygula()
        window?.makeFirstResponder(aramaAlani)
    }

    // MARK: Ağaç veri kaynağı

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        cocuklar(item).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        cocuklar(item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // Sadece alt sayfası olan düğümde açma oku çıkar.
        !((item as? AgacDugumu)?.cocuklar.isEmpty ?? true)
    }

    private func cocuklar(_ item: Any?) -> [AgacDugumu] {
        guard let dugum = item as? AgacDugumu else { return kokDugumler }
        return dugum.cocuklar
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let kimlik = NSUserInterfaceItemIdentifier("NotSatiri")
        if let yenidenKullan = outlineView.makeView(withIdentifier: kimlik, owner: self) as? NotSatirGorunumu {
            return yenidenKullan
        }
        let satir = NotSatirGorunumu()
        satir.identifier = kimlik
        return satir
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let dugum = item as? AgacDugumu else { return nil }
        let kimlik = NSUserInterfaceItemIdentifier("NotHucresi")
        let hucre: NSTableCellView
        if let yenidenKullan = outlineView.makeView(withIdentifier: kimlik, owner: self) as? NSTableCellView {
            hucre = yenidenKullan
        } else {
            hucre = NSTableCellView()
            hucre.identifier = kimlik

            let ikon = NSImageView()
            ikon.imageScaling = .scaleProportionallyDown
            ikon.translatesAutoresizingMaskIntoConstraints = false
            hucre.addSubview(ikon)
            hucre.imageView = ikon

            let etiket = NSTextField(labelWithString: "")
            etiket.font = NSFont.systemFont(ofSize: 12.5)
            etiket.textColor = .darkGray
            etiket.lineBreakMode = .byTruncatingTail
            etiket.translatesAutoresizingMaskIntoConstraints = false
            hucre.addSubview(etiket)
            hucre.textField = etiket

            NSLayoutConstraint.activate([
                ikon.leadingAnchor.constraint(equalTo: hucre.leadingAnchor, constant: 2),
                ikon.centerYAnchor.constraint(equalTo: hucre.centerYAnchor),
                ikon.widthAnchor.constraint(equalToConstant: 14),
                ikon.heightAnchor.constraint(equalToConstant: 14),
                etiket.leadingAnchor.constraint(equalTo: ikon.trailingAnchor, constant: 5),
                etiket.trailingAnchor.constraint(equalTo: hucre.trailingAnchor, constant: -6),
                etiket.centerYAnchor.constraint(equalTo: hucre.centerYAnchor)
            ])
        }
        // Alt sayfası olan sayfa dolu, olmayan boş belge simgesiyle gösterilir.
        let sembol: String
        if !dugum.sayfaMi {
            sembol = "folder"
        } else {
            sembol = dugum.cocuklar.isEmpty ? "doc.text" : "doc.on.doc"
        }
        hucre.imageView?.image = renklendirilmisSembol(sembol,
                                                        renk: NSColor.black.withAlphaComponent(dugum.sayfaMi ? 0.45 : 0.6),
                                                        boyut: 12)
        hucre.textField?.stringValue = dugum.ad
        hucre.textField?.font = NSFont.systemFont(ofSize: 12.5, weight: dugum.sayfaMi ? .regular : .medium)
        return hucre
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !programatikSecimYapiliyor else { return }
        guard let dugum = tablo.item(atRow: tablo.selectedRow) as? AgacDugumu,
              let icerik = dugum.icerikURL else { return }
        acikNotURL = icerik
        notSecildi?(icerik)
    }

    /// Çift tıklamak adı satırın üzerinde düzenlemeye açar (Finder gibi).
    @objc private func cifteTiklandi() {
        let satir = tablo.clickedRow
        guard satir >= 0, let dugum = tablo.item(atRow: satir) as? AgacDugumu else { return }
        adiYerindeDuzenle(dugum: dugum, satir: satir)
    }

    private func adiYerindeDuzenle(dugum: AgacDugumu, satir: Int) {
        guard let hucre = tablo.view(atColumn: 0, row: satir, makeIfNecessary: true) as? NSTableCellView,
              let alan = hucre.textField else { return }
        duzenlenenDugum = dugum
        adDuzenlemesiIptal = false
        alan.isEditable = true
        alan.isSelectable = true
        alan.isBordered = true
        alan.drawsBackground = true
        alan.backgroundColor = .textBackgroundColor
        alan.textColor = .textColor
        alan.focusRingType = .default
        alan.delegate = self
        alan.stringValue = dugum.ad
        window?.makeFirstResponder(alan)
        alan.currentEditor()?.selectAll(nil)
    }

    private func adDuzenlemesiniBitir(_ alan: NSTextField) {
        alan.isEditable = false
        alan.isSelectable = false
        alan.isBordered = false
        alan.drawsBackground = false
        alan.textColor = .darkGray
        guard let dugum = duzenlenenDugum else { return }
        duzenlenenDugum = nil

        let yeniAd = alan.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        guard !adDuzenlemesiIptal, !yeniAd.isEmpty, yeniAd != dugum.ad else {
            alan.stringValue = dugum.ad   // Vazgeçildi: eski adı geri yaz.
            return
        }
        adiDegistir(dugum, yeniAd: yeniAd)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let dugum = notification.userInfo?["NSObject"] as? AgacDugumu else { return }
        acikKlasorYollari.insert(dugum.cocuklarKlasoru.path)
        acikKlasorleriKaydet()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let dugum = notification.userInfo?["NSObject"] as? AgacDugumu else { return }
        acikKlasorYollari.remove(dugum.cocuklarKlasoru.path)
        acikKlasorleriKaydet()
    }

    // MARK: Klasör / not işlemleri

    /// Başlık çubuğundaki "yeni not" için hedef: seçili sayfanın kardeşi olacak
    /// şekilde onun bulunduğu klasör; seçim yoksa kök.
    func hedefKlasor() -> URL {
        guard let dugum = tablo.item(atRow: tablo.selectedRow) as? AgacDugumu else { return notlarKlasoru() }
        return dugum.sayfaMi ? dugum.klasorURL.deletingLastPathComponent() : dugum.klasorURL
    }

    /// Sağ tıklanan satırın düğümü (boşluğa tıklandıysa nil).
    private func tiklananDugum() -> AgacDugumu? {
        tablo.item(atRow: tablo.clickedRow) as? AgacDugumu
    }

    @objc private func altSayfaEkleTiklandi() {
        guard let dugum = tiklananDugum() else {
            yeniSayfaIstendi?(notlarKlasoru())
            return
        }
        let hedefKlasor = dugum.cocuklarKlasoru
        // Bu dal artık açık kalsın ki yeni sayfa görünsün.
        acikKlasorYollari.insert(hedefKlasor.path)
        acikKlasorleriKaydet()
        yeniSayfaIstendi?(hedefKlasor)
    }

    /// Sağ tıklanan sayfanın yanına (aynı seviyeye) yeni bir sayfa açar.
    @objc private func kardesSayfaEkleTiklandi() {
        guard let dugum = tiklananDugum() else {
            yeniSayfaIstendi?(notlarKlasoru())
            return
        }
        yeniSayfaIstendi?(dugum.sayfaMi ? dugum.klasorURL.deletingLastPathComponent() : dugum.klasorURL)
    }

    @objc private func yenidenAdlandirTiklandi() {
        guard let dugum = tiklananDugum() else { return }
        // Sağ tık menüsü de satır üzerinde düzenlemeyi açar; ayrı bir pencere gerekmez.
        let satir = tablo.row(forItem: dugum)
        guard satir >= 0 else { return }
        adiYerindeDuzenle(dugum: dugum, satir: satir)
    }

    private func adiDegistir(_ dugum: AgacDugumu, yeniAd: String) {
        let eskiCocukKlasoru = dugum.klasorURL
        let yeniCocukKlasoru: URL

        if let icerik = dugum.icerikURL {
            guard let yeni = sayfayiYenidenAdlandir(icerik, yeniAd: yeniAd), yeni != icerik else { return }
            yeniCocukKlasoru = sayfaKlasoru(yeni)
            if acikNotURL == icerik {
                acikNotURL = yeni
                notYenidenAdlandirildi?(icerik, yeni)
            }
        } else {
            // Salt kapsayıcı klasör (eski yapıdan).
            let ust = dugum.klasorURL.deletingLastPathComponent()
            var aday = ust.appendingPathComponent(yeniAd, isDirectory: true)
            guard aday != dugum.klasorURL else { return }
            var sayac = 2
            while FileManager.default.fileExists(atPath: aday.path) {
                aday = ust.appendingPathComponent("\(yeniAd) (\(sayac))", isDirectory: true)
                sayac += 1
            }
            guard (try? FileManager.default.moveItem(at: dugum.klasorURL, to: aday)) != nil else { return }
            yeniCocukKlasoru = aday
        }
        // Açık sayfa taşınan dalın altındaysa yeni yolunu bildir.
        if let acik = acikNotURL, acik.path.hasPrefix(eskiCocukKlasoru.path + "/") {
            let yeniURL = URL(fileURLWithPath: yeniCocukKlasoru.path + acik.path.dropFirst(eskiCocukKlasoru.path.count))
            acikNotURL = yeniURL
            notYenidenAdlandirildi?(acik, yeniURL)
        }
        if acikKlasorYollari.remove(eskiCocukKlasoru.path) != nil {
            acikKlasorYollari.insert(yeniCocukKlasoru.path)
            acikKlasorleriKaydet()
        }
        yenile(secili: acikNotURL)
    }

    /// Dönüştürme seçeneği yalnızca eski düzendeki düz notlarda görünür.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let eskiDuzenMi = tiklananDugum()?.icerikURL.map { $0.lastPathComponent != kIcerikDosyaAdi } ?? false
        for oge in menu.items where oge.action == #selector(klasoreDonusturTiklandi) {
            oge.isHidden = !eskiDuzenMi
        }
        // Ayırıcı da onunla birlikte gizlensin.
        if let index = menu.items.firstIndex(where: { $0.action == #selector(klasoreDonusturTiklandi) }), index > 0 {
            menu.items[index - 1].isHidden = !eskiDuzenMi
        }
    }

    /// "Ad.md" düzenindeki notu "Ad/index.md" düzenine taşır.
    @objc private func klasoreDonusturTiklandi() {
        guard let dugum = tiklananDugum(), let icerik = dugum.icerikURL,
              let yeni = sayfayiKlasoreDonustur(icerik) else { return }
        if acikNotURL == icerik {
            acikNotURL = yeni
            notYenidenAdlandirildi?(icerik, yeni)
        }
        yenile(secili: acikNotURL)
    }

    @objc private func silTiklandi() {
        guard let dugum = tiklananDugum() else { return }
        let altKlasor = dugum.klasorURL
        let altDallariVar = !dugum.cocuklar.isEmpty

        let uyari = NSAlert()
        uyari.messageText = "\"\(dugum.ad)\" silinsin mi?"
        uyari.informativeText = altDallariVar
            ? "Sayfa ve altındaki tüm sayfalar Çöp Kutusu'na taşınacak."
            : "Bu sayfa Çöp Kutusu'na taşınacak."
        uyari.addButton(withTitle: "Sil")
        uyari.addButton(withTitle: "Vazgeç")
        if let silButonu = uyari.buttons.first {
            silButonu.hasDestructiveAction = true
        }
        guard uyari.runModal() == .alertFirstButtonReturn else { return }

        // Yeni düzende sayfanın her şeyi klasörünün içinde; tek hamlede gider.
        if FileManager.default.fileExists(atPath: altKlasor.path) {
            try? FileManager.default.trashItem(at: altKlasor, resultingItemURL: nil)
        }
        if let icerik = dugum.icerikURL, icerik.lastPathComponent != kIcerikDosyaAdi {
            try? FileManager.default.trashItem(at: icerik, resultingItemURL: nil)
        }

        // Açık sayfa silindiyse (ya da silinen dalın altındaysa) editörü boşalt.
        if let acik = acikNotURL, acik == dugum.icerikURL || acik.path.hasPrefix(altKlasor.path + "/") {
            acikNotURL = nil
            notSilindi?(acik)
        }
        yenile(secili: nil)
    }
}
