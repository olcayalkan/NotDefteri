#!/usr/bin/env python3
"""README animasyonlarını üretir: docs/baslik.svg, docs/kart-*.svg, docs/kurulum.svg.

Hepsi aynı mantığı izler: Markdown kaynağı yazılır, uygulamadaki gibi biçimlenmiş hâline
dönüşür. SVG içindeki CSS animasyonu GitHub'da <img> ile oynar. Hareket kuralları
(emilkowalski/skills `animate`): yalnızca transform ve opacity; giriş/çıkış güçlü ease-out,
ekranda yer değiştirme ease-in-out; ardışık öğeler 60 ms kademeli; prefers-reduced-motion
açıkken son hâl durağan görünür. Gereksinim yok (yalnızca Python standart kütüphanesi).

    python3 scripts/readme-animasyonlar.py
"""
from html import escape
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"

# Sepya teması (Tema.swift).
ZEMIN = "#d6cfba"
SAYFA = "#e4ddc9"
CERCEVE = "#c2b89e"
CIZGI = "#cec7b1"
KENAR = "#be8070"
METIN = "#3a3026"
ISARET = "#968670"
ALT = "#605444"
KUTU = "#c7bda6"
BAG = "#1f5f9e"
UYARI_ZEMIN = "#e6d29a"
UYARI_KENAR = "#c9a227"

SERIF = "Georgia, 'Times New Roman', serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', monospace"
EASE_OUT = "cubic-bezier(0.23, 1, 0.32, 1)"       # giriş ve çıkış
EASE_IN_OUT = "cubic-bezier(0.77, 0, 0.175, 1)"   # ekranda yer değiştirme


def yuzde(t, toplam):
    return f"{max(0.0, min(100.0, t / toplam * 100)):.3f}%"


def anahtar_kareler(ad, toplam, adimlar, egri=EASE_OUT):
    """adimlar: [(saniye, {css özellikleri})]. Her adımdan sonraki geçiş `egri` ile yapılır."""
    satirlar = []
    for t, ozellik in adimlar:
        govde = "; ".join(f"{k}: {v}" for k, v in ozellik.items())
        satirlar.append(f"  {yuzde(t, toplam)} {{ {govde}; animation-timing-function: {egri}; }}")
    return f"@keyframes {ad} {{\n" + "\n".join(satirlar) + "\n}"


def gir_cik(ad, toplam, gir, cik, kayma="translateY(6px)", cikis_kayma=None, sure=0.4):
    """Öğe `gir` anında kayarak belirir, `cik` anında söner (çıkış girişin tersinden)."""
    cikis_kayma = cikis_kayma or kayma
    return anahtar_kareler(ad, toplam, [
        (0, {"opacity": 0, "transform": kayma}),
        (gir, {"opacity": 0, "transform": kayma}),
        (gir + sure, {"opacity": 1, "transform": "translate(0, 0)"}),
        (cik, {"opacity": 1, "transform": "translate(0, 0)"}),
        (cik + 0.3, {"opacity": 0, "transform": cikis_kayma}),
        (toplam, {"opacity": 0, "transform": cikis_kayma}),
    ])


def svg_belgesi(gen, yuk, baslik, css, hareket_azalt, icerik):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{gen}" height="{yuk}" viewBox="0 0 {gen} {yuk}" '
            f'role="img" aria-label="{escape(baslik)}"><title>{escape(baslik)}</title>\n<style>\n'
            f".anim {{ opacity: 0; }}\n{css}\n"
            f"@media (prefers-reduced-motion: reduce) {{ {hareket_azalt} }}\n</style>\n{icerik}\n</svg>\n")


# ───────────────────────────── Başlık ─────────────────────────────

SLOGAN = "Notların, yapılacakların ve fikirlerin için sade bir defter — macOS ve Linux'ta."
ETIKETLER = ["✍️ Yazarken biçimlenir", "✅ Yapılacaklar", "🖼️ Görseller", "🔗 Sayfa bağları", "📁 Kendi dosyaların"]


