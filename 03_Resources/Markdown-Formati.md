---
tags: [format, spesifikasyon, referans]
guncelleme: 2026-08-24
---

# NotDefteri Markdown Lehçesi

Uygulamanın diske yazdığı biçimin tam tanımı.
Kaynak: `Sources/NotDefteri/Cekirdek/MarkdownCevirici.swift` ve `Sources/NotDefteri/Cekirdek/MetinBlogu.swift`.

## Desteklenen Sözdizimi

| Özellik | Yazılış | Obsidian |
|---|---|---|
| Başlık 1–3 | `# `, `## `, `### ` | ✅ standart |
| Madde listesi | `- öğe` | ✅ standart |
| Numaralı liste | `1. öğe` | ✅ standart |
| Yapılacak | `- [ ] iş`, `- [x] iş` | ✅ standart |
| Alıntı | `> alıntı` | ✅ standart |
| Uyarı kutusu | `> [!💡 sarı] metin`, devamında `> satır` | ⚠️ Obsidian benzeri özel başlık |
| Ayırıcı | `---` | ✅ standart |
| Kalın | `**metin**` | ✅ standart |
| İtalik | `*metin*` | ✅ standart |
| Üstü çizili | `~~metin~~` | ✅ standart |
| Satır içi kod | `` `metin` `` | ✅ standart |
| Vurgu | `==metin==` | ✅ Obsidian uzantısı |
| Bağlantı | `[metin](url)` | ✅ standart |
| Sayfa bağlantısı | `[[Sayfa Adı]]`, `[[Üst/Sayfa Adı]]` | ✅ wikilink |
| Kod bloğu | Üçlü backtick; açılışta isteğe bağlı dil etiketi (ör. `go`) | ✅ standart |
| Görsel | `![](Görseller/Ad.png){320x240}` | ⚠️ `{ExY}` ekranda metin olarak kalır |
| Punto | `<punto=16>metin</punto>` | ❌ ham etiket görünür |

Blok girintisi seviye başına iki boşluktur. Açılışta `* ` madde işareti ve
mevcut numara/önek yazılışı da korunur; yapısal düzenleme kanonik öneki üretir.
Tablo ve tanınmayan frontmatter düz metin olarak korunur.

### Sayfa bağlantıları

`[[Sayfa Adı]]` sayfayı açar. Aynı adlı sayfalarda köke göre tam yol kullanılır:
`[[Üst/Sayfa Adı]]`. Kökteki sayfanın adı da çakışıyorsa `[[./Sayfa Adı]]`
onu ayırır. Olmayan hedef soluk görünür; tıklama o adla oluşturmayı sorar.
Kod içindeki ve kaçışlı `\[[Sayfa Adı]]` metinler düz metin olarak kalır.

⌘P sayfa adlarında Türkçe duyarlı bulanık arama açar; boş sorgu son açılan
sayfaları gösterir. Editörde `[[` aynı listeyi satır içinde açar.
↑/↓ seçimi değiştirir, Enter uygular, Esc kapatır. Yeniden adlandırma ve taşıma,
alt sayfaların yollarıyla birlikte bağlantıları atomik dosya yazımlarıyla günceller.
İçindekiler altındaki “Bağlantı verenler” açılışta ve kayıttan sonra önbellekten hesaplanır.
Kaynak: `Sources/NotDefteri/Cekirdek/SayfaBaglantilari.swift`,
`Sources/NotDefteri/Gorunum/HizliBulucu.swift` ve
`Sources/NotDefteri/KenarPanel/KenarPaneli+Baglantilar.swift`.

### Sayfa üstbilgisi (frontmatter)

```markdown
---
genislik: tam
yazi: kucuk
---
Sayfanın metni
```

İlk satır tam olarak `---` olduğunda, en fazla 200 satır içinde `---` ile kapanan
ve en az bir `anahtar:` içeren YAML benzeri önek sayfa üstbilgisidir. `genislik:` ve
`yazi:` bilinen alanlardır; her biri en fazla bir kez bulunabilir. Eski sürümlerdeki
`ikon:` ve `kapak:` satırları artık kullanılmaz; bilinmeyen anahtar gibi aynen korunur
(silinmez, değiştirilmez, kapak görsel dosyalarına dokunulmaz). Bilinmeyen anahtarlar, devam satırları, listeler ve yorumlar korunur.
Alanlar değişmedikçe özgün boşluklar, sıra ve satır sonları aynı kalır.
Üstbilgi editör metninden ayrı tutulur; boş üstbilgi üretilmez. Kapanışı olmayan
önek normal metindir; tek başına `---` ayırıcıdır.
Kaynak: `Sources/NotDefteri/Cekirdek/SayfaAgaci.swift` ve `sayfaMarkdownunuUret()`.

