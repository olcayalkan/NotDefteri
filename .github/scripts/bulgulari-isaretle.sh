#!/usr/bin/env bash
# Derleyici ve test günlüğündeki hata/uyarıları GitHub açıklamasına (annotation) çevirir.
# Açıklamalar koşunun ana sayfasında ve PR'ın "Files changed" sekmesinde ilgili satırda
# görünür; günlüğü baştan sona okumadan sorunun hangi aşamada ve nerede olduğu bulunur.
set -uo pipefail

gunluk=$1
asama=$2
ozet=${GITHUB_STEP_SUMMARY:-/dev/stdout}
kok=${GITHUB_WORKSPACE:-$PWD}
depo=${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}
surum=${GITHUB_SHA:-HEAD}

[[ -s $gunluk ]] || exit 0

# Aynı uyarı birden çok hedefte tekrar basılabiliyor; her konum bir kez işaretlensin.
bulgular=$(grep -E '^/[^:]+\.swift:[0-9]+(:[0-9]+)?: (error|warning): ' "$gunluk" | sort -u)
[[ -n $bulgular ]] || exit 0

# Komut sözdizimini bozan karakterler kaçırılır (GitHub workflow commands kuralı).
kacir() { local s=${1//%/%25}; s=${s//$'\r'/%0D}; printf '%s' "${s//$'\n'/%0A}"; }

hata=0
uyari=0
satirlar=""
while IFS= read -r satir; do
  [[ $satir =~ ^(/[^:]+\.swift):([0-9]+)(:([0-9]+))?:\ (error|warning):\ (.*)$ ]] || continue
  dosya=${BASH_REMATCH[1]#"$kok"/}
  no=${BASH_REMATCH[2]}
  sutun=${BASH_REMATCH[4]}
  tur=${BASH_REMATCH[5]}
  mesaj=${BASH_REMATCH[6]}

  echo "::$tur file=$dosya,line=$no${sutun:+,col=$sutun},title=$asama::$(kacir "$mesaj")"

  if [[ $tur == error ]]; then hata=$((hata + 1)); simge="❌"; else uyari=$((uyari + 1)); simge="⚠️"; fi
  satirlar+="| $simge | [\`$dosya:$no\`]($depo/blob/$surum/$dosya#L$no) | ${mesaj//|/\\|} |"$'\n'
done <<< "$bulgular"

{
  printf '### %s: %d hata, %d uyarı\n\n' "$asama" "$hata" "$uyari"
  printf '| | Konum | Mesaj |\n|---|---|---|\n'
  printf '%s' "$satirlar" | head -50
  [[ $((hata + uyari)) -gt 50 ]] && printf '\nİlk 50 bulgu gösteriliyor; tamamı iş günlüğünde.\n'
  printf '\n'
} >> "$ozet"
exit 0
