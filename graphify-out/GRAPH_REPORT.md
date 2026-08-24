# Graph Report - NotDefteri  (2026-08-24)

## Corpus Check
- 37 files · ~80,986 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 511 nodes · 1114 edges · 31 communities (25 shown, 6 thin omitted)
- Extraction: 79% EXTRACTED · 21% INFERRED · 0% AMBIGUOUS · INFERRED: 232 edges (avg confidence: 0.85)
- Token cost: 103,673 input · 0 output

## Community Hubs (Navigation)
- Metin Normalleştirme & Başlık Üretimi
- NotKaydedici Durum Yönetimi
- Görsel Eki & Boyutlandırma
- Markdown Çevirici & Font
- Uygulama Yaşam Döngüsü & LaunchAgent
- Ağaç Veri Kaynağı & Satır Düzenleme
- Başlık Çubuğu Düğmeleri
- Çevirici Sınırları & Açık İşler
- Tema & Renk Türetme
- Sayfa Ağacı Modeli
- Pencere Kurulumu & Tema Uygulama
- Değişiklik Bildirimi & Geri Al
- Ağaç Düğümü & Proje Künyesi
- Sabitler & Modül Bildirimleri
- SF Symbol Boyama
- Sürükle Tutamacı & Fare İzleme
- Yazma Kararı & Sessiz Veri Kaybı
- Arama Alanı & Ad Düzenleme
- Görsel Yapıştırma
- Satır Vurgu Animasyonu
- Kalın & Punto Komutları
- Kaydetme Akışı & Hata Bildirimi
- Eğik Çizgi Komutları & Mimari Kararlar
- Arama Filtresi & Ağaç Gezinme
- Önbellek Darboğazı & URL Tuzağı
- Test Altyapısı & Refactor Kayıtları
- Not Açma & Oluşturma
- Kenar Panel Başlık Çubuğu
- Punto Göstergesi
- Notlar Arası Gezinme
- Paket Bildirimi

## God Nodes (most connected - your core abstractions)
1. `NotPenceresi` - 79 edges
2. `KenarPaneli` - 69 edges
3. `NotKaydedici` - 38 edges
4. `Kod Haritasi` - 33 edges
5. `CeviriciTestleri` - 26 edges
6. `Mimari Kararlar` - 24 edges
7. `AgacDugumu` - 23 edges
8. `BaslikCubugu` - 22 edges
9. `KaydediciTestleri` - 19 edges
10. `markdownMetniUret()` - 18 edges

## Surprising Connections (you probably didn't know these)
- `Otomatik Adlandirma` --conceptually_related_to--> `otomatikBaslikUret()`  [INFERRED]
  ozet.md → Sources/NotDefteri/Cekirdek/MarkdownCevirici.swift
- `Tam Ekran Iki Yoldan` --conceptually_related_to--> `BaslikCubugu`  [INFERRED]
  06_Metadata/Mimari-Kararlar.md → Sources/NotDefteri/Gorunum/BaslikCubugu.swift
- `Gorsel Kendi Satirinda Durur` --rationale_for--> `ResimEki`  [INFERRED]
  06_Metadata/Mimari-Kararlar.md → Sources/NotDefteri/Gorunum/ResimEki.swift
- `.app Paketi Uretmek` --conceptually_related_to--> `notlarKlasoru()`  [AMBIGUOUS]
  01_Projects/Acik-Isler.md → Sources/NotDefteri/Cekirdek/DosyaSistemi.swift
- `Gorsel Bagi ve Cozumleme Sirasi` --conceptually_related_to--> `gorsellerKlasoru()`  [INFERRED]
  03_Resources/Markdown-Formati.md → Sources/NotDefteri/Cekirdek/DosyaSistemi.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Sessiz Veri Kaybi Zinciri ve Duzeltmesi** — 01_projects_acik_isler_sessiz_veri_kaybi, sources_notdefteri_pencere_notpenceresi_kaydetme_kaydeturle, sources_notdefteri_pencere_notpenceresi_kaydetme_kayithatasinibildir, sources_notdefteri_pencere_notpenceresi_pencere_kapanistagerekirsekaydet, sources_notdefteri_cekirdek_notkaydedici_notkaydedici, 06_metadata_mimari_kararlar_ayni_icerigi_tekrar_yazmama [EXTRACTED 1.00]
