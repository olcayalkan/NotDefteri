---
tags: [mimari, karar-kaydi]
guncelleme: 2026-08-24
---

# Mimari Kararlar

Kodda **neden** öyle yazıldığı. Bir şeyi "düzeltmeden" önce buraya bak —
çoğunun arkasında bilinçli bir gerekçe var.

## Veri Modeli

### Sayfa = kendi klasörü + `index.md`
```
SSRF/
  index.md        ← sayfanın metni
  Görseller/      ← bu sayfanın resimleri
  Örnekler/       ← alt sayfa, aynı yapıda (özyinelemeli)
    index.md
```
**Neden:** Sayfa taşınırken alt sayfaları ve görselleri tek hamlede taşınıyor.
`sayfayiYenidenAdlandir()` yalnızca klasörü `moveItem` ediyor.

### Eski düzen hâlâ destekleniyor
`Ad.md` + kardeş `Ad/` klasörü. `agaciYukle()` (satır 828) ikisini birden tarar,
`sayfayiKlasoreDonustur()` (924) göç ettirir. **Kaldırma** — kullanıcı verisi var.

## Metin Biçimlendirme

### Sabit taban punto (`kTabanPunto = 14`)
Dosyaya yalnızca tabandan **farklı** puntolar `<punto=..>` ile yazılır.
**Neden:** Aksi hâlde her açılış/derlemede kaydedilen puntolar kayardı.
`gYaziBoyutu` kalıcı değil, her açılışta tabana döner.

### Başlık paragraf özniteliği
`kBaslikSeviyesiAnahtari` (satır 165) paragrafın başlık düzeyini taşır.
Diske `#`, `##`, `###` olarak yazılır. Punto/kalın işareti gerekmez —
başlık fontu seviyeden türetilir (`baslikFontu()`, satır 168).

### Eğik çizgi komutları
`/1 /2 /3 /0 /page` satır başında, boşluk veya Enter ile tamamlanır.
`textView(_:shouldChangeTextIn:)` içinde yakalanır ama düzenleme
**`DispatchQueue.main.async` ile sonraki döngüye bırakılır** (satır 1963).
**Neden:** Delegate geri çağrısının içinde metin değiştirmek AppKit'te tanımsız davranış.

## Görsel Eki

### Görsel HER ZAMAN sayfanın kendi klasörüne yazılır
Sayfa henüz diskte yoksa `gorseliDiskeYaz()` önce onu oluşturur.

**Neden:** Bağlar göreli (`Görseller/x.png`) ve `Görseller/` klasörü sayfanın
klasöründe. Böylece sayfa yeniden adlandırılınca ya da taşınınca görsel
birlikte gidiyor, bağ kendiliğinden geçerli kalıyor. Eskiden kaydedilmemiş
notun görseli kök klasöre yazılıyordu; sayfayla bağı kopuyordu.

### Dosya adı MUTLAKA temizlenir
`guvenliDosyaAdi()` (`Cekirdek/DosyaAdi.swift`) parantez, süslü parantez,
köşeli parantez, tırnak vb. karakterleri tireye çevirir.

**Neden:** Bağ biçimi `![](yol)`. Yolda geçen bir `)` bağı erken bitiriyor ve
görsel bir daha okunamıyordu. Gerçek vaka: bölüm başlığı bir Shellshock yüküydü
(`User-Agent: () { :; }; nslookup $(whoami)`), üretilen dosya adı parantez içerdi,
`resimBaginiCozumle` deseni (`\(([^)]*)\)`) ilk `)` karakterinde kesti.
Not her açılışta o görseller düz metne dönüşüyordu.


### Görsel kendi satırında durur
`ekiEkle()` (satır 556) ekin önüne/arkasına `\n` koyar.
**Neden:** Aynı satırı metinle paylaşırsa satır yüksekliği görsel kadar olur,
yanında kocaman boşluk oluşur.

### Sığdırma saklanan boyutu değiştirmez
`cellFrame(for:...)` (satır 400) görseli satıra sığdırır ama `gosterimBoyutu`
sabit kalır. **Neden:** Pencere genişleyince görsel eski boyutuna dönsün.

### Görsel adı bölüm başlığından
`bulunanBolumBasligi()` (satır 529) imleçten yukarı doğru en yakın başlığı bulur;
dosya `Başlık1.png`, ikincisi `Başlık1-2.png` olur.

## Kaydetme

