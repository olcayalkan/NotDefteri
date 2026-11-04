import AppKit
import NotDefteriCekirdek

// MARK: - NotPenceresi: Yapıştırma komutları

extension NotPenceresi {

    /// ⌘V zaten notun biçimine uydurarak yapıştırır (bkz. `YapistirmaBicimlendirme`).
    /// Bu komut (⇧⌘V) tek seferlik kaçış yoludur: kaynak biçimi korunur.
    @objc func hamYapistirKomutu(_ sender: Any?) {
        makeFirstResponder(metinGorunumu)
        metinGorunumu.hamYapistir()
    }
}
