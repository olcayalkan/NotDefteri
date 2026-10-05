import Foundation

// Platform, RTF/RTFD/HTML fontlarını kKalinAnahtari ve kPuntoOlcegiAnahtari'na,
// ekleri kGorselAnahtari'na çevirerek bu dosyaya verir. NSFont/NSTextAttachment
// okuyan giriş adaptörü 041'de uygulanır; burada yalnızca anlamsal veri işlenir.

/// Bir paragrafın başlık sayılması için gövde puntosuna göre en az bu kadar
/// büyük olması gerekir. Düzeyler: /1 en iri.
private let kBaslikOranlari: [(oran: CGFloat, seviye: Int)] = [(1.50, 1), (1.28, 2), (1.12, 3)]

/// Bu uzunluğu aşan paragraf, iri puntoyla yazılmış olsa bile başlık sayılmaz
/// (büyük puntolu gövde metni olan belgelerde her paragraf başlık olmasın).
private let kEnUzunBaslik = 120

// MARK: Metin sadeleştirme

/// Yapıştırılan metindeki yabancı boşluk ve madde imi artıklarını temizler.
///
/// Web'den kopyalanan metin kırılmaz boşluk (U+00A0), sıfır genişlikli boşluk
/// ve `\r\n` satır sonlarıyla gelir; HTML listeleri de "\t•\t" gibi sekmeli
/// madde imleri üretir. Bunlar not dosyasına olduğu gibi yazılınca metin
/// görünürde normal ama aramada ve yeniden açışta bozuk davranıyordu.
package func yapistirmaMetniniSadelestir(_ metin: String) -> String {
    let sonuc = NSMutableString(string: metin)
    sadelestirmeleriUygula(sonuc)
    return String(sonuc)
}

/// Aynı sadeleştirmeler, öznitelikleri koruyarak yerinde uygulanır.
private func sadelestirmeleriUygula(_ ms: NSMutableString) {
    // (desen, yerine, düzenli ifade mi)
    let kurallar: [(String, String, Bool)] = [
        ("\r\n", "\n", false),
        ("\r", "\n", false),
        ("\u{2028}", "\n", false),   // satır ayırıcı
        ("\u{2029}", "\n", false),   // paragraf ayırıcı
        ("\u{00A0}", " ", false),    // kırılmaz boşluk
        ("\u{200B}", "", false),     // sıfır genişlikli boşluk
        ("\u{FEFF}", "", false),
        ("(?m)^[\t ]*([\u{2022}\u{25E6}\u{25AA}\u{00B7}])[\t ]+", "• ", true),  // liste madde imleri
        ("(?m)[ \t]+$", "", true),   // satır sonu boşluk artıkları
    ]
    for (desen, yenisi, duzenliMi) in kurallar {
        ms.replaceOccurrences(of: desen, with: yenisi,
                              options: duzenliMi ? .regularExpression : [],
                              range: NSRange(location: 0, length: ms.length))
    }
}

// MARK: Zengin metin

/// Platformun anlamsala çevirdiği pano metnini not biçimine indirger.
/// Giriş noktası: (NSAttributedString) -> NSAttributedString; giriş font puntosu
/// kPuntoOlcegiAnahtari = kaynakPunto / kTabanPunto olarak taşınmalıdır.
/// Çıktı yalnızca anlamsal öznitelikler içerir. Ham RTF/HTML doğrudan verilmez.
///
/// Görsel ekleri olduğu gibi taşınır; bunları sayfanın kendi klasörüne
/// kaydetmek çağıranın işidir (bkz. `NotMetinGorunumu`).
package func disIcerigiNotBicimineCevir(_ gelen: NSAttributedString) -> NSAttributedString {
    let kaynak = NSMutableAttributedString(attributedString: gelen)
    sadelestirmeleriUygula(kaynak.mutableString)
    guard kaynak.length > 0 else { return NSAttributedString(string: "") }

    let govdePunto = govdePuntosunuBul(kaynak)
    let ns = NSString(string: kaynak.string)
    var basliklar: [(NSRange, Int)] = []
    var konum = 0
    while konum < ns.length {
        let paragraf = ns.paragraphRange(for: NSRange(location: konum, length: 0))
        guard paragraf.length > 0 else { break }
        let seviye = baslikSeviyesiTahminEt(kaynak, metin: ns, paragraf: paragraf, govdePunto: govdePunto)
        if seviye > 0 { basliklar.append((paragraf, seviye)) }
        konum = NSMaxRange(paragraf)
    }

    let sonuc = NSMutableAttributedString(string: kaynak.string)
    kaynak.enumerateAttributes(in: NSRange(location: 0, length: kaynak.length)) { oznitelikler, aralik, _ in
        if let gorsel = oznitelikler[kGorselAnahtari] as? [String: Any] {
            sonuc.setAttributes([kGorselAnahtari: gorsel], range: aralik)
        } else if oznitelikler[kKalinAnahtari] as? Bool == true {
            sonuc.addAttribute(kKalinAnahtari, value: true, range: aralik)
        }
    }
    for (aralik, seviye) in basliklar {
        sonuc.addAttribute(kBaslikSeviyesiAnahtari, value: seviye, range: aralik)
    }
    return sonuc
}

