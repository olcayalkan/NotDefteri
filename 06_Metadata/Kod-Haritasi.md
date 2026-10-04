---
tags: [kod-haritasi, referans]
guncelleme: 2026-08-28
kaynak: Sources/NotDefteri/
---

# Kod Haritası

Kaynak dosyaları 5 katmanda bulunur.
**Satır numarası vermiyoruz** — dosyalar küçük, adı bilmek yetiyor.

## Katmanlar

```
Cekirdek/     UI'dan bağımsız mantık — test edilebilir
Gorunum/      AppKit görünümleri
KenarPanel/   Kenar panel (KenarPaneli ve extension dosyaları)
Pencere/      Ana pencere (NotPenceresi ve extension dosyaları)
Uygulama/     Yaşam döngüsü ve menü
```

Bağımlılık yönü: `Uygulama → Pencere → KenarPanel → Gorunum → Cekirdek`

## Cekirdek/ — mantık

| Dosya | Satır | İçerik |
|---|---|---|
| `YapistirmaBicimlendirme.swift` | 175 | **Dış içeriği nota uydurma** — `disIcerigiNotBicimineCevir()` (RTF/HTML biçimini notun diline indirger), `disMetniNotBicimineCevir()`, `yapistirmaMetniniSadelestir()` |
| `MetinBlogu.swift` | 186 | Blok türü, uyarı kutusu başlığı/kimliği, girinti, kaynak öneki, paragraf öznitelikleri ve yerel liste numaralama |
| `HtmlCevirici.swift` | 103 | Dışa aktarımda mevcut Markdown okuyucusundan kaçırılmış HTML, izinli href, gömülü PNG ve açık/koyu inline CSS üretimi |
| `MarkdownCevirici.swift` | 694 | **Çift yönlü çevirici**: başlık/bloklar, satır içi biçimler, bağlantı/kod/wikilink, paragraf kaynak yazılışı; `sayfaMarkdownunuUret()` üstbilgiyle kaydeder; font yardımcıları |
| `SayfaBaglantilari.swift` | 223 | Sayfa hedefi indeksi, Türkçe bulanık arama, ortak son açılanlar/açılma tarihleri ve değişim geri çağrısı, olmayan yolları düşürme, bağlantı çözümleme ve yeniden yazma |
| `AnaSayfaVerisi.swift` | 83 | UI içermeyen arama önbelleği girdisi (özgün Markdown ve girdiyle bir kez taranan yapılacak satırları dahil), `onbellekGirdisiUret()`; Ana Sayfa için sıralı bekleyen yapılacaklar |
| `Sablonlar.swift` | 26 | Toplantı, günlük ve proje Markdown şablonları; yerel tarihli günlük sayfa adı |
| `Favoriler.swift` | 66 | AppKit’siz sıralı favoriler: göreli yol kaydı, ekle/çıkar/taşı/yolGuncelle ve olmayan dosyaları düşürme |
| `SayfaAgaci.swift` | 388 | `AgacDugumu`, `agaciYukle()`, sayfa taşıma/adlandırma; kardeş sırası `siraUygula()` ile; `SayfaUstbilgisi`, `sayfaUstbilgisiniAyir()`, `ikon:`/`kapak:` satırları bilinmeyen anahtar olarak korunur, `sayfaYolu()` |
| `SayfaSirasi.swift` | 100 | Klasör başına gizli `.sira.json` (`sabitler`/`sira` ad listeleri): okuma, `siraUygula()`, doğrulamalı atomik yazma, yeniden adlandırma/taşıma/silmede ad güncelleme |
| `NotKaydedici.swift` | 114 | **Kayıt mantığı** — yazma kararı, disk yazımı, otomatik kayıt zamanlayıcısı. AppKit'siz, test edilebilir |
| `CopKutusu.swift` | 217 | Uygulama içi `.cop` deposu: metadata, iki düzen için geri alınabilir taşıma, çakışmada köke geri yükleme, yol doğrulamalı kalıcı silme ve 30 günlük temizlik |
| `DosyaSistemi.swift` | 62 | `notlarKlasoru()`, `gorsellerKlasoru()`, LaunchAgent |
| `DosyaAdi.swift` | 69 | `guvenliDosyaAdi()`, `benzersizDosyaYolu()`, `gorselDosyasiniKopyala()` — görsel adlarını Markdown-güvenli yapar |
| `Sabitler.swift` | 28 | `kTabanPunto`, `kMinYaziBoyutu`, `kOtomatikKayitAraligi`… |
| `Ayarlar.swift` | 28 | `UserDefaults` destekli durum: `gTemaIndex`, `gKenarPanelGenislik`, `gYaziBoyutu`, varsayılan açık `gAcilistaAnaSayfa` |
| `MetinNormallestirme.swift` | 18 | `aramaIcinSadelestir()` — Türkçe duyarlı arama |

