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
- **Kaynak:** `Sources/NotDefteri/NotDefteri.swift` — tek dosya, ~2570 satır
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

Uygulamanın Markdown çeviricisi **kayıplı** — tanımadığı sözdizimini kaydedince
siliyor. Ayrıntı: [[Markdown-Formati]]. Bu vault'taki notlar uygulamanın
klasöründe olmadığı için etkilenmiyor; ama uygulamayla Obsidian'ı aynı klasörde
kullanırsan veri kaybedersin.
