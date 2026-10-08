#!/usr/bin/env bash
# Ubuntu 22.04 masaüstünde her şeyi tek seferde kurar: GTK bağımlılıkları, Swift, derleme,
# terminal kısayolu (`not`), uygulama menüsü girdisi; sonunda pencereyi açar.
# Tekrar çalıştırmak güvenlidir (güncellemeden sonra da kullanılabilir).
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
echo "Derleniyor (ilk derleme birkaç dakika sürebilir)..."
swift build --product NotDefteri

# Terminalde `not` yazınca açılsın. /usr/local/bin her kabukta PATH'te; source gerekmez.
KOK="$(pwd)"
KISAYOL=/usr/local/bin/not
if [[ -e "$KISAYOL" ]] && ! grep -qs "kur.sh üretti" "$KISAYOL"; then
    echo "Uyarı: $KISAYOL başka bir programa ait; üzerine yazılmadı." >&2
else
    printf '#!/usr/bin/env bash\n# Not Defteri kısayolu; scripts/linux-kur.sh üretti.\nexec "%s/calistir.sh" "$@"\n' "$KOK" \
        | sudo tee "$KISAYOL" >/dev/null
    sudo chmod 755 "$KISAYOL"
fi

# Uygulama menüsü: Office > Not Defteri
./scripts/linux-calistir.sh --menuye-ekle

echo
echo "Kurulum tamam. Bundan sonra terminalde yalnızca: not"
echo
./calistir.sh
