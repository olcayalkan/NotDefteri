#!/usr/bin/env bash
# docs/wiki/ içeriğini GitHub Wiki'ye yayımlar.
#
# Kullanım:
#   ./scripts/wiki-yayinla.sh
#
# İlk kez: GitHub'da Wiki sekmesinden bir sayfa oluşturun; wiki deposu ancak o zaman açılır.

set -euo pipefail
cd "$(dirname "$0")/.."

KAYNAK="docs/wiki"
DEPO="$(git remote get-url origin | sed -E 's#\.git$##').wiki.git"
GECICI="$(mktemp -d)"
trap 'rm -rf "$GECICI"' EXIT

git clone --quiet --depth 1 "$DEPO" "$GECICI" || {
    echo "Wiki deposu açılamadı. GitHub'da Wiki sekmesinden ilk sayfayı oluşturup tekrar deneyin." >&2
    exit 1
}

# Wiki, kaynağın birebir kopyası olsun: kaynakta olmayan sayfalar silinir.
find "$GECICI" -maxdepth 1 -name '*.md' -delete
cp "$KAYNAK"/*.md "$GECICI"/

cd "$GECICI"
git add -A
if git diff --cached --quiet; then
    echo "Wiki zaten güncel."
    exit 0
fi
git commit --quiet -m "Docs: Wiki docs/wiki/ ile eşitlendi ($(git -C "$OLDPWD" rev-parse --short HEAD))"
git push --quiet
echo "Wiki yayımlandı: ${DEPO%.wiki.git}/wiki"
