# Graph Report - Sources  (2026-08-24)

## Corpus Check
- Corpus is ~10,486 words - fits in a single context window. You may not need a graph.

## Summary
- 241 nodes · 732 edges · 7 communities
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Kaydetme & Metin Komutları
- Kenar Panel & Sayfa Ağacı
- Görsel Eki & Metin Görünümü
- Dosya Sistemi & Markdown Çözümleme
- Başlık Çubuğu & Fare Etkileşimi
- Uygulama & Menü
- Tema & UI Yardımcıları

## God Nodes (most connected - your core abstractions)
1. `NotPenceresi` - 71 edges
2. `KenarPaneli` - 62 edges
3. `NotMetinGorunumu` - 23 edges
4. `BaslikCubugu` - 21 edges
5. `AgacDugumu` - 21 edges
6. `ResimEkiHucresi` - 17 edges
7. `anaMenuyuOlustur()` - 15 edges
8. `varsayilanFont()` - 13 edges
9. `KenarPaneliSurukleTutamaci` - 13 edges
10. `NSColor` - 12 edges

## Surprising Connections (you probably didn't know these)
- `markdowndenAttributedStringUret()` --references--> `NotPenceresi`  [INFERRED]
  NotDefteri/main.swift → NotDefteri/main.swift  _Bridges community 3 → community 0_
- `Tema` --references--> `String`  [EXTRACTED]
  NotDefteri/main.swift →   _Bridges community 6 → community 0_
- `AgacDugumu` --references--> `String`  [EXTRACTED]
  NotDefteri/main.swift →   _Bridges community 0 → community 1_
- `boyutSinirla()` --references--> `CGFloat`  [EXTRACTED]
  NotDefteri/main.swift →   _Bridges community 6 → community 3_
- `KenarPaneli` --references--> `CGFloat`  [EXTRACTED]
  NotDefteri/main.swift →   _Bridges community 6 → community 1_

## Import Cycles
- None detected.

## Communities (7 total, 0 thin omitted)

### Community 0 - "Kaydetme & Metin Komutları"
Cohesion: 0.10
Nodes (18): baslikFontu(), benzersizSayfaURL(), fontUret(), isaretlemeleriTemizle(), kalinFont(), kalinMi(), markdownMetniUret(), NotMetinGorunumu (+10 more)

### Community 1 - "Kenar Panel & Sayfa Ağacı"
Cohesion: 0.09
Nodes (14): AgacDugumu, .ad, .cocuklarKlasoru, .sayfaMi, aramaIcinSadelestir(), KenarPaneli, .tumNotUrlListesi, notlarKlasoru() (+6 more)

### Community 2 - "Görsel Eki & Metin Görünümü"
Cohesion: 0.09
Nodes (19): Bool, Int, NotSatirGorunumu, .isSelected, ResimEkiHucresi, NSApplication, NSControl, NSOutlineView (+11 more)

### Community 3 - "Dosya Sistemi & Markdown Çözümleme"
Cohesion: 0.15
Nodes (26): AppKit, Date, agaciYukle(), boyutSinirla(), degistirilmeTarihi(), giristeAcikMi(), giristeAcmayiAyarla(), gorsellerKlasoru() (+18 more)

### Community 4 - "Başlık Çubuğu & Fare Etkileşimi"
Cohesion: 0.11
Nodes (6): BaslikCubugu, KenarPaneliSurukleTutamaci, NSEvent, NSTrackingArea, NSWindow, Void

### Community 5 - "Uygulama & Menü"
Cohesion: 0.16
Nodes (8): Any, anaMenuyuOlustur(), UygulamaDelegesi, NSApplicationDelegate, NSMenu, NSMenuDelegate, NSMenuItem, NSObject

### Community 6 - "Tema & UI Yardımcıları"
Cohesion: 0.18
Nodes (11): CGFloat, aramaKutuRengi(), aramaOdakRengi(), boyutMetni(), NSColor, renklendirilmisSembol(), secimVurguRengi(), Tema (+3 more)

## Knowledge Gaps
- **10 isolated node(s):** `AppKit`, `.gosterimBoyutu`, `.isSelected`, `.sayfaMi`, `.ad` (+5 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NotPenceresi` connect `Kaydetme & Metin Komutları` to `Kenar Panel & Sayfa Ağacı`, `Görsel Eki & Metin Görünümü`, `Dosya Sistemi & Markdown Çözümleme`, `Başlık Çubuğu & Fare Etkileşimi`, `Uygulama & Menü`?**
  _High betweenness centrality (0.328) - this node is a cross-community bridge._
- **Why does `KenarPaneli` connect `Kenar Panel & Sayfa Ağacı` to `Kaydetme & Metin Komutları`, `Görsel Eki & Metin Görünümü`, `Dosya Sistemi & Markdown Çözümleme`, `Başlık Çubuğu & Fare Etkileşimi`, `Uygulama & Menü`, `Tema & UI Yardımcıları`?**
  _High betweenness centrality (0.298) - this node is a cross-community bridge._
- **Why does `BaslikCubugu` connect `Başlık Çubuğu & Fare Etkileşimi` to `Kaydetme & Metin Komutları`, `Kenar Panel & Sayfa Ağacı`, `Görsel Eki & Metin Görünümü`, `Dosya Sistemi & Markdown Çözümleme`, `Tema & UI Yardımcıları`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `NotPenceresi` (e.g. with `.arkayaAtButonaTiklandi()` and `.mouseDown()`) actually correct?**
  _`NotPenceresi` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `KenarPaneli` (e.g. with `.kenarPaneliniAcKapa()` and `.yeniNotOlustur()`) actually correct?**
  _`KenarPaneli` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 13 inferred relationships involving `NotMetinGorunumu` (e.g. with `.baslikSeviyesiUygula()` and `.gecmisiSifirla()`) actually correct?**
  _`NotMetinGorunumu` has 13 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AppKit`, `.gosterimBoyutu`, `.isSelected` to the rest of the system?**
  _10 weakly-connected nodes found - possible documentation gaps or missing edges._