import AppKit

/// Bağımsız NSTextView Markdown yorumlamaz; dosyanın tamamı salt okunur kalır.
final class KodGoruntuleyici: NSViewController {
    private let url: URL
    private let kok: URL
    private let kapat: () -> Void
    private let metin = NSTextView()
    private let durum = NSTextField(labelWithString: "Yükleniyor…")
    private let kopyala = NSButton(title: "Tümünü kopyala", target: nil, action: nil)
    private let finder = NSButton(title: "Finder'da göster", target: nil, action: nil)
    private var nesil: UInt = 0
    private var hamMetin: String?

    init(url: URL, kok: URL, kapat: @escaping () -> Void) {
        self.url = url
        self.kok = kok
        self.kapat = kapat
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        let kaydirma = NSScrollView(frame: NSRect(x: 12, y: 52, width: 696, height: 416))
        kaydirma.autoresizingMask = [.width, .height]
        kaydirma.hasVerticalScroller = true
        kaydirma.hasHorizontalScroller = true
        kaydirma.borderType = .bezelBorder
        metin.frame = NSRect(origin: .zero, size: kaydirma.contentSize)
        metin.isEditable = false
        metin.isSelectable = true
        metin.isRichText = false
        metin.importsGraphics = false
        metin.allowsUndo = false
        metin.isVerticallyResizable = true
        metin.isHorizontallyResizable = true
        metin.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        metin.textContainer?.widthTracksTextView = false
        metin.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        metin.textContainerInset = NSSize(width: 8, height: 8)
        metin.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        metin.backgroundColor = aktifTema.arkaplan
        metin.usesFindBar = true
        kaydirma.documentView = metin
        view.addSubview(kaydirma)
        durum.frame = NSRect(x: 12, y: 20, width: 290, height: 18)
        durum.font = .systemFont(ofSize: 11)
        durum.lineBreakMode = .byTruncatingTail
        view.addSubview(durum)
        kopyala.isEnabled = false
        finder.isHidden = true
        for (dugme, x, en, eylem) in [(kopyala, 314.0, 140.0, #selector(tumunuKopyala)),
                                     (finder, 460.0, 150.0, #selector(finderdaGoster))] {
            dugme.frame = NSRect(x: x, y: 12, width: en, height: 30)
            dugme.autoresizingMask = [.minXMargin]
            dugme.bezelStyle = .rounded
            dugme.target = self
            dugme.action = eylem
            view.addSubview(dugme)
        }
        let kapatDugmesi = NSButton(title: "Kapat", target: self, action: #selector(kapatTiklandi))
        kapatDugmesi.frame = NSRect(x: 618, y: 12, width: 90, height: 30)
        kapatDugmesi.autoresizingMask = [.minXMargin]
        kapatDugmesi.bezelStyle = .rounded
        kapatDugmesi.keyEquivalent = "\u{1b}"
        view.addSubview(kapatDugmesi)
        yukle()
    }

    private func yukle() {
        nesil &+= 1
        let beklenen = nesil, url = url, kok = kok, tema = aktifTema
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let temelRenk = kMetinRenk
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let sonuc = try SayfaDosyalari.oku(url, kok: kok)
                var renkli: NSAttributedString?
                if case .metin(let ham) = sonuc {
                    let depo = NSMutableAttributedString(string: ham, attributes: [.font: font, .foregroundColor: temelRenk])
                    for token in kodVurgula(ham, dil: dilAdiniNormallestir(url.pathExtension)) {
                        depo.addAttribute(.foregroundColor, value: kodRengi(token.tur, tema: tema), range: token.aralik)
                    }
                    renkli = depo.copy() as? NSAttributedString
                }
                let hazir = renkli
                DispatchQueue.main.async {
                    guard let self, self.nesil == beklenen else { return }
                    switch sonuc {
                    case .metin(let ham):
                        self.hamMetin = ham
                        if let hazir { self.metin.textStorage?.setAttributedString(hazir) }
                        self.kopyala.isEnabled = true
                        self.durum.stringValue = "Salt okunur"
                    case .buyuk: self.gosterilemedi("Dosya çok büyük — Finder'da göster")
                    case .ikili: self.gosterilemedi("Metin değil — Finder'da göster")
                    }
                }
            } catch {
                let mesaj = error.localizedDescription
                DispatchQueue.main.async {
                    guard let self, self.nesil == beklenen else { return }
                    self.gosterilemedi(mesaj)
                }
            }
        }
    }

    private func gosterilemedi(_ mesaj: String) {
        metin.string = mesaj
        durum.stringValue = "Görüntülenemedi"
        finder.isHidden = false
    }

    @objc private func tumunuKopyala() {
        guard let hamMetin else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hamMetin, forType: .string)
    }

    @objc private func finderdaGoster() {
        let url = url, kok = kok, beklenen = nesil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sonuc = Result { try SayfaDosyalari.dogrula(url, kok: kok) }
            DispatchQueue.main.async {
                guard let self, self.nesil == beklenen else { return }
                switch sonuc {
                case .success: NSWorkspace.shared.activateFileViewerSelecting([url])
                case .failure(let hata): self.gosterilemedi(hata.localizedDescription)
                }
            }
        }
    }

    @objc private func kapatTiklandi() {
        nesil &+= 1
        kapat()
    }
}
