import AppKit
import NotDefteriCekirdek

struct AnaSayfaKarti {
    let url: URL
    let tarih: Date?
}

/// Sabit bölümlerden oluşur; kartlar yatay, sayfanın bütünü dikey kayar.
final class AnaSayfa: NSScrollView {
    var sayfaAc: ((URL) -> Void)?
    var yapilacagaGit: ((BekleyenYapilacak) -> Void)?
    var yapilacagiTamamla: ((BekleyenYapilacak) -> Void)?
    var yeniSayfa: (() -> Void)?
    var gunlukNot: (() -> Void)?
    var sablonSec: (() -> Void)?

    private let belge = AnaSayfaBelgesi()
    private let bolumler = NSStackView()
    private var sonlar: [AnaSayfaKarti] = []
    private var yapilacaklar: [BekleyenYapilacak] = []
    private var metinRengi: NSColor {
        let renk = aktifTema.arkaplan.usingColorSpace(.genericRGB)
        let parlaklik = (renk?.redComponent ?? 1) * 0.2126 + (renk?.greenComponent ?? 1) * 0.7152 + (renk?.blueComponent ?? 1) * 0.0722
        return parlaklik < 0.45 ? .white : .black
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        hasVerticalScroller = true
        kagitKaydiriciKullan()
        drawsBackground = false
        borderType = .noBorder
        documentView = belge
        belge.translatesAutoresizingMaskIntoConstraints = false
        bolumler.orientation = .vertical
        bolumler.alignment = .leading
        bolumler.distribution = .fill
        bolumler.spacing = 14
        bolumler.translatesAutoresizingMaskIntoConstraints = false
        belge.addSubview(bolumler)
        NSLayoutConstraint.activate([
            belge.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            belge.heightAnchor.constraint(greaterThanOrEqualTo: contentView.heightAnchor),
            bolumler.topAnchor.constraint(equalTo: belge.topAnchor, constant: 28),
            bolumler.leadingAnchor.constraint(equalTo: belge.leadingAnchor, constant: 24),
            bolumler.trailingAnchor.constraint(equalTo: belge.trailingAnchor, constant: -24),
            bolumler.bottomAnchor.constraint(lessThanOrEqualTo: belge.bottomAnchor, constant: -28)
        ])
        let yukseklik = belge.heightAnchor.constraint(equalTo: bolumler.heightAnchor, constant: 56)
        yukseklik.priority = .defaultHigh
        yukseklik.isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }

    func guncelle(sonlar: [AnaSayfaKarti], yapilacaklar: [BekleyenYapilacak]) {
        self.sonlar = sonlar
        self.yapilacaklar = yapilacaklar
        temayiUygula()
    }

    func basaDon() {
        layoutSubtreeIfNeeded()
        contentView.scroll(to: .zero)
        reflectScrolledClipView(contentView)
    }

    func temayiUygula() {
        let kaydirmaKonumu = contentView.bounds.origin
        wantsLayer = true
        layer?.backgroundColor = aktifTema.arkaplan.cgColor
        for gorunum in bolumler.arrangedSubviews {
            bolumler.removeArrangedSubview(gorunum)
            gorunum.removeFromSuperview()
        }
        let saat = Calendar.current.component(.hour, from: Date())
        let selam = saat < 12 ? "Günaydın" : saat < 18 ? "İyi günler" : "İyi akşamlar"
        bolumler.addArrangedSubview(etiket(selam, boyut: 28, kalin: true))
        let tarih = DateFormatter()
        tarih.locale = Locale(identifier: "tr_TR")
        tarih.dateFormat = "d MMMM yyyy, EEEE"
        bolumler.addArrangedSubview(etiket(tarih.string(from: Date()), boyut: 13, soluk: true))
        kartBolumu("Son açılanlar", kartlar: sonlar)
        bolumBasligi("Bekleyen yapılacaklar")
        if yapilacaklar.isEmpty {
            bolumler.addArrangedSubview(etiket("Bekleyen yapılacak yok.", soluk: true))
        } else {
            var sonURL: URL?
            for gorev in yapilacaklar.prefix(20) {
                if sonURL != gorev.url {
                    let grup = etiket(sayfaAdi(gorev.url), kalin: true)
                    grup.toolTip = sayfaBagYolu(gorev.url)
                    bolumler.addArrangedSubview(grup)
                    sonURL = gorev.url
                }
                let satir = NSStackView()
                satir.orientation = .horizontal
                satir.spacing = 6
                let kutu = AnaSayfaDugmesi("", eylem: { [weak self] in self?.yapilacagiTamamla?(gorev) })
                kutu.setButtonType(.switch)
                kutu.contentTintColor = metinRengi
                kutu.setAccessibilityLabel("Yapılacağı tamamla: \(gorev.metin)")
                kutu.widthAnchor.constraint(equalToConstant: 22).isActive = true
                let ad = gorev.metin.isEmpty ? "(Boş yapılacak)" : gorev.metin
                let bag = dugme(ad) { [weak self] in self?.yapilacagaGit?(gorev) }
                bag.alignment = .left
                bag.lineBreakMode = .byTruncatingTail
                bag.toolTip = gorev.metin
                bag.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                satir.addArrangedSubview(kutu)
                satir.addArrangedSubview(bag)
                satir.translatesAutoresizingMaskIntoConstraints = false
                bolumler.addArrangedSubview(satir)
                satir.widthAnchor.constraint(equalTo: bolumler.widthAnchor).isActive = true
                bag.widthAnchor.constraint(equalTo: satir.widthAnchor, constant: -28).isActive = true
            }
            if yapilacaklar.count > 20 {
                bolumler.addArrangedSubview(etiket("+\(yapilacaklar.count - 20) daha", soluk: true))
            }
        }
        bolumBasligi("Hızlı eylemler")
        // Dar pencerelerde de üç eylem erişilebilir kalır.
        bolumler.addArrangedSubview(dugme("Yeni sayfa") { [weak self] in self?.yeniSayfa?() })
        bolumler.addArrangedSubview(dugme("Günlük not") { [weak self] in self?.gunlukNot?() })
        bolumler.addArrangedSubview(dugme("Şablondan…") { [weak self] in self?.sablonSec?() })
        layoutSubtreeIfNeeded()
        contentView.scroll(to: kaydirmaKonumu)
        reflectScrolledClipView(contentView)
    }

