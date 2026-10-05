#!/usr/bin/env bash
# Ubuntu 22.04 masaüstünde GTK bağımlılıklarını kurar, derler ve pencereyi açar.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Linux ]]; then
    echo "Bu betik Ubuntu 22.04 Linux içindir." >&2
    exit 1
fi

sudo apt-get update
sudo apt-get install -y binutils git gnupg2 libc6-dev libcurl4-openssl-dev \
    libedit2 libgcc-11-dev libpython3-dev libsqlite3-0 libstdc++-11-dev \
    libxml2-dev libz3-dev pkg-config tzdata unzip zlib1g-dev libgtk-4-dev \
    curl ca-certificates

SWIFTLY_ORTAM="${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
if ! swift --version >/dev/null 2>&1; then
    if [[ -f "$SWIFTLY_ORTAM" ]]; then
        source "$SWIFTLY_ORTAM"
    fi
fi

if ! swift --version >/dev/null 2>&1; then
    if ! command -v swiftly >/dev/null 2>&1; then
        KURULUM_DIZINI="$(mktemp -d)"
        trap 'rm -rf "$KURULUM_DIZINI"' EXIT
        curl -fL "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz" \
            -o "$KURULUM_DIZINI/swiftly.tar.gz"
        tar -xzf "$KURULUM_DIZINI/swiftly.tar.gz" -C "$KURULUM_DIZINI"
        "$KURULUM_DIZINI/swiftly" init --skip-install --assume-yes --quiet-shell-followup
        source "$SWIFTLY_ORTAM"
    fi
    swiftly install "$(cat .swift-version)" --assume-yes
    hash -r
fi

swift --version
pkg-config --modversion gtk4
swift build
swift run
