#!/usr/bin/env bash
# Terminalde `not` yazınca Not Defteri'yi açan kısayolu kurar (macOS ve Linux).
# Kısayol bu deponun calistir.sh'sini çağırır; derleme gerekiyorsa önce derler.
#
# Kullanım: ./scripts/kisayol-kur.sh      (bir kez yeterli)
#           not            aç
#           not -r         optimize (release) derlemeyle aç
#           not -t         önce testleri çalıştır
set -euo pipefail
KOK="$(cd "$(dirname "$0")/.." && pwd)"
DIZIN="$HOME/.local/bin"
KISAYOL="$DIZIN/not"

# Başka bir programın `not` komutunu ezme; yalnızca bizim ürettiğimiz güncellenir.
MEVCUT="$(command -v not || true)"
if [[ -n "$MEVCUT" && "$MEVCUT" != "$KISAYOL" ]]; then
    echo "Uyarı: '$MEVCUT' zaten 'not' adını kullanıyor; kısayol önce gelmezse o çalışır." >&2
fi
if [[ -f "$KISAYOL" ]] && ! grep -q "kisayol-kur.sh üretti" "$KISAYOL"; then
    echo "$KISAYOL başka bir dosya; üzerine yazılmadı." >&2
    exit 1
fi

mkdir -p "$DIZIN"
cat > "$KISAYOL" <<KISAYOL_SONU
#!/usr/bin/env bash
# Not Defteri kısayolu; scripts/kisayol-kur.sh üretti.
exec "$KOK/calistir.sh" "\$@"
KISAYOL_SONU
chmod +x "$KISAYOL"

# ~/.local/bin PATH'te değilse kabuk yapılandırmasına bir kez eklenir.
case ":$PATH:" in
  *":$DIZIN:"*) echo "Kuruldu. Terminalde 'not' yazman yeterli." ;;
  *)
    if [[ "$(basename "${SHELL:-bash}")" == zsh ]]; then AYAR="$HOME/.zshrc"; else AYAR="$HOME/.bashrc"; fi
    if ! grep -qs 'HOME/.local/bin' "$AYAR"; then
        printf '\n# Not Defteri kısayolu (not)\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$AYAR"
    fi
    echo "Kuruldu. Bu terminalde: source $AYAR  — yeni terminallerde doğrudan 'not' yaz."
    ;;
esac
