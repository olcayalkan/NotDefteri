#!/usr/bin/env python3
"""README'nin özellik ve kurulum animasyonlarını üretir: docs/ozellikler.svg, docs/kurulum.svg.

Başlık animasyonuyla (docs/baslik.gif) aynı mantık: Markdown kaynağı yazılır, uygulamadaki
gibi biçimlenmiş hâline dönüşür. SVG içindeki CSS animasyonu GitHub'da <img> ile oynar;
yalnızca transform ve opacity hareket eder, prefers-reduced-motion'da son hâl durağan görünür.
Gereksinim yok (yalnızca Python standart kütüphanesi).

    python3 scripts/readme-animasyonlar.py
"""
from html import escape
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"

# Sepya teması (Tema.swift) ve başlık GIF'iyle aynı renkler.
ZEMIN = "#d6cfba"
CIZGI = "#cec7b1"
KENAR = "#be8070"
METIN = "#3a3026"
ISARET = "#968670"
ALT = "#605444"
KUTU = "#c7bda6"
BAG = "#1f5f9e"
VURGU = "#efd27a"
UYARI_ZEMIN = "#e6d29a"
UYARI_KENAR = "#c9a227"

SERIF = "Georgia, 'Times New Roman', serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', monospace"
# Güçlü ease-out (animate skill'i): giriş ve çıkışlar için.
EASE_OUT = "cubic-bezier(0.23, 1, 0.32, 1)"


def yuzde(t, toplam):
    return f"{max(0.0, min(100.0, t / toplam * 100)):.3f}%"


def anahtar_kareler(ad, toplam, adimlar, egri=EASE_OUT):
    """adimlar: [(saniye, {css özellikleri})]. Her adımdan sonraki geçiş `egri` ile yapılır."""
    satirlar = []
    for t, ozellik in adimlar:
        govde = "; ".join(f"{k}: {v}" for k, v in ozellik.items())
        satirlar.append(f"  {yuzde(t, toplam)} {{ {govde}; animation-timing-function: {egri}; }}")
    return f"@keyframes {ad} {{\n" + "\n".join(satirlar) + "\n}"


def defter_zemini(gen, yuk):
    cizgiler = "".join(f'<line x1="0" y1="{y}" x2="{gen}" y2="{y}" stroke="{CIZGI}"/>' for y in range(44, yuk, 34))
    return (f'<rect width="{gen}" height="{yuk}" rx="14" fill="{ZEMIN}"/>{cizgiler}'
            f'<line x1="70" y1="0" x2="70" y2="{yuk}" stroke="{KENAR}" stroke-width="2"/>')


# ───────────────────────────── Özellikler ─────────────────────────────

OZELLIKLER = [
    # (özellik adı, kaynak parçaları [(metin, işaret mi)], görünüm SVG'si)
    ("Başlıklar", [("## ", True), ("Toplantı notları", False)],
     f'<text font-family="{SERIF}" font-weight="bold" font-size="26" fill="{METIN}">Toplantı notları</text>'),
    ("Biçimli yazı", [("**", True), ("kalın", False), ("**", True), (" ve ", False), ("==", True), ("vurgu", False), ("==", True)],
     f'<rect x="88" y="-21" width="64" height="28" rx="4" fill="{VURGU}"/>'
     f'<text font-family="{SERIF}" font-size="22" fill="{METIN}"><tspan font-weight="bold">kalın</tspan> ve '
     f'<tspan>vurgu</tspan></text>'),
    ("Yapılacaklar", [("- [ ] ", True), ("Raporu gönder", False)],
     f'<rect x="0" y="-18" width="20" height="20" rx="4" fill="none" stroke="{METIN}" stroke-width="2"/>'
     f'<text x="32" font-family="{SERIF}" font-size="22" fill="{METIN}">Raporu gönder</text>'),
    ("Sayfa bağları", [("[[", True), ("Proje Planı", False), ("]]", True)],
     f'<text font-family="{SERIF}" font-size="22" fill="{BAG}">📄 <tspan text-decoration="underline">Proje Planı</tspan></text>'),
    ("Uyarı kutusu", [("> [!💡 sarı] ", True), ("Cuma teslim", False)],
     f'<rect x="-10" y="-26" width="200" height="38" rx="7" fill="{UYARI_ZEMIN}"/>'
     f'<rect x="-10" y="-26" width="4" height="38" fill="{UYARI_KENAR}"/>'
     f'<text x="6" font-family="{SERIF}" font-size="21" fill="{METIN}">💡 Cuma teslim</text>'),
    ("Blok menüsü", [("/", True)],
     f'<g class="menu"><rect x="0" y="-24" width="330" height="34" rx="8" fill="{KUTU}"/>'
     f'<text x="14" font-family="{SERIF}" font-size="18" fill="{ALT}">Başlık 1 · Yapılacak · Kod bloğu · Tablo</text></g>'),
]


