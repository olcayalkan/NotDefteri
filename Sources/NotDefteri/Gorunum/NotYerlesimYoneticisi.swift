import AppKit
import NotDefteriCekirdek

// MARK: - Tablo zeminini çerçevenin içinde tutan yerleşim yöneticisi

/// Kutu çizgili tablonun satır zeminleri `.backgroundColor` özniteliğiyle çizilemiyor:
/// AppKit satır sonunu sağ kenara, önceki satırdan süren aynı renkli zemini sol kenara
/// kadar boyuyor, yarı saydam dikdörtgenler birbirinin üstüne biniyordu. Zemin burada
/// satır başına bir kez, dış çizgilerin içine çizilir. Seçim ve diğer zeminler de
/// (arama vurgusu gibi) tabloya düştüğünde aynı kutuya kırpılır. Yapılacak kutuları da
/// burada çizilir; font gliflerine bırakılınca iki durum farklı boyutta çıkıyordu.
final class NotYerlesimYoneticisi: NSLayoutManager {
    /// Bir çizim geçişi boyunca tablo kutuları bir kez ölçülür: her satır ayrı bir zemin
    /// çağrısıdır, her çağrıda yeniden ölçmek 30 satırlık tabloda yüzlerce sorgu eder.
    /// Çizim dışında önbellek yoktur; düzenleme eski kutu bırakmaz.
    private var olcumOnbellegi: [Int: TabloOlcusu]?