def baslik_svg():
    gen, yuk, sol = 1000, 270, 96
    toplam = 9.5
    harf = 32.4                      # 54 px tek aralıklı font; textLength ile sabitlenir
    yazim_bas, yazim_hiz = 0.6, 0.09
    yazim_son = yazim_bas + 12 * yazim_hiz
    isaret_gen = 2 * harf
    css = [
        # "# NotDefteri" harf harf açılır: örtü ve imleç adım adım sağa kayar.
        f"@keyframes ortu {{ 0% {{ transform: translateX(0); }} "
        f"{yuzde(yazim_bas, toplam)} {{ transform: translateX(0); animation-timing-function: steps(12, end); }} "
        f"{yuzde(yazim_son, toplam)} {{ transform: translateX({12 * harf}px); }} 100% {{ transform: translateX({12 * harf}px); }} }}",
        anahtar_kareler("imlec", toplam, [(0, {"opacity": 1}), (yazim_son + 0.3, {"opacity": 1}),
                                          (yazim_son + 0.301, {"opacity": 0}), (toplam, {"opacity": 0})], egri="linear"),
        # "# " söner, düz metin yerine kayar, ardından başlık fontu belirir.
        anahtar_kareler("isaret", toplam, [(0, {"opacity": 1}), (2.0, {"opacity": 1}), (2.25, {"opacity": 0}),
                                           (toplam, {"opacity": 0})]),
        anahtar_kareler("mono", toplam, [(0, {"opacity": 1, "transform": "translateX(0)"}),
                                         (2.1, {"opacity": 1, "transform": "translateX(0)"}),
                                         (2.55, {"opacity": 1, "transform": f"translateX({-isaret_gen}px)"}),
                                         (2.7, {"opacity": 0, "transform": f"translateX({-isaret_gen}px)"}),
                                         (toplam, {"opacity": 0, "transform": f"translateX({-isaret_gen}px)"})],
                        egri=EASE_IN_OUT),
        gir_cik("baslik", toplam, 2.55, 8.6, kayma="translateY(4px)", sure=0.35),
        gir_cik("slogan", toplam, 3.0, 8.65, kayma="translateY(8px)"),
    ]
    govde = [
        f'<rect width="{gen}" height="{yuk}" rx="16" fill="{ZEMIN}"/>',
        f'<text class="anim isaret" x="{sol}" y="118" font-family="{MONO}" font-size="54" fill="{ISARET}" '
        f'textLength="{harf}" lengthAdjust="spacingAndGlyphs">#</text>',   # boşluk konumla verilir: textLength sondaki boşluğu yok sayıp # işaretini geriyordu
        f'<text class="anim mono" x="{sol + isaret_gen}" y="118" font-family="{MONO}" font-size="54" fill="{METIN}" '
        f'textLength="{10 * harf}" lengthAdjust="spacingAndGlyphs">NotDefteri</text>',
        f'<g class="ortu"><rect x="{sol}" y="66" width="{12 * harf + 8}" height="66" fill="{ZEMIN}"/>'
        f'<rect class="imlec" x="{sol + 2}" y="70" width="5" height="58" fill="{METIN}"/></g>',
        f'<text class="anim baslik" x="{sol}" y="120" font-family="{SERIF}" font-weight="bold" font-size="76" '
        f'fill="{METIN}">NotDefteri</text>',
        f'<text class="anim slogan" x="{sol + 2}" y="172" font-family="{SERIF}" font-style="italic" font-size="25" '
        f'fill="{ALT}">{escape(SLOGAN)}</text>',
    ]
    x = sol
    for i, etiket in enumerate(ETIKETLER):
        # Georgia 17 px'te harf başına ~8 px (Pillow ile ölçüldü); emoji ~24 px. Yazı ortalanır,
        # font farklı olsa da kutudan taşmaz.
        en = len(etiket.split(" ", 1)[1]) * 8.1 + 24 + 30
        css.append(gir_cik(f"e{i}", toplam, 3.3 + i * 0.06, 8.7 + i * 0.03, kayma="translateY(8px)"))
        css.append(f".e{i} {{ animation: e{i} {toplam}s infinite; }}")
        govde.append(f'<g class="anim e{i}"><rect x="{x:.0f}" y="196" width="{en:.0f}" height="34" rx="17" fill="{KUTU}"/>'
                     f'<text x="{x + en / 2:.0f}" y="219" text-anchor="middle" font-family="{SERIF}" font-size="17" '
                     f'fill="{METIN}">{escape(etiket)}</text></g>')
        x += en + 10
    assert x < gen - 20, f"etiketler sığmıyor: {x}"
    # Defter çizgileri en üstte: örtü kutusu altta kalan çizgileri kesmesin.
    govde.append("".join(f'<line x1="0" y1="{y}" x2="{gen}" y2="{y}" stroke="{CIZGI}" stroke-opacity="0.7"/>'
                         for y in range(44, yuk, 34)))
    govde.append(f'<line x1="70" y1="0" x2="70" y2="{yuk}" stroke="{KENAR}" stroke-width="2"/>')
    for ad in ["ortu", "imlec", "isaret", "mono", "baslik", "slogan"]:
        css.append(f".{ad} {{ animation: {ad} {toplam}s infinite; }}")
    hareket_azalt = (".ortu, .isaret, .mono { display: none; } "
                     ".anim, .baslik, .slogan { animation: none; opacity: 1; transform: none; }")
    return svg_belgesi(gen, yuk, "NotDefteri — " + SLOGAN, "\n".join(css), hareket_azalt, "".join(govde))


