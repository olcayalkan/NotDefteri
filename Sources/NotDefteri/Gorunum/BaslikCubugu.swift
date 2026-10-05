import AppKit
import NotDefteriCekirdek

// MARK: - Özel başlık çubuğu (Yeni Not / Sabitle / Arkaya At / Kapat)

final class BaslikCubugu: NSView {

    weak var pencere: NSWindow?
    private(set) var sabitlemeAcik = false

    var yeniNotTiklandi: (() -> Void)?
    var kapatTiklandi: (() -> Void)?
    var kenarPaneliDegistirTiklandi: (() -> Void)?
    var geriAlTiklandi: (() -> Void)?
    var ileriAlTiklandi: (() -> Void)?
    var sayfaYoluTiklandi: ((URL) -> Void)?
    private var sayfalar: [URL] = []
    private let yol = NSStackView()

    let notAdiEtiketi = NSTextField(labelWithString: "Yeni Not")

    private lazy var kenarPaneliButon = ozelButonOlustur(sembol: "sidebar.left", aciklama: "Kenar Paneli Göster/Gizle")
    private lazy var yeniNotButon = ozelButonOlustur(sembol: "square.and.pencil", aciklama: "Yeni Not")
    private lazy var geriAlButon = ozelButonOlustur(sembol: "arrow.uturn.backward", aciklama: "Geri Al (⌘Z)")
    private lazy var ileriAlButon = ozelButonOlustur(sembol: "arrow.uturn.forward", aciklama: "Yinele (⌘Y)")
    private lazy var sabitleButon = ozelButonOlustur(sembol: "pin", aciklama: "Sabitle (her zaman üstte)")
    private lazy var arkayaAtButon = ozelButonOlustur(sembol: "minus", aciklama: "Arka plana at")
    private lazy var kapatButon = ozelButonOlustur(sembol: "xmark", aciklama: "Kapat")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = aktifTema.baslikCubugu.cgColor

        kenarPaneliButon.target = self
        kenarPaneliButon.action = #selector(kenarPaneliButonaTiklandi)

        yeniNotButon.target = self
        yeniNotButon.action = #selector(yeniNotButonaTiklandi)

        geriAlButon.target = self
        geriAlButon.action = #selector(geriAlButonaTiklandi)

        ileriAlButon.target = self
        ileriAlButon.action = #selector(ileriAlButonaTiklandi)

        sabitleButon.target = self
        sabitleButon.action = #selector(sabitleButonaTiklandi)

        arkayaAtButon.target = self
        arkayaAtButon.action = #selector(arkayaAtButonaTiklandi)

        kapatButon.target = self
        kapatButon.action = #selector(kapatButonaTiklandi)

        notAdiEtiketi.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        notAdiEtiketi.textColor = .darkGray
        notAdiEtiketi.lineBreakMode = .byTruncatingTail
        yol.orientation = .horizontal
        yol.spacing = 3
        yol.distribution = .fillProportionally
        yol.isHidden = true
        addSubview(yol)

