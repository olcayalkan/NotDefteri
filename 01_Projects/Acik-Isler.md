---
tags: [proje, is-listesi]
guncelleme: 2026-08-24
kaynak: ozet.md
---

# Açık İşler

`ozet.md` analizinden çıkan iş listesi, etki/maliyet sırasına göre.

## 1. Markdown Çeviriciyi Kayıpsız Yapmak
**Etki: yüksek · Maliyet: orta · Dosya: `main.swift:206`**

`markdownMetniUret()` tanımadığı sözdizimini yok ediyor. "Tanımadığını olduğu
gibi koru" mantığına çevrilmeli. Bu, Obsidian ile birlikte çalışmayı güvenli
kılan tek değişiklik.

Yaklaşım: AttributedString'e çevirirken tanınmayan satırları bir öznitelikle
işaretle (`kHamMetinAnahtari` gibi), geri yazarken o parçaları dokunmadan bas.

İlgili: `03_Resources/Markdown-Formati.md`

## 2. Saf Fonksiyonlara Test Yazmak
**Etki: yüksek · Maliyet: düşük**

Test hedefi yok. En kolay başlangıç — bunlar zaten saf:

| İşlev | Satır |
|---|---|
| `isaretlemeleriTemizle()` | 197 |
| `markdownMetniUret()` | 206 |
| `markdowndenAttributedStringUret()` | 284 |
| `otomatikBaslikUret()` | 242 |
| `boyutSinirla()` / `boyutMetni()` | 187 / 192 |
| `aramaIcinSadelestir()` | 73 |

Gidiş-dönüş testi en değerlisi: `markdown → attr → markdown` özdeş olmalı.

`Package.swift`'e `.testTarget` eklemek gerekir. Şu an tek `executableTarget`
var; test için mantığı bir kütüphane hedefine ayırmak veya `@testable`
kullanabilmek adına yapıyı bölmek gerekebilir.

## 3. `NotPenceresi`'ni Bölmek
**Etki: orta · Maliyet: yüksek · Satır 1686–2445**

760 satır, 71 bağlantı. Ayrılabilecek sorumluluklar:
- Kaydetme/otomatik kayıt → `NotKaydedici`
- Metin biçimlendirme (kalın, punto, başlık) → `BicimlendirmeKomutlari`
- Klavye kısayolları → ayrı işleyici

Tek dosya kısıtı da gözden geçirilmeli — 2560 satır tek dosya bakımı zorlaştırıyor.

## 4. Hata Yutmayı Azaltmak
**Etki: orta · Maliyet: düşük**

Dosya işlemleri neredeyse tamamen `try?`. Disk dolu, izin yok, dosya kilitli
gibi durumlar sessizce kayboluyor — kullanıcı notunun kaydedilmediğini fark etmiyor.

En azından `kaydetURLe()` (satır 1920) başarısızlığı kullanıcıya bildirmeli.

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
