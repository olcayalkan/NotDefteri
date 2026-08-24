---
tags: [format, spesifikasyon, referans]
guncelleme: 2026-08-24
---

# NotDefteri Markdown Lehçesi

Uygulamanın diske yazdığı biçimin tam tanımı.
Kaynak: `markdownMetniUret()` (satır 206) ve `markdowndenAttributedStringUret()` (satır 284).

## Desteklenen Sözdizimi

| Özellik | Yazılış | Obsidian |
|---|---|---|
| Başlık 1–3 | `# `, `## `, `### ` | ✅ standart |
| Kalın | `**metin**` | ✅ standart |
| Görsel | `![](Görseller/Ad.png){320x240}` | ⚠️ `{ExY}` ekranda metin olarak kalır |
| Punto | `<punto=16>metin</punto>` | ❌ ham etiket görünür |

Başka hiçbir şey **yok**: liste, tablo, kod bloğu, italik, bağlantı, alıntı,
onay kutusu, frontmatter, yatay çizgi — hiçbiri tanınmıyor.

## Çevirici Ne Kadar Sadık

Kaydetme, metni AttributedString'den yeniden üretir. Ama tanınmayan sözdizimi
**metin olarak korunur** — 24 Ağu 2026 ölçümünde 18 Obsidian biçiminin
18'i gidiş-dönüşten sağlam çıktı.

```
Obsidian'da yaz:   - [ ] görev
NotDefteri gösterir: "- [ ] görev"   (düz metin, madde işareti yok)
NotDefteri kaydeder: "- [ ] görev"   (metin aynen korunur)
```

Yani **içerik kaybolmuyor, sadece biçimli görünmüyor.**

Test edilmiş ve korunduğu doğrulanmış: liste, onay kutusu, tablo, kod bloğu,
frontmatter, `[[wikilink]]`, `[bağlantı](url)`, italik, alıntı, yatay çizgi,
4+ seviye başlık, ham HTML.

### Bilinen sınır
Parser bağlam duyarsız. Kod bloğu içinde **eşleşen** bir `**` çifti varsa
kalın sayılır ve ``` bloğu korunmaz. Eşleşmeyen `**` ise (ör. `2 ** 3`)
artık doğru şekilde düz metin kalıyor.

## Punto Etiketi Mantığı

Taban punto **14 pt** (`kTabanPunto`). Yalnızca farklı olanlar etiketlenir:

```
normal metin<punto=18>büyük</punto>normal
```

Sınır: 10–28 pt (`boyutSinirla()`, satır 187).
Tam sayıysa ondalık yazılmaz: `14.0` → `14` (`boyutMetni()`, satır 192).

## Görsel Bağı

```
![](Görseller/Başlık1.png){320x240}
      └─ yol           └─ gösterim boyutu (isteğe bağlı)
```

Çözümleme sırası (`resimBaginiCozumle()`, satır 261):
1. Sayfanın kendi klasörüne göre
2. Olmazsa kök `~/Documents/NotDefteri/` klasörüne göre (eski `ekler/` bağları için)

Dosya diskte yoksa `nil` döner ve **metin olduğu gibi korunur** — bilinçli.

## Başlık Punto Çarpanları

| Seviye | Çarpan | Sonuç (14 pt tabandan) |
|---|---|---|
| `#` | 1.75 | 25 pt |
| `##` | 1.40 | 20 pt |
| `###` | 1.15 | 16 pt |

Hepsi kalın (`baslikFontu()`, satır 168).

## Obsidian Uyumu İçin Yapılacaklar

Çeviriciyi "tanımadığını olduğu gibi koru" mantığına çevirmek en temiz çözüm.
Bkz. `01_Projects/Obsidian-Uyumlulugu.md`.

## İlgili

- [[Kod-Haritasi]] — çevirici işlevlerinin yeri
- [[Mimari-Kararlar]] — punto ve başlık kararlarının gerekçesi
- [[Acik-Isler]] — kayıpsız çevirici işi