### Uyarı kutusu

```markdown
> [!💡 sarı] İlk satır
> İkinci satır
```

Devam satırının öneki `> ` şeklindedir (boş devam satırında da sondaki boşluk
bulunur). Başlık tek bir emoji ve `gri`, `mavi`, `sarı`, `kırmızı` veya `yeşil`
rengini içerir. Başlığı izleyen bitişik `> ` satırları aynı kutudur; alıntıdan
ayırmak için araya öneksiz boş satır konur. Yeni kutunun varsayılanı 💡 ve sarıdır.
`/` menüsündeki “Uyarı kutusu” kutu oluşturur. “Uyarı: Renk” seçenekleri ve
kutunun sağ tık menüsü rengi değiştirir. Emojiye tıklamak sistem emoji paletini açar.
Enter kutu içinde yeni satır oluşturur; boş satırdaki Enter düz paragrafa çıkar.
Kaynak: `MetinBlogu.swift`, `MarkdownCevirici.swift`, `NotMetinGorunumu+UyariKutusu.swift`.

### Sayfa seçenekleri, bul ve alt bilgi

Görünüm menüsündeki seçenekler sayfa başına saklanır:

| Anahtar | Etkin değer | Varsayılan ve kullanım |
|---|---|---|
| `genislik` | `tam` | Alan yoksa editör pencere genişliğinde ve 14 pt yan payla açılır. `tam` yan payı kaldırır. |
| `yazi` | `kucuk` | Alan yoksa normal punto kullanılır. `kucuk` fontları %85 boyutta gösterir; Markdown punto etiketleri aynı kalır. |

Seçenek kapatıldığında anahtarı kaldırılır; bilinmeyen üstbilgi alanları korunur.
⌘F yerel bul çubuğunu, ⌘⌥F değiştirme alanını açar. ⌘G ve ⇧⌘G sonraki ve önceki
eşleşmeye gider; komutlar Düzen > Bul alt menüsünde de bulunur.
Editörün altındaki kelime sayısı değişen paragraf ve gerekli komşu sınırdan
artımlı hesaplanır; etiket 0,15 saniyelik debounce ile güncellenir.
Son düzenleme zamanı açılışta dosyadan alınır, düzenlemede güncellenir.
Kaynak: `NotPenceresi+SayfaSecenekleri.swift`, `NotMetinGorunumu+Sayfa.swift`, `Menu.swift`.

Satır başında `# `, `## `, `### `, `- `, `* `, `1. `, `[] `, `[ ] ` ve `> `
blok biçimine dönüşür. `---` Enter ile ayırıcıya dönüşür. Liste, yapılacak ve
alıntıda Enter aynı türü sürdürür; boş öğede Enter düz paragrafa döner.
Tab/Shift-Tab girintiyi değiştirir; satırın metin başında Backspace biçimi kaldırır.
Kutuya tıklamak tamamlanmayı değiştirir. Her işlem tek geri alma kaydıdır.

## Çevirici Ne Kadar Sadık

Kaydetme, metni AttributedString'den yeniden üretir. Ama tanınmayan sözdizimi
**metin olarak korunur** — 24 Ağu 2026 ölçümünde 18 Obsidian biçiminin
18'i gidiş-dönüşten sağlam çıktı.

```
Obsidian'da yaz:   - [ ] görev
NotDefteri gösterir: "☐ görev"       (tıklanabilir kutu)
NotDefteri kaydeder: "- [ ] görev"   (metin aynen korunur)
```

Tanınmayan işaretleme metin olarak korunur.

Mevcut çevirici testlerinin kapsadığı sözdizimi: liste, onay kutusu, tablo, kod bloğu,
frontmatter, `[[wikilink]]`, `[bağlantı](url)`, italik, alıntı, yatay çizgi,
4+ seviye başlık, ham HTML.

### Kaçış kuralı

