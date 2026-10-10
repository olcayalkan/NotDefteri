import Foundation

/// Yeni, boş not köküne yalnızca bir kez eklenen normal Markdown sayfası.
/// Uygulama bu sayfaya özel davranmaz: kullanıcı düzenleyebilir, taşıyabilir veya silebilir.
package let kKullanimKilavuzuSayfaAdi = "NOT DEFTERI KULLANIM KILAVUZU"

private let kullanimKilavuzuMarkdown = #"""
# NOT DEFTERI KULLANIM KILAVUZU

Not Defteri, notları normal Markdown dosyaları olarak saklar. Bu sayfa günlük kullanım için hızlı başvuru rehberidir.

## Hızlı başlangıç

- Sol panelden bir sayfa seçin; üst çubuktaki **Yeni Sayfa** düğmesiyle yeni not açın.
- Yeni boş sayfanın ilk satırı, sayfanın adını otomatik belirler.
- Yazmayı bıraktıktan sonra not otomatik kaydedilir; isterseniz Kaydet komutunu kullanın.
- Sayfaları soldaki ağaçta sürükleyip bırakarak sıralayın veya bir sayfanın altına taşıyın.
- Sayfaya sağ tıklayarak alt sayfa ekleyin, yeniden adlandırın, sabitleyin ya da silin.

## Temel kısayollar

macOS'ta `⌘` Command, `⌥` Option ve `⇧` Shift'tir. Linux'ta çoğu `⌘` karşılığı `Ctrl` olur.

| İşlem | macOS | Linux |
|---|---|---|
| Hızlı sayfa bulucu | `⌘P` | `Ctrl+P` |
| Ana Sayfa | `⇧⌘H` | `Ctrl+Shift+H` |
| Kaydet | `⌘S` | `Ctrl+S` |
| Geri al / yinele | `⌘Z` / `⇧⌘Z` | `Ctrl+Z` / `Ctrl+Y` |
| Kes, kopyala, yapıştır | `⌘X`, `⌘C`, `⌘V` | `Ctrl+X`, `Ctrl+C`, `Ctrl+V` |
| Tümünü seç | `⌘A` | `Ctrl+A` |
| Bul / değiştir | `⌘F` / `⌥⌘F` | `Ctrl+F` / `Ctrl+Alt+F` |
| Kalın / italik | `⌘B` / `⌘I` | `Ctrl+B` / `Ctrl+I` |
| Üstü çizili | `⇧⌘X` | `Ctrl+Shift+X` |
| Satır içi kod | `⌘E` | `Ctrl+E` |
| Vurgu | `⌥⌘H` | `Ctrl+Alt+H` |
| Sayfa bağlantısı | `⌘K` | `Ctrl+K` |
| Puntoyu büyüt / küçült | `⌘*` / `⌘-` | `Ctrl+*` / `Ctrl+-` |
| Sayfa geçmişi | `⌥⌘Y` | `Ctrl+Alt+Y` |
| PDF dışa aktar | `⇧⌘E` | `Ctrl+Shift+E` |
| Tam ekran | `⌃⌘F` | `F11` |
| Kısayollar penceresi | `⌘/` | `Ctrl+/` |

Güncel listenin tamamı için **Yardım → Klavye kısayolları** menüsünü açın; penceredeki arama alanı işlev adına veya tuşa göre filtreler.

## Yazı boyutu ve punto

Varsayılan gövde yazısı **14 pt**'dir; desteklenen aralık **10–28 pt**'dir.

1. Boyutunu değiştirmek istediğiniz metni seçin.
2. Kenar panelindeki **A−** / **A+** düğmelerini veya punto kısayollarını kullanın.
3. Seçim yoksa değişiklik imleçten sonra yazacağınız metne uygulanır.

Kenar panelindeki punto göstergesi, imlecin veya seçili metnin güncel boyutunu gösterir. Başlıkların boyutu başlık düzeyinden gelir; gövde metninin puntosunu değiştirmek en tutarlı sonuçtur.

**Görünüm → Küçük yazı**, yalnızca o sayfanın ekrandaki görünümünü küçültür; Markdown içeriğini değiştirmez. **Tam genişlik** metin alanını sayfanın tamamına yayar.

## Başlıklar, bloklar ve içindekiler

Satır başında aşağıdaki yazımları kullanabilirsiniz:

| Yazım | Sonuç |
|---|---|
| `# `, `## `, `### ` | Başlık 1, 2, 3 |
| `- ` | Madde listesi |
| `1. ` | Numaralı liste |
| `- [ ] ` veya `[] ` | Yapılacak maddesi |
| `> ` | Alıntı |
| `---` | Ayırıcı |
| Üç ters tırnak | Kod bloğu |
| `/` | Blok menüsü |

