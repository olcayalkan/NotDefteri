import AppKit
import NotDefteriCekirdek

private let kKodTokenAnahtari = NSAttributedString.Key("kodToken")
private let kodRenklendirmeKuyrugu = DispatchQueue(label: "NotDefteri.kod-renklendirme", qos: .userInitiated)

/// Kod bloğu çerçevesinin üst kenarına oturan küçük şerit: dil etiketi + Kopyala.
/// Eskiden ilk kod satırının üstüne 180×24'lük düğme olarak biniyor, metni örtüyordu.
final class KodBloguAraclari: NSView {
    static let yukseklik: CGFloat = 16
    let etiket = NSTextField(labelWithString: "")
    let dugme = NSButton(title: "Kopyala", target: nil, action: nil)
    var kopyala: (() -> Void)?
    var kimlik: String?
    var aralik = NSRange()
    private var bildirim: DispatchWorkItem?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 90, height: Self.yukseklik))
        wantsLayer = true
        layer?.cornerRadius = 4
        etiket.font = .monospacedSystemFont(ofSize: 9.5, weight: .regular)
        dugme.isBordered = false
        dugme.refusesFirstResponder = true
        dugme.target = self
        dugme.action = #selector(tiklandi)
        dugmeBasliginiYaz("Kopyala")
        addSubview(etiket)
        addSubview(dugme)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) desteklenmiyor") }
    @objc private func tiklandi() { kopyala?() }

    private func dugmeBasliginiYaz(_ baslik: String) {
        dugme.attributedTitle = NSAttributedString(string: baslik, attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: kMetinRenk.withAlphaComponent(0.7)])
        yerlesimiKur()
    }

    /// Genişlik içeriğe göre; sağ kenar sabit kalır ki "Kopyalandı" yazısı şeridi kaydırmasın.
    func yerlesimiKur() {
        let sag = frame.maxX
        etiket.sizeToFit()
        dugme.sizeToFit()
        let etiketEn = etiket.stringValue.isEmpty ? 0 : ceil(etiket.frame.width)
        let dugmeEn = ceil(dugme.frame.width)
        let en = 6 + etiketEn + (etiketEn > 0 ? 6 : 0) + dugmeEn + 4
        etiket.frame = NSRect(x: 6, y: (Self.yukseklik - etiket.frame.height) / 2, width: etiketEn, height: etiket.frame.height)
        dugme.frame = NSRect(x: en - dugmeEn - 4, y: 0, width: dugmeEn, height: Self.yukseklik)
        frame = NSRect(x: sag - en, y: frame.minY, width: en, height: Self.yukseklik)
    }

    func sifirla() {
        bildirim?.cancel()
        kimlik = nil
        isHidden = true
        dugmeBasliginiYaz("Kopyala")
    }

    func kopyalandi() {
        bildirim?.cancel()
        dugmeBasliginiYaz("Kopyalandı")
        let islem = DispatchWorkItem { [weak self] in self?.dugmeBasliginiYaz("Kopyala") }
        bildirim = islem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: islem)
    }
}

extension NotMetinGorunumu {
    func kodBloklariniCiz(_ kirliAlan: NSRect) {
        cerceveliBloklariCiz(kirliAlan, anahtar: kKodBloguAnahtari)
    }

    func kodBloguBasindaSil() -> Bool {
        guard isEditable, let depo = textStorage, depo.length > 0, selectedRange().length == 0 else { return false }
        var aralik = NSRange()
        let konum = min(selectedRange().location, depo.length - 1)
        guard depo.attribute(kKodBloguAnahtari, at: konum, longestEffectiveRange: &aralik,
                             in: NSRange(location: 0, length: depo.length)) != nil,
              selectedRange().location <= aralik.location + blokIsaretiUzunlugu(depo, konum: aralik.location) else { return false }
        let govde = kodBloguGovdesi(depo.attributedSubstring(from: aralik))
        if govde.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blokDuzenle(aralik, yeni: NSAttributedString(string: govde),
                        secim: NSRange(location: aralik.location, length: 0), yazim: [:])
        }
        return true
    }

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
              let depo = textStorage, depo.length > 0, let yerlesim = layoutManager else { kodAraclari.isHidden = true; return }
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
        // Konum çizilen çerçeveden türetilir: ikisi aynı geometriyi paylaşır, araç kutudan
        // kopamaz. Şerit üst kenarın ortasına oturur, kod satırını örtmez.
        guard let cerceve = blokCerceveKaresi(aralik, anahtar: kKodBloguAnahtari) else {
            kodAraclari.isHidden = true; return
        }
        if kodAraclari.kimlik != bilgi["kimlik"] { kodAraclari.sifirla() }
        kodAraclari.kimlik = bilgi["kimlik"]
        kodAraclari.aralik = aralik
        kodAraclari.etiket.stringValue = kodBloguDilEtiketi(bilgi)
        kodAraclari.etiket.textColor = kMetinRenk.withAlphaComponent(0.55)
        kodAraclari.layer?.backgroundColor = aktifTema.arkaplan.cgColor
        // yerlesimiKur sağ kenarı korur: önce sağ kenar çerçevenin 10 pt içine konur.
        kodAraclari.frame.origin = NSPoint(x: cerceve.maxX - 10 - kodAraclari.frame.width,
                                           y: cerceve.minY - KodBloguAraclari.yukseklik / 2)
        kodAraclari.yerlesimiKur()
        guard visibleRect.intersects(kodAraclari.frame) else { kodAraclari.isHidden = true; return }
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

    func kodBlogunuEkle(dil: String, komutAraligi: NSRange) {
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