### Otomatik kayıt: tek atımlık timer
`icerikDegisti()` (satır 2126) 5 sn'lik **tek atımlık** timer kurar, zaten varsa
yenisini açmaz. **Neden:** Kesintisiz yazarken en fazla 5 sn'de bir disk yazımı;
boştayken hiç timer dönmez (enerji dostu). `tolerance = 1` ile sistem
uyandırmaları birleştirebilir.

### Otomatik kayıtta panel yenilenmez
`kaydetURLe(..., panelYenile: false)` (satır 2174).
**Neden:** `KenarPaneli.yenile()` tüm notların içeriğini diskten okur (arama önbelleği).
Her 5 saniyede bir bunu yapmak pahalı.

### Aynı içeriği tekrar yazmama
`kaydetURLe()` (satır 1920) `sonYazilanIcerik` ile karşılaştırır.

### Not değiştirirken geçmiş sıfırlanır
`gecmisiSifirla()` (satır 2081) `notuAc()` içinde çağrılır.
**Neden:** Yoksa ⌘Z önceki notun içeriğini şu ankinin üzerine geri getirir.

## Kenar Panel

### Metin alanı delege metotları MUTLAKA süzülür
`KenarPaneli` iki farklı metin alanının delegesi: arama kutusu ve satır
üzerindeki ad düzenleme alanı. Dört geri çağrının **hepsi** hangi alandan
geldiğini kontrol etmeli.

**Neden:** `controlTextDidChange` süzülmüyordu. Ad düzenlenirken her tuş
vuruşunda `filtreUygula()` -> `reloadData()` çalışıyor, düzenlenen hücre yok
ediliyor, alan editörü kapanıyor ve ad **yarım metinle** kaydediliyordu:
"A" yazınca dosyanın adı "A" oluyor, düzenleme bitiyordu.

Aynı yol "Reentrant call to reloadData" uyarısının da kaynağıydı — reloadData
alan editörü etkinken, outline view'ın kendi bağlamından çağrılıyordu.


### Ağaç tazeleme AppKit geri çağrılarından ERTELENİR
Yeniden adlandırma, silme ve klasöre dönüştürme `DispatchQueue.main.async`
ile sonraki döngüye bırakılır.

**Neden:** `controlTextDidEndEditing` AppKit satır düzenleyicisini kapatırken
tetikleniyor. O sırada `reloadData` çağırmak outline view'ın iç durumunu
bozuyor — "Reentrant call to reloadData" uyarısı çıkıyor ve **yeniden
adlandırmadan sonra panel çalışmaz hâle geliyordu.**

Dikkat: `yenilemeSuruyor` bayrağı bunu ÇÖZMEZ. O yalnızca özyinelemeyi
engelliyor; buradaki çağrı AppKit'in kendi reload bağlamının içinden geliyor.
Tek çözüm bağlamdan çıkmak.

### `yenile()` yeniden girişe kapalı
`yenilemeSuruyor` bayrağı var. **Neden:** NSOutlineView iç içe `reloadData`
desteklemiyor. Şu yol kendini tetikliyordu: satır seç → `notSecildi` →
`notuAc` → `yenile` → `reloadData`. AppKit seçim bildirimini bazen
ertelediği için `programatikSecimYapiliyor` bayrağı tek başına yetmiyordu.

Ayrıca panelden seçilerek açılan not artık ağacı yeniden kurmuyor
(`notuAc(url, panelYenile: false)`) — ağaç zaten güncel.

## Arama

### Önbellek artımlı
`icerikOnbelleginiTazele()` değişmemiş notu yeniden okumaz (mtime karşılaştırması).
**Tuzak:** `URL.resourceValues` örnek başına önbellekler — aynı `URL` örneğini
yeniden sorgularsan dosya değişse bile eski değeri alırsın. Her ölçümde taze
`URL` kur. `agaciYukle()` zaten böyle çalışıyor.

**Asıl maliyet önbellekte değil:** 1000 notta `yenile()`in %72'si ağaç
taramasında geçiyor, %28'i içerik okumada.

### Türkçe duyarlı normalleştirme
```swift
metin.folding(options: [.diacriticInsensitive, .caseInsensitive],
              locale: Locale(identifier: "tr_TR"))
```
**Neden:** `İ/I/ı` ve `ö ü ş ç ğ` doğru eşleşsin. Locale vermezsen
Türkçe nokta-i sorunları çıkar.

## Performans (2026-10-08 ölçümleri)

