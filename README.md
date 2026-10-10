<p align="center">
  <img src="docs/baslik.gif" width="100%"
       alt="NotDefteri — Notların, yapılacakların ve fikirlerin için sade bir defter, macOS ve Linux'ta. Yazarken biçimlenir, yapılacaklar, görseller, sayfa ağacı, kendi dosyaların.">
</p>

<p align="center">
  <a href="docs/tanitim.mp4"><img src="docs/tanitim.gif" width="100%" alt="20 saniyelik tanıtım: ## Bugün yazılıp başlığa dönüşüyor; uygulama penceresinde yapılacaklar yazılıp işaretleniyor, [[ ile sayfa bağı kuruluyor; notların Belgeler › NotDefteri klasöründe sıradan dosyalar olarak durduğu gösteriliyor."></a>
</p>

---

## Özellikler

Bir karta tıklayınca nasıl kullanıldığını anlatan bölüme gidersin.

<p align="center">
  <a href="#yazarken-biçimlendirme"><img src="docs/kart-bicim.gif" width="100%" alt="Yazarken biçimlenir: işaretleri yaz, metin anında şekillensin. Nasıl kullanıldığına git."></a>
</p>
<p align="center">
  <a href="#yapılacaklar"><img src="docs/kart-yapilacaklar.gif" width="49%" alt="Yapılacaklar: bütün işlerin Ana Sayfa'da tek listede. Nasıl kullanıldığına git."></a>
  <a href="#görsel-ekleme"><img src="docs/kart-gorseller.gif" width="49%" alt="Görseller: sürükle bırak, görsel sayfada görünsün. Nasıl kullanıldığına git."></a>
</p>
<p align="center">
  <a href="#sayfa-oluşturma"><img src="docs/kart-agac.gif" width="49%" alt="Sayfa ağacı: alt sayfalar ekle, sürükleyerek düzenle. Nasıl kullanıldığına git."></a>
  <a href="#notlar-nerede-saklanıyor"><img src="docs/kart-dosyalar.gif" width="49%" alt="Notlar senin: bilgisayarında sıradan dosyalar olarak durur. Nerede saklandığına git."></a>
</p>
<p align="center">
  <a href="#diğer-özellikler"><img src="docs/kart-fazlasi.gif" width="100%" alt="Daha fazlası: hızlı bulucu, sayfa bağları, sayfa geçmişi, çöp kutusu, dışa aktarma ve otomatik kayıt. Tüm özelliklere git."></a>
</p>

### Diğer özellikler

- **Hızlı sayfa bulucu** (`⌘P` / `Ctrl+P`): Sayfa adının bir kısmını yaz, hemen bul. Türkçe harflere
  takılmaz (“istanbul” yazınca “İstanbul” da çıkar).
- **Ana Sayfa.** Son açtığın sayfalar, bekleyen işlerin ve tek tıkla yeni sayfa, günlük not ya da hazır şablon.
- **Sayfa bağları.** `[[` yazınca sayfa önerileri çıkar; seçtiğin sayfaya tek tıkla geçersin.
  Sayfa taşınsa ya da adı değişse de bağlar kendiliğinden güncellenir.
- **Blok menüsü.** Satır başında `/` yazınca başlık, liste, alıntı, uyarı kutusu gibi seçenekler açılır.
- **İçindekiler.** Uzun sayfalarda sağ kenarda başlık listesi durur; okuduğun bölüm vurgulanır,
  tıklayınca o başlığa gider.
- **Otomatik kayıt.** Yazmayı bıraktıktan 5&nbsp;saniye sonra kaydeder; kapatırken de kaydeder.
- **Sayfa geçmişi.** Bir sayfanın eski hâline geri dönebilirsin.
- **Çöp kutusu.** Silinen sayfalar 30&nbsp;gün boyunca geri getirilebilir.
- **Dışa aktarma.** Sayfayı PDF, web sayfası ya da düz metin olarak kaydet.
- **Bölüm katlama.** Başlıkların altını katlayıp uzun sayfayı sadeleştir.
- **Kağıt temaları.** Sepya, Yeşilimsi Kağıt, Gri Kağıt, Krem.
- **Üstte tut.** Raptiye düğmesiyle pencere diğer pencerelerin üstünde kalır.

