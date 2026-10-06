import AppKit
import NotDefteriCekirdek

extension KenarPaneli {
    /// Dal taşınması seyrek bir işlem; yalnızca önbellekte etkilenen hedefi olan dosyalar okunur.
    func dalBaglantilariniGuncelle(eskiKlasor: URL, yeniKlasor: URL, eskiIcerik: URL?, yeniIcerik: URL?) {
        let sonuc = sayfaBaglantilari.daliGuncelle(eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor,
            eskiIcerik: eskiIcerik, yeniIcerik: yeniIcerik, notlar: tumNotlar,
            onbellek: icerikOnbellek, favoriler: favoriler)
        tumNotlar = sonuc.notlar
        icerikOnbellek = sonuc.onbellek
        sayfaIndeksiDegisti?()
        for url in tumNotlar {
            if let metin = sonuc.guncellenenMetinler[url] { notIceriginiGuncelle(url, metin: metin) }
        }
        let hedefler = sonuc.hedefler
        let hatalar = sonuc.hatalar
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
