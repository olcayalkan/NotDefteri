import AppKit
import NotDefteriCekirdek

/// Odağı editörde tutar; düğmeler metin seçimini değiştirmez.
final class YuzerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Görünüm paneli (lazy var) tutar; panel görünümü yalnızca görünürken tutar, döngü gizlenince kırılır.
    private weak var gorunum: NSView?

    init(gorunum: NSView) {
        self.gorunum = gorunum
        super.init(contentRect: gorunum.bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        hasShadow = true
        hidesOnDeactivate = true
        backgroundColor = aktifTema.kenarPanel
    }

    func goster(_ kare: NSRect, ustunde: Bool, pencere: NSWindow) {
        backgroundColor = aktifTema.kenarPanel
        let alan = pencere.screen?.visibleFrame ?? pencere.frame
        guard let gorunum else { return }
        let boyut = gorunum.frame.size
        if contentView !== gorunum { contentView = gorunum }
        let y = ustunde ? kare.maxY + 5 : kare.minY - boyut.height - 5
        setFrame(NSRect(x: min(max(kare.minX, alan.minX), max(alan.minX, alan.maxX - boyut.width)),
                        y: min(max(y, alan.minY), max(alan.minY, alan.maxY - boyut.height)),
                        width: boyut.width, height: boyut.height), display: true)
        if parent !== pencere {
            parent?.removeChildWindow(self)
            pencere.addChildWindow(self, ordered: .above)
        }
        orderFront(nil)
    }

    func gizle() {
        orderOut(nil)
        parent?.removeChildWindow(self)
        contentView = nil
    }
}

final class BlokMenusu: NSView {
    enum Komut: Int, CaseIterable {
        case baslik1, baslik2, baslik3, madde, numarali, yapilacak, alinti, kod, ayirici, sayfa, gorsel
        case uyari, uyariGri, uyariMavi, uyariSari, uyariKirmizi, uyariYesil
        var ad: String {
            ["Başlık 1", "Başlık 2", "Başlık 3", "Madde listesi", "Numaralı liste", "Yapılacak", "Alıntı", "Kod bloğu", "Ayırıcı", "Alt sayfa", "Görsel",
             "Uyarı kutusu", "Uyarı: Gri", "Uyarı: Mavi", "Uyarı: Sarı", "Uyarı: Kırmızı", "Uyarı: Yeşil"][rawValue]
        }
        var kisayollar: [String] {
            switch self {
            case .baslik1: return ["1", "b1"]
            case .baslik2: return ["2", "b2"]
            case .baslik3: return ["3", "b3"]
            case .sayfa: return ["page", "sayfa"]
            default: return []
            }
        }
    }

    var secildi: ((Komut) -> Void)?
    var dilSecildi: ((String) -> Void)?
    private(set) var dilSecimi = false
    private var dilSorgusu = ""
    private var dilEslesmeleri: [String] = []
    private let dilBasligi = NSTextField(labelWithString: "")
    private let diller = ["", "swift", "go", "python", "javascript", "typescript", "bash", "json", "sql", "html", "css"]
    private var eslesmeler = Komut.allCases
    private var secili = 0
    private var dugmeler: [NSButton] = []
    private lazy var panel = YuzerPanel(gorunum: self)
    var gorunur: Bool { panel.isVisible }