`/` ile açılan menüden başlık, liste, yapılacak, alıntı, kod bloğu, uyarı kutusu, ayırıcı, alt sayfa, görsel veya tablo seçebilirsiniz. Hızlı seçim için `/1`, `/2`, `/3`, `/0`, `/kod`, `/uyari`, `/sayfa` ve `/tablo` yazabilirsiniz.

### Tablolar

`/tablo` yazıp `Enter`a basın. Açılan pencerede başlık satırı dahil satır sayısını ve sütun sayısını girin; uygulama düzenlenebilir bir tablo ekler. Hücre içindeki yazıyı doğrudan değiştirin. Tablolar Markdown olarak saklandığından başka Markdown uygulamalarında da açılır.

Başlıklar sağdaki **İçindekiler** panelinde görünür. Bir başlığa tıklayarak ilgili bölüme gidebilirsiniz. macOS'ta `⌥⌘[` / `⌥⌘]`, Linux'ta `Ctrl+Alt+[` / `Ctrl+Alt+]` ile bulunduğunuz bölümü katlayıp açabilirsiniz.

## Bağlantılar, arama ve sayfalar

- Bir sayfaya bağlantı vermek için `[[` yazın; önerilerden yön tuşları ve Enter ile seçim yapın.
- Bağlantı veren sayfalar sağdaki içindekiler alanında listelenir.
- Sol panel araması açık not ağacını süzer. Hızlı Sayfa Bulucu tüm sayfalarda geçiş içindir.
- Arama Türkçe karakterleri normalleştirir: `istanbul`, `İstanbul` sonucunu da bulur.
- Sayfayı **📌 Sabitle** komutuyla kardeşleri arasında üstte tutabilirsiniz.

## Tema, görseller ve kod

**Görünüm → Tema** menüsünde Sepya, Terminal, Yeşilimsi Kağıt, Gri Kağıt ve Krem seçenekleri bulunur. Terminal koyu arka planlıdır; tema seçimi uygulama genelinde saklanır.

- `- [ ]` görevleri Ana Sayfa'da bir araya gelir; kutuya tıklayınca tamamlanır.
- Görseli sürükleyip bırakın veya yapıştırın. İlgili sayfanın `Görseller/` klasörüne kaydedilir.
- Kod bloğu eklerken **Otomatik** seçeneği; anahtar kelime, metin, yorum, sayı, tür, fonksiyon ve operatörleri renklendirir. Daha kesin sonuç için `swift`, `python` veya `json` gibi bir dil de seçebilirsiniz.
- Uyarı kutusunu blok menüsünden ekleyin; sağ tıklayarak rengini değiştirin.

## Geçmiş, silme ve dışa aktarma

- **Sayfa geçmişi**, önceki sürümleri görüntülemenizi ve geri yüklemenizi sağlar.
- Silinen sayfalar **Çöp kutusu**nda 30 gün boyunca geri yüklenebilir.
- Sayfayı PDF, HTML veya Markdown olarak dışa aktarabilirsiniz.
- Markdown olarak kopyala komutu biçimli içeriği taşınabilir metin olarak panoya alır.

## Notlar nerede?

Notlar varsayılan olarak `~/Documents/NotDefteri/` içinde saklanır. Her sayfanın kendi klasöründe `index.md`, isteğe bağlı `Görseller/` ve `.gecmis/` bulunur. Bu klasörü düzenli yedekleyebilirsiniz.

Bu sayfa normal bir nottur: dilediğiniz gibi düzenleyebilir, taşıyabilir veya silebilirsiniz.
"""#

/// Kök henüz hiç görünür öğe içermiyorsa başlangıç rehberini oluşturur.
/// Var olan notlara, aynı adlı klasöre veya kullanıcının değiştirdiği rehbere dokunmaz.
@discardableResult
package func ilkKullanimKilavuzunuHazirla(kok: URL = notlarKlasoru()) throws -> URL? {
    let fm = FileManager.default
    // Her açılışta tüm not ağacını taramak yerine yalnızca kökün boş olup
    // olmadığına bakılır. Normal sayfa, eski biçimdeki .md ve başka kullanıcı
    // dosyaları da bu ilk-kurulum adımını güvenle durdurur.
    let gorunenler = try fm.contentsOfDirectory(at: kok, includingPropertiesForKeys: nil,
                                                 options: [.skipsHiddenFiles])
    guard gorunenler.isEmpty else { return nil }

    let klasor = kok.appendingPathComponent(kKullanimKilavuzuSayfaAdi, isDirectory: true)
    guard !dosyaYoluVarMi(klasor) else { return nil }
    try notlarYolunuDogrula(klasor, kok: kok)
    try fm.createDirectory(at: klasor, withIntermediateDirectories: false)

    let hedef = klasor.appendingPathComponent(kIcerikDosyaAdi)
    do {
        try kullanimKilavuzuMarkdown.write(to: hedef, atomically: true, encoding: .utf8)
    } catch {
        try? fm.removeItem(at: klasor)
        throw error
    }
    return hedef
}
