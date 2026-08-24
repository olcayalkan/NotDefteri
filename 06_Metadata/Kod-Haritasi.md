---
tags: [kod-haritasi, referans]
guncelleme: 2026-08-24
kaynak: Sources/NotDefteri/
---

# Kod Haritası

26 dosya, 5 katman, ~2684 satır. En büyük dosya 302 satır.
**Satır numarası vermiyoruz** — dosyalar küçük, adı bilmek yetiyor.

## Katmanlar

```
Cekirdek/     UI'dan bağımsız mantık — test edilebilir
Gorunum/      AppKit görünümleri
KenarPanel/   Kenar panel (KenarPaneli + 3 extension)
Pencere/      Ana pencere (NotPenceresi + 6 extension)
Uygulama/     Yaşam döngüsü ve menü
```

Bağımlılık yönü: `Uygulama → Pencere → KenarPanel → Gorunum → Cekirdek`

## Cekirdek/ — mantık

| Dosya | Satır | İçerik |
|---|---|---|
| `MarkdownCevirici.swift` | 214 | **Çift yönlü çevirici** — `markdownMetniUret()`, `markdowndenAttributedStringUret()`, `isaretlemeleriTemizle()`, `otomatikBaslikUret()`, font yardımcıları |
| `SayfaAgaci.swift` | 169 | `AgacDugumu`, `agaciYukle()`, `sayfaKlasoru()`, `sayfayiYenidenAdlandir()`, `sayfayiKlasoreDonustur()` |
| `NotKaydedici.swift` | 118 | **Kayıt mantığı** — yazma kararı, disk yazımı, otomatik kayıt zamanlayıcısı. AppKit'siz, test edilebilir |
| `DosyaSistemi.swift` | 62 | `notlarKlasoru()`, `gorsellerKlasoru()`, LaunchAgent |
| `Sabitler.swift` | 28 | `kTabanPunto`, `kMinYaziBoyutu`, `kOtomatikKayitAraligi`… |
| `Ayarlar.swift` | 22 | `UserDefaults` destekli durum: `gTemaIndex`, `gKenarPanelGenislik`, `gYaziBoyutu` |
| `MetinNormallestirme.swift` | 18 | `aramaIcinSadelestir()` — Türkçe duyarlı arama |

## Gorunum/ — görünümler

| Dosya | Satır | İçerik |
|---|---|---|
| `ResimEki.swift` | 141 | `ResimEki`, `ResimEkiHucresi` — sürüklenerek boyutlandırma |
| `BaslikCubugu.swift` | 140 | Özel pencere kontrolleri |
| `NotMetinGorunumu.swift` | 74 | `NSTextView` alt sınıfı — görsel yapıştırma |
| `Tema.swift` | 53 | `Tema`, `temaListesi`, `aktifTema`, renk türetme |
| `NotSatirGorunumu.swift` | 47 | Kenar panel satır vurgusu |
| `KenarPaneliSurukleTutamaci.swift` | 37 | Panel genişliği tutamacı |
| `SembolBoyama.swift` | 21 | `renklendirilmisSembol()` |

## KenarPanel/

| Dosya | Satır | İçerik |
|---|---|---|
| `KenarPaneli.swift` | 302 | Sınıf gövdesi, depolanan özellikler, UI kurulumu, yerleşim |
| `KenarPaneli+AgacVeriKaynagi.swift` | 150 | `NSOutlineView` veri kaynağı + delegesi, hücre üretimi |
| `KenarPaneli+DosyaIslemleri.swift` | 142 | Sayfa ekleme, yeniden adlandırma, silme, sağ tık menüsü |
| `KenarPaneli+Arama.swift` | 137 | `yenile()`, `suzulmusAgac()`, `filtreUygula()` |

## Pencere/

| Dosya | Satır | İçerik |
|---|---|---|
| `NotPenceresi+Komutlar.swift` | 147 | Eğik çizgi komutları (`/1 /2 /3 /page`), başlık uygulama, geri al/yinele |
| `NotPenceresi.swift` | 141 | Sınıf gövdesi, depolanan özellikler, `init`, alt görünüm kurulumu |
| `NotPenceresi+Kaydetme.swift` | 134 | `kaydetURLe()`, `otomatikKaydet()`, timer yönetimi, isim sorma |
| `NotPenceresi+Pencere.swift` | 125 | Notlar arası gezinme, panel aç/kapa, `performKeyEquivalent`, kapatma |
| `NotPenceresi+Bicimlendirme.swift` | 121 | Kalın (⌘B), punto (⌘*/⌘−), tema seçimi |
| `NotPenceresi+Not.swift` | 91 | `notuAc()`, `yeniNotOlustur()`, `yeniSayfaOlustur()` |
| `NotPenceresi+Gorsel.swift` | 41 | `gorseliDiskeYaz()` |

## Uygulama/

| Dosya | Satır | İçerik |
|---|---|---|
| `Menu.swift` | 78 | `anaMenuyuOlustur()` — menü + `#selector` bağlantıları |
| `Ana.swift` | 49 | `UygulamaDelegesi`, `@main enum Ana` |

## Testler

`Tests/NotDefteriTests/` — 42 test (`CeviriciTestleri` 23, `KaydediciTestleri` 13, `OnbellekTestleri` 6).
Kapsam: gidiş-dönüş çevirici, işaret temizleme, punto sınırlama, otomatik başlık,
Türkçe arama, font yardımcıları. `swift test` ile çalıştır.

## Bölünmüş Tipler Hakkında

`NotPenceresi` ve `KenarPaneli` extension'larla dosyalara bölündü. Swift'te
extension'lar farklı dosyalarda olduğu için `private` üyeler görünmez —
dosyalar arası kullanılan üyelerden `private` kaldırıldı (modül içi `internal`).
Yalnızca tek dosyada kullanılanlar `private` kaldı.

`override` yalnızca `@objc` üyelerde extension'a taşınabiliyor;
`NSWindow` alt sınıfı olduğu için `performKeyEquivalent`, `close` vb. çalışıyor.

## İlgili

- [[Mimari-Kararlar]] — bu kodun neden öyle yazıldığı
- [[Markdown-Formati]] — çeviricinin ürettiği biçim
- [[Acik-Isler]] — sıradaki işler
- [[ozet]] — projenin tam analizi
