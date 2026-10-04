#!/usr/bin/env bash
# NotDefteri'yi başlatır. Kod değiştiyse önce derler.
#
# Kullanım:
#   ./calistir.sh          derle (gerekiyorsa) ve başlat
#   ./calistir.sh -r       release derle ve başlat
#   ./calistir.sh -t       önce testleri çalıştır, geçerse başlat
#   ./calistir.sh -d       baştan derle (temiz)

set -e
cd "$(dirname "$0")"

IKILI=".build/debug/NotDefteri"
DERLEME="swift build"

case "${1:-}" in
  -d) echo "Temiz derleme..."; rm -rf .build ;;
  -t) echo "Testler çalışıyor..."
      swift test 2>&1 | grep -E "Executed [0-9]+ tests" | tail -1
      swift test > /dev/null 2>&1 || { echo "Testler başarısız, açılmıyor."; exit 1; } ;;
  -r) IKILI=".build/release/NotDefteri"; DERLEME="swift build -c release" ;;
esac

# Zaten açıksa ikinci kopya açma, öne getir.
if pgrep -f "$IKILI" > /dev/null; then
    echo "NotDefteri zaten açık, öne getiriliyor."
    osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "NotDefteri") to true' 2>/dev/null || true
    exit 0
fi

echo "Derleniyor..."
if DERLEME_CIKTISI=$($DERLEME 2>&1); then
    printf '%s\n' "$DERLEME_CIKTISI" | tail -1
else
    printf '%s\n' "$DERLEME_CIKTISI" | tail -20 >&2
    echo "Derleme başarısız, açılmıyor." >&2
    exit 1
fi

echo "Başlatılıyor..."
# Çökmede Swift'in etkileşimli hata ayıklayıcısı tuş bekleyip süreci açık tutmasın;
# yığın izi günlüğe yazılsın ve süreç kapansın.
GUNLUK_DIZINI="$HOME/Library/Logs/NotDefteri"
mkdir -p "$GUNLUK_DIZINI"
GUNLUK="$GUNLUK_DIZINI/$(date +%Y-%m-%d_%H-%M-%S).log"
SWIFT_BACKTRACE="enable=yes,interactive=no,preset=full,limit=150" "$IKILI" < /dev/null >> "$GUNLUK" 2>&1 &
echo "Açıldı (pid $!). Notlar: ~/Documents/NotDefteri/"
echo "Günlük: $GUNLUK"
