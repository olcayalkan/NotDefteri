#!/usr/bin/env bash
# NotDefteri'yi başlatır. Kod değiştiyse önce derler.
#
# Kullanım:
#   ./calistir.sh          derle (gerekiyorsa) ve başlat
#   ./calistir.sh -t       önce testleri çalıştır, geçerse başlat
#   ./calistir.sh -d       baştan derle (temiz)

set -e
cd "$(dirname "$0")"

IKILI=".build/release/NotDefteri"

case "$1" in
  -d) echo "Temiz derleme..."; rm -rf .build ;;
  -t) echo "Testler çalışıyor..."
      swift test 2>&1 | grep -E "Executed [0-9]+ tests" | tail -1
      swift test > /dev/null 2>&1 || { echo "Testler başarısız, açılmıyor."; exit 1; } ;;
esac

# Zaten açıksa ikinci kopya açma, öne getir.
if pgrep -f "$IKILI" > /dev/null; then
    echo "NotDefteri zaten açık, öne getiriliyor."
    osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "NotDefteri") to true' 2>/dev/null || true
    exit 0
fi

echo "Derleniyor..."
swift build -c release 2>&1 | tail -1

echo "Başlatılıyor..."
"$IKILI" &
echo "Açıldı (pid $!). Notlar: ~/Documents/NotDefteri/"
