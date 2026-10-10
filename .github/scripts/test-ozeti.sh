#!/usr/bin/env bash
# Test günlüğünden koşu sayfasına özet tablo yazar.
# Günlüğü açmadan kaç testin koştuğu ve hangilerinin kırıldığı görülsün diye.
set -uo pipefail

gunluk=$1
platform=$2
ozet=${GITHUB_STEP_SUMMARY:-/dev/stdout}

if [[ ! -s $gunluk ]]; then
  printf '### %s\n\nTestler çalışmadı: derleme ya da önceki bir adım başarısız oldu.\n' "$platform" >> "$ozet"
  exit 0
fi

# XCTest her suite için bir satır basar; toplam, "All tests" satırından hemen sonra gelir.
toplam_satiri=$(grep -A1 "Test Suite 'All tests'" "$gunluk" | grep -E "Executed [0-9]+ tests?" | tail -1)
calisan=$(sed -nE 's/.*Executed ([0-9]+) tests?.*/\1/p' <<< "$toplam_satiri")
kirik=$(sed -nE 's/.* with ([0-9]+) failures?.*/\1/p' <<< "$toplam_satiri")
sure=$(sed -nE 's/.* in ([0-9.]+) .*/\1/p' <<< "$toplam_satiri")

if [[ -z $calisan ]]; then
  durum="⚠️ Test süreci yarıda kesildi (çökme ya da zaman aşımı)"
elif [[ ${kirik:-0} -eq 0 ]]; then
  durum="✅ Geçti"
else
  durum="❌ Kırık test var"
fi

{
  printf '### %s\n\n' "$platform"
  printf '| Durum | Çalışan | Kırık | Süre |\n|---|---|---|---|\n'
  printf '| %s | %s | %s | %s sn |\n\n' "$durum" "${calisan:--}" "${kirik:--}" "${sure:--}"

  hatalar=$(grep -E "error: .*(failed|XCT)" "$gunluk" | sed -E 's#^.*/([^/]+\.swift:[0-9]+): error: #\1: #' | head -30)
  if [[ -n $hatalar ]]; then
    printf '<details><summary>Kırık testler</summary>\n\n```\n%s\n```\n\n</details>\n' "$hatalar"
  fi
} >> "$ozet"