- **Kenar Panel Arama Yenileme Akisi** — sources_notdefteri_kenarpanel_kenarpaneli_arama_yenile, sources_notdefteri_cekirdek_sayfaagaci_agaciyukle, sources_notdefteri_kenarpanel_kenarpaneli_arama_icerikonbelleginitazele, sources_notdefteri_kenarpanel_kenarpaneli_arama_filtreuygula, sources_notdefteri_cekirdek_metinnormallestirme_aramaicinsadelestir, 01_projects_acik_isler_artimli_onbellek [INFERRED 0.95]
- **Markdown Gidis-Donus Dongusu** — sources_notdefteri_cekirdek_markdowncevirici_markdownmetniuret, sources_notdefteri_cekirdek_markdowncevirici_markdowndenattributedstringuret, 03_resources_markdown_formati_metin_olarak_koruma, 03_resources_markdown_formati_baglam_duyarsiz_parser, 01_projects_acik_isler_eslesmemis_isaretleme, sources_notdefteri_cekirdek_markdowncevirici_kapanisvarmi [EXTRACTED 1.00]

## Communities (31 total, 6 thin omitted)

### Community 0 - "Metin Normalleştirme & Başlık Üretimi"
Cohesion: 0.05
Nodes (21): Foundation, NotDefteri, isaretlemeleriTemizle(), otomatikBaslikUret(), aramaIcinSadelestir(), String, degistirilmeTarihi(), Date (+13 more)

### Community 1 - "NotKaydedici Durum Yönetimi"
Cohesion: 0.11
Nodes (17): Equatable, FileManager, NotKaydedici, .zamanlayiciKurulu, Sonuc, basarisiz, gerekmedi, yazildi (+9 more)

### Community 2 - "Görsel Eki & Boyutlandırma"
Cohesion: 0.10
Nodes (23): NSPoint, NSSize, NSTextAttachment, NSTextAttachmentCell, NSTextContainer, NSTextStorage, resimBaginiCozumle(), ResimEki (+15 more)

### Community 3 - "Markdown Çevirici & Font"
Cohesion: 0.13
Nodes (25): Baslik Punto Carpanlari, Baslik Paragraf Ozniteligi (kBaslikSeviyesiAnahtari), NSAttributedString, NSFont, NSRange, NSString, baslikFontu(), boyutMetni() (+17 more)

### Community 4 - "Uygulama Yaşam Döngüsü & LaunchAgent"
Cohesion: 0.09
Nodes (20): .app Paketi Uretmek, NSApplication, NSApplicationDelegate, NSMenuDelegate, NSObject, Giriste Baslat (LaunchAgent), giristeAcikMi(), giristeAcmayiAyarla() (+12 more)

### Community 5 - "Ağaç Veri Kaynağı & Satır Düzenleme"
Cohesion: 0.11
Nodes (12): NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate, Set, Int, Notification, NSMenu, KenarPaneli (+4 more)

### Community 6 - "Başlık Çubuğu Düğmeleri"
Cohesion: 0.10
Nodes (9): BaslikCubugu, Bool, NSButton, NSCoder, NSEvent, NSRect, NSWindow, String (+1 more)

### Community 7 - "Çevirici Sınırları & Açık İşler"
Cohesion: 0.16
Nodes (20): Acik Isler, Dosya Izleme (DispatchSource), Eslesmemis Isaretleme Hatasi, Kayipli Cevirici Varsayimi, Baglam Duyarsiz Parser, NotDefteri Markdown Lehcesi, Taninmayan Sozdizimini Metin Olarak Koruma, Punto Etiketi (<punto=N>) (+12 more)

### Community 8 - "Tema & Renk Türetme"
Cohesion: 0.22
Nodes (10): Kalici Durum (UserDefaults), Secim Vurgusu Elle Ciziliyor, aramaKutuRengi(), aramaOdakRengi(), NSColor, secimVurguRengi(), CGFloat, String (+2 more)

