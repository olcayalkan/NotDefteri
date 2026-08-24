import AppKit

// MARK: - Görsel yapıştırma/sürükleme kabul eden metin görünümü

final class NotMetinGorunumu: NSTextView {

    /// Panodan gelen görseli diske yazıp ek üretmesi için pencereye sorar.
    /// İkinci parametre, görselin eklendiği bölümün başlığı (varsa).
    var gorselEklenecek: ((NSImage, String?) -> ResimEki?)?

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if let gorsel = panodanGorsel(pboard), let ek = gorselEklenecek?(gorsel, bulunanBolumBasligi()) {
            ekiEkle(ek)
            return true
        }
        return super.readSelection(from: pboard, type: type)
    }

    /// İmlecin bulunduğu yerden yukarı doğru en yakın başlık satırının metni.
    /// Görsel dosyasını o bölümün adıyla kaydetmek için kullanılır.
    private func bulunanBolumBasligi() -> String? {
        guard let metinDeposu = textStorage, metinDeposu.length > 0 else { return nil }
        let ns = metinDeposu.string as NSString
        var aralik = ns.paragraphRange(for: NSRange(location: min(selectedRange().location, ns.length - 1), length: 0))
        while true {
            if aralik.length > 0,
               metinDeposu.attribute(kBaslikSeviyesiAnahtari, at: aralik.location, effectiveRange: nil) != nil {
                let baslik = ns.substring(with: aralik).trimmingCharacters(in: .whitespacesAndNewlines)
                if !baslik.isEmpty { return baslik }
            }
            guard aralik.location > 0 else { return nil }
            aralik = ns.paragraphRange(for: NSRange(location: aralik.location - 1, length: 0))
        }
    }

    private func panodanGorsel(_ pano: NSPasteboard) -> NSImage? {
        // Ekran görüntüleri ve kopyalanan görseller doğrudan pano verisi olarak gelir.
        if let gorsel = NSImage(pasteboard: pano), gorsel.size.width > 0 { return gorsel }
        // Finder'dan sürüklenen dosyalar.
        if let urller = pano.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let ilk = urller.first,
           ["png", "jpg", "jpeg", "gif", "heic", "tiff"].contains(ilk.pathExtension.lowercased()) {
            return NSImage(contentsOf: ilk)
        }
        return nil
    }

    private func ekiEkle(_ ek: ResimEki) {
        let aralik = selectedRange()
        let ns = (textStorage?.string ?? "") as NSString

        // Görsel kendi satırında (blok) dursun: aynı satırı yazıyla paylaşınca
        // satır yüksekliği görsel kadar olur ve yanında kocaman boşluk oluşur.
        let satirBasindaMi = aralik.location == 0 || ns.character(at: aralik.location - 1) == 10  // "\n"
        let satirSonundaMi = NSMaxRange(aralik) >= ns.length || ns.character(at: NSMaxRange(aralik)) == 10

        // Görsel ve çevresindeki satır sonları normal metin biçiminde olsun (başlık değil).
        let duzOznitelik: [NSAttributedString.Key: Any] = [.font: varsayilanFont(), .foregroundColor: kMetinRenk]

        let eklenecek = NSMutableAttributedString()
        if !satirBasindaMi { eklenecek.append(NSAttributedString(string: "\n", attributes: duzOznitelik)) }
        let gorselAralikBasi = eklenecek.length
        eklenecek.append(NSAttributedString(attachment: ek))
        eklenecek.addAttribute(.foregroundColor, value: kMetinRenk, range: NSRange(location: gorselAralikBasi, length: 1))
        if !satirSonundaMi { eklenecek.append(NSAttributedString(string: "\n", attributes: duzOznitelik)) }

        guard shouldChangeText(in: aralik, replacementString: eklenecek.string) else { return }
        textStorage?.replaceCharacters(in: aralik, with: eklenecek)
        didChangeText()
        // İmleci görselden hemen sonraya al ve yazımın normal biçimde sürmesini sağla.
        setSelectedRange(NSRange(location: aralik.location + gorselAralikBasi + 1, length: 0))
        typingAttributes = duzOznitelik
    }
}
