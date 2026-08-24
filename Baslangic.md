---
tags: [giris, harita]
guncelleme: 2026-08-24
---

# NotDefteri — Başlangıç

Bu vault hem **Swift kaynak kodu** hem de projenin **bilgi havuzu**.
Amaç: kodu her seferinde baştan okumadan çalışabilmek.

## Nereden Başlamalı

| Soru | Not |
|---|---|
| "Şu işlev nerede?" | [[Kod-Haritasi]] |
| "Bu neden böyle yazılmış?" | [[Mimari-Kararlar]] |
| "Dosya biçimi nedir?" | [[Markdown-Formati]] |
| "Sırada ne var?" | [[Acik-Isler]] |
| "Proje genel olarak nedir?" | [[ozet]] |

## Proje Künyesi

- **Dil:** Swift 5.9 · **Framework:** AppKit (bağımlılıksız) · **Platform:** macOS 12+
- **Kaynak:** `Sources/NotDefteri/` — 26 dosya, 5 katman, ~2684 satır
- **Tanımlayıcılar Türkçe:** `NotPenceresi`, `agaciYukle()`, `kenarPaneli`
- **Uygulamanın not klasörü:** `~/Documents/NotDefteri/` (bu vault değil)

```bash
swift build -c release && .build/release/NotDefteri
```

## Vault Düzeni

| Klasör | İçerik |
|---|---|
| `06_Metadata/` | Kod haritası, mimari kararlar — **önce buraya bak** |
| `03_Resources/` | Format spesifikasyonu, referans |
| `01_Projects/` | Aktif işler |
| `00_Inbox/` | Ham fikirler |
| `04_Archive/` | Biten işler |

## Dikkat

Uygulamanın Markdown çeviricisi **sınırlı ama kayıpsız.** Tanımadığı sözdizimi
(liste, tablo, kod bloğu, italik, `[[wikilink]]`, frontmatter) biçimli görünmez
ama **metin olarak korunur** — 24 Ağu 2026 ölçümünde 18 Obsidian biçiminin 18'i
gidiş-dönüşten sağlam çıktı. Ayrıntı: [[Markdown-Formati]].

Yani Obsidian'da yazdığın tablo uygulamada düz metin gibi durur, ama kaydedince
silinmez. Bilinen sınır: parser bağlam duyarsız, kod bloğu içindeki *eşleşen*
`**` çifti hâlâ kalın sayılıyor.