def ozellikler_svg():
    gen, satir_yuk, ust = 1000, 64, 70
    yuk = ust + len(OZELLIKLER) * satir_yuk + 24
    toplam = 11.0
    kademe = 0.18        # satırlar arası gecikme: sayfa bir anda dolmasın
    css, govde = [], []
    for i, (ad, kaynak, gorunum) in enumerate(OZELLIKLER):
        y = ust + i * satir_yuk
        bas = 0.3 + i * kademe
        donus = 2.0 + i * kademe
        bitis = toplam - 1.2 + i * 0.04
        # Kaynak girer (sağdan hafif), bekler, sola kayarak çıkar; görünüm aşağıdan oturur.
        css.append(anahtar_kareler(f"k{i}", toplam, [
            (0, {"opacity": 0, "transform": "translateX(8px)"}),
            (bas, {"opacity": 0, "transform": "translateX(8px)"}),
            (bas + 0.35, {"opacity": 1, "transform": "translateX(0)"}),
            (donus, {"opacity": 1, "transform": "translateX(0)"}),
            (donus + 0.25, {"opacity": 0, "transform": "translateX(-8px)"}),
            (toplam, {"opacity": 0, "transform": "translateX(-8px)"}),
        ]))
        css.append(anahtar_kareler(f"g{i}", toplam, [
            (0, {"opacity": 0, "transform": "translateY(6px)"}),
            (donus + 0.1, {"opacity": 0, "transform": "translateY(6px)"}),
            (donus + 0.5, {"opacity": 1, "transform": "translateY(0)"}),
            (bitis, {"opacity": 1, "transform": "translateY(0)"}),
            (bitis + 0.35, {"opacity": 0, "transform": "translateY(6px)"}),
            (toplam, {"opacity": 0, "transform": "translateY(6px)"}),
        ]))
        css.append(anahtar_kareler(f"e{i}", toplam, [
            (0, {"opacity": 0}), (bas, {"opacity": 0}), (bas + 0.35, {"opacity": 1}),
            (bitis + 0.1, {"opacity": 1}), (bitis + 0.45, {"opacity": 0}), (toplam, {"opacity": 0}),
        ]))
        css.append(f".k{i} {{ animation: k{i} {toplam}s infinite; }} .g{i} {{ animation: g{i} {toplam}s infinite; }} "
                   f".e{i} {{ animation: e{i} {toplam}s infinite; }}")
        parcalar = "".join(f'<tspan fill="{ISARET if isaret else METIN}">{escape(metin)}</tspan>' for metin, isaret in kaynak)
        govde.append(
            f'<text class="etiket e{i}" x="96" y="{y + 8}" font-family="{SERIF}" font-size="17" font-style="italic" fill="{ALT}">{escape(ad)}</text>'
            f'<g transform="translate(300 {y + 8})"><text class="kaynak k{i}" font-family="{MONO}" font-size="20">{parcalar}</text>'
            f'<g class="gorunum g{i}">{gorunum}</g></g>')
    hareket_azalt = (".kaynak { animation: none; opacity: 0; } "
                     ".gorunum, .etiket { animation: none; opacity: 1; transform: none; }")
    return svg_belgesi(gen, yuk, "Not Defteri özellikleri: Markdown kaynağı yazıldığı anda biçimlenir",
                       "\n".join(css), hareket_azalt, defter_zemini(gen, yuk) + "".join(govde))


# ───────────────────────────── Kurulum ─────────────────────────────

T_ZEMIN = "#2a251f"
T_UST = "#3a332b"
T_METIN = "#e9e0c9"
T_SOLUK = "#a89a80"
T_ISTEM = "#d9a95b"
T_BASARI = "#a8c686"

KURULUM = [
    # (tür, metin, önce bekleme sn)
    ("komut", "git clone https://github.com/olcayalkan/NotDefteri.git", 0.6),
    ("cikti", "Cloning into 'NotDefteri'...", 0.5),
    ("komut", "cd NotDefteri", 0.6),
    ("komut", "./scripts/kisayol-kur.sh", 0.5),
    ("basari", "Kuruldu. Terminalde 'not' yazman yeterli.", 0.4),
    ("komut", "not", 0.8),
    ("cikti", "Derleniyor...", 0.3),
    ("soluk", "Build complete! (41.20s)", 1.4),
    ("cikti", "Başlatılıyor...", 0.3),
    ("basari", "Açıldı (pid 4242). Notlar: ~/Documents/NotDefteri/", 0.5),
]