### Öznitelik değeri sözlük olamaz (macOS)
`NSDictionary.hash` eleman sayısıdır. AppKit öznitelik sözlüklerini hash ile
tekilleştirdiği için satır başına farklı `[String: String]` değeri her satırı
aynı kovaya düşürüyordu: 280 KB not açmak O(n²), 4,3 sn. `MarkdownKaynagi`
macOS'ta hash'i dağılan bir nesne olarak saklanır. **Tuzak:** Linux'ta
(corelibs) `NSObject` alt sınıfı öznitelik değeri CFRunArray karşılaştırmasında
çöküyor; orada değer sözlük kalır. Erişim yalnızca `MarkdownKaynagi(oznitelik:)`
ve `.oznitelikDegeri` üzerinden.

### Linux'ta NSString/NSAttributedString köprüsü pahalı
corelibs'te değiştirilebilir NSString Swift String'dir; `append` her seferinde
UTF-16 uzunluğunu baştan sayar (karesel). Karakter başına `character(at:)`
da yavaş. Büyük metin tek seferde kurulur, taramalar `Array(metin.utf16)` üzerinde
yapılır. GTK iter'ları bağlar için sıralı ve artımlı ilerletilir.

### Ana thread'den çıkarılanlar
Kayıt/açılıştaki arama girdisi (`notIceriginiArkaPlandaGuncelle`) arka planda
üretilir; daha yeni tarihli girdi ezilmez. Senkron güncellemeye güvenen yollar
(yapılacak doğrulama, dal taşıma) eski `notIceriginiGuncelle`'yi kullanır.

| Ölçüm (265 KB not, 1000 sayfa) | Önce | Sonra |
|---|---|---|
| macOS not açma | 4,3 sn | 1,2 sn |
| macOS otomatik kayıt | 2,0 sn | 0,45 sn |
| macOS kaydırma adımı | 10,4 ms | ~0 (içindekiler takibi) |
| macOS ağaç taraması | 200 ms | 140 ms |
| Linux not açma | 3,6 sn | 2,0 sn |
| Linux otomatik kayıt | 1,4 sn | 0,67 sn |

## Klavye

### Punto kısayolları menüden geçmiyor
`performKeyEquivalent()` (satır 2398) `*`, `+`, `=`, `-`, `_` tuşlarını
shift'i **yok sayarak** yakalar.
**Neden:** Türkçe Q klavyede `*` shift'siz, ABD düzeninde shift'li üretilir.
Menü `keyEquivalent` eşleşmesi düzene göre kaçıyor.

### Tam ekran iki yoldan
Fn+F veya ⌃⌘F. Yeşil buton gizli ama `collectionBehavior`'a
`.fullScreenPrimary` eklendiği için `toggleFullScreen` çalışıyor.

## UI

### İçindekiler paneli metnin ÜSTÜNDE yüzer
`IcindekilerPaneli` sağ kenarda, `kaydirmaGorunumu`nun üstünde duruyor —
metin alanını daraltmıyor. **Neden:** Notion'daki davranış bu; panel daraltılmışken
yalnızca 26 px ve şeffaf, metni okumayı engellemiyor.

Başlık yoksa `isHidden = true` — boş bir kutu görünmüyor.

Girdiler `kBaslikSeviyesiAnahtari` özniteliğinden toplanıyor, Markdown metnini
yeniden ayrıştırmaktan değil; böylece çevirici ile tek kaynak paylaşıyorlar.

### Özel başlık çubuğu
Standart pencere düğmeleri gizli (`standardWindowButton(...)?.isHidden = true`),
`BaslikCubugu` kendi düğmelerini çiziyor. Sürükleme `mouseDown` →
`performDrag(with:)` (satır 718).

### Seçim vurgusu elle çiziliyor
`NotSatirGorunumu.drawSelection()` boş bırakılmış, yerine animasyonlu
`vurguGorunumu` katmanı var (satır 746).
**Neden:** Varsayılan mavi seçim kağıt temalarıyla uyumsuz.

## Kalıcı Durum (`UserDefaults`)

| Anahtar | İçerik |
|---|---|
| `temaIndex` | Seçili tema |
| `kenarPanelGenislik` | Panel genişliği (140–360) |
| `kenarPanelGizli` | Panel açık/kapalı |
| `sonNotYolu` | Açılışta geri yüklenecek not |
| `acikKlasorler` | Ağaçta açık bırakılan dallar |

## İlgili

- [[Kod-Haritasi]] — burada anlatılanların satır numaraları
- [[Markdown-Formati]] — format kararlarının ayrıntısı
- [[Acik-Isler]] — değiştirilmesi düşünülen kararlar
