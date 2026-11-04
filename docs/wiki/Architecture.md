# Architecture

NotDefteri is one Swift package with a shared core and a thin native UI per platform.
The core follows **Clean Architecture**, split by feature.

## Targets

| Target | Role |
|---|---|
| `NotDefteriCekirdek` | Platform-independent logic: Markdown, page tree, saving, search. Foundation only |
| `NotDefteriMac` | macOS UI (AppKit) |
| `NotDefteriLinux` | Linux UI (GTK 4) |
| `CGtk` | C bridge to GTK 4 |
| `NotDefteri` (`Calistirici`) | Executable entry point for the current platform |

Dependency direction: **UI → Core**. The core never imports AppKit or GTK.

## Core layout

```
Sources/NotDefteriCekirdek/
├── Core/
│   ├── Error/         Exceptions (thrown) and Failure (returned)
│   ├── UseCase/       UseCase protocol
│   └── Util/          constants, settings, platform hooks, file names
├── Features/
│   ├── Editor/
│   │   ├── Domain/    entities (blocks, tables) and use cases (Enter rules, code help)
│   │   └── Data/      Markdown / HTML converters
│   ├── Sayfa/         (pages)
│   │   ├── Domain/    Sayfa entity, SayfaDeposu repository protocol, open/save use cases
│   │   └── Data/      file data sources, models, SayfaDeposuImpl
│   └── AnaSayfa/      Home page data
└── BagimlilikKonteyneri.swift   dependency container
```

## UI layout

Both UI targets mirror the core's features:

```
Sources/NotDefteriMac/            Sources/NotDefteriLinux/
├── App/                          ├── App/
└── Features/                     └── Features/
    ├── Editor/Presentation/          ├── Editor/Presentation/
    │   ├── Pages/                    │   ├── Pages/
    │   └── Widgets/                  │   └── Widgets/
    ├── KenarPanel/Presentation/      ├── KenarPanel/Presentation/
    └── AnaSayfa/Presentation/        └── AnaSayfa/Presentation/
```

## How a page opens and saves

1. The UI calls `BagimlilikKonteyneri.paylasilan.sayfayiAc(url)`.
2. `SayfayiAc` asks the `SayfaDeposu` repository, which reads through `SayfaDosyaKaynagi`.
3. The result is a `Result<Sayfa, Basarisizlik>`: the raw Markdown, its metadata and body.
4. Saving goes through `SayfayiKaydet`, which writes with `NotKaydedici` and then records page history.

Parsed Markdown is kept in a small LRU cache, so reopening a large page does not parse it again.

## Conventions

- **Turkish identifiers and comments.** Comments explain *why*, not *what*.
- **Large types grow by extension files:** `Type+Topic.swift`.
- **No third-party dependencies.**
- Design decisions are recorded in `06_Metadata/Mimari-Kararlar.md`.
