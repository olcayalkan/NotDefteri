import AppKit

// MARK: - Kullanıcı tercihleri (UserDefaults ile kalıcı)
//
// Bu dosyadaki değerler çalışma anında değişir ve `UserDefaults`ta saklanır.
// Değişmeyen ölçüler için `Sabitler.swift`e bakın.

/// Seçili temanın `temaListesi` içindeki sırası.
var gTemaIndex: Int = {
    let kayitli = UserDefaults.standard.integer(forKey: "temaIndex")
    return temaListesi.indices.contains(kayitli) ? kayitli : 0
}()

/// Kenar panelin genişliği; sürükle tutamacıyla değiştirilir.
var gKenarPanelGenislik: CGFloat = {
    let kayitli = UserDefaults.standard.double(forKey: "kenarPanelGenislik")
    return kayitli > 0 ? CGFloat(kayitli) : 190
}()

/// İmlecin o anki yazım puntosu (yalnızca yeni yazılacak metin için varsayılan).
/// Kalıcı DEĞİLDİR ve var olan metnin yorumunu etkilemez; her açılışta tabana döner.
var gYaziBoyutu: CGFloat = kTabanPunto

/// Kayıt yokken Ana Sayfa açılır; kapatıldığında eski son-not davranışı korunur.
var gAcilistaAnaSayfa: Bool {
    get { UserDefaults.standard.object(forKey: "acilistaAnaSayfa") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "acilistaAnaSayfa") }
}