# ───────────────────────────── Özellik kartları ─────────────────────────────

def _kaynak(*parcalar):
    """Markdown kaynağı: işaretler soluk, metin koyu (tek aralıklı)."""
    return (f'<text font-family="{MONO}" font-size="18">'
            + "".join(f'<tspan fill="{ISARET if isaret else METIN}">{escape(m)}</tspan>' for m, isaret in parcalar)
            + "</text>")


def _yazi(metin, boyut=20, renk=METIN, **ek):
    nitelik = " ".join(f'{k.replace("_", "-")}="{v}"' for k, v in ek.items())
    return f'<text font-family="{SERIF}" font-size="{boyut}" fill="{renk}" {nitelik}>{metin}</text>'


GORSEL = (f'<rect x="0" y="-30" width="64" height="44" rx="6" fill="#b9c9d6"/>'
          f'<circle cx="46" cy="-18" r="6" fill="#f2d27a"/>'
          f'<path d="M4 10 L22 -10 L34 2 L42 -6 L60 10 Z" fill="#7d9a6a"/>')

# (dosya adı, README bağlantısı, emoji, başlık, açıklama, demo öğeleri)
# Demo öğesi: (svg, x, y, giriş sn, çıkış sn ya da None = sona kadar, kayma yönü)
KARTLAR = [
    ("bicim", "#yazarken-biçimlendirme", "✍️", "Yazarken biçimlenir", "İşaretleri yaz, metin anında şekillensin.", [
        (_kaynak(("**", True), ("Önemli", False), ("**", True), (" toplantı", False)), 0, 0, 0.3, 1.8, "x"),
        (_yazi('<tspan font-weight="bold">Önemli</tspan> toplantı', 22), 0, 0, 1.95, None, "y"),
    ]),
    ("yapilacaklar", "#yapılacaklar", "✅", "Yapılacaklar", "Bütün işlerin Ana Sayfa'da tek listede.", [
        (_kaynak(("- [ ] ", True), ("Raporu gönder", False)), 0, 0, 0.3, 1.8, "x"),
        (f'<rect x="0" y="-17" width="19" height="19" rx="4" fill="none" stroke="{METIN}" stroke-width="2"/>'
         + _yazi("Raporu gönder", 21, x="30"), 0, 0, 1.95, None, "y"),
        (f'<rect x="0" y="-17" width="19" height="19" rx="4" fill="{METIN}"/>'
         f'<path d="M4 -8 L8 -4 L15 -12" stroke="{SAYFA}" stroke-width="2.5" fill="none"/>'
         f'<line class="cizik" x1="30" y1="-6" x2="168" y2="-6" stroke="{METIN}" stroke-width="2"/>', 0, 0, 3.4, None, "o"),
    ]),
    ("baglar", "#sayfalar-arası-bağ", "🔗", "Sayfalar arası bağ", "Sayfaları birbirine bağla, tek tıkla geç.", [
        (_kaynak(("[[", True), ("Proje Planı", False), ("]]", True)), 0, 0, 0.3, 1.8, "x"),
        (_yazi('📄 <tspan text-decoration="underline">Proje Planı</tspan>', 21, BAG), 0, 0, 1.95, None, "y"),
    ]),
    ("gorseller", "#görsel-ekleme", "🖼️", "Görseller", "Sürükle bırak, görsel sayfada görünsün.", [
        (f'<rect x="-6" y="-38" width="300" height="58" rx="8" fill="none" stroke="{ISARET}" stroke-dasharray="6 5"/>'
         + _yazi("Görseli buraya sürükle", 17, ISARET, x="56", y="-4"), 0, 0, 0.3, 1.9, "o"),
        (GORSEL + _yazi("plan.png", 16, ALT, x="78", y="-4"), 0, 0, 1.95, None, "d"),
    ]),
    ("agac", "#sayfa-oluşturma", "🌳", "Sayfa ağacı", "Alt sayfalar ekle, sürükleyerek düzenle.", [
        (_yazi("📁 Proje", 18), 0, -22, 0.3, None, "y"),
        (_yazi("📄 Toplantı notları", 17, ALT), 26, 2, 0.9, None, "y"),
        (_yazi("📄 Bütçe", 17, ALT), 26, 25, 1.4, None, "y"),
    ]),
    ("dosyalar", "#notlar-nerede-saklanıyor", "📁", "Notlar senin", "Bilgisayarında sıradan dosyalar olarak durur.", [
        (_yazi("📂 Belgeler › NotDefteri", 18), 0, -22, 0.3, None, "y"),
        (_yazi("📄 Toplantı notları", 17, ALT), 26, 2, 0.9, None, "y"),
        (_yazi("Başka uygulamalarla da açılır", 15, ISARET, font_style="italic"), 26, 25, 1.5, None, "y"),
    ]),
]