        for altGorunum in [kenarPaneliButon, yeniNotButon, geriAlButon, ileriAlButon, notAdiEtiketi, sabitleButon, arkayaAtButon, kapatButon] {
            addSubview(altGorunum)
        }
        sabitlemeGorunumunuGuncelle()
        gecmisDurumunuGoster(geriAlinabilir: false, ileriAlinabilir: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func ozelButonOlustur(sembol: String, aciklama: String) -> NSButton {
        let buton = NSButton(image: NSImage(systemSymbolName: sembol, accessibilityDescription: aciklama) ?? NSImage(), target: nil, action: nil)
        buton.bezelStyle = .circular
        buton.isBordered = false
        buton.imageScaling = .scaleProportionallyDown
        buton.toolTip = aciklama
        buton.contentTintColor = .darkGray
        buton.refusesFirstResponder = true  // Odak yazı alanından kaçmasın.
        return buton
    }

    func temayiUygula() {
        layer?.backgroundColor = aktifTema.baslikCubugu.cgColor
    }

    override func layout() {
        super.layout()
        let boyut: CGFloat = 22
        let bosluk: CGFloat = 8
        let y = (bounds.height - boyut) / 2

        var x = bounds.width - boyut - 10
        kapatButon.frame = NSRect(x: x, y: y, width: boyut, height: boyut)
        x -= (boyut + bosluk)
        arkayaAtButon.frame = NSRect(x: x, y: y, width: boyut, height: boyut)
        x -= (boyut + bosluk)
        sabitleButon.frame = NSRect(x: x, y: y, width: boyut, height: boyut)

        let solX: CGFloat = 10
        for (sira, buton) in [kenarPaneliButon, yeniNotButon, geriAlButon, ileriAlButon].enumerated() {
            buton.frame = NSRect(x: solX + (boyut + bosluk) * CGFloat(sira), y: y, width: boyut, height: boyut)
        }

        let etiketX = solX + (boyut + bosluk) * 4
        let etiketGenislik = max(0, sabitleButon.frame.minX - 8 - etiketX)
        notAdiEtiketi.frame = NSRect(x: etiketX, y: (bounds.height - 16) / 2, width: etiketGenislik, height: 16)
        yol.frame = NSRect(x: etiketX, y: y, width: etiketGenislik, height: boyut)
    }

    func sayfaYolunuGoster(_ yeni: [URL]) {
        guard sayfalar != yeni else { return }
        sayfalar = yeni
        yol.arrangedSubviews.forEach { yol.removeArrangedSubview($0); $0.removeFromSuperview() }
        yol.isHidden = yeni.count < 2
        notAdiEtiketi.isHidden = yeni.count >= 2
        for (sira, url) in yeni.enumerated() {
            if sira > 0 {
                let ayirac = NSTextField(labelWithString: "›")
                ayirac.textColor = .darkGray
                yol.addArrangedSubview(ayirac)
            }
            let dugme = NSButton(title: sayfaAdi(url), target: self, action: #selector(yolaTiklandi(_:)))
            dugme.tag = sira
            dugme.isBordered = false
            dugme.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            dugme.contentTintColor = .darkGray
            dugme.refusesFirstResponder = true
            dugme.toolTip = sayfaAdi(url)
            dugme.cell?.lineBreakMode = .byTruncatingMiddle
            dugme.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            yol.addArrangedSubview(dugme)
        }
        needsLayout = true
    }

    @objc private func yolaTiklandi(_ sender: NSButton) {
        guard sayfalar.indices.contains(sender.tag) else { return }
        sayfaYoluTiklandi?(sayfalar[sender.tag])
    }

    @objc private func kenarPaneliButonaTiklandi() { kenarPaneliDegistirTiklandi?() }

    @objc private func yeniNotButonaTiklandi() { yeniNotTiklandi?() }

    @objc private func geriAlButonaTiklandi() { geriAlTiklandi?() }

    @objc private func ileriAlButonaTiklandi() { ileriAlTiklandi?() }

    /// Geri/ileri alınacak işlem yoksa düğmeyi soluklaştırıp devre dışı bırakır.
    func gecmisDurumunuGoster(geriAlinabilir: Bool, ileriAlinabilir: Bool) {
        geriAlButon.isEnabled = geriAlinabilir
        geriAlButon.alphaValue = geriAlinabilir ? 1.0 : 0.3
        ileriAlButon.isEnabled = ileriAlinabilir
        ileriAlButon.alphaValue = ileriAlinabilir ? 1.0 : 0.3
    }

    @objc private func sabitleButonaTiklandi() {
        sabitlemeAcik.toggle()
        pencere?.level = sabitlemeAcik ? .floating : .normal
        sabitlemeGorunumunuGuncelle()
    }

    private func sabitlemeGorunumunuGuncelle() {
        sabitleButon.contentTintColor = sabitlemeAcik ? .systemOrange : .darkGray
    }

    @objc private func arkayaAtButonaTiklandi() {
        pencere?.miniaturize(nil)
    }

    @objc private func kapatButonaTiklandi() {
        kapatTiklandi?()
    }

    override func mouseDown(with event: NSEvent) {
        pencere?.performDrag(with: event)
    }
}
