---
tags: [analiz, genel-bakis]
guncelleme: 2026-08-24
---

# NotDefteri — Proje Analizi

_Analiz tarihi: 2026-08-24_

## 1. Genel Bakış

macOS için yazılmış, **tek dosyalık** (2560 satır) native bir not defteri uygulaması.
Saf AppKit; hiçbir üçüncü parti bağımlılık yok. Notlar diskte **düz Markdown**
dosyaları olarak tutulur — yani veri formatı zaten Obsidian'a çok yakın.

| | |
|---|---|
| Dil / Araç | Swift 5.9, SwiftPM (`swift-tools-version:5.9`) |
| Hedef | `.executableTarget` — `NotDefteri` |
| Platform | macOS 12+ |
| Framework | Yalnızca `AppKit` |
| Kaynak | `Sources/NotDefteri/` (26 dosya, 5 katman) |
| Bağımlılık | Yok |
| Veri konumu | `~/Documents/NotDefteri/` |
| Kod dili | Tüm tanımlayıcılar Türkçe (`NotPenceresi`, `agaciYukle()`, `kenarPaneli`…) |

## 2. Mimari

Katmansız, tek dosyada MARK bölümleriyle ayrılmış klasik AppKit yapısı.
Bağımlılıklar yukarıdan aşağı akar; iletişim **closure callback**'lerle yapılır
(protokol/delege soyutlaması yok).

```
UygulamaDelegesi (NSApplicationDelegate)
└── NotPenceresi (NSWindow, NSTextViewDelegate)      ← merkez düğüm
    ├── BaslikCubugu (NSView)                        özel başlık çubuğu
    ├── KenarPaneli (NSView + NSOutlineView)         arama + sayfa ağacı
    │   └── AgacDugumu                               sayfa/klasör modeli
    ├── KenarPaneliSurukleTutamaci (NSView)          panel genişliği
    └── NSScrollView
        └── NotMetinGorunumu (NSTextView)            editör
            └── ResimEki / ResimEkiHucresi           gömülü görseller
```

`graphify-out/GRAPH_REPORT.md` de aynı sonucu veriyor: en bağlantılı düğümler
`NotPenceresi` (71 kenar) ve `KenarPaneli` (62 kenar); 241 düğüm, 732 kenar,
7 topluluk, import döngüsü yok.

### Sorumluluk dağılımı

| Bileşen | Satır | Sorumluluk |
|---|---|---|
| Tema + renk yardımcıları | 1–95 | 4 kağıt teması, renk koyulaştırma, SF Symbol boyama |
| Dosya sistemi | 97–156 | Notlar klasörü, Görseller klasörü, LaunchAgent |
| Markdown ↔ AttributedString | 158–369 | Kendi yazılmış çift yönlü dönüştürücü |
| Görsel eki | 371–509 | Köşeden sürükleyerek boyutlandırılabilir gömülü resim |
| `NotMetinGorunumu` | 513–582 | Yapıştırma/sürükleme ile görsel ekleme |
| `BaslikCubugu` | 586–721 | Özel pencere kontrolleri (sabitle, kapat, geri/ileri) |
| Sayfa ağacı modeli | 769–935 | Klasör tarama, yeniden adlandırma, göç |
| `KenarPaneli` | 939–1646 | Ağaç görünümü, arama, sağ tık menüsü, punto/başlık çubuğu |
| `NotPenceresi` | 1686–2445 | Tüm iş mantığının koordinasyonu |
| Menü + giriş noktası | 2449–2560 | Ana menü, `NSApplication` başlatma |

## 3. Veri Modeli — Bu Bölüm Obsidian İçin Kritik

### Sayfa düzeni (yeni)

```
~/Documents/NotDefteri/
  SSRF/
    index.md          ← sayfanın metni
    Görseller/        ← bu sayfanın resimleri
    Örnekler/         ← alt sayfa (aynı yapıda, özyinelemeli)
      index.md
```

### Eski düzen (hâlâ destekleniyor)

```
  SSRF.md             ← düz not
  SSRF/               ← alt sayfaları ve görselleri
```

`agaciYukle()` her iki düzeni birden tarar; sağ tık → "Sayfa Klasörüne Dönüştür"
eskiyi yeniye taşır. `~/Documents/NotDefteri/` şu an **karışık durumda** —
hem `SSRFNOT.md` hem `SSRFNOT/` klasörü, ayrıca eski `ekler/` klasörü var.

### Markdown lehçesi

| Özellik | Sözdizimi | Obsidian uyumu |
|---|---|---|
| Başlık 1–3 | `# `, `## `, `### ` | ✅ Standart |
| Kalın | `**metin**` | ✅ Standart |
| Görsel | `![](Görseller/Başlık1.png){320x240}` | ⚠️ `{ExY}` soneki Obsidian'da **görünür metin** olarak kalır |
| Punto | `<punto=16>metin</punto>` | ❌ Obsidian'da ham HTML gibi görünür / bilinmeyen etiket |