def kart_svg(sira, ad, emoji, baslik, aciklama, demo):
    gen, yuk = 480, 214
    toplam = 7.5
    # Kartlar aynı anda değil, sırayla döner; sayfa canlı ama dağınık görünmez.
    kayma = sira * 0.25
    cikis = toplam - 0.9
    css, govde = [], [
        f'<rect x="1" y="1" width="{gen - 2}" height="{yuk - 2}" rx="16" fill="{ZEMIN}" stroke="{CERCEVE}" stroke-width="2"/>',
        _yazi(f"{emoji} {escape(baslik)}", 23, METIN, x="26", y="46", font_weight="bold"),
        _yazi(escape(aciklama), 15, ALT, x="26", y="72"),
        f'<rect x="18" y="92" width="{gen - 36}" height="84" rx="10" fill="{SAYFA}"/>',
        _yazi("Nasıl kullanılır →", 13, BAG, x=str(gen - 24), y="200", text_anchor="end"),
    ]
    kaymalar = {"x": ("translateX(8px)", "translateX(-8px)"), "y": ("translateY(6px)", "translateY(6px)"),
                "o": ("translate(0, 0)", "translate(0, 0)"), "d": ("translateY(-14px) scale(0.96)", "translateY(6px)")}
    for i, (svg, x, y, gir, cik, yon) in enumerate(demo):
        giris, cikis_k = kaymalar[yon]
        css.append(gir_cik(f"d{i}", toplam, gir + kayma, (cik + kayma) if cik else cikis + i * 0.04,
                           kayma=giris, cikis_kayma=cikis_k))
        css.append(f".d{i} {{ animation: d{i} {toplam}s infinite; transform-box: fill-box; }}")
        govde.append(f'<g transform="translate({40 + x} {140 + y})"><g class="anim d{i}">{svg}</g></g>')
    # Yapılacak işaretlenince üstü soldan sağa çizilir.
    css.append(anahtar_kareler("cizik", toplam, [
        (0, {"transform": "scaleX(0)"}), (3.5 + kayma, {"transform": "scaleX(0)"}),
        (3.85 + kayma, {"transform": "scaleX(1)"}), (toplam, {"transform": "scaleX(1)"})]))
    css.append(f".cizik {{ animation: cizik {toplam}s infinite; transform-box: fill-box; transform-origin: left center; }}")
    # Hareket azaltılınca: kaynak ve sürükleme ipucu gizli, son hâl görünür.
    gizli = ", ".join(f".d{i}" for i, (_, _, _, _, cik, _) in enumerate(demo) if cik)
    hareket_azalt = (f".anim, .cizik {{ animation: none; opacity: 1; transform: none; }}"
                     + (f" {gizli} {{ display: none; }}" if gizli else ""))
    return svg_belgesi(gen, yuk, f"{baslik}: {aciklama}", "\n".join(css), hareket_azalt, "".join(govde))


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
                f'<g class="anim satir s{i}">'
                f'<text x="{sol}" y="{y}" font-family="{MONO}" font-size="16" fill="{T_ISTEM}">{istem}</text>'
                f'<text x="{x0}" y="{y}" font-family="{MONO}" font-size="16" fill="{renk}" '
                f'textLength="{n * harf:.1f}" lengthAdjust="spacingAndGlyphs">{escape(metin)}</text>'
                f'<g class="ortu o{i}"><rect x="{x0}" y="{y - 17}" width="{n * harf + 4:.1f}" height="23" fill="{T_ZEMIN}"/>'
                f'<rect class="imlec i{i}" x="{x0}" y="{y - 15}" width="9" height="19" fill="{T_METIN}"/></g></g>')
        else:
            govde.append(f'<text class="anim satir s{i}" x="{sol}" y="{y}" font-family="{MONO}" font-size="16" fill="{renk}" '
                         f'textLength="{len(metin) * harf:.1f}" lengthAdjust="spacingAndGlyphs">{escape(metin)}</text>')

    pencere = (f'<rect width="{gen}" height="{yuk}" rx="12" fill="{T_ZEMIN}"/>'
               f'<path d="M0 12a12 12 0 0 1 12-12h{gen - 24}a12 12 0 0 1 12 12v24H0z" fill="{T_UST}"/>'
               + "".join(f'<circle cx="{22 + k * 20}" cy="18" r="6" fill="{r}"/>'
                         for k, r in enumerate(["#ff5f57", "#febc2e", "#28c840"]))
               + f'<text x="{gen / 2}" y="23" text-anchor="middle" font-family="{SERIF}" font-size="14" fill="{T_SOLUK}">'
                 f'Terminal — NotDefteri</text>')
    hareket_azalt = ".anim, .satir, .ortu, .imlec { animation: none; opacity: 1; transform: none; } .ortu { display: none; }"
    return svg_belgesi(gen, yuk, "Kurulum: depoyu klonla, kısayolu kur, not yazınca uygulama açılır",
                       "\n".join(css), hareket_azalt, pencere + "".join(govde))


if __name__ == "__main__":
    ciktilar = [("baslik.svg", baslik_svg()), ("kurulum.svg", kurulum_svg())]
    ciktilar += [(f"kart-{ad}.svg", kart_svg(i, ad, emoji, baslik, aciklama, demo))
                 for i, (ad, _, emoji, baslik, aciklama, demo) in enumerate(KARTLAR)]
    for ad, icerik in ciktilar:
        yol = DOCS / ad
        yol.write_text(icerik, encoding="utf-8")
        print(f"{yol.relative_to(DOCS.parent)} — {yol.stat().st_size / 1024:.1f} KB")
