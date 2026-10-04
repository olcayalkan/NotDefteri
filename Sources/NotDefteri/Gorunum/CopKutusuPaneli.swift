import AppKit

final class CopKutusuPaneli: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let copKutusu: CopKutusu
    private let degisti: () -> Void
    private let arama = NSSearchField()
    private let tablo = NSTableView()
    private let durum = NSTextField(labelWithString: "")
    private let bosalt = NSButton(title: "Çöpü boşalt", target: nil, action: nil)
    private var ogeler: [CopOgesi] = []
    private var suzulmus: [CopOgesi] = []
    private var okumaHatalari: [String] = []
    private let tarih = RelativeDateTimeFormatter()

    init(copKutusu: CopKutusu, degisti: @escaping () -> Void) {
        self.copKutusu = copKutusu
        self.degisti = degisti
        super.init(nibName: nil, bundle: nil)
        tarih.locale = Locale(identifier: "tr_TR")
        tarih.unitsStyle = .full
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 360))
        arama.frame = NSRect(x: 12, y: 320, width: 426, height: 26)
        arama.placeholderString = "Çöp kutusunda ara"
        arama.delegate = self
        view.addSubview(arama)
        let kaydirma = NSScrollView(frame: NSRect(x: 12, y: 50, width: 426, height: 260))
        kaydirma.hasVerticalScroller = true
        let sutun = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cop"))
        sutun.width = 410
        tablo.addTableColumn(sutun)
        tablo.headerView = nil
        tablo.rowHeight = 58
        tablo.dataSource = self
        tablo.delegate = self
        tablo.selectionHighlightStyle = .none
        kaydirma.documentView = tablo
        view.addSubview(kaydirma)
        durum.frame = NSRect(x: 12, y: 18, width: 265, height: 18)
        durum.font = .systemFont(ofSize: 11)
        durum.textColor = .secondaryLabelColor
        view.addSubview(durum)
        bosalt.frame = NSRect(x: 315, y: 10, width: 123, height: 30)
        bosalt.bezelStyle = .rounded
        bosalt.target = self
        bosalt.action = #selector(bosaltTiklandi)
        view.addSubview(bosalt)
        yenile()
    }

    func yenile() {
        do {
            let sonuc = try copKutusu.ogeler()
            ogeler = sonuc.ogeler
            okumaHatalari = sonuc.hatalar
            filtrele()
        } catch { hataGoster(error.localizedDescription) }
    }

    func controlTextDidChange(_ obj: Notification) {
        // Yalnızca yüklenmiş adlar süzülür; tuş başına disk ya da belge taraması yoktur.
        filtrele()
    }

    private func filtrele() {
        let sorgu = aramaIcinSadelestir(arama.stringValue)
        suzulmus = ogeler.filter { sorgu.isEmpty || aramaIcinSadelestir($0.ad).contains(sorgu) }
        tablo.reloadData()
        durum.stringValue = ogeler.isEmpty ? "Çöp kutusu boş" : "\(ogeler.count) öğe · 30 gün saklanır"
        if !okumaHatalari.isEmpty { durum.stringValue += " · \(okumaHatalari.count) öğe okunamadı" }
        durum.toolTip = okumaHatalari.joined(separator: "\n")
        bosalt.isEnabled = !ogeler.isEmpty || !okumaHatalari.isEmpty
    }

    func numberOfRows(in tableView: NSTableView) -> Int { suzulmus.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let oge = suzulmus[row]
        let satir = NSView(frame: NSRect(x: 0, y: 0, width: 410, height: 58))
        let ad = NSTextField(labelWithString: "\(oge.bilgi.icerikDosyasi == nil ? "📁" : "📄") \(oge.ad)")
        ad.frame = NSRect(x: 4, y: 31, width: 215, height: 20)
        ad.lineBreakMode = .byTruncatingTail
        ad.toolTip = oge.bilgi.ozgunYol
        satir.addSubview(ad)
        let zaman = NSTextField(labelWithString: tarih.localizedString(for: oge.bilgi.silinmeTarihi, relativeTo: Date()))
        zaman.frame = NSRect(x: 4, y: 9, width: 215, height: 18)
        zaman.font = .systemFont(ofSize: 11)
        zaman.textColor = .secondaryLabelColor
        satir.addSubview(zaman)
        for (sira, secenek) in [("Geri yükle", #selector(geriYukleTiklandi(_:))), ("Kalıcı sil", #selector(silTiklandi(_:)))].enumerated() {
            let buton = NSButton(title: secenek.0, target: self, action: secenek.1)
            buton.bezelStyle = .rounded
            buton.controlSize = .small
            buton.tag = row
            buton.frame = NSRect(x: 220 + sira * 94, y: 16, width: 92, height: 26)
            satir.addSubview(buton)
        }
        return satir
    }

    @objc private func geriYukleTiklandi(_ sender: NSButton) {
        guard suzulmus.indices.contains(sender.tag) else { return }
        do {
            try copKutusu.geriYukle(suzulmus[sender.tag])
            degisti()
        } catch { hataGoster(error.localizedDescription) }
        yenile()
    }

    @objc private func silTiklandi(_ sender: NSButton) {
        guard suzulmus.indices.contains(sender.tag) else { return }
        let oge = suzulmus[sender.tag]
        guard onayla("\"\(oge.ad)\" kalıcı silinsin mi?", dugme: "Kalıcı sil") else { return }
        do { try copKutusu.kaliciSil(oge) }
        catch { hataGoster(error.localizedDescription) }
        yenile()
    }

    @objc private func bosaltTiklandi() {
        guard onayla("Çöp kutusu boşaltılsın mı?", dugme: "Çöpü boşalt") else { return }
        let hatalar = copKutusu.temizle(eskiOlanlar: false)
        if !hatalar.isEmpty { hataGoster(hatalar.joined(separator: "\n")) }
        yenile()
    }

    private func onayla(_ mesaj: String, dugme: String) -> Bool {
        let uyari = NSAlert()
        uyari.messageText = mesaj
        uyari.informativeText = "Bu işlem geri alınamaz. Alt sayfalar ve görseller de kalıcı silinir."
        uyari.addButton(withTitle: dugme).hasDestructiveAction = true
        uyari.addButton(withTitle: "Vazgeç")
        return uyari.runModal() == .alertFirstButtonReturn
    }

    private func hataGoster(_ mesaj: String) {
        let uyari = NSAlert()
        uyari.messageText = "Çöp kutusu işlemi tamamlanamadı"
        uyari.informativeText = mesaj
        uyari.runModal()
    }
}