### Community 9 - "Sayfa Ağacı Modeli"
Cohesion: 0.30
Nodes (11): Sayfa = Kendi Klasoru + index.md, benzersizSayfaURL(), klasorSayfasiMi(), sayfaAdi(), sayfaKlasoru(), sayfayiKlasoreDonustur(), sayfayiYenidenAdlandir(), String (+3 more)

### Community 10 - "Pencere Kurulumu & Tema Uygulama"
Cohesion: 0.16
Nodes (8): NSTextViewDelegate, NSWindow, NSMenuItem, NotPenceresi, .mevcutDosyaURL, .canBecomeKey, .canBecomeMain, URL

### Community 11 - "Değişiklik Bildirimi & Geri Al"
Cohesion: 0.18
Nodes (4): Notification, Any, Bool, NSEvent

### Community 12 - "Ağaç Düğümü & Proje Künyesi"
Cohesion: 0.17
Nodes (9): Bes Katmanli Mimari, Kod Haritasi, Proje Kunyesi (Swift 5.9 / AppKit / macOS 12+), AgacDugumu, .ad, .cocuklarKlasoru, .sayfaMi, Bool (+1 more)

### Community 14 - "SF Symbol Boyama"
Cohesion: 0.18
Nodes (9): NSOutlineView, renklendirilmisSembol(), CGFloat, NSImage, String, Any, Bool, NSTableRowView (+1 more)

### Community 15 - "Sürükle Tutamacı & Fare İzleme"
Cohesion: 0.26
Nodes (5): NSTrackingArea, NSView, KenarPaneliSurukleTutamaci, NSEvent, Void

### Community 16 - "Yazma Kararı & Sessiz Veri Kaybı"
Cohesion: 0.25
Nodes (11): Kayit Yolundaki Sessiz Veri Kaybi, Ayni Icerigi Tekrar Yazmama, Not Degistirirken Gecmis Sifirlanir, Otomatik Kayit: Tek Atimlik Timer, NotKaydedici.yaz(), yazmakGerekli, kaydetURLe(), kayitHatasiniBildir() (+3 more)

### Community 17 - "Arama Alanı & Ad Düzenleme"
Cohesion: 0.20
Nodes (6): NSControl, NSTextField, Selector, Bool, Notification, NSTextView

### Community 18 - "Görsel Yapıştırma"
Cohesion: 0.29
Nodes (6): NSPasteboard, NSTextView, NotMetinGorunumu, Bool, NSImage, String

### Community 19 - "Satır Vurgu Animasyonu"
Cohesion: 0.20
Nodes (6): NSTableRowView, NotSatirGorunumu, .isSelected, Bool, NSCoder, NSRect

### Community 20 - "Kalın & Punto Komutları"
Cohesion: 0.24
Nodes (4): Any, Any, anaMenuyuOlustur(), NSMenu

### Community 21 - "Kaydetme Akışı & Hata Bildirimi"
Cohesion: 0.29
Nodes (3): Bool, String, URL

### Community 22 - "Eğik Çizgi Komutları & Mimari Kararlar"
Cohesion: 0.22
Nodes (10): Gorsel Bagi ve Cozumleme Sirasi, Egik Cizgi Komutlari (/1 /2 /3 /0 /page), Eski Duzen Destegi (Ad.md + Ad/), Gorsel Adi Bolum Basligindan Uretilir, Gorsel Kendi Satirinda Durur, Mimari Kararlar, Ozel Baslik Cubugu, Tam Ekran Iki Yoldan (+2 more)

### Community 24 - "Önbellek Darboğazı & URL Tuzağı"
Cohesion: 0.39
Nodes (9): Agac Taramasi Darbogazi, Artimli Arama Onbellegi Isi, URL.resourceValues Tuzagi (Olcum Sondasi), Artimli Arama Onbellegi, Otomatik Kayitta Panel Yenilenmez, URL.resourceValues Onbellek Tuzagi, agaciYukle(), icerikOnbelleginiTazele() (+1 more)

