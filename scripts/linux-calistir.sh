#!/usr/bin/env bash
# Linux'ta NotDefteri'yi başlatır. Kod değiştiyse önce derler.
#
# Kullanım:
#   ./scripts/linux-calistir.sh                derle (gerekiyorsa, debug) ve başlat — macOS'taki `swift run` gibi
#   ./scripts/linux-calistir.sh --release      optimize derleme; değişiklikten sonra tüm modül yeniden derlenir (yavaş)
#   ./scripts/linux-calistir.sh --menuye-ekle  uygulama menüsüne "Not Defteri" kısayolu ekle (bir kez)
#
# İlk kurulum için önce ./scripts/linux-kur.sh çalıştırılır.
set -euo pipefail
cd "$(dirname "$0")/.."
KOK="$(pwd)"

# Masaüstü terminali giriş kabuğu değildir; ~/.profile okunmadığı için swift yolda olmayabilir.
SWIFTLY_ORTAM="${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
if ! command -v swift >/dev/null 2>&1 && [[ -f "$SWIFTLY_ORTAM" ]]; then
    # shellcheck disable=SC1090
    source "$SWIFTLY_ORTAM"
fi

if [[ "${1:-}" == "--menuye-ekle" ]]; then
    MENU_DIZINI="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$MENU_DIZINI"
    cat > "$MENU_DIZINI/notdefteri.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Not Defteri
Comment=Markdown tabanlı not defteri
Exec="$KOK/scripts/linux-calistir.sh"
Icon=accessories-text-editor
Terminal=false
Categories=Office;Utility;TextEditor;
EOF
    echo "Uygulama menüsüne eklendi: Office > Not Defteri"
    exit 0
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "Swift bulunamadı. Önce ./scripts/linux-kur.sh çalıştırın." >&2
    exit 1
fi

# Debug artımlı derlenir (tek dosya ~1,5 sn). Release tüm modülü yeniden optimize eder:
# 2 çekirdekli sunucuda tek değişiklikte ~17 sn, git pull sonrası dakikalar. Not açma/kayıt
# süresine etkisi küçük; asıl maliyet Foundation (corelibs) tarafında.
YAPILANDIRMA=debug
[[ "${1:-}" == "--release" ]] && YAPILANDIRMA=release

echo "Derleniyor ($YAPILANDIRMA)..."
if ! DERLEME_CIKTISI=$(swift build -c "$YAPILANDIRMA" --product NotDefteri 2>&1); then
    printf '%s\n' "$DERLEME_CIKTISI" | tail -20 >&2
    echo "Derleme başarısız, açılmıyor." >&2
    exit 1
fi
printf '%s\n' "$DERLEME_CIKTISI" | tail -1

# GtkApplication tek örneklidir: uygulama zaten açıksa yeni süreç mevcut pencereyi öne getirip çıkar.
GUNLUK_DIZINI="${XDG_STATE_HOME:-$HOME/.local/state}/NotDefteri"
mkdir -p "$GUNLUK_DIZINI"
GUNLUK="$GUNLUK_DIZINI/$(date +%Y-%m-%d_%H-%M-%S).log"
# Çökmede etkileşimli hata ayıklayıcı tuş bekleyip süreci açık tutmasın; yığın izi günlüğe yazılsın.
SWIFT_BACKTRACE="enable=yes,interactive=no,preset=full" nohup "$KOK/.build/$YAPILANDIRMA/NotDefteri" \
    </dev/null >>"$GUNLUK" 2>&1 &
echo "Açıldı (pid $!). Notlar: ~/Documents/NotDefteri/"
echo "Günlük: $GUNLUK"