def kurulum_svg():
    gen, satir_yuk, ust, sol = 1000, 27, 78, 34
    yuk = ust + len(KURULUM) * satir_yuk + 26
    harf = 9.6           # 16 px tek aralıklı fontta harf genişliği; textLength ile sabitlenir
    yazma_hizi = 0.045   # harf başına saniye
    istem = "$ "
    zamanlar, t = [], 0.0
    for tur, metin, bekle in KURULUM:
        t += bekle
        sure = len(metin) * yazma_hizi if tur == "komut" else 0.0
        zamanlar.append((t, sure))
        t += sure
    toplam = t + 3.5

    css, govde = [], []
    for i, ((tur, metin, _), (bas, sure)) in enumerate(zip(KURULUM, zamanlar)):
        y = ust + i * satir_yuk
        renk = {"komut": T_METIN, "cikti": T_METIN, "basari": T_BASARI, "soluk": T_SOLUK}[tur]
        cikis = toplam - 0.6
        # Satır görünürlüğü: çıktı terminaldeki gibi anında belirir; sonda hepsi birlikte söner.
        css.append(anahtar_kareler(f"s{i}", toplam, [
            (0, {"opacity": 0}), (bas, {"opacity": 0}), (bas + 0.001, {"opacity": 1}),
            (cikis, {"opacity": 1}), (cikis + 0.4, {"opacity": 0}), (toplam, {"opacity": 0}),
        ], egri="linear"))
        css.append(f".s{i} {{ animation: s{i} {toplam}s infinite; }}")
        if tur == "komut":
            x0 = sol + len(istem) * harf
            n = len(metin)
            # Örtü + imleç harf harf sağa kayar (steps): metin yazılıyormuş gibi açılır.
            css.append(f"@keyframes o{i} {{ 0% {{ transform: translateX(0); }} "
                       f"{yuzde(bas, toplam)} {{ transform: translateX(0); animation-timing-function: steps({n}, end); }} "
                       f"{yuzde(bas + sure, toplam)} {{ transform: translateX({n * harf:.1f}px); }} "
                       f"100% {{ transform: translateX({n * harf:.1f}px); }} }}")
            sonraki = zamanlar[i + 1][0] if i + 1 < len(zamanlar) else toplam
            # İmleç yalnızca o satır etkin satırken görünür.
            css.append(anahtar_kareler(f"i{i}", toplam, [
                (0, {"opacity": 0}), (bas, {"opacity": 0}), (bas + 0.001, {"opacity": 1}),
                (sonraki, {"opacity": 1}), (sonraki + 0.001, {"opacity": 0}), (toplam, {"opacity": 0}),
            ], egri="linear"))
            css.append(f".o{i} {{ animation: o{i} {toplam}s infinite; }} .i{i} {{ animation: i{i} {toplam}s infinite; }}")
            govde.append(
                f'<g class="satir s{i}">'
                f'<text x="{sol}" y="{y}" font-family="{MONO}" font-size="16" fill="{T_ISTEM}">{istem}</text>'
                f'<text x="{x0}" y="{y}" font-family="{MONO}" font-size="16" fill="{renk}" '
                f'textLength="{n * harf:.1f}" lengthAdjust="spacingAndGlyphs">{escape(metin)}</text>'
                f'<g class="ortu o{i}"><rect x="{x0}" y="{y - 17}" width="{n * harf + 4:.1f}" height="23" fill="{T_ZEMIN}"/>'
                f'<rect class="imlec i{i}" x="{x0}" y="{y - 15}" width="9" height="19" fill="{T_METIN}"/></g></g>')
        else:
            govde.append(f'<text class="satir s{i}" x="{sol}" y="{y}" font-family="{MONO}" font-size="16" fill="{renk}" '
                         f'textLength="{len(metin) * harf:.1f}" lengthAdjust="spacingAndGlyphs">{escape(metin)}</text>')

    pencere = (f'<rect width="{gen}" height="{yuk}" rx="12" fill="{T_ZEMIN}"/>'
               f'<path d="M0 12a12 12 0 0 1 12-12h{gen - 24}a12 12 0 0 1 12 12v24H0z" fill="{T_UST}"/>'
               + "".join(f'<circle cx="{22 + k * 20}" cy="18" r="6" fill="{r}"/>'
                         for k, r in enumerate(["#ff5f57", "#febc2e", "#28c840"]))
               + f'<text x="{gen / 2}" y="23" text-anchor="middle" font-family="{SERIF}" font-size="14" fill="{T_SOLUK}">'
                 f'Terminal — NotDefteri</text>')
    hareket_azalt = ".satir, .ortu, .imlec { animation: none; opacity: 1; transform: none; } .ortu { display: none; }"
    return svg_belgesi(gen, yuk, "Kurulum: depoyu klonla, kısayolu kur, not yazınca uygulama açılır",
                       "\n".join(css), hareket_azalt, pencere + "".join(govde))


def svg_belgesi(gen, yuk, baslik, css, hareket_azalt, icerik):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{gen}" height="{yuk}" viewBox="0 0 {gen} {yuk}" '
            f'role="img" aria-label="{escape(baslik)}"><title>{escape(baslik)}</title>\n<style>\n'
            f".kaynak, .gorunum, .etiket, .satir {{ opacity: 0; }}\n"
            f"{css}\n@media (prefers-reduced-motion: reduce) {{ {hareket_azalt} }}\n</style>\n{icerik}\n</svg>\n")


if __name__ == "__main__":
    for ad, uret in [("ozellikler.svg", ozellikler_svg), ("kurulum.svg", kurulum_svg)]:
        yol = DOCS / ad
        yol.write_text(uret(), encoding="utf-8")
        print(f"{yol} — {yol.stat().st_size / 1024:.1f} KB")
