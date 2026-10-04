import AppKit

extension NotPenceresi {
    @objc func hizliBulucuKomutu(_ gonderen: Any?) { hizliBulucuyuAc() }

    func hizliBulucuyuAc(sorgu: String = "") {
        metinGorunumu.yuzerGorunumleriGizle()
        kenarPaneli.icerikOnbelleginiIste()
        hizliBulucu.ara = { [weak self] in self?.kenarPaneli.sayfaBaglantilari.ara($0) ?? [] }
        hizliBulucu.secildi = { [weak self] sayfa in
            guard let self else { return }
            self.notuAc(sayfa.url)
            self.makeFirstResponder(self.metinGorunumu)
        }
        hizliBulucu.gosterMerkezde(self, sorgu: sorgu)
    }

    func sayfaBaginiAc(_ hedef: String) {
        let hedef = hedef.trimmingCharacters(in: .whitespaces)
        let baglantilar = kenarPaneli.sayfaBaglantilari
        if let url = baglantilar.coz(hedef) { notuAc(url); return }
        if baglantilar.belirsizMi(hedef) { hizliBulucuyuAc(sorgu: hedef); return }
        let olusturmaYolu = hedef.hasPrefix("./") ? String(hedef.dropFirst(2)) : hedef
        let parcalar = olusturmaYolu.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parcalar.isEmpty, parcalar.allSatisfy({ sayfaAdiGecerliMi($0) && !$0.contains("[") && !$0.contains("]") }) else {
            let uyari = NSAlert()
            uyari.messageText = "Bu bağlantının sayfa adı kullanılamaz"
            uyari.informativeText = hedef
            uyari.runModal()
            return
        }
        let uyari = NSAlert()
        uyari.messageText = "\"\(hedef)\" sayfası oluşturulsun mu?"
        uyari.addButton(withTitle: "Oluştur")
        uyari.addButton(withTitle: "Vazgeç")
        guard uyari.runModal() == .alertFirstButtonReturn,
              mevcutNotuKaybolmayacakSekildeKaydet() else { return }
        let klasor = parcalar.reduce(notlarKlasoru()) { $0.appendingPathComponent($1, isDirectory: true) }
        let url = klasor.appendingPathComponent(kIcerikDosyaAdi)
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
                try "".write(to: url, atomically: true, encoding: .utf8)
            }
            notuAc(url)
            makeFirstResponder(metinGorunumu)
        } catch {
            let hata = NSAlert(error: error)
            hata.messageText = "Sayfa oluşturulamadı"
            hata.runModal()
        }
    }

    func geriBaglantilariTazele() {
        geriBagZamanlayicisi?.invalidate()
        geriBagZamanlayicisi = nil
        let sayfalar = mevcutDosyaURL.map { kenarPaneli.baglantiVerenler($0) } ?? []
        icindekiler.baglantiVerenleriGuncelle(sayfalar)
    }

    /// İçerik önbelleği açılışta ve başarılı kayıtta değişir; yazım bildirimi bu yola gelmez.
    func geriBaglantilariTazelemeyiPlanla() {
        geriBagZamanlayicisi?.invalidate()
        let zamanlayici = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in self?.geriBaglantilariTazele() }
        geriBagZamanlayicisi = zamanlayici
        RunLoop.main.add(zamanlayici, forMode: .common)
    }

    func acikNotunBaglariniYenidenYaz(_ hedefler: [String: String]) {
        // Taşıma ve yeniden adlandırma, ana sayfada gizlenen editörü de günceller.
        let duzenlenebilirdi = metinGorunumu.isEditable
        metinGorunumu.isEditable = true
        defer { metinGorunumu.isEditable = duzenlenebilirdi }
        metinGorunumu.sayfaBaglariniYenidenYaz(hedefler)
        metinGorunumu.sayfaBaglariniBoya()
        if kaydedici.duzenlendiMi, let url = mevcutDosyaURL { kaydetURLe(url, panelYenile: false) }
        geriBaglantilariTazelemeyiPlanla()
    }
}