    /// `kutu` dış çizgilerin içi (kırpma sınırı); `satirlar` tablo satırlarının dikey
    /// kapsamı. Üst/alt çerçeve satırının dikdörtgeni çizginin yarısından taşar; hangi
    /// dikdörtgenin tabloya ait olduğu kutuya değil satırlara bakılarak anlaşılır.
    private struct TabloOlcusu {
        let kutu: NSRect
        let satirlar: ClosedRange<CGFloat>
    }

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        olcumOnbellegi = [:]
        defer { olcumOnbellegi = nil }
        tabloZeminleriniCiz(characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil), koken: origin)
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    }

    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<NSRect>, count rectCount: Int,
                                          forCharacterRange charRange: NSRange, color: NSColor) {
        let koken = firstTextView?.textContainerOrigin ?? .zero
        let tablolar = tabloKutulari(charRange).map(\.olcu)
        guard !tablolar.isEmpty else {
            super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
            return
        }
        var kareler: [NSRect] = []
        for kare in UnsafeBufferPointer(start: rectArray, count: rectCount) {
            guard let tablo = tablolar.first(where: { $0.satirlar.contains(kare.midY - koken.y) }) else {
                kareler.append(kare)
                continue
            }
            let kirpik = kare.intersection(tablo.kutu.offsetBy(dx: koken.x, dy: koken.y))
            if !kirpik.isEmpty { kareler.append(kirpik) }
        }
        guard !kareler.isEmpty else { return }
        kareler.withUnsafeBufferPointer {
            super.fillBackgroundRectArray($0.baseAddress!, count: $0.count, forCharacterRange: charRange, color: color)
        }
    }

    // MARK: Yapılacak kutuları

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let depo = textStorage else { return }
        let karakterler = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        bagEmojileriniCiz(karakterler, koken: origin)
        depo.enumerateAttribute(kBlokIsaretiAnahtari, in: karakterler) { deger, aralik, _ in
            guard deger as? Bool == true, let kutu = yapilacakKutusu(aralik.location) else { return }
            yapilacakKutusunuCiz(kutu.kare.offsetBy(dx: origin.x, dy: origin.y), tamam: kutu.tamam)
        }
    }

    /// Okunur hâldeki sayfa bağının ilk "[" glifi emoji genişliğinde boşluktur; emoji buraya,
    /// bağ adının taban çizgisine çizilir. İmleç bağa girince glif "[" olur, emoji çizilmez.
    private func bagEmojileriniCiz(_ karakterler: NSRange, koken: NSPoint) {
        guard let depo = textStorage else { return }
        let ns = depo.string as NSString
        depo.enumerateAttribute(kSayfaBagiAnahtari, in: karakterler) { deger, aralik, _ in
            guard deger != nil else { return }
            for konum in aralik.location..<NSMaxRange(aralik) where ns.character(at: konum) == 0x5B {
                let glif = glyphIndexForCharacter(at: konum)
                guard glif < numberOfGlyphs, propertyForGlyph(at: glif) == .controlCharacter else { continue }
                let font = konum + 2 < depo.length ? depo.attribute(.font, at: konum + 2, effectiveRange: nil) as? NSFont : nil
                let emoji = NotMetinGorunumu.bagEmojisiMetni(font ?? NSFont.systemFont(ofSize: kTabanPunto))
                let satir = lineFragmentRect(forGlyphAt: glif, effectiveRange: nil)
                let taban = location(forGlyphAt: glif)
                let emojiFontu = emoji.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: kTabanPunto)
                emoji.draw(at: NSPoint(x: koken.x + satir.minX + taban.x,
                                       y: koken.y + satir.minY + taban.y - emojiFontu.ascender))
            }
        }
    }

    /// Yapılacak işaretinin kutusu (metin kabı koordinatları): satırdaki metnin büyük harf
    /// yüksekliğinde, onun ortasında. İşaret değilse ya da katlanmış satırdaysa `nil`.
    func yapilacakKutusu(_ karakter: Int) -> (kare: NSRect, tamam: Bool)? {
        guard let depo = textStorage, karakter < depo.length,
              depo.attribute(kBlokIsaretiAnahtari, at: karakter, effectiveRange: nil) as? Bool == true,
              let blok = MetinBlogu(oznitelik: depo.attribute(kMetinBloguAnahtari, at: karakter, effectiveRange: nil)),
              blok.tur == .yapilacak else { return nil }
        let glif = glyphIndexForCharacter(at: karakter)
        guard glif < numberOfGlyphs, propertyForGlyph(at: glif) != .null else { return nil }
        var isaret = NSRange()
        _ = depo.attribute(kBlokIsaretiAnahtari, at: karakter, longestEffectiveRange: &isaret,
                           in: NSRange(location: 0, length: depo.length))
        // Boş görevde işaretten sonra satır sonu gelir; o da metnin fontunu taşır.
        let font = NSMaxRange(isaret) < depo.length
            ? depo.attribute(.font, at: NSMaxRange(isaret), effectiveRange: nil) as? NSFont : nil
        let metinFontu = font ?? NSFont.systemFont(ofSize: kTabanPunto)
        let satir = lineFragmentRect(forGlyphAt: glif, effectiveRange: nil)
        let taban = location(forGlyphAt: glif)
        let boyut = (metinFontu.capHeight * 1.25).rounded()
        // Boş görevde satırın taban çizgisi küçük işaretten gelir; kutu, metin yazıldığında
        // olacağı taban çizgisine göre konur ki yazınca yerinden oynamasın.
        let orta = satir.minY + max(taban.y, metinFontu.ascender) - metinFontu.capHeight / 2
        return (NSRect(x: satir.minX + taban.x + 0.5, y: orta - boyut / 2, width: boyut, height: boyut), blok.tamamlandi)
    }

    /// Açık görev koyu çerçeve, tamamlanan görev yeşil dolu kutuda beyaz tik: iki durum aynı boyutta.
    private func yapilacakKutusunuCiz(_ kare: NSRect, tamam: Bool) {
        let kutu = NSBezierPath(roundedRect: kare.insetBy(dx: 0.7, dy: 0.7), xRadius: kare.width * 0.22, yRadius: kare.width * 0.22)
        guard tamam else {
            kMetinRenk.withAlphaComponent(0.78).setStroke()
            kutu.lineWidth = 1.4
            kutu.stroke()
            return
        }
        tamamlananGorevRengi().setFill()
        kutu.fill()
        let tik = NSBezierPath()
        tik.move(to: NSPoint(x: kare.minX + kare.width * 0.26, y: kare.minY + kare.height * 0.53))
        tik.line(to: NSPoint(x: kare.minX + kare.width * 0.43, y: kare.minY + kare.height * 0.70))
        tik.line(to: NSPoint(x: kare.minX + kare.width * 0.75, y: kare.minY + kare.height * 0.32))
        tik.lineWidth = max(1.4, kare.width * 0.13)
        tik.lineCapStyle = .round
        tik.lineJoinStyle = .round
        NSColor.white.setStroke()
        tik.stroke()
    }

    // MARK: Zemin

    /// Başlık belirgin, gövde satırları dönüşümlü; çerçeve satırları gövde tonundadır ki
    /// bant ile çizgi arasında boşluk kalmasın.
    private func tabloZemini(_ tur: String?) -> NSColor {
        switch tur {
        case TabloSatiriTuru.baslik.rawValue: return kMetinRenk.withAlphaComponent(0.20)
        case TabloSatiriTuru.govdeAlternatif.rawValue: return kMetinRenk.withAlphaComponent(0.035)
        default: return kMetinRenk.withAlphaComponent(0.075)
        }
    }

    private func tabloZeminleriniCiz(_ aralik: NSRange, koken: NSPoint) {
        guard let depo = textStorage else { return }
        let ns = depo.string as NSString
        for (tablo, olcu) in tabloKutulari(aralik) {
            let kutu = olcu.kutu
            var konum = tablo.location
            while konum < NSMaxRange(tablo) {
                let satir = ns.lineRange(for: NSRange(location: konum, length: 0))
                konum = NSMaxRange(satir)
                let glif = glyphIndexForCharacter(at: satir.location)
                guard glif < numberOfGlyphs else { continue }
                let parca = lineFragmentRect(forGlyphAt: glif, effectiveRange: nil)
                let bant = NSRect(x: kutu.minX, y: parca.minY, width: kutu.width, height: parca.height).intersection(kutu)
                guard !bant.isEmpty else { continue }
                tabloZemini(depo.attribute(kTabloSatiriAnahtari, at: satir.location, effectiveRange: nil) as? String).setFill()
                bant.offsetBy(dx: koken.x, dy: koken.y).fill(using: .sourceOver)
            }
        }
    }

    // MARK: Ölçüm

    /// Aralığa değen tabloların tam aralığı ve metin kabı koordinatlarındaki ölçüsü.
    private func tabloKutulari(_ aralik: NSRange) -> [(aralik: NSRange, olcu: TabloOlcusu)] {
        guard let depo = textStorage else { return [] }
        let tumu = NSRange(location: 0, length: depo.length)
        var sonuc: [(aralik: NSRange, olcu: TabloOlcusu)] = [], gorulen = Set<Int>()
        depo.enumerateAttribute(kTabloGorselAnahtari, in: NSIntersectionRange(aralik, tumu)) { deger, alt, _ in
            guard deger != nil else { return }
            var tablo = NSRange()
            _ = depo.attribute(kTabloGorselAnahtari, at: alt.location, longestEffectiveRange: &tablo, in: tumu)
            guard gorulen.insert(tablo.location).inserted else { return }
            guard let olcu = olcumOnbellegi?[tablo.location] ?? tabloOlcusu(tablo) else { return }
            olcumOnbellegi?[tablo.location] = olcu
            sonuc.append((tablo, olcu))
        }
        return sonuc
    }

    /// Dış çizgilerin kapladığı kutu: "┌" sol üst, "┘" sağ alt köşe. Kutu çizgileri glifin
    /// ortasından geçtiği için glif sınırı yarım karakter dışarıda kalır; köşelerin
    /// mürekkep sınırı kullanılır. Bozulmuş çerçevede glif sınırına düşülür.
    private func tabloOlcusu(_ tablo: NSRange) -> TabloOlcusu? {
        guard let depo = textStorage, let kapsayici = textContainers.first, tablo.length > 0 else { return nil }
        let ns = depo.string as NSString
        var son = NSMaxRange(tablo) - 1
        while son > tablo.location, [10, 13].contains(ns.character(at: son)) { son -= 1 }
        let glifler = glyphRange(forCharacterRange: NSRange(location: tablo.location, length: son + 1 - tablo.location),
                                 actualCharacterRange: nil)
        guard glifler.length > 0, NSMaxRange(glifler) <= numberOfGlyphs else { return nil }
        let ust = lineFragmentRect(forGlyphAt: glifler.location, effectiveRange: nil).minY
        let alt = lineFragmentRect(forGlyphAt: NSMaxRange(glifler) - 1, effectiveRange: nil).maxY
        guard alt > ust else { return nil }
        if ns.character(at: tablo.location) == 0x250C, ns.character(at: son) == 0x2518,
           let solUst = murekkep(tablo.location), let sagAlt = murekkep(son) {
            let kutu = NSRect(x: solUst.minX, y: solUst.minY, width: sagAlt.maxX - solUst.minX, height: sagAlt.maxY - solUst.minY)
            return TabloOlcusu(kutu: kutu, satirlar: ust...alt)
        }
        return TabloOlcusu(kutu: boundingRect(forGlyphRange: glifler, in: kapsayici), satirlar: ust...alt)
    }

    /// Glifin mürekkep sınırı (metin kabı koordinatları, y aşağı doğru).
    private func murekkep(_ karakter: Int) -> NSRect? {
        guard let depo = textStorage else { return nil }
        // Kutu karakterleri yedek fonttan gelir; doğru font için öznitelikler düzeltilmiş olmalı.
        depo.ensureAttributesAreFixed(in: NSRange(location: karakter, length: 1))
        guard let font = depo.attribute(.font, at: karakter, effectiveRange: nil) as? NSFont else { return nil }
        let glif = glyphIndexForCharacter(at: karakter)
        guard glif < numberOfGlyphs else { return nil }
        let kutu = font.boundingRect(forCGGlyph: cgGlyph(at: glif))
        guard kutu.width > 0, kutu.height > 0 else { return nil }
        let parca = lineFragmentRect(forGlyphAt: glif, effectiveRange: nil)
        let taban = location(forGlyphAt: glif)
        return NSRect(x: parca.minX + taban.x + kutu.minX, y: parca.minY + taban.y - kutu.maxY,
                      width: kutu.width, height: kutu.height)
    }
}
