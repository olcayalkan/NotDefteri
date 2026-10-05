import CGtk
import Foundation

/// Belge NSString (UTF-16) konumuyla, GtkTextBuffer ise Unicode karakteriyle sayar.
/// UTF-16 ↔ iter çevirisi GtkKoprusu'ndadır; burada yalnızca onun üstünde aralık
/// yardımcıları ve UTF-16 → karakter sayısı (iter ilerletmek için) durur.
enum LinuxMetinDonusumu {
    typealias Tampon = UnsafeMutablePointer<GtkTextBuffer>

    static func iter(_ tampon: Tampon, _ konum: Int) -> GtkTextIter { GtkKoprusu.iter(tampon, utf16: konum) }

    static func konum(_ iter: GtkTextIter) -> Int { GtkKoprusu.utf16(iter) }

    static func iterler(_ tampon: Tampon, _ aralik: NSRange) -> (GtkTextIter, GtkTextIter) {
        let bas = iter(tampon, aralik.location)
        var son = bas
        gtk_text_iter_forward_chars(&son, Int32(karakterSayisi(tampon, bas: bas, utf16: aralik.length)))
        return (bas, son)
    }

    static func aralik(_ bas: GtkTextIter, _ son: GtkTextIter) -> NSRange {
        var b = bas, s = son
        // get_slice, child anchor'ı U+FFFC olarak verir; belgedeki görsel karakteriyle eşleşir.
        guard let ham = gtk_text_iter_get_slice(&b, &s) else { return NSRange(location: konum(bas), length: 0) }
        defer { g_free(ham) }
        return NSRange(location: konum(bas), length: (String(cString: ham) as NSString).length)
    }

    static func secim(_ tampon: Tampon) -> NSRange {
        var bas = GtkTextIter(), son = GtkTextIter()
        gtk_text_buffer_get_selection_bounds(tampon, &bas, &son)
        return aralik(bas, son)
    }

    static func secimiAyarla(_ tampon: Tampon, _ aralik: NSRange) {
        var (bas, son) = iterler(tampon, aralik)
        gtk_text_buffer_select_range(tampon, &son, &bas) // insert = son: imleç seçimin sonunda.
    }

    /// `bas`tan başlayıp `utf16` birim tutan metnin Unicode karakter sayısı.
    static func karakterSayisi(_ tampon: Tampon, bas: GtkTextIter, utf16: Int) -> Int {
        var tarama = bas
        var kalan = utf16, sayi = 0
        while kalan > 0, gtk_text_iter_is_end(&tarama) == 0 {
            kalan -= gtk_text_iter_get_char(&tarama) > 0xFFFF ? 2 : 1
            sayi += 1
            gtk_text_iter_forward_char(&tarama)
        }
        return sayi
    }

    /// Tampona girmeden NSString aralığının karakter sayısı (çizimde iter ilerletmek için).
    static func karakterSayisi(_ metin: NSString, _ aralik: NSRange) -> Int {
        (metin.substring(with: aralik) as String).unicodeScalars.count
    }
}
