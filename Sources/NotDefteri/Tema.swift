import AppKit

// MARK: - Tema

struct Tema {
    let ad: String
    let arkaplan: NSColor
    let baslikCubugu: NSColor
    let kenarPanel: NSColor
}

let temaListesi: [Tema] = [
    Tema(ad: "Sepya",
         arkaplan: NSColor(calibratedRed: 0.84, green: 0.81, blue: 0.73, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.78, green: 0.74, blue: 0.65, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.80, green: 0.77, blue: 0.69, alpha: 1.0)),
    Tema(ad: "Yeşilimsi Kağıt",
         arkaplan: NSColor(calibratedRed: 0.79, green: 0.83, blue: 0.76, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.72, green: 0.77, blue: 0.70, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.75, green: 0.80, blue: 0.73, alpha: 1.0)),
    Tema(ad: "Gri Kağıt",
         arkaplan: NSColor(calibratedRed: 0.80, green: 0.80, blue: 0.80, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.73, green: 0.73, blue: 0.73, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.76, green: 0.76, blue: 0.76, alpha: 1.0)),
    Tema(ad: "Krem",
         arkaplan: NSColor(calibratedRed: 0.86, green: 0.83, blue: 0.76, alpha: 1.0),
         baslikCubugu: NSColor(calibratedRed: 0.80, green: 0.76, blue: 0.67, alpha: 1.0),
         kenarPanel: NSColor(calibratedRed: 0.82, green: 0.79, blue: 0.71, alpha: 1.0)),
]

var gTemaIndex: Int = {
    let kayitli = UserDefaults.standard.integer(forKey: "temaIndex")
    return temaListesi.indices.contains(kayitli) ? kayitli : 0
}()

var aktifTema: Tema { temaListesi[gTemaIndex] }

extension NSColor {
    /// Rengi belirtilen miktar kadar koyulaştırır (0-1 arası).
    func koyulastir(_ miktar: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.genericRGB) else { return self }
        return NSColor(calibratedRed: max(rgb.redComponent - miktar, 0),
                        green: max(rgb.greenComponent - miktar, 0),
                        blue: max(rgb.blueComponent - miktar, 0),
                        alpha: rgb.alphaComponent)
    }
}

/// Kenar paneldeki, üzerinde çalışılan (seçili) notun dış kaplama rengi: panel renginin koyusu.
func secimVurguRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.14) }
/// Arama kutusunun, panelden ayrışması için biraz koyulaştırılmış rengi.
func aramaKutuRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.07) }
/// Arama kutusuna odaklanıldığında kullanılan, biraz daha koyu vurgu rengi.
func aramaOdakRengi() -> NSColor { aktifTema.kenarPanel.koyulastir(0.16) }

/// Bir SF Symbol'ü verilen renkle (varsayılan tonlama/gölge olmadan) yeniden boyar.
func renklendirilmisSembol(_ ad: String, renk: NSColor, boyut: CGFloat = 12) -> NSImage? {
    guard let taban = NSImage(systemSymbolName: ad, accessibilityDescription: nil) else { return nil }
    let yapilandirma = NSImage.SymbolConfiguration(pointSize: boyut, weight: .regular)
    guard let yapilandirilmis = taban.withSymbolConfiguration(yapilandirma) else { return nil }
    let sonuc = NSImage(size: yapilandirilmis.size)
    sonuc.lockFocus()
    yapilandirilmis.draw(at: .zero, from: NSRect(origin: .zero, size: yapilandirilmis.size), operation: .sourceOver, fraction: 1.0)
    renk.set()
    NSRect(origin: .zero, size: yapilandirilmis.size).fill(using: .sourceAtop)
    sonuc.unlockFocus()
    sonuc.isTemplate = false
    return sonuc
}

/// Türkçe karakter/büyük-küçük harf duyarsız arama için metni sadeleştirir
/// (ör. "İ"/"I"/"ı"/"i" birbiriyle ve "ö"/"ü"/"ş"/"ç"/"ğ" sade karşılıklarıyla eşleşir).
///
/// Noktalı/noktasız i ailesi önce tek harfe indirgenir. Aksi hâlde
/// `.diacriticInsensitive` "İ"nin noktasını silip "I" yapıyor, ardından
/// tr_TR küçültmesi onu "ı"ya çeviriyordu; sonuçta "istanbul" araması
/// "İstanbul" başlıklı notu bulamıyordu.
func aramaIcinSadelestir(_ metin: String) -> String {
    var sade = metin
    for harf in ["İ", "I", "ı"] {
        sade = sade.replacingOccurrences(of: harf, with: "i")
    }
    return sade.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
}

let kMetinRenk = NSColor.black
var gKenarPanelGenislik: CGFloat = {
    let kayitli = UserDefaults.standard.double(forKey: "kenarPanelGenislik")
    return kayitli > 0 ? CGFloat(kayitli) : 190
}()
let kKenarPanelMinGenislik: CGFloat = 140
let kKenarPanelMaksGenislik: CGFloat = 360
let kBaslikYuksekligi: CGFloat = 34
let kOtomatikKayitAraligi: TimeInterval = 5
let kMinYaziBoyutu: CGFloat = 10
let kMaksYaziBoyutu: CGFloat = 28

/// Sabit taban punto. Etiketsiz metnin ve başlıkların ölçüsü buna göre belirlenir;
/// hiçbir zaman değişmez, böylece kaydedilen puntolar yeniden açışta/derlemede kaymaz.
let kTabanPunto: CGFloat = 14

/// İmlecin o anki yazım puntosu (yalnızca yeni yazılacak metin için varsayılan).
/// Kalıcı DEĞİLDİR ve var olan metnin yorumunu etkilemez; her açılışta tabana döner.
var gYaziBoyutu: CGFloat = kTabanPunto
