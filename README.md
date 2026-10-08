# Not Defteri

macOS ve Linux için sade, hızlı, Markdown tabanlı bir not uygulaması.

Notlar sıradan `.md` dosyaları olarak diskte durur. Uygulamayı silsen de notların
okunabilir kalır; Obsidian, VS Code ya da herhangi bir metin düzenleyiciyle açılabilir.

- **macOS:** saf AppKit, bağımlılık yok
- **Linux:** GTK 4 (Ubuntu 22.04'te denendi)
- **Dil:** Swift 5.9, SwiftPM

---

## Özellikler

- **Sayfa ağacı.** Her sayfanın altında alt sayfalar olabilir. Sürükle-bırakla taşınır ve sıralanır.
- **Biçimli düzenleme.** Kalın, italik, üstü çizili, satır içi kod, vurgu, başlıklar, listeler,
  yapılacaklar, alıntı, kod bloğu, uyarı kutusu, ayırıcı, görsel.
- **`/` blok menüsü.** Satır başında `/` yazınca blok türü seçilir.
- **Sayfa bağları.** `[[Sayfa adı]]` yazınca diğer sayfaya bağ kurulur. Sayfa taşınıp
  adlandırılınca bağlar kendiliğinden güncellenir. Her sayfanın altında ona bağ veren sayfalar listelenir.
- **İçindekiler.** Sağ kenarda başlıklardan oluşan yüzen bir panel. Okuduğun bölüm vurgulanır,
  tıklayınca o başlığa gider.
- **Hızlı sayfa bulucu** (`⌘P` / `Ctrl+P`): Türkçe karakterlere duyarsız arama
  ("istanbul" yazınca "İstanbul" da bulunur).
- **Ana Sayfa.** Son açılan sayfalar, tüm notlardaki bekleyen yapılacaklar, hızlı eylemler
  (yeni sayfa, günlük not, şablondan sayfa).
- **Otomatik kayıt.** Yazmayı bıraktıktan 5 sn sonra kaydeder; kapatırken de kaydeder.
- **Sayfa geçmişi.** Sayfanın eski sürümlerine dönülebilir.
- **Çöp kutusu.** Silinen sayfalar 30 gün boyunca geri yüklenebilir.
- **Dışa aktarma.** PDF, tek dosya HTML ya da Markdown.
- **Katlama.** Başlıkların altındaki bölümler katlanabilir.
- **Kağıt temaları.** Sepya, Yeşilimsi Kağıt, Gri Kağıt, Krem.
- **Pencereyi üstte tutma (📌).** Pencere diğer pencerelerin üstünde kalır.

---

## Kurulum ve Çalıştırma

### macOS

Gerekenler: macOS 12+, Xcode ya da Xcode Command Line Tools (Swift 5.9+).

```bash
git clone <depo-adresi> NotDefteri
cd NotDefteri
swift run
```

Ya da yardımcı betikle:

```bash
./calistir.sh        # derle (gerekiyorsa) ve aç — uygulama zaten açıksa öne getirir
./calistir.sh -r     # optimize (release) derleme ile aç
./calistir.sh -t     # önce testleri çalıştır, geçerse aç
./calistir.sh -d     # baştan temiz derleme
```

Girişte kendiliğinden açılması için: **Not Defteri menüsü → Girişte Otomatik Başlat**.

### Linux (Ubuntu 22.04)

**İlk kurulum (bir kez):** GTK 4 geliştirme paketlerini ve Swift'i kurar, sonra derler.

```bash
git clone <depo-adresi> NotDefteri
cd NotDefteri
./scripts/linux-kur.sh
```

**Uygulamayı açmak:**

```bash
cd ~/NotDefteri
./scripts/linux-calistir.sh
```

Betik kod değiştiyse önce derler (debug; artımlı olduğu için tek dosyada ~1,5 sn), sonra
uygulamayı arka planda açar. İlk çalıştırmadaki tam derleme birkaç dakika sürebilir.

| Komut | Ne yapar |
|---|---|
| `./scripts/linux-calistir.sh` | Derle ve aç (macOS'taki `swift run` gibi) |
| `./scripts/linux-calistir.sh --release` | Optimize derleme ile aç. Değişiklikten sonra tüm modül yeniden derlendiği için yavaş |
| `./scripts/linux-calistir.sh --menuye-ekle` | Uygulama menüsüne **Office → Not Defteri** kısayolu ekler (bir kez yeterli) |

Güncellemek için:

```bash
cd ~/NotDefteri && git pull && ./scripts/linux-calistir.sh
```

> **Not:** Pencereyi üstte tutma (📌) X11'de çalışır; Wayland bunu desteklemez.

---

## Kullanım

### Sayfa oluşturma

- Başlık çubuğundaki **yeni sayfa** düğmesi, seçili sayfanın yanına yeni bir sayfa ekler.
- Kenar panelde sayfaya **sağ tıklayınca**: alt sayfa ekle, yanına sayfa ekle, yeniden adlandır,
  sabitle (📌), sil.
- Yeni sayfanın adı ilk satırdan otomatik alınır; ilk satırı değiştirdikçe ad da değişir.

### Yazarken biçimlendirme

- **Metin seçince** üstünde bir biçim çubuğu çıkar: Kalın, İtalik, Çizili, Kod, Vurgu, Bağlantı.
- **Satır başında `/`** yazınca blok menüsü açılır: Başlık 1/2/3, Madde listesi, Numaralı liste,
  Yapılacak, Alıntı, Kod bloğu, Ayırıcı, Alt sayfa, Görsel, Uyarı kutusu (gri, mavi, sarı,
  kırmızı, yeşil). Yazarak süzülür, `Enter` ile seçilir.
- Kenar paneldeki **B1 / B2 / B3 / Aa** düğmeleri satırı başlığa ya da düz metne çevirir.
  **A− / A+** seçili metnin puntosunu değiştirir.
- Markdown sözdizimi de çalışır: `# `, `- `, `1. `, `- [ ] `, `> `, ` ``` ` vb.

### Sayfalar arası bağ

`[[` yazınca sayfa önerileri çıkar. Seçince `[[Sayfa adı]]` bağı oluşur; tıklayınca o sayfa açılır.
Olmayan bir sayfaya bağ verirsen, tıklayınca sayfayı oluşturmayı önerir.

### Görsel ekleme

Görseli editöre yapıştır ya da sürükle. Dosya sayfanın `Görseller/` klasörüne kopyalanır.
Görselin köşesinden sürükleyerek boyutunu değiştirebilirsin.

### Yapılacaklar

`- [ ] iş` satırları **Ana Sayfa**'da toplanır. Oradan işaretlediğin iş, kendi sayfasında da
tamamlandı olarak işaretlenir.

---

## Klavye Kısayolları

Linux'ta `⌘` yerine `Ctrl`, `⌥` yerine `Alt` kullanılır. Tam liste: **Yardım → Klavye kısayolları** (`⌘/`).

| İşlem | macOS | Linux |
|---|---|---|
| Hızlı sayfa bulucu | `⌘P` | `Ctrl+P` |
| Ana Sayfa | `⇧⌘H` | `Ctrl+Shift+H` |
| Kaydet | `⌘S` | `Ctrl+S` |
| Geri al / Yinele | `⌘Z` / `⌘Y` | `Ctrl+Z` / `Ctrl+Y` |
| Kalın / İtalik | `⌘B` / `⌘I` | `Ctrl+B` / `Ctrl+I` |
| Üstü çizili | `⇧⌘X` | `Ctrl+Shift+X` |
| Satır içi kod | `⌘E` | `Ctrl+E` |
| Vurgu | `⌥⌘H` | `Ctrl+Alt+H` |
| Bağlantı | `⌘K` | `Ctrl+K` |
| Bul / Bul ve değiştir | `⌘F` / `⌥⌘F` | `Ctrl+F` / `Ctrl+Alt+F` |
| Sonrakini bul | `⌘G` | `Ctrl+G` |
| Kaynak biçimiyle yapıştır | `⇧⌘V` | `Ctrl+Shift+V` |
| Önceki / sonraki not | `⌘[` / `⌘]` | `Ctrl+[` / `Ctrl+]` |
| Bölümü katla / aç | `⌥⌘[` / `⌥⌘]` | `Ctrl+Alt+[` / `Ctrl+Alt+]` |
| Tümünü katla / aç | `⇧⌥⌘[` / `⇧⌥⌘]` | `Ctrl+Alt+Shift+[` / `]` |
| Puntoyu büyüt / küçült | `⌘*` / `⌘-` | `Ctrl+*` / `Ctrl+-` |
| Sayfa geçmişi | `⌥⌘Y` | `Ctrl+Alt+Y` |
| PDF olarak dışa aktar | `⇧⌘E` | `Ctrl+Shift+E` |
| Tam ekran | `⌃⌘F` | `F11` |
| Kenar paneli | — | `Ctrl+\` |
| İçindekiler paneli | — | `Ctrl+Shift+\` |
| Çıkış | `⌘Q` | `Ctrl+Q` |

---

## Notlar Nerede Saklanıyor?

Tüm notlar **`~/Documents/NotDefteri/`** klasöründedir. Her sayfa bir klasördür:

```
~/Documents/NotDefteri/
├── Proje/
│   ├── index.md          ← sayfanın içeriği
│   ├── Görseller/        ← sayfaya eklenen görseller
│   └── Toplantı Notları/ ← alt sayfa
│       └── index.md
└── Günlük/
    └── index.md
```

- Dosyalar düz Markdown'dır. Uygulama tanımadığı sözdizimini (tablo, wikilink, frontmatter…)
  biçimli göstermese de **olduğu gibi korur**.
- Markdown'a iki küçük ek vardır: punto için `<punto=16>metin</punto>`, görsel boyutu için
  `![](resim.png){320x240}`.
- Klasörü Git ile yedekleyebilir, Dropbox/iCloud ile eşitleyebilirsin.
- Gizli `.sira.json` dosyaları kenar paneldeki elle sıralamayı, `.cop` klasörü çöp kutusunu tutar.

---

## Sorun Giderme

| Sorun | Çözüm |
|---|---|
| Linux: "Swift bulunamadı" | Önce `./scripts/linux-kur.sh` çalıştır. Yeni terminal açtıysan `source ~/.local/share/swiftly/env.sh` |
| Linux: uygulama açılmıyor ya da çöküyor | Günlüğe bak: `~/.local/state/NotDefteri/` altındaki en yeni `.log` dosyası |
| Linux: ilk açılış çok uzun sürdü | İlk derleme tam derlemedir (birkaç dakika). Sonraki açılışlar ~1,5 sn |
| Uygulama ikinci kez açılmıyor | Tek pencereli çalışır; açıkken tekrar başlatınca mevcut pencere öne gelir |
| Bir not açılmadı ya da kaydedilmedi | Uygulama uyarı gösterir ve kapanmayı engeller. Yazdıkların pencerede durur, kopyalayıp yedekle |

---

## Geliştirme

```bash
swift build          # derle
swift test           # testleri çalıştır
```

| Klasör | İçerik |
|---|---|
| `Sources/NotDefteri/Cekirdek/` | Platformdan bağımsız mantık: Markdown çevirici, sayfa ağacı, kayıt, arama (iki platform ortak) |
| `Sources/NotDefteri/` (diğerleri) | macOS arayüzü (AppKit) |
| `Sources/NotDefteriLinux/` | Linux arayüzü (GTK 4) |
| `Sources/CGtk/` | GTK için C köprüsü |
| `Tests/` | Çekirdek ve macOS testleri |
| `06_Metadata/` | Kod haritası ve mimari kararlar. Kodu okumadan önce buraya bak |

Kod kuralları (Türkçe tanımlayıcılar, katmanlar, yorum tarzı) için `CLAUDE.md` ve
`06_Metadata/Mimari-Kararlar.md` dosyalarına bak.
