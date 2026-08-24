---
tags: [proje, is-listesi]
guncelleme: 2026-08-24
kaynak: ozet.md
---

# Açık İşler

`ozet.md` analizinden çıkan iş listesi, etki/maliyet sırasına göre.

## 1. ✅ Markdown Çeviricinin Kayıpları — BİTTİ (24 Ağu 2026)
**`Cekirdek/MarkdownCevirici.swift` · 23 test**

### Ölçüm önce yapıldı
"Çevirici kayıplı" varsayımı büyük ölçüde YANLIŞ çıktı. 18 Obsidian
sözdizimi denendi, **15'i zaten sorunsuz** gidiş-dönüş yapıyordu:
liste, onay kutusu, tablo, kod bloğu, frontmatter, wikilink, bağlantı,
italik, alıntı, yatay çizgi, 4+ seviye başlık, ham HTML.

Bunlar uygulama tarafından tanınmıyor ama **metin olarak korunuyor** —
yani Obsidian'da yazılan not NotDefteri'nde kaydedilince içeriği kaybetmiyor,
sadece biçimli görünmüyor.

### Gerçek hata: eşleşmemiş işaretleme
Bozulan 3 örnek aynı sınıftandı — kapanışı olmayan işaretleme biçim
başlatıyor, geri yazarken sona uydurma bir kapanış ekleniyordu:

| Girdi | Eski çıktı |
|---|---|
| `2 ** 3 = 8` | `2 ** 3 = 8\n**` |
| `<punto=16>açık kaldı` | `<punto=16>açık kaldı\n</punto>` |
| kod bloğu içinde `a ** b` | sona `**` eklenmiş |

Birikmiyordu (bir turdan sonra sabitleniyor) ama nota görünür çöp ekliyordu.

**Düzeltme:** `kapanisVarMi()` yardımcısı eklendi. `**` ve `<punto=N>`
yalnızca ileride kapanışları varsa biçim başlatıyor; eşleşmemiş olan
düz metin kalıyor. Sonuç: 18/18 temiz.

