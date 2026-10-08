import Foundation

// Belge sözleşmesi: değerler yalnızca String, Bool, Int, Double, URL ve bunların
// Foundation'a köprülenebilen sözlükleridir (tek istisna: MarkdownKaynagi.oznitelikDegeri). Eksik Bool false, eksik punto ölçeği 1'dir.
// Görünüm fontu, rengi, eki ve paragraf stili platform adaptörüne aittir.
package let kBaslikSeviyesiAnahtari = NSAttributedString.Key("baslikSeviyesi") // Int: 1...3
package let kKalinAnahtari = NSAttributedString.Key("kalin") // Bool; başlığın kalın görünümünden bağımsız
package let kItalikAnahtari = NSAttributedString.Key("italik") // Bool
package let kUstuCiziliAnahtari = NSAttributedString.Key("ustuCizili") // Bool; tamamlanan görevden bağımsız
package let kSatirIciKodAnahtari = NSAttributedString.Key("satirIciKod") // Bool
package let kVurguAnahtari = NSAttributedString.Key("vurgu") // Bool
package let kBaglantiAnahtari = NSAttributedString.Key("baglantiURL") // URL
package let kSayfaBagiAnahtari = NSAttributedString.Key("sayfaBagi") // String: [[hedef]] içindeki hedef
package let kCiplakBagAnahtari = NSAttributedString.Key("ciplakBag") // Bool
package let kPuntoOlcegiAnahtari = NSAttributedString.Key("puntoOlcegi") // Double: kayıt puntosu / kTabanPunto

// [String: Any]: yol (String, özgün göreli yol), dosyaURL (URL, çözülmüş kaynak),
// genislik/yukseklik (Double, 1...10000; ikisi de yoksa doğal boyut adaptörde çözülür).
// U+FFFC üzerinde taşınır. Codec doğrulaması ve gösterim boyutu platformun işidir.
package let kGorselAnahtari = NSAttributedString.Key("gorsel")

// [String: Any]: tur (String: madde/numarali/yapilacak/alinti/ayirici/uyari),
// seviye/numara (Int), tamamlandi/devam (Bool), emoji/renk/uyariKimligi (String),
// kaynakOnEk (isteğe bağlı String). MetinBlogu bu sözlüğün okuma/yazma yardımcısıdır.
package let kMetinBloguAnahtari = NSAttributedString.Key("metinBlogu")
package let kUyariKutusuAnahtari = NSAttributedString.Key("uyariKutusu") // String: ortak uyarı kimliği
package let kBlokKimligiAnahtari = NSAttributedString.Key("blokKimligi") // String: kod/uyarı blok kimliği

// [String: Any]: ilkSatirGirintisi, govdeGirintisi, sekmeAraligi,
// enAzSatirYuksekligi, paragrafBoslugu (önce/sonra), isaretEnAzGenisligi,
// isaretSonuBoslugu (Double); numaraMetni (String). Numaralı listede adaptör
// max(isaretEnAzGenisligi, ölçülen numaraMetni + isaretSonuBoslugu) kullanır;
// farkı govdeGirintisi'ne ekler. Tek sol sekme durağı gövde girintisindedir.
package let kParagrafGeometrisiAnahtari = NSAttributedString.Key("paragrafGeometrisi")
package let kKodBloguAnahtari = NSAttributedString.Key("kodBlogu") // [String: String]: acilis, kapanis, kimlik
package let kKodBloguDiliAnahtari = NSAttributedString.Key("kodBloguDili") // String
package let kMarkdownKaynakAnahtari = NSAttributedString.Key("markdownKaynak") // MarkdownKaynagi
package let kBlokIsaretiAnahtari = NSAttributedString.Key("blokIsareti") // Bool: görünen/görünmez önek; yazılmaz
package let kBosKodSatiriAnahtari = NSAttributedString.Key("bosKodSatiri") // Bool: boş kod satırı; yazılmaz
package let kKacisliKoseParantezAnahtari = NSAttributedString.Key("kacisliKoseParantez") // Bool: literal [

package func anlamsalGorselBoyutuGecerliMi(en: Double, boy: Double) -> Bool {
    en.isFinite && boy.isFinite && (1...10_000).contains(en) && (1...10_000).contains(boy)
}

/// Paragrafın özgün Markdown yazılışı ve okunduğu andaki kanonik karşılığı.
package struct MarkdownKaynagi: Equatable {
    package let metin: String
    package let kanonik: String

    package init(metin: String, kanonik: String) {
        self.metin = metin
        self.kanonik = kanonik
    }

    /// Depoya yazılacak değer. macOS'ta sözlük olamaz: NSDictionary.hash eleman sayısıdır ve
    /// AppKit öznitelik sözlüklerini hash ile tekilleştirdiği için satır başına farklı sözlük
    /// her satırı aynı kovaya düşürüp büyük not açmayı O(n²) yapıyordu. Linux'ta (corelibs)
    /// ise NSObject alt sınıfı öznitelik değeri CFRunArray karşılaştırmasında çöküyor.
    package var oznitelikDegeri: Any {
        #if os(macOS)
        MarkdownKaynakNesnesi(self)
        #else
        ["metin": metin, "kanonik": kanonik]
        #endif
    }

    package init?(oznitelik: Any?) {
        #if os(macOS)
        guard let nesne = oznitelik as? MarkdownKaynakNesnesi else { return nil }
        self = nesne.kaynak
        #else
        guard let sozluk = oznitelik as? [String: String], let metin = sozluk["metin"],
              let kanonik = sozluk["kanonik"] else { return nil }
        self.init(metin: metin, kanonik: kanonik)
        #endif
    }
}

#if os(macOS)
private final class MarkdownKaynakNesnesi: NSObject {
    let kaynak: MarkdownKaynagi
    private let hashDegeri: Int

    init(_ kaynak: MarkdownKaynagi) {
        // NSString'den köprülenen metin her karşılaştırmada Unicode normalleştirmesine
        // düşer; AppKit öznitelikleri tekilleştirirken isEqual sık çağrılıyor.
        var metin = kaynak.metin, kanonik = kaynak.kanonik
        metin.makeContiguousUTF8()
        kanonik.makeContiguousUTF8()
        self.kaynak = MarkdownKaynagi(metin: metin, kanonik: kanonik)
        // XOR değil: çoğu satırda metin == kanonik, XOR hep 0 verip aynı çakışmayı geri getirir.
        var hasher = Hasher()
        hasher.combine(metin)
        hasher.combine(kanonik)
        hashDegeri = hasher.finalize()
    }

    override var hash: Int { hashDegeri }

    override func isEqual(_ object: Any?) -> Bool {
        guard let diger = object as? MarkdownKaynakNesnesi else { return false }
        return diger === self || (diger.hashDegeri == hashDegeri && diger.kaynak == kaynak)
    }
}
#endif
