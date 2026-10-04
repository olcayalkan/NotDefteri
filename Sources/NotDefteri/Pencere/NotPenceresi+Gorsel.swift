import AppKit
import UniformTypeIdentifiers

// MARK: - NotPenceresi: Görsel ekleme

extension NotPenceresi {

    // MARK: Görsel ekleme

    /// Yapıştırılan/sürüklenen görseli, sayfanın kendi klasöründeki "Görseller"
    /// altına PNG olarak yazar. Dosya adı, görselin eklendiği bölümün başlığıdır
    /// (ör. "Başlık1.png", ikincisi "Başlık1-2.png"); başlık yoksa "Görsel" olur.
    func gorseliDiskeYaz(_ gorsel: NSImage, bolumBasligi: String?) -> ResimEki? {
        guard let tiff = gorsel.tiffRepresentation,
              let temsil = NSBitmapImageRep(data: tiff),
              let png = temsil.representation(using: .png, properties: [:]) else { return nil }

        let hedef = bosGorselYolu(bolumBasligi: bolumBasligi, uzanti: "png")
        guard (try? png.write(to: hedef)) != nil else { return nil }

        // Ek, ekrandaki piksel boyutunu değil görselin nokta boyutunu kullanır.
        let noktaBoyutu = NSSize(width: temsil.pixelsWide, height: temsil.pixelsHigh)
        let gercekGorsel = NSImage(size: noktaBoyutu)
        gercekGorsel.addRepresentation(temsil)
        return resimEkiUret(gorsel: gercekGorsel, dosyaURL: hedef,
                            bagYolu: "\(kGorsellerKlasorAdi)/\(hedef.lastPathComponent)")
    }

    /// Başka bir sayfadan kopyalanan görsel dosyasını BU sayfanın kendi
    /// "Görseller" klasörüne kopyalar ve yeni bir ek üretir.
    ///
    /// Kaynak dosyaya dokunulmaz: özgün sayfa görselini kaybetmesin diye
    /// taşıma değil kopyalama yapılır. Yeniden kodlama da yok — bayt bayt
    /// kopyalandığı için JPEG/HEIC gibi biçimler kalitesini yitirmez.
    func gorseliKopyala(_ kaynak: URL, bolumBasligi: String?) -> ResimEki? {
        guard let hedef = gorselDosyasiniKopyala(kaynak, hedefKlasor: sayfaninGorselKlasoru(), taban: bolumBasligi),
              let gorsel = NSImage(contentsOf: hedef) else { return nil }

        return resimEkiUret(gorsel: gorsel, dosyaURL: hedef,
                            bagYolu: "\(kGorsellerKlasorAdi)/\(hedef.lastPathComponent)")
    }

    /// Başka bir sayfadan kopyalanan içeriği bu sayfaya uygun hâle getirir.
    ///
    /// Markdown, kaynak sayfanın klasörüne göre çözülür (görseller oradan
    /// okunur), sonra her görselin dosyası BU sayfanın klasörüne kopyalanır.
    /// Böylece kaynak sayfa görselini kaybetmez, hedef sayfa da kendi
    /// kopyasına sahip olur — sayfalar taşınınca bağlar kopmaz.
    func kopyalananIcerigiHazirla(markdown: String, kaynakTaban: URL?) -> NSAttributedString? {
        let taban = kaynakTaban ?? notlarKlasoru()
        let icerik = NSMutableAttributedString(attributedString: yapistirmaMarkdownunuCevir(markdown, taban: taban))
        guard icerik.length > 0 else { return nil }

        // Kopyalar önce toplanır, sonra sondan başa uygulanır: aralıklar kaymasın.
        var yenilenecekler: [(NSRange, ResimEki)] = []
        var kopyalanamayan: URL?
        icerik.enumerateAttribute(.attachment, in: NSRange(location: 0, length: icerik.length), options: []) { deger, aralik, durdur in
            guard let eski = deger as? ResimEki, let kaynak = eski.dosyaURL else { return }
            guard let yeni = gorseliKopyala(kaynak, bolumBasligi: nil) else {
                kopyalanamayan = kaynak
                durdur.pointee = true
                return
            }
            yeni.gosterimBoyutu = eski.gosterimBoyutu
            yenilenecekler.append((aralik, yeni))
        }
        if let kaynak = kopyalanamayan {
            let uyari = NSAlert()
            uyari.alertStyle = .critical
            uyari.messageText = "İçerik yapıştırılamadı"
            uyari.informativeText = "\"\(kaynak.lastPathComponent)\" bu sayfanın görsel klasörüne kopyalanamadı. Yapıştırma iptal edildi."
            uyari.addButton(withTitle: "Tamam")
            uyari.runModal()
            return nil
        }
        for (aralik, ek) in yenilenecekler.reversed() {
            let parca = NSMutableAttributedString(attachment: ek)
            parca.addAttribute(.foregroundColor, value: kMetinRenk, range: NSRange(location: 0, length: parca.length))
            icerik.replaceCharacters(in: aralik, with: parca)
        }
        return icerik
    }

    /// Bu sayfanın görsel klasöründe, adı çakışmayan yeni bir dosya yolu.
    ///
    /// Dosya adı bölüm başlığından üretilir ama MUTLAKA temizlenir:
    /// Markdown bağı `![](yol)` biçiminde, yoldaki bir ")" bağı erken
    /// bitirip görseli kalıcı olarak okunamaz hâle getiriyordu.
    private func bosGorselYolu(bolumBasligi: String?, uzanti: String) -> URL {
        let taban = guvenliDosyaAdi(bolumBasligi ?? "Görsel")
        return benzersizDosyaYolu(klasor: sayfaninGorselKlasoru(), taban: taban, uzanti: uzanti)
    }

    /// Bu sayfanın "Görseller" klasörü.
    ///
    /// Görsel HER ZAMAN sayfanın kendi klasörüne yazılmalı ki sayfa taşınınca
    /// ya da yeniden adlandırılınca birlikte gitsin. Sayfa henüz diskte
    /// yoksa önce onu oluştururuz; aksi hâlde görsel kök klasörde kalıyor
    /// ve sayfayla bağı kopuyordu.
    private func sayfaninGorselKlasoru() -> URL {
        if mevcutDosyaURL == nil {
            sayfayiDiskeAl()
        }
        return gorsellerKlasoru(mevcutDosyaURL.map { sayfaKlasoru($0) } ?? notlarKlasoru())
    }

    /// Kaydedilmemiş notu diske alır (görsel eklemeden önce çağrılır).
    ///
    /// Görselin sayfanın kendi klasörüne yazılabilmesi için sayfanın önce
    /// var olması gerekiyor. Ad, varsa ilk satırdan üretilir.
    private func sayfayiDiskeAl() {
        let icerik = metinGorunumu.string
        let taban = icerik.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Yeni Sayfa"
            : otomatikBaslikUret(icerik: icerik)
        let url = benzersizDosyaURL(taban: taban)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        guard (try? "".write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        mevcutDosyaURL = url
        otomatikAdlandirildiMi = true
        baslikEtiketiniGuncelle()
        kenarPaneli.yenile(secili: url)
    }
}