### Community 25 - "Test Altyapısı & Refactor Kayıtları"
Cohesion: 0.25
Nodes (9): NotKaydedici Cikarimi (Kayit Mantiginin Ayrilmasi), Saf Fonksiyonlara Test Yazmak, Turkce Arama Hatasi (aramaIcinSadelestir), Bolunmus Tipler (Extension ile Dosya Bolme), Test Hedefi (42 Test), Punto Kisayollari Menuden Gecmiyor, Turkce Duyarli Normallestirme, Tanri-Sinif (NotPenceresi) (+1 more)

### Community 27 - "Kenar Panel Başlık Çubuğu"
Cohesion: 0.29
Nodes (4): NSTableColumn, NSButton, NSCoder, NSRect

## Ambiguous Edges - Review These
- `notlarKlasoru()` → `.app Paketi Uretmek`  [AMBIGUOUS]
  01_Projects/Acik-Isler.md · relation: conceptually_related_to
- `Obsidian ile Ayni Klasoru Paylasma Riski` → `Kayipli Cevirici Varsayimi`  [AMBIGUOUS]
  Baslangic.md · relation: conceptually_related_to

## Knowledge Gaps
- **14 isolated node(s):** `PackageDescription`, `yazildi`, `gerekmedi`, `basarisiz`, `.zamanlayiciKurulu` (+9 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `notlarKlasoru()` and `.app Paketi Uretmek`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Obsidian ile Ayni Klasoru Paylasma Riski` and `Kayipli Cevirici Varsayimi`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `NotPenceresi` connect `Pencere Kurulumu & Tema Uygulama` to `NotKaydedici Durum Yönetimi`, `Görsel Eki & Boyutlandırma`, `Markdown Çevirici & Font`, `Uygulama Yaşam Döngüsü & LaunchAgent`, `Ağaç Veri Kaynağı & Satır Düzenleme`, `Başlık Çubuğu Düğmeleri`, `Çevirici Sınırları & Açık İşler`, `Sayfa Ağacı Modeli`, `Değişiklik Bildirimi & Geri Al`, `Sabitler & Modül Bildirimleri`, `Sürükle Tutamacı & Fare İzleme`, `Görsel Yapıştırma`, `Kalın & Punto Komutları`, `Kaydetme Akışı & Hata Bildirimi`, `Eğik Çizgi Komutları & Mimari Kararlar`, `Test Altyapısı & Refactor Kayıtları`, `Not Açma & Oluşturma`, `Punto Göstergesi`, `Notlar Arası Gezinme`?**
  _High betweenness centrality (0.414) - this node is a cross-community bridge._
- **Why does `KenarPaneli` connect `Ağaç Veri Kaynağı & Satır Düzenleme` to `Metin Normalleştirme & Başlık Üretimi`, `Uygulama Yaşam Döngüsü & LaunchAgent`, `Çevirici Sınırları & Açık İşler`, `Tema & Renk Türetme`, `Sayfa Ağacı Modeli`, `Pencere Kurulumu & Tema Uygulama`, `Ağaç Düğümü & Proje Künyesi`, `Sabitler & Modül Bildirimleri`, `SF Symbol Boyama`, `Sürükle Tutamacı & Fare İzleme`, `Arama Alanı & Ad Düzenleme`, `Satır Vurgu Animasyonu`, `Arama Filtresi & Ağaç Gezinme`, `Test Altyapısı & Refactor Kayıtları`, `Kenar Panel Başlık Çubuğu`?**
  _High betweenness centrality (0.298) - this node is a cross-community bridge._
- **Why does `NotKaydedici` connect `NotKaydedici Durum Yönetimi` to `Metin Normalleştirme & Başlık Üretimi`, `Pencere Kurulumu & Tema Uygulama`, `Ağaç Düğümü & Proje Künyesi`, `Yazma Kararı & Sessiz Veri Kaybı`, `Test Altyapısı & Refactor Kayıtları`?**
  _High betweenness centrality (0.168) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `NotPenceresi` (e.g. with `Egik Cizgi Komutlari (/1 /2 /3 /0 /page)` and `NotKaydedici`) actually correct?**
  _`NotPenceresi` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `KenarPaneli` (e.g. with `Kalici Durum (UserDefaults)` and `NSOutlineView`) actually correct?**
  _`KenarPaneli` has 5 INFERRED edges - model-reasoned connections that need verification._