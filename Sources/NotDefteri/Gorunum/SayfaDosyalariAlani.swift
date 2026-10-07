import AppKit
import NotDefteriCekirdek

final class SayfaDosyalariAlani: NSView, NSTableViewDataSource, NSTableViewDelegate {
    var dosyaSecildi: ((SayfaDosyasi) -> Void)?
    var boyutDegisti: (() -> Void)?
    private let baslik = NSButton(title: "", target: nil, action: nil)
    private let kaydirma = NSScrollView()
    private let tablo = NSTableView()
    private var satirlar: [(klasor: String, dosya: SayfaDosyasi?)] = []
    private var acik = false
    private(set) var dosyaSayisi = 0
    var hedefYukseklik: CGFloat { dosyaSayisi == 0 ? 0 : 30 + (acik ? min(144, CGFloat(satirlar.count) * 24) : 0) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        // Kâğıt temaları açık renklidir; koyu sistem görünümünde grup satırı ve seçim koyu çizilmesin.
        appearance = NSAppearance(named: .aqua)
        baslik.isBordered = false
        baslik.alignment = .left
        baslik.font = .systemFont(ofSize: 12, weight: .medium)
        baslik.target = self
        baslik.action = #selector(katlamayiDegistir)
        addSubview(baslik)
        let yol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("yol"))
        yol.minWidth = 40
        let boyut = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("boyut"))
        boyut.width = 76
        boyut.minWidth = 76
        boyut.maxWidth = 76
        tablo.addTableColumn(yol)
        tablo.addTableColumn(boyut)
        tablo.headerView = nil
        tablo.rowHeight = 22
        tablo.intercellSpacing = NSSize(width: 4, height: 2)
        tablo.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tablo.backgroundColor = .clear
        tablo.dataSource = self
        tablo.delegate = self
        tablo.target = self
        tablo.action = #selector(satirTiklandi)
        kaydirma.hasVerticalScroller = true
        kaydirma.drawsBackground = false
        kaydirma.documentView = tablo
        addSubview(kaydirma)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }

    func guncelle(_ dosyalar: [SayfaDosyasi]) {
        dosyaSayisi = dosyalar.count
        acik = false
        satirlar = []
        var sonKlasor: String?
        for dosya in dosyalar {
            if sonKlasor != dosya.klasor {
                satirlar.append((dosya.klasor.isEmpty ? "Bu klasör" : dosya.klasor, nil))
                sonKlasor = dosya.klasor
            }
            satirlar.append((dosya.klasor, dosya))
        }
        tablo.reloadData()
        basligiGuncelle()
        boyutDegisti?()
    }

    private func basligiGuncelle() {
        baslik.attributedTitle = NSAttributedString(string: "\(acik ? "▾" : "▸") Dosyalar (\(dosyaSayisi))",
            attributes: [.font: baslik.font ?? .systemFont(ofSize: 12, weight: .medium), .foregroundColor: kMetinRenk])
        baslik.setAccessibilityLabel("Dosyalar (\(dosyaSayisi))")
        baslik.setAccessibilityValue(acik ? "Açık" : "Katlı")
        kaydirma.isHidden = !acik
        needsLayout = true
    }

    @objc private func katlamayiDegistir() {
        acik.toggle()
        basligiGuncelle()
        boyutDegisti?()
    }

    override func layout() {
        super.layout()
        baslik.frame = NSRect(x: 0, y: max(0, bounds.height - 30), width: bounds.width, height: 30)
        kaydirma.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - 30))
    }

    func numberOfRows(in tableView: NSTableView) -> Int { satirlar.count }
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool { satirlar[row].dosya == nil }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { satirlar[row].dosya != nil }
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool { false }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 22 }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let satir = satirlar[row]
        let boyutSutunu = tableColumn?.identifier.rawValue == "boyut"
        let hucre = NSTableCellView()
        let etiket = NSTextField(labelWithString: "")
        etiket.translatesAutoresizingMaskIntoConstraints = false
        etiket.font = .systemFont(ofSize: 11, weight: satir.dosya == nil ? .medium : .regular)
        etiket.lineBreakMode = .byTruncatingMiddle
        // Panel kâğıt temasının üstünde durur; sistem etiket renkleri koyu görünümde zeminle karışır.
        etiket.textColor = satir.dosya == nil || boyutSutunu ? kMetinRenk.withAlphaComponent(0.65) : kMetinRenk
        etiket.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hucre.textField = etiket
        hucre.addSubview(etiket)
        var kisitlar = [etiket.centerYAnchor.constraint(equalTo: hucre.centerYAnchor),
                        etiket.trailingAnchor.constraint(equalTo: hucre.trailingAnchor, constant: -4)]
        var solKenar = etiket.leadingAnchor.constraint(equalTo: hucre.leadingAnchor, constant: 2)
        if let dosya = satir.dosya {
            if boyutSutunu {
                etiket.stringValue = ByteCountFormatter.string(fromByteCount: dosya.boyut, countStyle: .file)
                etiket.alignment = .right
            } else {
                etiket.stringValue = dosya.goreliYol
                let simge = NSImageView()
                simge.translatesAutoresizingMaskIntoConstraints = false
                simge.image = NSImage(systemSymbolName: dosya.kodMu ? "chevron.left.forwardslash.chevron.right" : dosya.metinMi ? "doc.text" : "doc", accessibilityDescription: dosya.kodMu ? "Kod" : dosya.metinMi ? "Metin" : "Dosya")
                simge.contentTintColor = kMetinRenk
                hucre.addSubview(simge)
                kisitlar += [simge.leadingAnchor.constraint(equalTo: hucre.leadingAnchor, constant: 2),
                             simge.centerYAnchor.constraint(equalTo: hucre.centerYAnchor),
                             simge.widthAnchor.constraint(equalToConstant: 16),
                             simge.heightAnchor.constraint(equalToConstant: 16)]
                solKenar = etiket.leadingAnchor.constraint(equalTo: simge.trailingAnchor, constant: 6)
                hucre.toolTip = dosya.goreliYol
            }
        } else if !boyutSutunu { etiket.stringValue = satir.klasor }
        NSLayoutConstraint.activate(kisitlar + [solKenar])
        return hucre
    }

    @objc private func satirTiklandi() {
        let row = tablo.clickedRow
        guard satirlar.indices.contains(row), let dosya = satirlar[row].dosya else { return }
        dosyaSecildi?(dosya)
    }
}
