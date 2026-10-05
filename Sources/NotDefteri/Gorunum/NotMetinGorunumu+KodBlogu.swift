import AppKit
import NotDefteriCekirdek

private let kKodTokenAnahtari = NSAttributedString.Key("kodToken")
private let kodRenklendirmeKuyrugu = DispatchQueue(label: "NotDefteri.kod-renklendirme", qos: .userInitiated)

final class KodBloguAraclari: NSView {
    let etiket = NSTextField(labelWithString: "")
    let dugme = NSButton(title: "Kopyala", target: nil, action: nil)
    var kopyala: (() -> Void)?
    var kimlik: String?
    var aralik = NSRange()
    private var bildirim: DispatchWorkItem?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        wantsLayer = true
        layer?.cornerRadius = 5
        etiket.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        etiket.alignment = .right
        etiket.frame = NSRect(x: 4, y: 4, width: 86, height: 16)
        dugme.frame = NSRect(x: 94, y: 0, width: 86, height: 24)
        dugme.font = .systemFont(ofSize: 11)
        dugme.bezelStyle = .rounded
        dugme.refusesFirstResponder = true
        dugme.target = self
        dugme.action = #selector(tiklandi)
        addSubview(etiket)
        addSubview(dugme)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }
    @objc private func tiklandi() { kopyala?() }

    func sifirla() {
        bildirim?.cancel()
        kimlik = nil
        isHidden = true
        dugme.title = "Kopyala"
    }

    func kopyalandi() {
        bildirim?.cancel()
        dugme.title = "Kopyalandı"
        let islem = DispatchWorkItem { [weak self] in self?.dugme.title = "Kopyala" }
        bildirim = islem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: islem)
    }
}

extension NotMetinGorunumu {
    func kodDurumunuSifirla() {
        kodZamanlayicisi?.invalidate()
        kodZamanlayicisi = nil
        kodSurumu += 1
        kodBekleyenAraliklar.removeAll()
        kodAraclari.sifirla()
        blokMenusu.gizle()
        if let depo = textStorage {
            layoutManager?.removeTemporaryAttribute(kKodTokenAnahtari, forCharacterRange: NSRange(location: 0, length: depo.length))
        }
    }

    @objc func kodDeposuDegisti(_ bildirim: Notification) {
        guard let depo = bildirim.object as? NSTextStorage,
              !yaziOlcegiUygulaniyor, !baglarGuncelleniyor else { return }
        let degisen = depo.editedRange
        guard degisen.location != NSNotFound else { return }
        let fark = depo.editedMask.contains(.editedCharacters) ? depo.changeInLength : 0
        let eskiSon = NSMaxRange(degisen) - fark
        // Debounce sırasında biriken blok konumları sonraki ekleme/silmelerle kayar.
        kodBekleyenAraliklar = kodBekleyenAraliklar.map { aralik in
            let bas = aralik.location < degisen.location ? aralik.location : aralik.location >= eskiSon ? aralik.location + fark : degisen.location
            let son = NSMaxRange(aralik) < degisen.location ? NSMaxRange(aralik) : NSMaxRange(aralik) >= eskiSon ? NSMaxRange(aralik) + fark : NSMaxRange(degisen)
            return NSRange(location: max(0, bas), length: max(0, son - bas))
        }
        // Yalnızca silme sonrası boş aralıkta sınırın iki yanı denetlenir.
        let bas = degisen.length == 0 ? max(0, degisen.location - 1) : degisen.location
        let son = min(depo.length, NSMaxRange(degisen) + (degisen.length == 0 ? 1 : 0))
        kodBekleyenAraliklar.append(NSRange(location: bas, length: max(0, son - bas)))
        kodAraclari.sifirla()
        kodRenklendirmeyiPlanla()
    }