## Kurulum ve Çalıştırma

<p align="center">
  <img src="docs/kurulum.gif" width="100%"
       alt="Terminalde kurulum: git clone ile depoyu indir, cd NotDefteri, ./scripts/kisayol-kur.sh ile kısayolu kur, ardından not yazınca uygulama derlenip açılır.">
</p>

**Hızlı kurulum (macOS).** Komutları kopyalayıp terminale yapıştır:

```bash
git clone https://github.com/olcayalkan/NotDefteri.git
cd NotDefteri
./scripts/kisayol-kur.sh
not
```

Linux için aşağıdaki [Linux](#linux-ubuntu-2204) bölümüne bak.

### macOS

Gerekenler: macOS 12+, Xcode ya da Xcode Command Line Tools (Swift 5.9+).

```bash
git clone https://github.com/olcayalkan/NotDefteri.git NotDefteri
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

### Terminal kısayolu: `not`

Linux'ta `linux-kur.sh` bunu kendisi kurar. macOS'ta bir kez kurduktan sonra terminalde
yalnızca `not` yazınca uygulama açılır (gerekiyorsa önce derlenir):

```bash
./scripts/kisayol-kur.sh
```

| Komut | Ne yapar |
|---|---|
| `not` | Derle (gerekiyorsa) ve aç |
| `not -r` | Optimize (release) derlemeyle aç |
| `not -t` | Önce testleri çalıştır, geçerse aç |
| `not -d` | Baştan temiz derle ve aç |

Kısayol `~/.local/bin/not` dosyasıdır ve bu klasördeki `calistir.sh`'yi çağırır.
`~/.local/bin` PATH'te değilse `~/.zshrc` (macOS) ya da `~/.bashrc` (Linux) dosyasına bir satır eklenir.
Linux'ta `calistir.sh` kendiliğinden `scripts/linux-calistir.sh`'ye geçer.

### Linux (Ubuntu 22.04)

Tek komut. Her şeyi o kurar: GTK 4 paketleri, Swift, derleme, `not` komutu, uygulama menüsü girdisi.
Sonunda uygulamayı açar.

```bash
git clone https://github.com/olcayalkan/NotDefteri.git ~/NotDefteri
~/NotDefteri/scripts/linux-kur.sh
```

Bundan sonra terminalde yalnızca:

```bash
not
```

Uygulama menüsünde de **Office → Not Defteri** olarak durur.

Güncellemek için `git pull` yapıp yine `not` yazman yeterli; kod değiştiyse kendisi derler
(ilk kurulumdaki tam derleme birkaç dakika sürer, sonrakiler birkaç saniye).

> **Not:** Pencereyi üstte tutma (📌) Wayland oturumlarında da çalışır (Zorin, Ubuntu GNOME): Wayland bu
> isteği desteklemediği için uygulama XWayland üzerinden açılır. İstemezsen `GDK_BACKEND=wayland not` ile başlat.

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
| Linux: `not` bulunamadı ya da "Swift bulunamadı" | `~/NotDefteri/scripts/linux-kur.sh` komutunu (yeniden) çalıştır |
| Linux: uygulama açılmıyor ya da çöküyor | Günlüğe bak: `~/.local/state/NotDefteri/` altındaki en yeni `.log` dosyası |
| Linux: ilk açılış çok uzun sürdü | İlk derleme tam derlemedir (birkaç dakika). Sonraki açılışlar ~1,5 sn |
| Uygulama ikinci kez açılmıyor | Tek pencereli çalışır; açıkken tekrar başlatınca mevcut pencere öne gelir |
| Bir not açılmadı ya da kaydedilmedi | Uygulama uyarı gösterir ve kapanmayı engeller. Yazdıkların pencerede durur, kopyalayıp yedekle |

---

## Geliştirme

- **macOS:** saf AppKit, üçüncü parti bağımlılık yok
- **Linux:** GTK 4 (Ubuntu 22.04'te denendi)
- **Dil:** Swift 5.9, SwiftPM
- **Dosya biçimi:** Markdown (`.md`); her sayfa kendi klasöründe `index.md`

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