Yani dosyalar %90 standart Markdown; iki özel uzantı var.

## 4. Özellikler

- **Editör**: zengin metin, kalın (⌘B), 10–28 pt punto (⌘+/⌘−), 3 seviye başlık
- **Eğik çizgi komutları**: satır başında `/1 /2 /3 /0` (başlık düzeyi),
  `/page` veya `/sayfa` (o sayfanın altına alt sayfa açar) + boşluk/Enter
- **Görseller**: panodan yapıştır veya Finder'dan sürükle → PNG olarak
  `Görseller/` altına yazılır; dosya adı bulunduğu **bölümün başlığından** üretilir
  (`Başlık1.png`, `Başlık1-2.png`). Köşedeki tutamaçtan oran korunarak boyutlandırılır
- **Kenar panel**: özyinelemeli sayfa ağacı, Türkçe-duyarlı arama
  (`folding` + `tr_TR` locale ile içerik + isim araması), yerinde yeniden adlandırma,
  sağ tık menüsü (alt sayfa / kardeş sayfa / yeniden adlandır / sil / dönüştür)
- **Otomatik kayıt**: 5 sn'lik tek atımlık timer, sadece değişiklik varken kurulur;
  pencere odağı kaybettiğinde ve çıkışta da yazar
- **Otomatik adlandırma**: kaydedilmemiş notun dosya adı ilk satırdan üretilir ve
  ilk satır değiştikçe dosya adı da takip eder
- **Silme**: `trashItem` ile Çöp Kutusu'na (kalıcı silme yok) — onay diyaloğu var
- **Pencere**: özel başlık çubuğu, her zaman üstte (pin), tam ekran (Fn+F / ⌃⌘F)
- **Temalar**: Sepya, Yeşilimsi Kağıt, Gri Kağıt, Krem — `UserDefaults`'ta saklanır
- **Girişte başlat**: `~/Library/LaunchAgents/com.notdefteri.baslangic.plist` yazıp
  `launchctl load -w` çağırır
- **Kalıcı durum** (`UserDefaults`): `temaIndex`, `kenarPanelGenislik`,
  `kenarPanelGizli`, `sonNotYolu`, `acikKlasorler`

### Kısayollar

| Tuş | İşlev |
|---|---|
| ⌘S | Kaydet |
| ⌘Z / ⌘Y / ⇧⌘Z | Geri al / Yinele |
| ⌘B | Kalın |
| ⌘* ⌘+ ⌘= / ⌘− ⌘_ | Punto büyüt / küçült |
| ⌘[ / ⌘] | Önceki / sonraki not |
| ⌃⌘F veya Fn+F | Tam ekran |
| ⌘Q | Çık (kaydeder) |

Punto kısayolları `performKeyEquivalent` içinde elle yakalanıyor — çünkü Türkçe Q
klavyede `*` shift'siz üretiliyor ve menü eşleşmesi kaçıyor.

## 5. Dikkate Değer Teknik Kararlar

1. **Sabit taban punto** (`kTabanPunto = 14`): dosyaya yalnızca tabandan farklı
   puntolar `<punto=..>` ile yazılır. Böylece yeniden derleme/açılışta punto kaymaz.
2. **Görsel kendi satırında**: aynı satırda metinle paylaşırsa satır yüksekliği
   görsel kadar olacağı için ek eklenirken önüne/arkasına `\n` konur.
3. **`cellFrame(for:...)` sığdırma**: görsel satıra sığmazsa oran korunarak
   küçültülür ama **saklanan boyut değişmez** — pencere genişleyince eski boyuta döner.
4. **Otomatik kayıtta panel yenilememe**: aynı dosyaya yazarken kenar panel
   tazelenmez, çünkü panel tüm notların içeriğini yeniden okur (arama önbelleği).
5. **Türkçe arama**: `İ/I/ı` ve `ö ü ş ç ğ` doğru eşleşsin diye
   `folding(options: [.diacriticInsensitive, .caseInsensitive], locale: tr_TR)`.
6. **Not değiştirirken `gecmisiSifirla()`**: yoksa ⌘Z önceki notun içeriğini
   şu ankinin üzerine geri getirir.

## 6. Zayıf Noktalar / Riskler