### Kalan (düşük öncelik)
Kod bloğu içindeki `**` artık kazara kapanmıyor ama parser hâlâ bağlam
duyarsız — kod bloğu içinde *eşleşen* bir `**` çifti varsa kalın sayılır.
Gerçek çözüm ``` bloklarını ayrı bir durum olarak tanımak.

## 2. ✅ Saf Fonksiyonlara Test Yazmak — BİTTİ (24 Ağu 2026)
**`Tests/NotDefteriTests/CeviriciTestleri.swift` · 21 test · `swift test`**

Yapılanlar:
- `main.swift` → `NotDefteri.swift`, giriş noktası `@main enum Ana`'ya taşındı.
  **Neden:** top-level kod içeren dosya `@testable import` edilemiyor.
- `Package.swift`'e `.testTarget` eklendi.
- Kapsam: gidiş-dönüş çevirici, işaret temizleme, punto sınırlama,
  otomatik başlık, Türkçe arama, font yardımcıları.

### Bu iş bir hata yakaladı
`aramaIcinSadelestir()` Türkçe aramada bozuktu:

| Girdi | Eski sonuç | Yeni sonuç |
|---|---|---|
| `İstanbul` | `ıstanbul` | `istanbul` |
| `istanbul` | `istanbul` | `istanbul` |

Eskiden **"istanbul" araması "İstanbul" başlıklı notu bulamıyordu.**
Kök neden: `.diacriticInsensitive` "İ"nin noktasını silip "I" yapıyor,
ardından `tr_TR` küçültmesi onu "ı"ya çeviriyordu.
Düzeltme: i ailesi (`İ I ı`) önce "i"ye indirgeniyor, ardından locale'sız folding.

### Kalan
"Bilinen kayıplar" başlığı altındaki 3 test çeviricinin **şu anki** kayıplı
davranışını belgeliyor. 1. madde yapılınca bunlar `gidisDonusKontrol`'e çevrilmeli.

## 3. ✅ `NotKaydedici` Çıkarıldı — BİTTİ (24 Ağu 2026)
**`Cekirdek/NotKaydedici.swift` · 13 yeni test**

Kayıt mantığı pencereden ayrıldı. `NotKaydedici` AppKit'e bağlı değil
(yalnızca Foundation), bu yüzden **pencere kurmadan test edilebiliyor**.

### Tipin sahiplendiği
- `sonYazilanIcerik`, `duzenlendiMi` durumu
- Yazma kararı (`yazmakGerekli`) ve disk yazımı (`yaz -> Sonuc`)
- Otomatik kayıt zamanlayıcısı

### Pencerede kalan (doğru yerde)
Uyarı gösterme, başlık etiketi, kenar panel tazeleme, otomatik adlandırma.

`NotPenceresi` üç depolanan alandan kurtuldu; `kaydetURLe()` artık
`switch kaydedici.yaz(...)` ile yalnızca arayüz tepkisi veriyor.

### Kalan
`NotPenceresi` hâlâ 6 extension'a yayılı ve `KenarPaneli` ile sıkı bağlı.
Sıradaki aday `mevcutDosyaURL` + `otomatikAdlandirildiMi` ikilisini de
kaydediciye ya da ayrı bir "açık not" tipine taşımak.

## 4. ✅ Kayıt Yolundaki Sessiz Veri Kaybı — BİTTİ (24 Ağu 2026)
**`Pencere/NotPenceresi+Kaydetme.swift`, `NotPenceresi+Pencere.swift`**

### Asıl hata `try?` değildi
`try?` yalnızca hatayı susturuyordu. Gerçek sorun sonraki üç satırdaydı:
yazma başarısız olsa bile `sonYazilanIcerik` ve `duzenlendiMi` güncelleniyordu.

Sonuç zinciri:
1. Disk dolu / izin yok → yazma başarısız, kimse bilmiyor
2. Kod notu "kaydedildi" sayıyor
3. Sonraki otomatik kayıt "içerik değişmemiş" diyip **atlıyor**
4. Kullanıcı pencereyi kapatıyor, yazdığı gidiyor

### Düzeltme
- `kaydetURLe()` artık `@discardableResult -> Bool`; `do/catch` ile yazıyor.
  Başarısızlıkta iç durum **güncellenmiyor** → otomatik kayıt yeniden deniyor.
- `kayitHatasiniBildir()`: kritik `NSAlert`, "Klasörü Göster" düğmesiyle.
  `kayitHatasiBildirildi` bayrağı 5 saniyede bir uyarı yağmasını engelliyor;
  başarılı kayıtta sıfırlanıyor.
- `kapanistaGerekirseKaydet()` da `Bool` döndürüyor; **`close()` kayıt
  başarısızsa pencereyi kapatmıyor.** Kullanıcı yazdığını kurtarma şansı buluyor.

### Kalan
Geri kalan 25 `try?` okuma/tarama yollarında (`agaciYukle`, `SayfaAgaci`).
Oralarda sessiz başarısızlık veri kaybettirmiyor, yalnızca öğe listede
görünmüyor — düşük öncelik.

## 5. ✅ Arama Önbelleği Artımlı Yapıldı — BİTTİ (24 Ağu 2026)
**`KenarPanel/KenarPaneli+Arama.swift` · 6 yeni test**

### Ölçüm planı değiştirdi
`yenile()` maliyeti 1000 notta 93 ms. Ama darboğaz sandığım yerde değildi:

| Aşama | 1000 notta | Pay |
|---|---|---|
| **Ağaç taraması** (`agaciYukle`) | 65 ms | **%72** |
| İçerik okuma | 25 ms | %28 |
| mtime kontrolü | 2.3 ms | %2.5 |

Planlanan düzeltme (içerik önbelleği) yalnızca %28'lik kısmı hedefliyordu.
Ölçülmeseydi yanlış yer optimize edilecekti.

### Yapılan
`icerikOnbelleginiTazele()`: değiştirilme tarihi aynıysa dosya yeniden
okunmuyor. mtime kontrolü okumadan ~10 kat ucuz. Silinen notlar sözlükten
düşüyor, önbellek sınırsız büyümüyor.

Ölçülen kazanç: 1000 notta 93 → 67 ms (%27).

### Yol boyunca çıkan tuzak
`URL.resourceValues` değerleri **örnek başına önbellekler**. Aynı `URL`
örneği yeniden sorgulanırsa dosya değişse bile eski tarihi döndürür.
İlk sondam bu yüzden "mtime güvenilmez" sonucu verdi — yanlıştı.
Taze `URL` ile mikrosaniye çözünürlük var. `agaciYukle()` her taramada
yeni URL kurduğu için uygulama güvende; regresyon testi eklendi.

### Kalan — asıl iş burada
Ağaç taraması (%72). Her klasör girdisi için ayrı `fileExists` +
`resourceValues` çağrısı var. Tek geçişli `FileManager.enumerator` ile
azaltılabilir. Ölçüm önce yapılmalı.

## 6. `.app` Paketi Üretmek
**Etki: düşük · Maliyet: düşük**

SwiftPM çıplak ikili üretiyor: imzasız, `Info.plist`'siz. Dock'ta düzgün
görünmesi ve LaunchAgent'in ikiliyi doğrudan çağırmaması için bundle gerekir.

## 7. Dosya İzleme
**Etki: düşük · Maliyet: orta**

Dosya dışarıdan değişirse (Obsidian, git, iCloud) uygulama fark etmiyor,
üstüne yazıyor. `DispatchSource` ile izlenebilir.

## İlgili

- [[Kod-Haritasi]] — dokunulacak satırlar
- [[Mimari-Kararlar]] — değiştirmeden önce oku
- [[Markdown-Formati]] — 1. madde için spesifikasyon
- [[ozet]] — bu listenin çıktığı analiz
