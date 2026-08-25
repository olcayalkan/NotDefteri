import AppKit

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

        // Görsel HER ZAMAN sayfanın kendi klasörüne yazılmalı ki sayfa taşınınca
        // ya da yeniden adlandırılınca birlikte gitsin. Sayfa henüz diskte
        // yoksa önce onu oluştururuz; aksi hâlde görsel kök klasörde kalıyor
        // ve sayfayla bağı kopuyordu.
        if mevcutDosyaURL == nil {
            sayfayiDiskeAl()
        }
        let hedefKlasor = gorsellerKlasoru(mevcutDosyaURL.map { sayfaKlasoru($0) } ?? notlarKlasoru())

        // Dosya adı bölüm başlığından üretilir ama MUTLAKA temizlenir:
        // Markdown bağı `![](yol)` biçiminde, yoldaki bir ")" bağı erken
        // bitirip görseli kalıcı olarak okunamaz hâle getiriyordu.
        let taban = guvenliDosyaAdi(bolumBasligi ?? "Görsel")
        let hedef = benzersizDosyaYolu(klasor: hedefKlasor, taban: taban, uzanti: "png")

        guard (try? png.write(to: hedef)) != nil else { return nil }

        // Ek, ekrandaki piksel boyutunu değil görselin nokta boyutunu kullanır.
        let noktaBoyutu = NSSize(width: temsil.pixelsWide, height: temsil.pixelsHigh)
        let gercekGorsel = NSImage(size: noktaBoyutu)
        gercekGorsel.addRepresentation(temsil)
        return resimEkiUret(gorsel: gercekGorsel, dosyaURL: hedef,
                            bagYolu: "\(kGorsellerKlasorAdi)/\(hedef.lastPathComponent)")
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
