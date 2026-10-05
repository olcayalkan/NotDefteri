import AppKit
import NotDefteriCekirdek

extension KenarPaneli {
    /// Dal taşınması seyrek bir işlem; yalnızca önbellekte etkilenen hedefi olan dosyalar okunur.
    func dalBaglantilariniGuncelle(eskiKlasor: URL, yeniKlasor: URL, eskiIcerik: URL?, yeniIcerik: URL?) {
        func donustur(_ url: URL) -> URL {
            if url == eskiIcerik, let yeniIcerik { return yeniIcerik }
            if url.path.hasPrefix(eskiKlasor.path + "/") {
                return URL(fileURLWithPath: yeniKlasor.path + url.path.dropFirst(eskiKlasor.path.count))
            }
            return url
        }
        let yeniIndeks = SayfaBaglantilari()
        yeniIndeks.guncelle(sayfaBaglantilari.sayfalar.map { SayfaSecenegi(url: donustur($0.url)) })
        let hedefler = sayfaBaglantilari.yenidenYazimlar(yeni: yeniIndeks, donustur: donustur)
        tumNotlar = tumNotlar.map(donustur)
        icerikOnbellek = Dictionary(icerikOnbellek.map { (donustur($0.key), $0.value) }, uniquingKeysWith: { ilk, _ in ilk })
        favoriler.yolGuncelle(donustur)
        sayfaBaglantilari.yollariTasi(donustur)
        sayfaIndeksiniGuncelle()
        var hatalar: [String] = []
        for url in tumNotlar {
            if let girdi = icerikOnbellek[url], girdi.tarih == degistirilmeTarihi(url), !girdi.bagHedefleri.contains(where: {
                hedefler[$0.trimmingCharacters(in: .whitespaces)] != nil
            }) { continue }
            do {
                let metin = try String(contentsOf: url, encoding: .utf8)
                let sayfa = sayfaUstbilgisiniAyir(metin)
                // Üstbilgiye dokunulmaz; her dosya atomik yazılır, hata sessizce yutulmaz.
                let yeni = sayfa.bilgi.kaynak + sayfaBaglariniDegistir(sayfa.govde, hedefler: hedefler)
                if yeni != metin { try yeni.write(to: url, atomically: true, encoding: .utf8) }
                notIceriginiGuncelle(url, metin: yeni)
            } catch {
                hatalar.append("\(sayfaBagYolu(url)): \(error.localizedDescription)")
            }
        }
        baglarYenidenYazildi?(hedefler)
        baglantiOnbellegiDegisti?()
        if !hatalar.isEmpty {
            let uyari = NSAlert()
            uyari.messageText = "Bazı sayfa bağlantıları güncellenemedi"
            uyari.informativeText = "Sayfa taşındı. Aşağıdaki dosyaların eski bağlantıları korundu:\n" + hatalar.joined(separator: "\n")
            uyari.runModal()
        }
    }
}
