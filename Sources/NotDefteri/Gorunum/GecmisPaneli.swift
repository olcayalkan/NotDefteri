import AppKit
import NotDefteriCekirdek

/// Sayfa geçmişi: solda sürüm listesi, sağda salt okunur önizleme.
final class GecmisPaneli: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let sayfaURL: URL
    private let geriYukle: (String) -> Void
    private let kapat: () -> Void
    private let tablo = NSTableView()
    private let onizleme = NSTextView()
    private let yukle = NSButton(title: "Bu sürümü geri yükle", target: nil, action: nil)
    private var geriYuklemeBekliyor = false
    private var kapatildi = false
    private var surumler: [SayfaSurumu] = []
    private let bicim = DateFormatter()

    init(sayfaURL: URL, geriYukle: @escaping (String) -> Void, kapat: @escaping () -> Void) {
        self.sayfaURL = sayfaURL
        self.geriYukle = geriYukle
        self.kapat = kapat
        super.init(nibName: nil, bundle: nil)
        bicim.locale = Locale(identifier: "tr_TR")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        let sol = NSScrollView(frame: NSRect(x: 12, y: 50, width: 190, height: 358))
        sol.hasVerticalScroller = true
        let sutun = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("surum"))
        sutun.width = 170
        tablo.addTableColumn(sutun)
        tablo.headerView = nil
        tablo.dataSource = self
        tablo.delegate = self
        sol.documentView = tablo
        view.addSubview(sol)

        let sag = NSScrollView(frame: NSRect(x: 210, y: 50, width: 418, height: 358))
        sag.hasVerticalScroller = true
        sag.borderType = .bezelBorder
        onizleme.isEditable = false
        onizleme.autoresizingMask = [.width]
        onizleme.textContainerInset = NSSize(width: 8, height: 8)
        sag.documentView = onizleme
        view.addSubview(sag)

        yukle.frame = NSRect(x: 450, y: 10, width: 178, height: 30)
        yukle.bezelStyle = .rounded
        yukle.target = self
        yukle.action = #selector(yukleTiklandi)
        yukle.isEnabled = false
        view.addSubview(yukle)
        let kapatDugmesi = NSButton(title: "Kapat", target: self, action: #selector(kapatTiklandi))
        kapatDugmesi.frame = NSRect(x: 350, y: 10, width: 90, height: 30)
        kapatDugmesi.bezelStyle = .rounded
        kapatDugmesi.keyEquivalent = "\u{1b}"
        view.addSubview(kapatDugmesi)

        SayfaGecmisi.listele(sayfaURL) { [weak self] sonuc in
            guard let self else { return }
            self.surumler = sonuc
            self.tablo.reloadData()
            if !sonuc.isEmpty { self.tablo.selectRowIndexes([0], byExtendingSelection: false) }
            else { self.onizleme.string = "Henüz kayıtlı sürüm yok." }
        }
    }

    private func etiket(_ tarih: Date) -> String {
        let takvim = Calendar.current
        bicim.dateFormat = "HH:mm"
        let saat = bicim.string(from: tarih)
        if takvim.isDateInToday(tarih) { return "Bugün " + saat }
        if takvim.isDateInYesterday(tarih) { return "Dün " + saat }
        bicim.dateFormat = "d MMM yyyy HH:mm"
        return bicim.string(from: tarih)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { surumler.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        etiket(surumler[row].tarih)
    }

    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool { false }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let satir = tablo.selectedRow
        yukle.isEnabled = !geriYuklemeBekliyor && surumler.indices.contains(satir)
        guard yukle.isEnabled else { return }
        do {
            let metin = try SayfaGecmisi.surumMetniniOku(surumler[satir])
            let belge = MacBelgeAdaptoru.markdownuAc(sayfaUstbilgisiniAyir(metin).govde, taban: sayfaKlasoru(sayfaURL))
            onizleme.textStorage?.setAttributedString(belge)
        } catch {
            yukle.isEnabled = false
            onizleme.string = "Sürüm okunamadı."
            NSAlert(error: error).runModal()
        }
    }

    @objc private func yukleTiklandi() {
        guard surumler.indices.contains(tablo.selectedRow), yukle.isEnabled else { return }
        do {
            let metin = try SayfaGecmisi.surumMetniniOku(surumler[tablo.selectedRow])
            try notlarYolunuDogrula(sayfaURL)
            let mevcut = try String(contentsOf: sayfaURL, encoding: .utf8)
            yukle.isEnabled = false
            geriYuklemeBekliyor = true
            SayfaGecmisi.kaydet(metin: mevcut, icerikURL: sayfaURL, zorla: true) { [weak self] sonuc in
                guard let self, !self.kapatildi else { return }
                do {
                    _ = try sonuc.get()
                    try notlarYolunuDogrula(self.sayfaURL)
                    // Koruma sürümü beklenirken disk değiştiyse eski yedekle geri yükleme yapma.
                    guard try String(contentsOf: self.sayfaURL, encoding: .utf8) == mevcut else {
                        throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Sayfa değişti. Geçmiş panelini yeniden açın."])
                    }
                    self.geriYukle(sayfaUstbilgisiniAyir(metin).govde)
                    self.kapat()
                } catch {
                    self.geriYuklemeBekliyor = false
                    self.yukle.isEnabled = true
                    NSAlert(error: error).runModal()
                }
            }
        } catch { NSAlert(error: error).runModal() }
    }

    @objc private func kapatTiklandi() { kapatildi = true; kapat() }
}
