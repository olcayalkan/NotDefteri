# Installation

## macOS

**Requirements:** macOS 12 or later, Xcode or the Xcode Command Line Tools (Swift 5.9+).

```bash
git clone https://github.com/olcayalkan/NotDefteri.git
cd NotDefteri
./scripts/kisayol-kur.sh
not
```

`kisayol-kur.sh` installs the `not` command once. After that, typing `not` builds the app
if the code changed and opens it.

To start the app at login: **Not Defteri → Girişte Otomatik Başlat** (Launch at login).

## Linux (Ubuntu 22.04)

One script installs the GTK 4 packages, Swift, the build, the `not` command and an app menu
entry, then opens the app.

```bash
git clone https://github.com/olcayalkan/NotDefteri.git ~/NotDefteri
~/NotDefteri/scripts/linux-kur.sh
```

The app also appears under **Office → Not Defteri** in the app menu.

> **Wayland:** Keep on top (📌) needs XWayland, so the app opens through it by default.
> Start with `GDK_BACKEND=wayland not` to use native Wayland instead.

## The `not` command

| Command | What it does |
|---|---|
| `not` | Build if needed, then open |
| `not -r` | Open an optimised (release) build |
| `not -t` | Run the tests first; open only if they pass |
| `not -d` | Clean build from scratch, then open |

The command is `~/.local/bin/not` and calls `calistir.sh` in the project folder. If
`~/.local/bin` is not on your `PATH`, a line is added to `~/.zshrc` (macOS) or `~/.bashrc` (Linux).

## Updating

```bash
git pull
not
```

The first build takes a few minutes; later builds take seconds.