| # | Konu | Etki |
|---|---|---|
| 1 | **Tek dosya, 2560 satır** | Bakım zorluğu; `NotPenceresi` 760 satır ile tanrı-sınıf |
| 2 | **Hata yutma** | Neredeyse tüm dosya işlemleri `try?` — disk hatası sessizce kaybolur |
| 3 | **Test yok** | Hiç test hedefi yok; Markdown çevirici gibi kritik saf fonksiyonlar test edilebilir olmasına rağmen |
| 4 | **Arama önbelleği** | `yenile()` her seferinde **tüm** notları diskten okur — O(n) I/O; birkaç yüz notta hissedilir |
| 5 | **Çoklu pencere yok** | Tek `NotPenceresi`; kapanınca uygulama sonlanır |
| 6 | **`.app` paketi yok** | SwiftPM çıktısı çıplak ikili; imzasız, `Info.plist`'siz — LaunchAgent doğrudan ikiliyi çağırıyor |
| 7 | **Sınırlı Markdown** | Liste, tablo, kod bloğu, bağlantı, italik, alıntı, onay kutusu **yok** — açılınca düz metin gibi görünür ve **kaydedince kaybolabilir** |
| 8 | **Kendine özgü etiketler** | `<punto=..>` ve `{320x240}` standart dışı |
| 9 | **Dosya izleme yok** | Dosya dışarıdan değişirse uygulama fark etmez, üstüne yazar |

## 7. Obsidian Kurulumu İçin Değerlendirme

### İyi haber

`~/Documents/NotDefteri/` klasörü **doğrudan bir Obsidian vault olarak açılabilir**.
Notlar UTF-8 Markdown, klasör hiyerarşisi Obsidian'ın klasör ağacıyla birebir eşleşir,
görseller göreli yollarla bağlı.

### Çakışma noktaları (önem sırasına göre)

1. **⚠️ En kritik — çift yönlü çalışma veri kaybettirir.**
   NotDefteri kaydederken metni AttributedString'den **yeniden üretir**
   (`markdownMetniUret`). Obsidian'da eklenen liste, tablo, kod bloğu, italik,
   `[[bağlantı]]`, YAML frontmatter gibi her şey NotDefteri'nde düz metne dönüşür
   ve o notu NotDefteri'nde kaydedince **biçim kalıcı olarak kaybolur.**
   → Aynı vault'ta iki uygulamayı birlikte kullanacaksan: **önce yedek al**,
   ya da her not için tek bir uygulamada çalış.

2. **`<punto=14>` etiketleri** Obsidian'da çirkin görünür.
   Temizlemek için: `grep -rl '<punto=' ~/Documents/NotDefteri` ile bul,
   `sed -E 's/<\/?punto[^>]*>//g'` ile sil (kaybolan tek şey punto bilgisi).

3. **Görsel boyut soneki** `![](Görseller/x.png){320x240}` →
   Obsidian'ın kendi sözdizimi `![[x.png|320]]` ya da `![](x.png)` +
   `{320x240}` metni ekranda kalır. Toplu dönüştürme mümkün.

4. **`index.md` düzeni**: Obsidian bu klasörleri "boş klasör + içinde index" gibi
   gösterir; ağaç görünümünde sayfa adı yerine klasör adı + `index` alt öğesi çıkar.
   Obsidian'da daha doğal olan düzen `SSRF.md` + `SSRF/` (yani NotDefteri'nin
   **eski** düzeni). Ya bu düzende kal, ya da Obsidian'ın "Folder note" eklentisini kur.

5. **Karışık durum**: `~/Documents/NotDefteri/` içinde şu an hem eski hem yeni
   düzen var (`SSRFNOT.md` + `SSRFNOT/`), ayrıca `ekler/`, `.pptx`, `.html`
   dosyaları duruyor. Vault açmadan önce toparlamak gerekir.

6. **`.obsidian/` klasörü**: gizli olduğu için `agaciYukle()` onu
   `.skipsHiddenFiles` ile zaten atlar. ✅ Sorun yok.

### Önerilen yol

| Senaryo | Öneri |
|---|---|
| **Obsidian'a tam geçiş** | Vault'u `~/Documents/NotDefteri` üzerinde aç, `<punto=>` etiketlerini ve `{ExY}` soneklerini toplu temizle, NotDefteri'ni artık açma |
| **İkisi birlikte** | Ayrı bir vault klasörü kullan; NotDefteri notlarını oraya kopyala. Aynı klasörü paylaşmak riskli (madde 1) |
| **NotDefteri'ni Obsidian-uyumlu yapmak** | `markdownMetniUret()`'i "tanımadığı sözdizimini olduğu gibi koru" mantığıyla yeniden yaz + `<punto=>` yerine standart bir gösterim seç. Kayda değer bir iş ama en temiz çözüm |

## 8. Derleme

```bash
swift build -c release
.build/release/NotDefteri
```

`.app` paketi üretilmiyor; Dock'ta düzgün görünmesi ve imzalanması için
`Info.plist` + bundle yapısı eklemek gerekir.