## Gorunum/ — görünümler

| Dosya | Satır | İçerik |
|---|---|---|
| `AnaSayfa.swift` | 222 | Selamlama/tarih, yatay son açılan/favori kartları, ilk 20 gruplu yapılacak ve hızlı eylemler; tema renkleri |
| `ResimEki.swift` | 212 | `ResimEki`, `ResimEkiHucresi` — sürüklenerek boyutlandırma |
| `BaslikCubugu.swift` | 180 | Özel pencere kontrolleri, tıklanabilir ata sayfa yolu |
| `SayfaSecenekAlani.swift` | 37 | Editör üstündeki ince şerit; hover'da "•••" sayfa seçenekleri düğmesi |
| `NotMetinGorunumu+Bloklar.swift` | 438 | Blok kısayolları, Enter/Tab/Backspace, kutu/çizim; menü aynı paragraf/undo yolunu kullanır |
| `NotMetinGorunumu+Sayfa.swift` | 73 | Artımlı kelime sayımı, kaynak puntoyu koruyan küçük yazı ölçeği |
| `NotMetinGorunumu+SayfaBaglantilari.swift` | 149 | Değişen paragrafta bağlantı işaretleme, geçici renk, [[ tamamlayıcı, tıklama ve undo ile yeniden yazma |
| `CopKutusuPaneli.swift` | 149 | Çöp popover’ı: önbellekte ad arama, sayfa/klasör simgesi ve göreli tarih, geri yükleme, kalıcı silme/boşaltma onayı |
| `HizliBulucu.swift` | 203 | ⌘P ve [[ için ortak AppKit arama/listesi, üst yol ve klavye gezinmesi |
| `NotMetinGorunumu+UyariKutusu.swift` | 171 | Görünür callout çizimi, yerel sınır düzeltme, renk menüsü ve sistem emoji paleti |
| `NotMetinGorunumu.swift` | 554 | `NSTextView` alt sınıfı: görsel/pano işlemleri, slash tuşları, yüzen görünümler, bağlantı tıklaması ve satır içi sayfa bulucu |
| `BlokMenusu.swift` | 166 | Türkçe filtreli blok ve uyarı rengi seçenekleri, klavye gezinmesi ve odağı koruyan çocuk panel |
| `SecimCubugu.swift` | 33 | Seçim üzerinde altı biçim düğmesi; pencerenin biçim komutlarını çağırır |
| `Tema.swift` | 53 | `Tema`, `temaListesi`, `aktifTema`, renk türetme |
| `NotSatirGorunumu.swift` | 58 | Kenar panel satır vurgusu + sürükle-bırak hedefi vurgusu |
| `KenarPaneliSurukleTutamaci.swift` | 37 | Panel genişliği tutamacı |
| `IcindekilerPaneli.swift` | 410 | **Sağ kenar içindekiler** — başlıklardan üretilir, hover'da açılır, tıklayınca kaydırır; altında bağlantı veren sayfalar |
| `SembolBoyama.swift` | 21 | `renklendirilmisSembol()` |

## KenarPanel/

| Dosya | Satır | İçerik |
|---|---|---|
| `KenarPaneli.swift` | 392 | Sınıf gövdesi, UI kurulumu, boyut değişince yerleşim; kapalı/geçişteki panelde görünüm güncellemelerini erteleme; Ana Sayfa üst satırı ve açık dosyadan ayrı seçim durumu; altta Çöp kutusu düğmesi |
| `KenarPaneli+AgacVeriKaynagi.swift` | 209 | `NSOutlineView` veri kaynağı + delegesi, hücre üretimi ve önbellekten emoji gösterimi |
| `KenarPaneli+DosyaIslemleri.swift` | 244 | Sayfa ekleme (gizliyken güncel açık notun klasörüne), yeniden adlandırma, silme, sağ tık menüsü (📌 Sabitle), `acikDaliTasindiOlarakIsle()` |
| `KenarPaneli+SurukleBirak.swift` | 116 | **Sürükle-bırak** — üstüne bırak: alt sayfa/köke taşıma; araya bırak: sıra değiştirme (`.sira.json`, sabit bölge sınırı) (`kSayfaSurukleTipi`) |
| `KenarPaneli+Baglantilar.swift` | 46 | Taşınan dal için hedef eşleme; etkilenen dosyaları atomik yazma ve hataları bildirme |
| `KenarPaneli+KisaYollar.swift` | 93 | Katlanabilir Favoriler/Son açılanlar bölümleri, ortak listeden en fazla beş son açılan, açık sayfa vurgusu, ertelenen görünüm güncellemesi, favori menüsü ve çöp popover’ını açma |
| `KenarPaneli+Arama.swift` | 297 | `yenile()`, `suzulmusAgac()`, `filtreUygula()`; içerik önbelleği seri arka plan kuyruğunda nesil kontrolüyle (okuma yolları beklemez, `baglantiOnbelleginiHazirla()` yazma yolları için bekler); artımlı sayfa indeksi |

## Pencere/

| Dosya | Satır | İçerik |
|---|---|---|
| `NotPenceresi+Komutlar.swift` | 160 | Blok menüsü komutlarını mevcut biçim/sayfa/görsel işlemlerine bağlama, /0, bağlantı açma, undo/redo |
| `NotPenceresi.swift` | 221 | Sınıf gövdesi, `init`, sayfa üstbilgisi, bul çubuğu, alt bilgi ve görünüm bağlantıları, kenar panel, pencere boyutu izleyicisi |
| `NotPenceresi+Kaydetme.swift` | 179 | `kaydetURLe()`, `otomatikKaydet()` üstbilgiyi korur; timer yönetimi, isim sorma |
| `NotPenceresi+Pencere.swift` | 174 | Notlar arası gezinme; panel/editör için ortak yerleşim, 0,2 sn geçiş ve nesil kontrolü; `performKeyEquivalent`, kapatma |
| `NotPenceresi+Bicimlendirme.swift` | 188 | Kalın/italik/çizili/kod/vurgu/bağlantı, punto, tema ve seçim çubuğu |
| `NotPenceresi+Baglantilar.swift` | 75 | Bulucuyu açma, olmayan hedefi oluşturma onayı, önbellekten geri bağlantı debounce ve açık editörü güncelleme |
| `NotPenceresi+AnaSayfa.swift` | 183 | Kayıtla Ana Sayfa geçişi; kaynak konumundan editöre gitme; atomik yapılacak tamamlama, günlük ve şablondan oluşturma |
| `NotPenceresi+Not.swift` | 176 | `notuAc()`, `yeniSayfaOlustur()`; üstbilgiyi gövdeden ayırma, sayfa seçenekleri undo ve sayfa yolu |
| `NotPenceresi+SayfaSecenekleri.swift` | 110 | Görünüm seçenekleri, ••• menüsü ve dışa aktarım komutları, frontmatter/undo bağlantısı, alt bilgi debounce |
| `NotPenceresi+DisaAktar.swift` | 181 | NSPrintOperation ile A4 PDF, tek dosya HTML, kaynak Markdown ve görsel kopyalama, Markdown panosu; kayıt ve aktarım hataları |
| `NotPenceresi+Yapistirma.swift` | 13 | `hamYapistirKomutu()` — ⇧⌘V, kaynak biçimini koruyan yapıştırma |
| `NotPenceresi+Gorsel.swift` | 150 | `gorseliDiskeYaz()`, `gorseliKopyala()`, `kopyalananIcerigiHazirla()` |

## Uygulama/

| Dosya | Satır | İçerik |
|---|---|---|
| `Menu.swift` | 135 | `anaMenuyuOlustur()`: menü, biçim kısayolları, ⌘P sayfa bulucu, Git > Ana Sayfa (⌘⇧H), açılış tercihi, Dosya > Çöp kutusu; vurgu ⌘⌥H |
| `Ana.swift` | 61 | `UygulamaDelegesi`, `@main enum Ana`; açılışta arka planda eski çöpleri temizleme |

## Testler

`Tests/NotDefteriTests/` — 110 test (`CeviriciTestleri` 23, `YenidenAdlandirmaTestleri` 15, `KaydediciTestleri` 13, `YapistirmaTestleri` 12, `TasimaTestleri` 12, `DosyaAdiTestleri` 10, `IcindekilerTestleri` 8, `OnbellekTestleri` 6, `KopyalamaTestleri` 6, `GorselBagiTestleri` 5).
Kapsam: gidiş-dönüş çevirici, işaret temizleme, punto sınırlama, otomatik başlık,
Türkçe arama, font yardımcıları, dış içeriğin nota uydurulması, sayfa taşıma. `swift test` ile çalıştır.

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