    private func etiket(_ metin: String, boyut: CGFloat = 13, kalin: Bool = false, soluk: Bool = false) -> NSTextField {
        let alan = NSTextField(labelWithString: metin)
        alan.font = .systemFont(ofSize: boyut, weight: kalin ? .semibold : .regular)
        alan.textColor = metinRengi.withAlphaComponent(soluk ? 0.6 : 0.9)
        alan.lineBreakMode = .byTruncatingTail
        alan.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return alan
    }

    private func dugme(_ ad: String, eylem: @escaping () -> Void) -> AnaSayfaDugmesi {
        let dugme = AnaSayfaDugmesi(ad, eylem: eylem)
        dugme.isBordered = false
        dugme.attributedTitle = NSAttributedString(string: ad, attributes: [
            .font: NSFont.systemFont(ofSize: 13), .foregroundColor: metinRengi.withAlphaComponent(0.9)])
        return dugme
    }

    private func bolumBasligi(_ ad: String) {
        let bosluk = NSView()
        bosluk.heightAnchor.constraint(equalToConstant: 8).isActive = true
        bolumler.addArrangedSubview(bosluk)
        bolumler.addArrangedSubview(etiket(ad, boyut: 16, kalin: true))
    }

    private func kartBolumu(_ ad: String, kartlar: [AnaSayfaKarti]) {
        bolumBasligi(ad)
        guard !kartlar.isEmpty else {
            bolumler.addArrangedSubview(etiket("Henüz açılmış sayfa yok.", soluk: true))
            return
        }
        let kaydirma = NSScrollView()
        kaydirma.drawsBackground = false
        kaydirma.hasHorizontalScroller = true
        kaydirma.hasVerticalScroller = false
        kaydirma.translatesAutoresizingMaskIntoConstraints = false
        let serit = NSView(frame: NSRect(x: 0, y: 0, width: CGFloat(kartlar.count) * 188 - 12, height: 126))
        let goreliTarih = RelativeDateTimeFormatter()
        goreliTarih.locale = Locale(identifier: "tr_TR")
        goreliTarih.unitsStyle = .full
        for (sira, veri) in kartlar.enumerated() {
            let kart = dugme("") { [weak self] in self?.sayfaAc?(veri.url) }
            kart.frame = NSRect(x: CGFloat(sira) * 188, y: 12, width: 176, height: 114)
            kart.wantsLayer = true
            kart.layer?.cornerRadius = 8
            kart.layer?.masksToBounds = true
            kart.layer?.backgroundColor = aktifTema.kenarPanel.cgColor
            kart.setAccessibilityLabel("Sayfayı aç: \(sayfaAdi(veri.url))")
            kart.toolTip = sayfaBagYolu(veri.url)
            let renkSeridi = NSView(frame: NSRect(x: 0, y: 76, width: 176, height: 38))
            renkSeridi.wantsLayer = true
            renkSeridi.layer?.backgroundColor = aktifTema.baslikCubugu.cgColor
            kart.addSubview(renkSeridi)
            let baslik = etiket(sayfaAdi(veri.url), kalin: true)
            baslik.frame = NSRect(x: 12, y: 43, width: 152, height: 20)
            kart.addSubview(baslik)
            let zaman = etiket(veri.tarih.map { goreliTarih.localizedString(for: $0, relativeTo: Date()) } ?? "Daha önce açıldı", boyut: 11, soluk: true)
            zaman.frame = NSRect(x: 12, y: 16, width: 152, height: 16)
            kart.addSubview(zaman)
            serit.addSubview(kart)
        }
        kaydirma.documentView = serit
        bolumler.addArrangedSubview(kaydirma)
        NSLayoutConstraint.activate([
            kaydirma.widthAnchor.constraint(equalTo: bolumler.widthAnchor),
            kaydirma.heightAnchor.constraint(equalToConstant: 140)
        ])
    }
}

private final class AnaSayfaBelgesi: NSView {
    override var isFlipped: Bool { true }
}

private final class AnaSayfaDugmesi: NSButton {
    private let eylem: () -> Void
    init(_ ad: String, eylem: @escaping () -> Void) {
        self.eylem = eylem
        super.init(frame: .zero)
        title = ad
        target = self
        action = #selector(tiklandi)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }
    @objc private func tiklandi() { eylem() }
}
