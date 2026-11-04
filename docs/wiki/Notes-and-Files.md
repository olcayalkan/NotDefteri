# Notes and Files

All notes live in **`~/Documents/NotDefteri/`**. Every page is a folder with an `index.md`:

```
~/Documents/NotDefteri/
├── Project/
│   ├── index.md          ← page content
│   ├── Görseller/        ← images added to the page
│   └── Meeting notes/    ← sub-page
│       └── index.md
└── Journal/
    └── index.md
```

## The format

- Files are **plain Markdown**. Syntax the app does not render (tables, frontmatter and so on)
  is **kept exactly as written**.
- Two small extensions:
  - `<punto=16>text</punto>` sets a font size;
  - `![](image.png){320x240}` sets an image size.
- Older single-file notes (`Name.md`) still open.

## Hidden files

| File | Purpose |
|---|---|
| `.sira.json` | Manual order and pinned pages in the sidebar, one per folder |
| `.cop/` | The trash; pages stay restorable for 30 days |

## Backup and sync

The folder is ordinary files, so Git, Dropbox and iCloud all work.

## Trying the app without touching your notes

Point the app at another folder:

```bash
NOTDEFTERI_KOK=/tmp/try not
```
