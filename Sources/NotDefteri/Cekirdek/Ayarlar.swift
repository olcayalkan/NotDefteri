import Foundation

// MARK: - Kullanıcı tercihleri (UserDefaults ile kalıcı)
//
// Bu dosyadaki değerler çalışma anında değişir ve `UserDefaults`ta saklanır.
// Değişmeyen ölçüler için `Sabitler.swift`e bakın.

/// Tek ayar deposu. NOTDEFTERI_KOK varken ayrı bir alan kullanılır; tema/son açılanlar gerçek ayarlara yazılmaz.
package let gAyarlar: UserDefaults = {
    if ProcessInfo.processInfo.environment["NOTDEFTERI_KOK"]?.hasPrefix("/") == true,
       let test = UserDefaults(suiteName: "NotDefteri.test") { return test }
    return .standard
}()

/// Seçili temanın kayıtlı indeksi; geçerliliğini platformun görünümü denetler.
/// Sürüm 2'de Terminal teması ikinci sıraya eklendi. Eski 1...3 seçimleri aynı
/// kağıt temasını göstermeye devam etsin diye yalnızca bir kez ileri taşınır.
package var gTemaIndex: Int = {
    temaSeciminiYukle(gAyarlar)
}()

/// Bozuk/elle değiştirilmiş eski indeksler taşma yaratmadan Sepya'ya döner.
/// Ayrı depo parametresi göçün gerçek kullanıcı ayarlarına dokunmadan sınanmasını sağlar.
package func temaSeciminiYukle(_ ayarlar: UserDefaults) -> Int {
    let kayitli = ayarlar.integer(forKey: "temaIndex")
    guard ayarlar.integer(forKey: "temaDuzeniSurumu") < 2 else {
        return (0...4).contains(kayitli) ? kayitli : 0
    }
    let tasinmis = (1...3).contains(kayitli) ? kayitli + 1 : 0
    ayarlar.set(tasinmis, forKey: "temaIndex")
    ayarlar.set(2, forKey: "temaDuzeniSurumu")
    return tasinmis
}

/// Kenar panelin genişliği; sürükle tutamacıyla değiştirilir.
package var gKenarPanelGenislik: CGFloat = {
    let kayitli = gAyarlar.double(forKey: "kenarPanelGenislik")
    return kayitli > 0 ? CGFloat(kayitli) : 190
}()

/// İmlecin o anki yazım puntosu (yalnızca yeni yazılacak metin için varsayılan).
/// Kalıcı DEĞİLDİR ve var olan metnin yorumunu etkilemez; her açılışta tabana döner.
package var gYaziBoyutu: CGFloat = kTabanPunto

/// Kayıt yokken Ana Sayfa açılır; kapatıldığında eski son-not davranışı korunur.
package var gAcilistaAnaSayfa: Bool {
    get { gAyarlar.object(forKey: "acilistaAnaSayfa") as? Bool ?? true }
    set { gAyarlar.set(newValue, forKey: "acilistaAnaSayfa") }
}