/// Belgenin gövde puntosu: en çok karakterin yazıldığı boyut.
///
/// Başlık düzeyi mutlak puntoya değil bu orana göre belirlenir; yoksa 11 punto
/// gövdesi olan bir PDF'in her satırı başlık, 18 punto gövdesi olan bir web
/// sayfasının hiçbir başlığı başlık sayılmıyordu.
private func govdePuntosunuBul(_ attr: NSAttributedString) -> CGFloat {
    var agirlik: [CGFloat: Int] = [:]
    attr.enumerateAttribute(kPuntoOlcegiAnahtari, in: NSRange(location: 0, length: attr.length), options: []) { deger, aralik, _ in
        let punto = CGFloat((deger as? Double) ?? 1) * kTabanPunto
        let boyut = (punto * 2).rounded() / 2
        agirlik[boyut, default: 0] += aralik.length
    }
    // Eşit ağırlıkta iki boyut varsa küçüğü gövdedir.
    let baskin = agirlik.max { sol, sag in
        sol.value == sag.value ? sol.key > sag.key : sol.value < sag.value
    }
    return baskin?.key ?? kTabanPunto
}

/// Paragrafın başlık düzeyi (0 = düz metin).
private func baslikSeviyesiTahminEt(_ attr: NSAttributedString, metin ns: NSString, paragraf: NSRange, govdePunto: CGFloat) -> Int {
    let metin = ns.substring(with: paragraf).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !metin.isEmpty, metin.count <= kEnUzunBaslik else { return 0 }

    // Görsel içeren paragraf başlık olamaz.
    var ekVar = false
    attr.enumerateAttribute(kGorselAnahtari, in: paragraf, options: []) { deger, _, dur in
        if deger != nil { ekVar = true; dur.pointee = true }
    }
    guard !ekVar else { return 0 }

    // Paragrafın TAMAMI iri olmalı: içinde tek bir gövde puntolu parça varsa
    // (ör. sonundaki dipnot işareti) bu bir başlık değil, vurgulu cümledir.
    var enKucuk = CGFloat.greatestFiniteMagnitude
    attr.enumerateAttributes(in: paragraf, options: []) { oznitelikler, aralik, _ in
        // Yalnızca boşluktan ibaret parçalar ölçüyü bozmasın.
        let parca = ns.substring(with: aralik).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !parca.isEmpty else { return }
        let punto = CGFloat((oznitelikler[kPuntoOlcegiAnahtari] as? Double) ?? 1) * kTabanPunto
        enKucuk = min(enKucuk, punto)
    }
    guard enKucuk < .greatestFiniteMagnitude, govdePunto > 0 else { return 0 }

    let oran = enKucuk / govdePunto
    return kBaslikOranlari.first { oran >= $0.oran }?.seviye ?? 0
}

// MARK: Düz metin

/// Panoda yalnızca düz metin varken kullanılır.
///
/// Metin Markdown'sa ("# Başlık", "**kalın**") notun kendi biçimine dönüşür;
/// değilse anlamsal gövde metni olarak eklenir. Notun kendi kayıt
/// biçimi de Markdown olduğu için bu, dışarıdan gelenle içeride yazılanı
/// aynı dile getirir.
package func disMetniNotBicimineCevir(_ metin: String, taban: URL? = nil) -> NSAttributedString {
    let sade = yapistirmaMetniniSadelestir(metin)
    guard !sade.isEmpty else { return NSAttributedString(string: "") }
    return yapistirmaMarkdownunuCevir(sade, taban: taban ?? notlarKlasoru())
}

/// Dış metin ve kendi pano biçimimiz aynı kısa yolu kullanır.
/// İşaret içeren metin mevcut ayrıştırıcıdan geçer; biçim ve görseller korunur.
package func yapistirmaMarkdownunuCevir(_ metin: String, taban: URL) -> NSAttributedString {
    let ns = NSString(string: metin)
    if ["#", "*", "![", "<", "`", "~~", "==", "["].allSatisfy({ ns.range(of: $0).location == NSNotFound }) {
        return NSAttributedString(string: metin)
    }
    return markdowndenAttributedStringUret(metin, taban: taban)
}
