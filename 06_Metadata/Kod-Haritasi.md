---
tags: [kod-haritasi, referans]
guncelleme: 2026-10-10
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
| `YapistirmaBicimlendirme.swift` | 159 | **Dış içeriği nota uydurma** — `disIcerigiNotBicimineCevir()` (RTF/HTML biçimini notun diline indirger), `disMetniNotBicimineCevir()`, `yapistirmaMetniniSadelestir()` |
| `MetinBlogu.swift` | 222 | Blok türü, uyarı kutusu başlığı/kimliği, girinti, kaynak öneki, paragraf öznitelikleri ve yerel liste numaralama |
| `HtmlCevirici.swift` | 109 | Dışa aktarımda mevcut Markdown okuyucusundan kaçırılmış HTML, izinli href, gömülü PNG ve açık/koyu inline CSS üretimi |
| `MarkdownCevirici.swift` | 847 | **Çift yönlü çevirici**: başlık/bloklar, satır içi biçimler, bağlantı/kod/wikilink, paragraf kaynak yazılışı; `sayfaMarkdownunuUret()` üstbilgiyle kaydeder; font yardımcıları; satır parçaları tek seferde birleşir (Linux'ta append karesel), bağ algılayıcı ön elemesi `bagIcerebilir()` |
| `SayfaBaglantilari.swift` | 322 | Sayfa hedefi indeksi, Türkçe bulanık arama, ortak son açılanlar/açılma tarihleri ve değişim geri çağrısı, olmayan yolları düşürme, bağlantı çözümleme ve yeniden yazma; `kodBloguKapanisi()` düzenli ifade yerine satır taraması (kopya yok) |
| `AnaSayfaVerisi.swift` | 143 | UI içermeyen arama önbelleği girdisi (özgün Markdown ve girdiyle bir kez taranan yapılacak satırları dahil), `onbellekGirdisiUret()`; Ana Sayfa için sıralı bekleyen yapılacaklar |
| `Sablonlar.swift` | 26 | Toplantı, günlük ve proje Markdown şablonları; yerel tarihli günlük sayfa adı |
| `Favoriler.swift` | 66 | AppKit’siz sıralı favoriler: göreli yol kaydı, ekle/çıkar/taşı/yolGuncelle ve olmayan dosyaları düşürme |
| `SayfaAgaci.swift` | 445 | `AgacDugumu`, `agaciYukle()`, sayfa taşıma/adlandırma; kardeş sırası `siraUygula()` ile; `SayfaUstbilgisi`, `sayfaUstbilgisiniAyir()`, `ikon:`/`kapak:` satırları bilinmeyen anahtar olarak korunur, `sayfaYolu()`; `klasoruTara()` klasör başına tek listeleme (sayfa mı, tarih, .sira.json aynı listeden) |
| `SayfaSirasi.swift` | 87 | Klasör başına gizli `.sira.json` (`sabitler`/`sira` ad listeleri): okuma, `siraUygula()`, doğrulamalı atomik yazma, yeniden adlandırma/taşıma/silmede ad güncelleme |
| `NotKaydedici.swift` | 111 | **Kayıt mantığı** — yazma kararı, disk yazımı, otomatik kayıt zamanlayıcısı. AppKit'siz, test edilebilir |
| `CopKutusu.swift` | 203 | Uygulama içi `.cop` deposu: metadata, iki düzen için geri alınabilir taşıma, çakışmada köke geri yükleme, yol doğrulamalı kalıcı silme ve 30 günlük temizlik |
| `DosyaSistemi.swift` | 205 | `notlarKlasoru()`, `gorsellerKlasoru()`, LaunchAgent |
| `DosyaAdi.swift` | 69 | `guvenliDosyaAdi()`, `benzersizDosyaYolu()`, `gorselDosyasiniKopyala()` — görsel adlarını Markdown-güvenli yapar |
| `Sabitler.swift` | 25 | `kTabanPunto`, `kMinYaziBoyutu`, `kOtomatikKayitAraligi`… |
| `Ayarlar.swift` | 32 | `UserDefaults` destekli durum: `gTemaIndex`, `gKenarPanelGenislik`, `gYaziBoyutu`, varsayılan açık `gAcilistaAnaSayfa` |
| `MetinNormallestirme.swift` | 18 | `aramaIcinSadelestir()` — Türkçe duyarlı arama |

## Gorunum/ — görünümler

| Dosya | Satır | İçerik |
|---|---|---|
| `AnaSayfa.swift` | 220 | Selamlama/tarih, yatay son açılan/favori kartları, ilk 20 gruplu yapılacak ve hızlı eylemler; tema renkleri |
| `ResimEki.swift` | 225 | `ResimEki`, `ResimEkiHucresi` — sürüklenerek boyutlandırma |
| `BaslikCubugu.swift` | 181 | Özel pencere kontrolleri, tıklanabilir ata sayfa yolu |
| `SayfaSecenekAlani.swift` | 38 | Editör üstündeki ince şerit; hover'da "•••" sayfa seçenekleri düğmesi |
| `NotMetinGorunumu+Bloklar.swift` | 404 | Blok kısayolları, Enter/Tab/Backspace, kutu/çizim; menü aynı paragraf/undo yolunu kullanır |
| `NotMetinGorunumu+Sayfa.swift` | 62 | Artımlı kelime sayımı, kaynak puntoyu koruyan küçük yazı ölçeği |
| `NotMetinGorunumu+SayfaBaglantilari.swift` | 198 | Değişen paragrafta bağlantı işaretleme, geçici renk, [[ tamamlayıcı, tıklama ve undo ile yeniden yazma |
| `CopKutusuPaneli.swift` | 146 | Çöp popover’ı: önbellekte ad arama, sayfa/klasör simgesi ve göreli tarih, geri yükleme, kalıcı silme/boşaltma onayı |
| `HizliBulucu.swift` | 204 | ⌘P ve [[ için ortak AppKit arama/listesi, üst yol ve klavye gezinmesi |
| `NotMetinGorunumu+UyariKutusu.swift` | 181 | Görünür callout çizimi, yerel sınır düzeltme, renk menüsü ve sistem emoji paleti |
| `KagitKaydirici.swift` | 20 | Oluk çizmeyen kaydırma çubuğu; kağıt zemininde beyaz şerit oluşmasın (sistem 'çubukları göster' ayarı) |
| `NotMetinGorunumu.swift` | 759 | `NSTextView` alt sınıfı: görsel/pano işlemleri, slash tuşları, yüzen görünümler, bağlantı tıklaması ve satır içi sayfa bulucu |
| `BlokMenusu.swift` | 253 | Türkçe filtreli blok ve uyarı rengi seçenekleri, klavye gezinmesi ve odağı koruyan çocuk panel |
| `SecimCubugu.swift` | 34 | Seçim üzerinde altı biçim düğmesi; pencerenin biçim komutlarını çağırır |
| `Tema.swift` | 57 | `Tema`, `temaListesi`, `aktifTema`, renk türetme |
| `NotSatirGorunumu.swift` | 59 | Kenar panel satır vurgusu + sürükle-bırak hedefi vurgusu |
| `KenarPaneliSurukleTutamaci.swift` | 38 | Panel genişliği tutamacı |
| `IcindekilerPaneli.swift` | 423 | **Sağ kenar içindekiler** — başlıklardan üretilir, hover'da açılır, tıklayınca kaydırır; kaydırılan bölümün başlığı etkin ve ortada; altında bağlantı veren sayfalar |
| `SembolBoyama.swift` | 22 | `renklendirilmisSembol()` |

## KenarPanel/

| Dosya | Satır | İçerik |
|---|---|---|
| `KenarPaneli.swift` | 398 | Sınıf gövdesi, UI kurulumu, boyut değişince yerleşim; kapalı/geçişteki panelde görünüm güncellemelerini erteleme; Ana Sayfa üst satırı ve açık dosyadan ayrı seçim durumu; altta Çöp kutusu düğmesi |
| `KenarPaneli+AgacVeriKaynagi.swift` | 198 | `NSOutlineView` veri kaynağı + delegesi, hücre üretimi ve önbellekten emoji gösterimi |
| `KenarPaneli+DosyaIslemleri.swift` | 266 | Sayfa ekleme (gizliyken güncel açık notun klasörüne), yeniden adlandırma, silme, sağ tık menüsü (📌 Sabitle), `acikDaliTasindiOlarakIsle()` |
| `KenarPaneli+SurukleBirak.swift` | 182 | **Sürükle-bırak** — üstüne bırak: alt sayfa/köke taşıma; araya bırak: sıra değiştirme (`.sira.json`, sabit bölge sınırı) (`kSayfaSurukleTipi`) |
| `KenarPaneli+Baglantilar.swift` | 27 | Taşınan dal için hedef eşleme; etkilenen dosyaları atomik yazma ve hataları bildirme |
| `KenarPaneli+KisaYollar.swift` | 85 | Katlanabilir Favoriler/Son açılanlar bölümleri, ortak listeden en fazla beş son açılan, açık sayfa vurgusu, ertelenen görünüm güncellemesi, favori menüsü ve çöp popover’ını açma |
| `KenarPaneli+Arama.swift` | 319 | `yenile()`, `suzulmusAgac()`, `filtreUygula()`; içerik önbelleği seri arka plan kuyruğunda nesil kontrolüyle (okuma yolları beklemez, `baglantiOnbelleginiHazirla()` yazma yolları için bekler); artımlı sayfa indeksi; kayıt/açılışta girdi arka planda (`notIceriginiArkaPlandaGuncelle`), ağaçtaki notu taramadan gösterme (`acikNotuGoster`) |

## Pencere/

| Dosya | Satır | İçerik |
|---|---|---|
| `NotPenceresi+Komutlar.swift` | 161 | Blok menüsü komutlarını mevcut biçim/sayfa/görsel işlemlerine bağlama, /0, bağlantı açma, undo/redo |
| `NotPenceresi.swift` | 223 | Sınıf gövdesi, `init`, sayfa üstbilgisi, bul çubuğu, alt bilgi ve görünüm bağlantıları, kenar panel, pencere boyutu izleyicisi |
| `NotPenceresi+Kaydetme.swift` | 184 | `kaydetURLe()`, `otomatikKaydet()` üstbilgiyi korur; timer yönetimi, isim sorma |
| `NotPenceresi+Pencere.swift` | 177 | Notlar arası gezinme; panel/editör için ortak yerleşim, 0,2 sn geçiş ve nesil kontrolü; `performKeyEquivalent`, kapatma |
| `NotPenceresi+Bicimlendirme.swift` | 187 | Kalın/italik/çizili/kod/vurgu/bağlantı, punto, tema, seçim çubuğu; kaydırmada etkin içindekiler başlığı |
| `NotPenceresi+Baglantilar.swift` | 80 | Bulucuyu açma, olmayan hedefi oluşturma onayı, önbellekten geri bağlantı debounce ve açık editörü güncelleme |
| `NotPenceresi+AnaSayfa.swift` | 199 | Kayıtla Ana Sayfa geçişi; kaynak konumundan editöre gitme; atomik yapılacak tamamlama, günlük ve şablondan oluşturma |
| `NotPenceresi+Not.swift` | 238 | `notuAc()`, `yeniSayfaOlustur()`; üstbilgiyi gövdeden ayırma, sayfa seçenekleri undo ve sayfa yolu |
| `NotPenceresi+SayfaSecenekleri.swift` | 148 | Görünüm seçenekleri, ••• menüsü ve dışa aktarım komutları, frontmatter/undo bağlantısı, alt bilgi debounce |
| `NotPenceresi+DisaAktar.swift` | 133 | NSPrintOperation ile A4 PDF, tek dosya HTML, kaynak Markdown ve görsel kopyalama, Markdown panosu; kayıt ve aktarım hataları |
| `NotPenceresi+Yapistirma.swift` | 14 | `hamYapistirKomutu()` — ⇧⌘V, kaynak biçimini koruyan yapıştırma |
| `NotPenceresi+Gorsel.swift` | 127 | `gorseliDiskeYaz()`, `gorseliKopyala()`, `kopyalananIcerigiHazirla()` |

## Uygulama/

| Dosya | Satır | İçerik |
|---|---|---|
| `Menu.swift` | 166 | `anaMenuyuOlustur()`: menü, biçim kısayolları, ⌘P sayfa bulucu, Git > Ana Sayfa (⌘⇧H), açılış tercihi, Dosya > Çöp kutusu; vurgu ⌘⌥H |
| `Ana.swift` | 67 | `UygulamaDelegesi`, `@main enum Ana`; açılışta arka planda eski çöpleri temizleme |

## Testler

`swift test` platforma uygun hedefleri çalıştırır; CI her PR'da macOS ve Linux'ta koşar.

**`Tests/NotDefteriCekirdekTests/`** — AppKit'siz, macOS ve Linux'ta koşar

| Alan | Dosyalar |
|---|---|
| Ortak temel | `GeciciKokTestCase` — her test geçici kökte, `NOTDEFTERI_KOK` oraya ayarlı; gerçek notlara dokunmaz |
| Markdown | `CeviriciTestleri` 24, `MetinBloguTestleri` 14, `YapiEnterTestleri` 10, `KodVurgulayiciTestleri` 11, `SablonTestleri` 6 |
| Sayfa ağacı ve dosya sistemi | `SayfaAgaciTestleri` 24, `CopKutusuTestleri` 14, `SayfaSirasiTestleri` 13, `DosyaSistemiTestleri` 12, `DosyaAdiTestleri` 11, `SayfaDosyalariTestleri` 10 |
| Bağlantı, arama, Ana Sayfa | `SayfaBaglantilariTestleri` 17, `AnaSayfaVerisiTestleri` 11, `FavorilerTestleri` 10, `OnbellekTestleri` 6 |
| Kayıt, geçmiş, dışa aktarım | `KaydediciTestleri` 13, `HtmlCeviriciTestleri` 12, `SayfaGecmisiTestleri` 10, `MarkdownDisaAktarTestleri` 7, `PerformansTestleri` 4 |

**`Tests/NotDefteriMacTests/`** — AppKit, yalnızca macOS

| Alan | Dosyalar |
|---|---|
| Editör | `EditorTestleri` 16 — editör `NotPenceresi` gibi kurulur, klavyeden yazılmış gibi sürülür |
| Görünüm adaptörü | `BelgeAdaptoruTestleri` 9, `FontTestleri` 3, `IcindekilerTestleri` 9 |
| Yapıştırma ve kopyalama | `YapistirmaTestleri` 12, `KopyalamaTestleri` 6, `YapistirmaDonmaTestleri` 2 |
| Taşıma ve adlandırma | `YenidenAdlandirmaTestleri` 15, `TasimaTestleri` 12, `GorselBagiTestleri` 5 |
| Arayüz bileşenleri | `ArayuzBilesenleriTestleri` 13 — tema, "/" blok menüsü, ⌘P bulucu |

Test yazarken: dosya sistemine dokunan çekirdek testi `GeciciKokTestCase`'ten türet. AppKit sarmalayıcıları
(`sayfayiYenidenAdlandir` vb.) hata olunca `NSAlert.runModal()` açar ve testi kilitler; çekirdek fonksiyonu `kok:` ile çağır.

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

## Tema, tablo ve Linux bütünleşmesi

- `Cekirdek/Tablo.swift`, `TabloModeli.swift`: tablo üretimi, hücre kaynak yazılışı ve Markdown/görsel aralık eşlemesi.
- `Cekirdek/ArkaPlanYenileyici.swift`: nesil kontrolüyle arka planda ağaç yenileme.
- `Cekirdek/KullanimKilavuzu.swift`: ortak kullanım kılavuzu içeriği.
- `Gorunum/NotMetinGorunumu+Tablolar.swift`: AppKit yerel hücre editörü, gezinme ve belge geri alma yolu.
- `Uygulama/Menu.swift`: ana menü ve not/ana sayfa/kenar panel için ortak Görünüm bağlam alt menüsü.
- `Sources/NotDefteriLinux/LinuxTablolar.swift`: GTK hücre editörü, konumlandırma ve kayıt/geri alma.
- `Sources/NotDefteriLinux/LinuxTamEkranKontrolleri.swift`: tam ekran kontrol görünürlüğü.
- `Tests/NotDefteriMacTests/GorunumBaglamMenusuTestleri.swift`, `TabloDuzenlemeTestleri.swift`: sağ tık tema ve hücre düzenleme regresyonları.
- `Tests/NotDefteriLinuxTests/GrafikTestOrtami.swift`: tüm grafik testleri için tek GTK başlatma ve gerçek ekran denetimi.
- `Tests/NotDefteriCekirdekTests/Tablo*`, `KodBloguEnterTestleri`, `TemaAyarlariTestleri`: tablo kaynağı, açık kod çıkışı ve tema ayarı geçişi.
