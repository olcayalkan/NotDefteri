import AppKit
import NotDefteriCekirdek

// MARK: - Yerleşim yöneticisi

/// Yapılacak kutuları ve okunur sayfa bağının 📄 emojisi burada çizilir; font gliflerine
/// bırakılınca iki durumdaki kutular farklı boyutta çıkıyordu.
final class NotYerlesimYoneticisi: NSLayoutManager {
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
}
