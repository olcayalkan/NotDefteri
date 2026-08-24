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

## 3. `NotPenceresi`'ni Bölmek
**Etki: orta · Maliyet: yüksek · Satır 1686–2445**

760 satır, 71 bağlantı. Ayrılabilecek sorumluluklar:
- Kaydetme/otomatik kayıt → `NotKaydedici`
- Metin biçimlendirme (kalın, punto, başlık) → `BicimlendirmeKomutlari`
- Klavye kısayolları → ayrı işleyici

Tek dosya kısıtı da gözden geçirilmeli — 2560 satır tek dosya bakımı zorlaştırıyor.

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

## 5. Arama Önbelleğini Ucuzlatmak
**Etki: düşük (şimdilik) · Maliyet: orta · Satır 1238**

`yenile()` her çağrıda tüm notları diskten okuyor. Birkaç yüz notta hissedilir.
Değiştirilme tarihine göre artımlı önbellek çözer.

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