Okuyucu yalnızca `\` ardından ``\ * ` ~ = [ ] > # . - < !`` karakterini çözer; `\(`, `C:\Users` gibi diğer diziler metin kalır.
Yazıcı düz metni aynen yazar, yalnızca yeniden açılınca biçim sayılacak karakteri kaçırır: satır başı blok/başlık öneki (`\# `, `\- `, `1\. `),
satırda eşi ya da o biçim varken `*`, `` ` ``, `==`, `~~`, `[[`/`](` varken `[`, `<punto` etiketi ve ardından kaçış karakteri gelen `\`.
Alıntı veya kutu devam satırında düz metindeki `[!💡 sarı]` gibi geçerli bir kutu
başlığının `[` karakteri kaçar; yeni kutu olarak okunması önlenir.
Kaynak: `kKacisKarakterleri`, `satirKacisRiskleri()`, `markdownKarakterleriniKacir()`.

### Satır içi biçimler ve kod

Çevirici açılan paragrafın özgün yazılışını saklar. Değişmeyen paragraf kayıt
sırasında aynı metni üretir; düzenlenen paragraf desteklenen biçimleri Markdown'a çevirir.
Kod bloğu içindeki Markdown işaretleri düz kod olarak kalır. Açılıştaki dil etiketi,
kapanış ve satır sonları değişmeyen blokta korunur. İçerikte backtick varsa çevirici
daha uzun ayıraç seçer. Boş kod satırında Enter normal paragrafa döner.

Açılış satırındaki dil etiketi sözdizimi renklerini belirler: `swift`, `go` (`golang`),
`python` (`py`), `javascript` (`js`), `typescript` (`ts`), `bash` (`sh`, `zsh`, `shell`),
`json`, `sql`, `html`, `css`. Etiketsiz veya bilinmeyen dilli blok renklenmez;
özgün açılış satırı ve gövde korunur. Anahtar kelime, string, sayı ve yorum renkleri
temadan türetilir. Düzenleme sırasında yalnızca değişen blok 0,15 saniye debounce
sonrasında renklenir; renkler geçici layout öznitelikleridir, kayda ve undo'ya girmez.

`/` menüsünde “Kod bloğu” seçimi dil listesini açar. Yazarak filtrelenir;
↑/↓ ve Enter veya tıklama dil seçer. “Dil yok” etiketsiz blok oluşturur; Esc iptal eder.
Fare blok üzerindeyken sağ üstte dil etiketi ve “Kopyala” düğmesi görünür.
Düğme çitler ve editör işaretleri olmadan gövdeyi düz metin olarak panoya yazar;
kısa süre “Kopyalandı” gösterir.
Kaynak: `KodVurgulayici.swift`, `KodRenkleri.swift`, `NotMetinGorunumu+KodBlogu.swift`, `BlokMenusu.swift`.

Yapıştırılan çıplak URL tıklanabilir olur ve dosyada çıplak URL olarak kalır.
Bağlantı komutu `[metin](url)` üretir; URL alanını boş bırakmak bağlantıyı kaldırır.
Bağlantılar tık veya ⌘+tık ile varsayılan tarayıcıda açılır.

Satır başında veya boşluktan sonra `/` blok menüsünü açar. Türkçe duyarlı sorgu
başlık, liste, yapılacak, alıntı, kod, ayırıcı, alt sayfa ve görsel seçeneklerini süzer.
`/1`, `/2`, `/3`, `/b1`, `/b2`, `/b3`, `/baş`, `/page` ve `/sayfa` eşleşir.
↑/↓ seçimi değiştirir; Enter seçeneği uygular ve `/sorgu` metnini siler.
Esc, boşluk veya eşleşmeyen sorgu menüyü kapatır. `/0` normal metin komutudur.

Metin seçimi üstte biçim çubuğunu gösterir. Kısayollar: kalın ⌘B, italik ⌘I,
üstü çizili ⌘⇧X, satır içi kod ⌘E, vurgu ⌘⇧H, bağlantı ⌘K.

## Punto Etiketi Mantığı

Taban punto **14 pt** (`kTabanPunto`). Yalnızca farklı olanlar etiketlenir:

```
normal metin<punto=18>büyük</punto>normal
```

Sınır: 10–28 pt (`boyutSinirla()`, satır 187).
Tam sayıysa ondalık yazılmaz: `14.0` → `14` (`boyutMetni()`, satır 192).

## Görsel Bağı

```
![](Görseller/Başlık1.png){320x240}
      └─ yol           └─ gösterim boyutu (isteğe bağlı)
```

Çözümleme sırası (`resimBaginiCozumle()`, satır 261):
1. Sayfanın kendi klasörüne göre
2. Olmazsa kök `~/Documents/NotDefteri/` klasörüne göre (eski `ekler/` bağları için)

Dosya diskte yoksa `nil` döner ve **metin olduğu gibi korunur** — bilinçli.

## Başlık Punto Çarpanları

| Seviye | Çarpan | Sonuç (14 pt tabandan) |
|---|---|---|
| `#` | 1.75 | 25 pt |
| `##` | 1.40 | 20 pt |
| `###` | 1.15 | 16 pt |

Hepsi kalın (`baslikFontu()`, satır 168).

## Obsidian Uyumu İçin Yapılacaklar

Çeviriciyi "tanımadığını olduğu gibi koru" mantığına çevirmek en temiz çözüm.
Bkz. `01_Projects/Obsidian-Uyumlulugu.md`.

## İlgili

- [[Kod-Haritasi]] — çevirici işlevlerinin yeri
- [[Mimari-Kararlar]] — punto ve başlık kararlarının gerekçesi
- [[Acik-Isler]] — kayıpsız çevirici işi