    func kodRenklendirmeyiPlanla() {
        kodSurumu += 1
        kodZamanlayicisi?.invalidate()
        let zamanlayici = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in self?.kodRenkleriniGuncelle() }
        kodZamanlayicisi = zamanlayici
        RunLoop.main.add(zamanlayici, forMode: .common)
    }

    private func kodRenkleriniGuncelle() {
        guard let depo = textStorage else { return }
        kodZamanlayicisi = nil
        let surum = kodSurumu
        let tumu = NSRange(location: 0, length: depo.length)
        let kirli = kodBekleyenAraliklar.map { NSIntersectionRange($0, tumu) }
        let bloklar = kodBloklariniHazirla(depo, araliklar: kirli)
        // Yalnızca düzenlenen blok kopyalanır; regex ana iş parçacığını meşgul etmez.
        kodRenklendirmeKuyrugu.async { [weak self] in
            let renklenen = bloklar.map { (aralik: $0.0, tokenlar: kodVurgula($0.1, dil: $0.2)) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.kodSurumu == surum, let yerlesim = self.layoutManager else { return }
                self.kodTokenlariniUygula(renklenen, kirli: kirli, yerlesim: yerlesim)
            }
        }
    }

    private func kodBloklariniHazirla(_ depo: NSTextStorage, araliklar kirli: [NSRange]) -> [(NSRange, String, String)] {
        let tumu = NSRange(location: 0, length: depo.length)
        var bloklar: [(NSRange, String, String)] = []
        var gorulen = Set<Int>()
        for aralik in kirli where aralik.length > 0 {
            var konum = aralik.location
            while konum < NSMaxRange(aralik) {
                var blok = NSRange()
                let bilgi = depo.attribute(kKodBloguAnahtari, at: konum, longestEffectiveRange: &blok, in: tumu) as? [String: String]
                if let bilgi, gorulen.insert(blok.location).inserted {
                    bloklar.append((blok, depo.mutableString.substring(with: blok), kodBloguDilEtiketi(bilgi)))
                }
                konum = NSMaxRange(blok)
            }
        }
        return bloklar
    }

    private func kodTokenlariniUygula(_ renklenen: [(aralik: NSRange, tokenlar: [(aralik: NSRange, tur: KodTokenTuru)])],
                                      kirli: [NSRange], yerlesim: NSLayoutManager) {
        for aralik in kirli + renklenen.map(\.aralik) where aralik.length > 0 {
            yerlesim.removeTemporaryAttribute(kKodTokenAnahtari, forCharacterRange: aralik)
        }
        for blok in renklenen {
            for token in blok.tokenlar {
                let aralik = NSRange(location: blok.aralik.location + token.aralik.location, length: token.aralik.length)
                yerlesim.addTemporaryAttribute(kKodTokenAnahtari, value: token.tur, forCharacterRange: aralik)
            }
            yerlesim.invalidateDisplay(forCharacterRange: blok.aralik)
        }
        kodBekleyenAraliklar.removeAll()
    }

    func kodAraclariniGuncelle(noktada nokta: NSPoint?) {
        guard let nokta, isEditable, !isHidden, visibleRect.contains(nokta),
              let depo = textStorage, depo.length > 0, let yerlesim = layoutManager,
              let kapsayici = textContainer else { kodAraclari.isHidden = true; return }
        let aracta = !kodAraclari.isHidden && kodAraclari.frame.contains(nokta)
        let konum = min(aracta ? kodAraclari.aralik.location : characterIndexForInsertion(at: nokta), depo.length - 1)
        var aralik = NSRange()
        guard let bilgi = depo.attribute(kKodBloguAnahtari, at: konum, longestEffectiveRange: &aralik,
                                         in: NSRange(location: 0, length: depo.length)) as? [String: String] else {
            kodAraclari.isHidden = true; return
        }
        guard !katlama.gizliMi(konum), !katlama.gizliMi(aralik.location) else {
            kodAraclari.isHidden = true; return
        }
        let glif = yerlesim.glyphIndexForCharacter(at: konum)
        let satir = yerlesim.lineFragmentRect(forGlyphAt: glif, effectiveRange: nil)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        guard aracta || satir.contains(nokta) else { kodAraclari.isHidden = true; return }
        let ilkGlif = yerlesim.glyphIndexForCharacter(at: aralik.location)
        let ilkSatir = yerlesim.lineFragmentRect(forGlyphAt: ilkGlif, effectiveRange: nil)
        let kare = NSRect(x: textContainerOrigin.x + kapsayici.size.width - kodAraclari.frame.width - 6,
                          y: textContainerOrigin.y + ilkSatir.minY, width: kodAraclari.frame.width, height: 24)
        guard visibleRect.intersects(kare) else { kodAraclari.isHidden = true; return }
        if kodAraclari.kimlik != bilgi["kimlik"] { kodAraclari.sifirla() }
        kodAraclari.kimlik = bilgi["kimlik"]
        kodAraclari.aralik = aralik
        kodAraclari.etiket.stringValue = kodBloguDilEtiketi(bilgi)
        kodAraclari.etiket.textColor = kMetinRenk
        kodAraclari.layer?.backgroundColor = aktifTema.kenarPanel.cgColor
        kodAraclari.frame = kare
        kodAraclari.isHidden = false
    }

    func kodBlogunuKopyala() {
        guard let depo = textStorage, kodAraclari.aralik.length > 0,
              kodAraclari.aralik.location < depo.length, NSMaxRange(kodAraclari.aralik) <= depo.length,
              let bilgi = depo.attribute(kKodBloguAnahtari, at: kodAraclari.aralik.location, effectiveRange: nil) as? [String: String],
              bilgi["kimlik"] == kodAraclari.kimlik else { return }
        let metin = kodBloguGovdesi(depo.attributedSubstring(from: kodAraclari.aralik))
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(metin, forType: .string) { kodAraclari.kopyalandi() }
    }

    func kodDilSeciminiBaslat(_ aralik: NSRange) {
        guard let pencere = window else { return }
        blokMenusu.dilleriGoster()
        blokMenusu.dilSecildi = { [weak self] dil in
            guard let self else { return }
            self.blokMenusu.gizle()
            self.kodBlogunuEkle(dil: dil, komutAraligi: aralik)
        }
        blokMenusu.goster(imlecEkranKaresi(aralik.location), pencere: pencere)
    }

    private func kodBlogunuEkle(dil: String, komutAraligi: NSRange) {
        guard isEditable, let depo = textStorage, NSMaxRange(komutAraligi) <= depo.length else { return }
        let paragraf = depo.mutableString.paragraphRange(for: NSRange(location: komutAraligi.location, length: 0))
        guard NSMaxRange(komutAraligi) <= NSMaxRange(paragraf) else { return }
        let yeni = NSMutableAttributedString(attributedString: depo.attributedSubstring(from: paragraf))
        yeni.deleteCharacters(in: NSRange(location: komutAraligi.location - paragraf.location, length: komutAraligi.length))
        var isaretler: [NSRange] = []
        yeni.enumerateAttribute(kBlokIsaretiAnahtari, in: NSRange(location: 0, length: yeni.length)) { deger, alt, _ in
            if deger as? Bool == true { isaretler.append(alt) }
        }
        for alt in isaretler.reversed() { yeni.deleteCharacters(in: alt) }
        let yazim = kodBloguOznitelikleri(kodBloguSinirlari(acilis: "```" + dil + "\n", kapanis: "```\n"))
        // Kod gövdesi inline Markdown özniteliklerini devralmaz.
        yeni.setAttributes(yazim, range: NSRange(location: 0, length: yeni.length))
        var isaret = yazim
        isaret[kBlokIsaretiAnahtari] = true
        yeni.insert(NSAttributedString(string: "\u{200B}", attributes: isaret), at: 0)
        blokDuzenle(paragraf, yeni: yeni, secim: NSRange(location: paragraf.location + 1, length: 0), yazim: yazim)
    }
}

// Bağlantı boyaması foregroundColor'ı temizlese de kod tokenı geçici depoda kalır.
extension NotMetinGorunumu: NSLayoutManagerDelegate {
    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldUseTemporaryAttributes attrs: [NSAttributedString.Key: Any],
                       forDrawingToScreen toScreen: Bool, atCharacterIndex charIndex: Int,
                       effectiveRange effectiveCharRange: NSRangePointer?) -> [NSAttributedString.Key: Any]? {
        guard toScreen else { return nil }
        guard let tur = attrs[kKodTokenAnahtari] as? KodTokenTuru else { return attrs }
        var sonuc = attrs
        sonuc[.foregroundColor] = kodRengi(tur, tema: aktifTema)
        return sonuc
    }
}
