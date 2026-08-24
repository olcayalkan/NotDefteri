---
tags: [kod-haritasi, referans]
guncelleme: 2026-08-24
kaynak: Sources/NotDefteri/NotDefteri.swift
---

# Kod Haritası — NotDefteri.swift

**2570 satır, tek dosya.** Dosyayı baştan okuma; aşağıdan hedef aralığı bul,
`Read` aracına `offset` + `limit` ver.

## Bölümler (MARK)

| Satır | Bölüm | Ne yapar |
|---|---|---|
| 3–95 | Tema | 4 kağıt teması, renk koyulaştırma, SF Symbol boyama |
| 97–118 | Kaydetme konumu | `~/Documents/NotDefteri`, `Görseller/` klasörü |
| 120–156 | LaunchAgent | Girişte otomatik başlatma plist'i |
| 158–369 | **Markdown ↔ AttributedString** | Çift yönlü çevirici — projenin kalbi |
| 371–509 | Görsel eki | Sürüklenerek boyutlandırılabilir gömülü resim |
| 511–582 | `NotMetinGorunumu` | Yapıştırma/sürükleme ile görsel ekleme |
| 584–721 | `BaslikCubugu` | Özel pencere kontrolleri |
| 723–767 | `NotSatirGorunumu` | Kenar panel satır vurgusu |
| 769–935 | Sayfa ağacı modeli | Klasör tarama, yeniden adlandırma, göç |
| 937–1646 | **`KenarPaneli`** | Ağaç, arama, sağ tık menüsü, punto/başlık çubuğu |
| 1648–1682 | Sürükle tutamacı | Panel genişliği ayarı |
| 1684–2445 | **`NotPenceresi`** | Tüm iş mantığının koordinasyonu |
| 2447–2522 | Menü | Ana menü kurulumu |
| 2524–2560 | Giriş noktası | `UygulamaDelegesi`, `app.run()` |

## Tipler

| Satır | Tip | Taban |
|---|---|---|
| 5 | `Tema` | `struct` |
| 38 | `NSColor` uzantısı | `koyulastir()` |
| 376 | `ResimEki` | `NSTextAttachment` |
| 389 | `ResimEkiHucresi` | `NSTextAttachmentCell` |
| 513 | `NotMetinGorunumu` | `NSTextView` |
| 586 | `BaslikCubugu` | `NSView` |
| 725 | `NotSatirGorunumu` | `NSTableRowView` |
| 804 | `AgacDugumu` | — (sayfa/klasör modeli) |
| 939 | `KenarPaneli` | `NSView` + 4 protokol |
| 1650 | `KenarPaneliSurukleTutamaci` | `NSView` |
| 1686 | `NotPenceresi` | `NSWindow`, `NSTextViewDelegate` |
| 2526 | `UygulamaDelegesi` | `NSObject`, `NSApplicationDelegate` |

## Sık Aranan İşlevler

### Markdown çevirici (saf fonksiyonlar — test edilebilir)
| Satır | İşlev |
|---|---|
| 197 | `isaretlemeleriTemizle()` — biçim işaretlerini söker |
| 206 | `markdownMetniUret()` — AttributedString → Markdown **(kayıplı!)** |
| 242 | `otomatikBaslikUret()` — ilk satırdan dosya adı |
| 261 | `resimBaginiCozumle()` — `![](x.png){320x240}` ayrıştırır |
| 284 | `markdowndenAttributedStringUret()` — Markdown → AttributedString |
| 187 | `boyutSinirla()` — punto 10–28 aralığına kırpar |
| 192 | `boyutMetni()` — 14.0 → "14" |

### Dosya sistemi / sayfa ağacı
| Satır | İşlev |
|---|---|
| 99 | `notlarKlasoru()` |
| 112 | `gorsellerKlasoru()` |
| 781 | `klasorSayfasiMi()` — `index.md` var mı |
| 787 | `sayfaKlasoru()` — yeni/eski düzen ayrımı |
| 828 | `agaciYukle()` — **özyinelemeli tarama**, her iki düzeni destekler |
| 878 | `benzersizSayfaURL()` — ad çakışması çözer |
| 893 | `sayfayiYenidenAdlandir()` |
| 924 | `sayfayiKlasoreDonustur()` — eski → yeni düzen göçü |

### Kaydetme akışı (`NotPenceresi`)
| Satır | İşlev |
|---|---|
| 1825 | `notuAc()` |
| 1890 | `mevcutNotuKaybolmayacakSekildeKaydet()` |
| 1920 | `kaydetURLe()` — **tek yazma noktası** |
| 2126 | `icerikDegisti()` — 5 sn timer kurar |
| 2144 | `otomatikKaydet()` — otomatik adlandırma mantığı burada |
| 2205 | `kapanistaGerekirseKaydet()` |

### Metin biçimlendirme
| Satır | İşlev |
|---|---|
| 1948 | `egikCizgiKomutu()` — `/1 /2 /3 /0 /page` tanır |
| 1980 | `komutuCalistir()` |
| 2002 | `baslikSeviyesiUygula()` |
| 2216 | `kalinYap()` |
| 2262 | `yaziBoyutunuDegistir()` |

### Arama / ağaç (`KenarPaneli`)
| Satır | İşlev |
|---|---|
| 1238 | `yenile()` — **tüm notları diskten okur, O(n) I/O** |
| 1259 | `suzulmusAgac()` — arama filtresi |
| 1282 | `filtreUygula()` |
| 73 | `aramaIcinSadelestir()` — Türkçe duyarlı normalleştirme |

### Görsel
| Satır | İşlev |
|---|---|
| 488 | `resimEkiUret()` |
| 529 | `bulunanBolumBasligi()` — görsel adını başlıktan üretir |
| 2091 | `gorseliDiskeYaz()` — PNG olarak `Görseller/` altına |

## Kısayol İşleyicileri

| Satır | Ne |
|---|---|
| 2398 | `performKeyEquivalent()` — ⌘Z/⌘Y/⌘*/⌘−, Fn+F elle yakalanır |
| 2449 | `anaMenuyuOlustur()` — menü + `#selector` bağlantıları |

Punto kısayolları menüden değil `performKeyEquivalent`'ten geçer:
Türkçe Q klavyede `*` shift'siz üretiliyor, menü eşleşmesi kaçıyor.

## İlgili

- [[Mimari-Kararlar]] — bu işlevlerin neden öyle yazıldığı
- [[Markdown-Formati]] — çeviricinin ürettiği biçim
- [[Acik-Isler]] — hangi bölümde iş var
- [[ozet]] — projenin tam analizi