    init() { super.init(frame: NSRect(x: 0, y: 0, width: 208, height: 1)) }
    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }

    func filtrele(_ sorgu: String) -> Bool {
        let sade = aramaIcinSadelestir(sorgu)
        let yeni = Komut.allCases.filter {
            sade.isEmpty || aramaIcinSadelestir($0.ad).contains(sade) || $0.kisayollar.contains { $0.hasPrefix(sade) }
        }
        guard !yeni.isEmpty else { gizle(); return false }
        if yeni != eslesmeler || dugmeler.isEmpty {
            eslesmeler = yeni
            secili = 0
            dugmeleriHazirla(eslesmeler.map(\.ad))
        }
        vurguyuGuncelle()
        return true
    }

    private func dugmeleriHazirla(_ adlar: [String]) {
        dugmeler.forEach { $0.removeFromSuperview() }
        dugmeler = adlar.enumerated().map { sira, ad in
            let dugme = NSButton(title: ad, target: self, action: #selector(tiklandi(_:)))
            dugme.tag = sira
            dugme.isBordered = false
            dugme.alignment = .left
            dugme.refusesFirstResponder = true
            dugme.font = NSFont.systemFont(ofSize: 13)
            dugme.frame = NSRect(x: 6, y: CGFloat(adlar.count - sira - 1) * 26 + 5, width: 196, height: 26)
            addSubview(dugme)
            return dugme
        }
        setFrameSize(NSSize(width: 208, height: CGFloat(adlar.count) * 26 + (dilSecimi ? 38 : 10)))
    }

    func dilleriGoster() {
        dilSecimi = true
        dilSorgusu = ""
        addSubview(dilBasligi)
        dilleriFiltrele()
    }

    func dilSorgusunuYaz(_ metin: String?, sil: Bool = false) {
        if sil { if !dilSorgusu.isEmpty { dilSorgusu.removeLast() } }
        else if let metin, metin.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) {
            dilSorgusu += metin
        }
        dilleriFiltrele()
        let eski = panel.frame
        panel.setFrame(NSRect(x: eski.minX, y: eski.maxY - frame.height, width: frame.width, height: frame.height), display: true)
    }

    private func dilleriFiltrele() {
        let sorgu = dilSorgusu.lowercased()
        dilEslesmeleri = diller.filter {
            sorgu.isEmpty || $0.contains(sorgu) || dilAdiniNormallestir(sorgu) == $0
        }
        secili = 0
        dugmeleriHazirla(dilEslesmeleri.map { $0.isEmpty ? "Dil yok" : $0 })
        dilBasligi.stringValue = sorgu.isEmpty ? "Dil: yazarak filtrele" : "Dil: " + dilSorgusu
        dilBasligi.font = .systemFont(ofSize: 12)
        dilBasligi.textColor = kMetinRenk
        dilBasligi.frame = NSRect(x: 10, y: frame.height - 28, width: 188, height: 20)
        vurguyuGuncelle()
    }

    func gezin(_ yon: Int) {
        let sayi = dilSecimi ? dilEslesmeleri.count : eslesmeler.count
        guard sayi > 0 else { return }
        secili = (secili + yon + sayi) % sayi
        vurguyuGuncelle()
    }
    func sec() {
        if dilSecimi {
            guard dilEslesmeleri.indices.contains(secili) else { return }
            dilSecildi?(dilEslesmeleri[secili])
        } else { secildi?(eslesmeler[secili]) }
    }
    @objc private func tiklandi(_ sender: NSButton) { secili = sender.tag; sec() }
    private func vurguyuGuncelle() {
        for (sira, dugme) in dugmeler.enumerated() {
            dugme.contentTintColor = kMetinRenk
            dugme.wantsLayer = true
            dugme.layer?.cornerRadius = 4
            dugme.layer?.backgroundColor = (sira == secili ? secimVurguRengi() : aktifTema.kenarPanel).cgColor
        }
    }
    func goster(_ kare: NSRect, pencere: NSWindow) { vurguyuGuncelle(); panel.goster(kare, ustunde: false, pencere: pencere) }
    func gizle() {
        panel.gizle()
        // Aynı komut listesine dönüşte dil düğmeleri yeniden kurulsun.
        if dilSecimi {
            dugmeler.forEach { $0.removeFromSuperview() }
            dugmeler.removeAll()
        }
        dilSecimi = false
        dilSecildi = nil
        dilBasligi.removeFromSuperview()
    }
}

extension NotMetinGorunumu {
    func yuzerGorunumleriGizle() {
        sayfaBulucusu.gizle()
        blokMenusu.gizle()
        secimCubugu.gizle()
        kodAraclari.sifirla()
    }

    func secimCubugunuGuncelle() {
        guard let pencere = window, pencere.isKeyWindow, pencere.firstResponder === self,
              selectedRange().length > 0, !hasMarkedText() else { secimCubugu.gizle(); return }
        blokMenusu.gizle()
        let aralik = NSRange(location: selectedRange().location, length: 1)
        let kare = firstRect(forCharacterRange: aralik, actualRange: nil)
        let yerel = convert(pencere.convertFromScreen(kare), from: nil)
        guard visibleRect.intersects(yerel) else { secimCubugu.gizle(); return }
        secimCubugu.goster(kare, pencere: pencere)
    }

    func blokMenusunuGuncelle() {
        guard let depo = textStorage, let pencere = window, pencere.isKeyWindow,
              pencere.firstResponder === self, selectedRange().length == 0, !hasMarkedText() else {
            blokMenusu.gizle(); slashAraligi = nil; return
        }
        if blokMenusu.dilSecimi { return }
        let imlec = selectedRange().location
        let ns = depo.mutableString
        let paragraf = ns.paragraphRange(for: NSRange(location: imlec, length: 0))
        let kapsam = NSRange(location: paragraf.location, length: imlec - paragraf.location)
        let slash = ns.range(of: "/", options: .backwards, range: kapsam)
        guard slash.location != NSNotFound, slash.location != kapatilanSlashKonumu,
              slash.location == paragraf.location + blokIsaretiUzunlugu(depo, konum: paragraf.location) || ns.rangeOfCharacter(from: .whitespaces, range: NSRange(location: slash.location - 1, length: 1)).location != NSNotFound,
              depo.attribute(kKodBloguAnahtari, at: slash.location, effectiveRange: nil) == nil,
              depo.attribute(kSatirIciKodAnahtari, at: slash.location, effectiveRange: nil) == nil else {
            blokMenusu.gizle(); slashAraligi = nil; return
        }
        let sorgu = ns.substring(with: NSRange(location: slash.location + 1, length: imlec - slash.location - 1))
        guard sorgu.rangeOfCharacter(from: .whitespacesAndNewlines) == nil, blokMenusu.filtrele(sorgu) else {
            blokMenusu.gizle(); slashAraligi = nil; return
        }
        slashAraligi = NSRange(location: slash.location, length: imlec - slash.location)
        blokMenusu.secildi = { [weak self] komut in
            guard let self, let aralik = self.slashAraligi else { return }
            self.blokMenusu.gizle()
            self.slashAraligi = nil
            self.kapatilanSlashKonumu = aralik.location
            if komut == .kod { self.kodDilSeciminiBaslat(aralik) }
            else { (self.window as? NotPenceresi)?.blokMenusuKomutunuCalistir(komut, aralik: aralik) }
        }
        blokMenusu.goster(imlecEkranKaresi(imlec), pencere: pencere)
    }
}
