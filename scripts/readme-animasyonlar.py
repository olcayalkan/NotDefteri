#!/usr/bin/env python3
"""README animasyonlarını üretir: docs/baslik.svg, docs/kart-*.svg, docs/kurulum.svg.

Hepsi aynı mantığı izler: Markdown kaynağı yazılır, uygulamadaki gibi biçimlenmiş hâline
dönüşür. SVG içindeki CSS animasyonu GitHub'da <img> ile oynar.

Tasarım: uygulamanın sepya kâğıt kimliği; serif başlık + sans metin, kendi çizilmiş tutarlı
simgeler (emoji yok), ince kenarlık, uçuk pastel vurgu, hafif kâğıt dokusu (minimalist-ui,
notion DESIGN.md, redesign-existing-projects). Hareket (emilkowalski/skills `animate`):
yalnızca transform ve opacity; giriş/çıkış güçlü ease-out, yer değiştirme ease-in-out;
80 ms kademe. Hareket azaltıldığında kayma kalkar, solma ve yazma sürer ("az ve yumuşak,
sıfır değil"). Animasyon desteklemeyen görüntüleyicide son hâl görünür.

    python3 scripts/readme-animasyonlar.py
"""
from html import escape
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"

# Sepya teması (Tema.swift) ve ondan türeyen sıcak tek renk ailesi.
SEPYA = "#d6cfba"
KAGIT = "#ede7d8"
YUZEY = "#f6f2e7"
MUREKKEP = "#2f2a24"
SOLUK = "#5f564a"      # kâğıtta 5.8:1, sepyada 4.6:1 (WCAG AA)
ISARET = "#857862"     # Markdown işaretleri bilerek soluk ama okunur: 3.9:1
CIZGI = "#c9c0a9"
KENAR = "#be8070"
VURGU = "#2f5f7f"      # tek vurgu rengi: bağlantılar
PASTEL = {             # (zemin, simge) — doygunluğu düşük, sıcak tonlu
    "sari": ("#f1e3bb", "#86590a"),
    "yesil": ("#e0e8d4", "#3f5f36"),
    "mavi": ("#dce5e8", "#2f5f7f"),
    "kum": ("#e6dcc6", "#6b5a3e"),
    "kirmizi": ("#f0dcd3", "#9a3f2d"),
    "murekkep": (MUREKKEP, "#f6f2e7"),
}

SERIF = "'Iowan Old Style', 'Palatino Linotype', Georgia, serif"
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif"
MONO = "'SF Mono', ui-monospace, Menlo, Consolas, 'DejaVu Sans Mono', monospace"
EASE_OUT = "cubic-bezier(0.23, 1, 0.32, 1)"
EASE_IN_OUT = "cubic-bezier(0.77, 0, 0.175, 1)"

# 24×24 ızgarada, 1.75 kalınlıkta, yuvarlak uçlu kendi simge setimiz.
SIMGELER = {
    "kalem": '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
    "onay": '<rect x="3.5" y="3.5" width="17" height="17" rx="4"/><path d="M8 12.5l2.7 2.7L16.5 9.5"/>',
    "gorsel": '<rect x="3" y="5" width="18" height="14" rx="3"/><circle cx="9" cy="10" r="1.6"/><path d="M4.5 17.5l4.8-4.8 3.7 3.7 2.4-2.4 4 3.5"/>',
    "agac": '<circle cx="6" cy="5" r="2"/><circle cx="16.5" cy="11" r="2"/><circle cx="16.5" cy="18.5" r="2"/><path d="M6 7v11.5h8.5M6 11h8.5"/>',
    "klasor": '<path d="M3 7.5A2.5 2.5 0 0 1 5.5 5h3.7l2 2.2h7.3A2.5 2.5 0 0 1 21 9.7v7.8a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z"/>',
    "arti": '<path d="M12 5v14M5 12h14"/>',
    "ara": '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.6-4.6"/>',
    "gecmis": '<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4.5 4.5v4h4"/><path d="M12 8.5V12l2.8 1.8"/>',
    "cop": '<path d="M4.5 7h15M9.5 7V4.8h5V7M6.8 7l.9 12.2h8.6L17.2 7"/>',
    "disa": '<path d="M12 4v10.5M8 8l4-4 4 4"/><path d="M5 14.5v3A2.5 2.5 0 0 0 7.5 20h9a2.5 2.5 0 0 0 2.5-2.5v-3"/>',
    "kayit": '<path d="M5 4.5h11l3 3v12H5z"/><path d="M8.5 4.5v4.5h6V4.5"/><path d="M8.5 19.5v-5h7v5"/>',
    "bag": '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
    "ampul": '<path d="M9.5 18h5M10.5 21h3"/><path d="M12 3a6 6 0 0 0-3.6 10.8c.7.5 1.1 1.3 1.1 2.2h5c0-.9.4-1.7 1.1-2.2A6 6 0 0 0 12 3z"/>',
    "sayfa": '<path d="M6.5 3.5h7.5l4 4v13h-11.5z"/><path d="M14 3.5v4h4"/>',
}


def simge(ad, x, y, boyut=24, renk=MUREKKEP):
    olcek = boyut / 24
    # Çizgi kalınlığı ölçekten bağımsız 1.75: büyük ve küçük simgeler aynı ağırlıkta görünür.
    return (f'<g transform="translate({x} {y}) scale({olcek:.3f})" fill="none" stroke="{renk}" '
            f'stroke-width="{1.75 / olcek:.2f}" stroke-linecap="round" stroke-linejoin="round">{SIMGELER[ad]}</g>')


def simge_karosu(ad, x, y, ton, boyut=44):
    zemin, renk = PASTEL[ton]
    return (f'<rect x="{x}" y="{y}" width="{boyut}" height="{boyut}" rx="11" fill="{zemin}"/>'
            + simge(ad, x + (boyut - 24) / 2, y + (boyut - 24) / 2, renk=renk))


def yazi(metin, x=0, y=0, boyut=17, renk=MUREKKEP, aile=SANS, **ek):
    nitelik = " ".join(f'{k.replace("_", "-")}="{v}"' for k, v in ek.items())
    return f'<text x="{x}" y="{y}" font-family="{aile}" font-size="{boyut}" fill="{renk}" {nitelik}>{metin}</text>'


def kaynak(parcalar, x=0, y=0, boyut=19):
    """Markdown kaynağı: işaretler soluk, metin koyu, tek aralıklı."""
    return (f'<text x="{x}" y="{y}" font-family="{MONO}" font-size="{boyut}">'
            + "".join(f'<tspan fill="{ISARET if isaret else MUREKKEP}">{escape(m)}</tspan>' for m, isaret in parcalar)
            + "</text>")


def doku(gen, yuk, rx):
    """Kâğıt dokusu: çok hafif gren; düz dijital yüzeyin soğukluğunu kırar."""
    return (f'<filter id="gren" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" '
            f'baseFrequency="0.85" numOctaves="2" stitchTiles="stitch"/>'
            f'<feColorMatrix values="0 0 0 0 0.18 0 0 0 0 0.15 0 0 0 0 0.11 0 0 0 0.07 0"/></filter>'
            f'<rect width="{gen}" height="{yuk}" rx="{rx}" filter="url(#gren)"/>')


class Sahne:
    """Bir SVG'nin zaman çizelgesi. Her hareket iki sürümle yazılır: tam ve hareket-azaltılmış
    (transform'suz, yalnızca opacity). Azaltılmış sürüm aynı zamanlamayla solarak oynar."""

    def __init__(self, toplam):
        self.toplam = toplam
        self.css = []
        self.azaltilacak = []

    def yuzde(self, t):
        return f"{max(0.0, min(100.0, t / self.toplam * 100)):.3f}%"

    def kareler(self, ad, adimlar, egri=EASE_OUT, azalt=True):
        def yaz(ad_, transform_var):
            satirlar = []
            for t, oz in adimlar:
                oz = {k: v for k, v in oz.items() if transform_var or k != "transform"}
                govde = "; ".join(f"{k}: {v}" for k, v in oz.items())
                satirlar.append(f"  {self.yuzde(t)} {{ {govde}; animation-timing-function: {egri}; }}")
            return f"@keyframes {ad_} {{\n" + "\n".join(satirlar) + "\n}"
        self.css.append(yaz(ad, True))
        self.css.append(f".{ad} {{ animation: {ad} {self.toplam}s infinite; }}")
        if azalt:
            self.css.append(yaz(f"{ad}-a", False))
            self.azaltilacak.append(ad)

    def gir_cik(self, ad, gir, cik, kayma="translateY(8px)", cikis_kayma=None, sure=0.45):
        """`gir`de kayarak belirir, `cik`ta söner; çıkış girişin tersinden (animate skill'i)."""
        cikis_kayma = cikis_kayma or kayma
        self.kareler(ad, [
            (0, {"opacity": 0, "transform": kayma}),
            (gir, {"opacity": 0, "transform": kayma}),
            (gir + sure, {"opacity": 1, "transform": "translate(0, 0)"}),
            (cik, {"opacity": 1, "transform": "translate(0, 0)"}),
            (cik + 0.3, {"opacity": 0, "transform": cikis_kayma}),
            (self.toplam, {"opacity": 0, "transform": cikis_kayma}),
        ])

    def svg(self, gen, yuk, baslik, icerik):
        azalt = " ".join(f".{ad} {{ animation-name: {ad}-a; }}" for ad in self.azaltilacak)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{gen}" height="{yuk}" viewBox="0 0 {gen} {yuk}" '
                f'role="img" aria-label="{escape(baslik)}"><title>{escape(baslik)}</title>\n<style>\n'
                # Animasyonsuz görüntüleyicide geçici öğeler (kaynak, ipucu, imleç) görünmez; son hâl kalır.
                ".gecici { opacity: 0; }\n"
                + "\n".join(self.css)
                + f"\n@media (prefers-reduced-motion: reduce) {{ {azalt} }}\n</style>\n{icerik}\n</svg>\n")


# ───────────────────────────── Başlık ─────────────────────────────

SLOGAN = "Notların, yapılacakların ve fikirlerin için sade bir defter."
ETIKETLER = [("kalem", "sari", "Yazarken biçimlenir"), ("onay", "yesil", "Yapılacaklar"),
             ("gorsel", "mavi", "Görseller"), ("agac", "kum", "Sayfa ağacı"), ("klasor", "kirmizi", "Kendi dosyaların")]


def baslik_svg():
    gen, yuk, sol = 1000, 300, 104
    s = Sahne(9.5)
    harf = 32.4                       # 54 px tek aralıklı; textLength ile sabitlenir
    yazim_bas, yazim_son = 0.6, 0.6 + 12 * 0.09
    s.css.append(f"@keyframes ortu {{ 0% {{ transform: translateX(0); }} "
                 f"{s.yuzde(yazim_bas)} {{ transform: translateX(0); animation-timing-function: steps(12, end); }} "
                 f"{s.yuzde(yazim_son)} {{ transform: translateX({12 * harf}px); }} 100% {{ transform: translateX({12 * harf}px); }} }}"
                 f"\n.ortu {{ animation: ortu {s.toplam}s infinite; }}")   # yazma azaltılmaz: içerik yer değiştirmiyor
    s.kareler("ortu-gizle", [(0, {"opacity": 1}), (yazim_son + 0.3, {"opacity": 1}), (yazim_son + 0.301, {"opacity": 0}),
                             (s.toplam, {"opacity": 0})], egri="linear", azalt=False)
    s.kareler("isaret", [(0, {"opacity": 1}), (2.0, {"opacity": 1}), (2.25, {"opacity": 0}), (s.toplam, {"opacity": 0})])
    s.kareler("mono", [(0, {"opacity": 1, "transform": "translateX(0)"}), (2.1, {"opacity": 1, "transform": "translateX(0)"}),
                       (2.55, {"opacity": 1, "transform": f"translateX({-2 * harf}px)"}),
                       (2.7, {"opacity": 0, "transform": f"translateX({-2 * harf}px)"}),
                       (s.toplam, {"opacity": 0, "transform": f"translateX({-2 * harf}px)"})], egri=EASE_IN_OUT)
    s.gir_cik("baslik", 2.55, 8.6, kayma="translateY(4px)", sure=0.35)
    s.gir_cik("slogan", 3.0, 8.65)
    s.gir_cik("ust", 0.2, 8.7, kayma="translateY(-4px)")
    govde = [
        f'<rect width="{gen}" height="{yuk}" rx="18" fill="{SEPYA}"/>',
        yazi("MACOS · LINUX", gen - 40, 44, 12, SOLUK, MONO, text_anchor="end", letter_spacing="1.5", **{"class": "ust"}),
        yazi("#", sol, 124, 54, ISARET, MONO, textLength=harf, lengthAdjust="spacingAndGlyphs", **{"class": "isaret gecici"}),
        yazi("NotDefteri", sol + 2 * harf, 124, 54, MUREKKEP, MONO, textLength=10 * harf, lengthAdjust="spacingAndGlyphs",
             **{"class": "mono gecici"}),
        # Örtü animasyonsuz görüntüleyicide yazının sağında durur (son hâl).
        # Örtü yazma bitince gizlenir: dokusuz düz kutu çizgileri kesip yama gibi kalıyordu.
        f'<g class="ortu-gizle gecici"><g class="ortu" transform="translate({12 * harf} 0)">'
        f'<rect x="{sol}" y="70" width="{12 * harf + 8}" height="68" fill="{SEPYA}"/>'
        f'<rect class="imlec" x="{sol + 2}" y="76" width="5" height="58" fill="{MUREKKEP}"/></g></g>',
        # Doku ve çizgiler örtünün üstünde: yazma sırasında örtü dokusuz bir yama gibi görünmesin.
        doku(gen, yuk, 18),
        "".join(f'<line x1="0" y1="{y}" x2="{gen}" y2="{y}" stroke="{CIZGI}" stroke-opacity="0.55"/>' for y in range(48, yuk, 34)),
        f'<line x1="74" y1="0" x2="74" y2="{yuk}" stroke="{KENAR}" stroke-width="2" stroke-opacity="0.8"/>',
        yazi("NotDefteri", sol - 2, 128, 84, MUREKKEP, SERIF, font_weight="bold", letter_spacing="-2.5", **{"class": "baslik"}),
        yazi(escape(SLOGAN), sol, 178, 24, SOLUK, SANS, **{"class": "slogan"}),
    ]
    x = sol
    for i, (ad, ton, etiket) in enumerate(ETIKETLER):
        # Sistem sans 15 px'te harf başına ~7.6 px; yazı ortalı, kutu cömert.
        en = len(etiket) * 7.4 + 54     # 13 sol + 18 simge + 8 boşluk + yazı + 15 sağ
        s.gir_cik(f"e{i}", 3.35 + i * 0.08, 8.7 + i * 0.03)
        zemin, renk = PASTEL[ton]
        govde.append(f'<g class="e{i}"><rect x="{x:.0f}" y="214" width="{en:.0f}" height="38" rx="9" fill="{zemin}"/>'
                     + simge(ad, x + 13, 224, 18, renk)
                     + yazi(escape(etiket), f"{x + 39 + (en - 54) / 2:.0f}", 238.5, 15, MUREKKEP, text_anchor="middle",
                            font_weight="500") + "</g>")
        x += en + 10
    assert x < gen - 24, f"etiketler sığmıyor: {x}"
    return s.svg(gen, yuk, "NotDefteri — " + SLOGAN + " macOS ve Linux'ta.", "".join(govde))


# ───────────────────────────── Özellik kartları ─────────────────────────────

def demo_satiri(metin_svg, x, y):
    return f'<g transform="translate({x} {y})">{metin_svg}</g>'


def kart(simge_ad, ton, baslik, aciklama, baglanti_yazi, demo, genis=False, toplam=8.0, kayma=0.0):
    """Kart: simge karosu, serif başlık, sans açıklama, demo sayfası, altta hizalı bağlantı.
    demo: [(svg, giriş, çıkış ya da None, yön)]; çıkışı olanlar geçicidir (kaynak, ipucu)."""
    gen, yuk = (1000, 300) if genis else (490, 320)
    s = Sahne(toplam)
    if genis:
        sayfa, metin_x, baslik_y, karo_y = (430, 28, 542, 244), 40, 136, 40
    else:
        sayfa, metin_x, baslik_y, karo_y = (24, 158, 442, 108), 32, 108, 32
    govde = [f'<rect x="1" y="1" width="{gen - 2}" height="{yuk - 2}" rx="16" fill="{KAGIT}" stroke="{MUREKKEP}" '
             f'stroke-opacity="0.13" stroke-width="1.5"/>', doku(gen, yuk, 16),
             f'<g class="karo">{simge_karosu(simge_ad, metin_x, karo_y, ton)}</g>',
             yazi(escape(baslik), metin_x, baslik_y, 30 if genis else 27, MUREKKEP, SERIF, font_weight="bold", letter_spacing="-0.6")]
    for i, satir in enumerate(aciklama):
        govde.append(yazi(escape(satir), metin_x, baslik_y + (34 if genis else 30) + i * 24, 17, SOLUK))
    # Bağlantılar her kartta aynı yükseklikte: yan yana kartlarda tek çizgi oluşturur.
    govde.append(yazi(f"{escape(baglanti_yazi)} →", metin_x, yuk - 30, 15, VURGU, font_weight="600"))
    sx, sy, sen, sboy = sayfa
    govde.append(f'<rect x="{sx}" y="{sy}" width="{sen}" height="{sboy}" rx="11" fill="{YUZEY}" stroke="{MUREKKEP}" '
                 f'stroke-opacity="0.08"/>')
    if simge_ad == "arti":
        # "+" karosu çeyrek tur dönerek belirir: kart "daha fazlası"nı açıyormuş gibi.
        s.gir_cik("karo", 0.2 + kayma, toplam - 0.8, "rotate(-90deg) scale(0.9)", "scale(0.9)", sure=0.55)
        s.css.append(".karo { transform-box: fill-box; transform-origin: center; }")
    kaymalar = {"x": ("translateX(10px)", "translateX(-10px)"), "y": ("translateY(8px)", "translateY(8px)"),
                "o": ("translate(0, 0)", "translate(0, 0)"), "d": ("translateY(-16px) scale(0.96)", "translateY(8px)"),
                "a": ("rotate(-90deg) scale(0.9)", "scale(0.9)")}
    for i, (svg, gir, cik, yon) in enumerate(demo):
        giris, cikis = kaymalar[yon]
        s.gir_cik(f"d{i}", gir + kayma, (cik + kayma) if cik else toplam - 0.9 + i * 0.03, giris, cikis)
        govde.append(f'<g class="d{i}{" gecici" if cik else ""}">{svg}</g>')
    # Yapılacak işaretlenince üstü soldan sağa çizilir (azaltılınca yalnızca belirir).
    s.kareler("cizik", [(0, {"opacity": 0, "transform": "scaleX(0)"}), (3.6 + kayma, {"opacity": 0, "transform": "scaleX(0)"}),
                        (3.61 + kayma, {"opacity": 1, "transform": "scaleX(0)"}), (3.95 + kayma, {"opacity": 1, "transform": "scaleX(1)"}),
                        (toplam - 0.9, {"opacity": 1, "transform": "scaleX(1)"}), (toplam - 0.6, {"opacity": 0, "transform": "scaleX(1)"}),
                        (toplam, {"opacity": 0, "transform": "scaleX(1)"})])
    s.css.append("[class^=d], .cizik { transform-box: fill-box; } [class^=d] { transform-origin: center; } "
                 ".cizik { transform-origin: left center; }")
    return s.svg(gen, yuk, f"{baslik}: {' '.join(aciklama)}", "".join(govde))


def kartlar():
    sari_z, sari_y = PASTEL["sari"]
    # Geniş kart: üç satır sırayla kaynaktan biçimli hâle dönüşür.
    bicim_demo = []
    satirlar = [
        ([("## ", True), ("Toplantı notları", False)],
         yazi("Toplantı notları", 0, 0, 27, MUREKKEP, SERIF, font_weight="bold", letter_spacing="-0.4")),
        ([("**", True), ("Karar:", False), ("**", True), (" bütçe ", False), ("==", True), ("onaylandı", False), ("==", True)],
         f'<rect x="120" y="-20" width="96" height="27" rx="4" fill="{sari_z}"/>'
         + yazi('<tspan font-weight="700">Karar:</tspan> bütçe onaylandı', 0, 0, 20, MUREKKEP)),
        ([("> [!💡 sarı] ", True), ("Cuma teslim", False)],
         f'<rect x="-12" y="-27" width="250" height="40" rx="8" fill="{sari_z}"/>'
         f'<rect x="-12" y="-27" width="3.5" height="40" rx="1.5" fill="{sari_y}"/>'
         + simge("ampul", 4, -18, 20, sari_y) + yazi("Cuma teslim", 32, 0, 19, MUREKKEP)),
    ]
    for i, (k, g) in enumerate(satirlar):
        y = 92 + i * 64
        bicim_demo.append((demo_satiri(kaynak(k), 466, y), 0.35 + i * 0.25, 1.9 + i * 0.25, "x"))
        bicim_demo.append((demo_satiri(g, 466, y), 2.05 + i * 0.25, None, "y"))

    yesil_y = PASTEL["yesil"][1]
    gorev = [
        (demo_satiri(kaynak([("- [ ] ", True), ("Raporu gönder", False)], boyut=18), 48, 220), 0.35, 1.9, "x"),
        (demo_satiri(f'<rect x="0" y="-17" width="19" height="19" rx="5" fill="none" stroke="{MUREKKEP}" stroke-width="1.75"/>'
                     + yazi("Raporu gönder", 30, 0, 19), 48, 220), 2.05, None, "y"),
        (demo_satiri(f'<rect x="0" y="-17" width="19" height="19" rx="5" fill="{yesil_y}"/>'
                     f'<path d="M4.5 -8 L8.2 -4.5 L14.5 -11.5" stroke="{YUZEY}" stroke-width="2.2" fill="none" '
                     f'stroke-linecap="round" stroke-linejoin="round"/>', 48, 220), 3.45, None, "o"),
        (demo_satiri(f'<line class="cizik" x1="30" y1="-6" x2="150" y2="-6" stroke="{MUREKKEP}" stroke-width="1.75"/>', 48, 220),
         0, None, "o"),
    ]

    mavi_z = PASTEL["mavi"][0]
    gorsel_kucuk = (f'<rect x="0" y="-34" width="72" height="50" rx="7" fill="{mavi_z}"/>'
                    f'<circle cx="52" cy="-20" r="6" fill="#e9cf86"/>'
                    f'<path d="M5 12 L25 -10 L38 3 L47 -6 L67 12 Z" fill="#8aa37a"/>')
    gorseller = [
        (demo_satiri(f'<rect x="-6" y="-40" width="396" height="66" rx="9" fill="none" stroke="{ISARET}" stroke-dasharray="6 5"/>'
                     + simge("gorsel", 104, -26, 22, ISARET) + yazi("Görseli buraya sürükle", 136, -8, 16, SOLUK), 48, 228),
         0.35, 1.95, "o"),
        (demo_satiri(gorsel_kucuk + yazi("plan.png", 90, -10, 16, SOLUK) + yazi("Sayfaya eklendi", 90, 10, 13, ISARET), 48, 228),
         2.05, None, "d"),
    ]

    def agac_satirlari(ust_simge, ust_ton, ust_yazi, alt):
        return [(demo_satiri(simge(ust_simge, 0, -17, 20, PASTEL[ust_ton][1]) + yazi(escape(ust_yazi), 30, 0, 17, MUREKKEP,
                                                                                       font_weight="600"), 48, 194), 0.35, None, "y")] + \
               [(demo_satiri(a, 76, 222 + j * 26), 0.9 + j * 0.5, None, "y") for j, a in enumerate(alt)]

    agac = agac_satirlari("klasor", "kum", "Proje", [simge("sayfa", 0, -16, 18, SOLUK) + yazi("Toplantı notları", 28, 0, 16, SOLUK),
                                                     simge("sayfa", 0, -16, 18, SOLUK) + yazi("Bütçe", 28, 0, 16, SOLUK)])
    dosyalar = agac_satirlari("klasor", "kirmizi", "Belgeler  ›  NotDefteri",
                              [simge("sayfa", 0, -16, 18, SOLUK) + yazi("Toplantı notları", 28, 0, 16, SOLUK),
                               yazi("Obsidian, VS Code ve diğer düzenleyicilerle açılır", 0, 0, 14, ISARET, font_style="italic")])

    # "+ Daha fazlası": artı döner, altı küçük özellik kademeli belirir.
    fazla_demo = []
    ogeler = [("ara", "Hızlı bulucu", "⌘P ile her sayfaya"), ("bag", "Sayfa bağları", "[[ ile sayfaları bağla"),
              ("gecmis", "Sayfa geçmişi", "Eski hâline dön"), ("cop", "Çöp kutusu", "30 gün geri getir"),
              ("disa", "Dışa aktarma", "PDF ya da web sayfası"), ("kayit", "Otomatik kayıt", "Yazarken kaydeder")]
    for i, (sim, ad, alt) in enumerate(ogeler):
        x, y = 466 + (i % 3) * 170, 118 + (i // 3) * 76
        fazla_demo.append((demo_satiri(simge(sim, 0, -18, 22) + yazi(escape(ad), 32, -2, 16, MUREKKEP, font_weight="600")
                                       + yazi(escape(alt), 32, 18, 13, SOLUK), x, y), 0.6 + i * 0.08, None, "y"))

    return [
        ("bicim", kart("kalem", "sari", "Yazarken biçimlenir",
                       ["İşaretleri yaz, metin anında şekillensin.", "Başlık, kalın, vurgu, uyarı kutusu ve dahası."],
                       "Nasıl kullanılır", bicim_demo, genis=True, toplam=9.0)),
        ("yapilacaklar", kart("onay", "yesil", "Yapılacaklar", ["Bütün işlerin Ana Sayfa'da tek listede."],
                              "Nasıl kullanılır", gorev, kayma=0.2)),
        ("gorseller", kart("gorsel", "mavi", "Görseller", ["Sürükle bırak, görsel sayfada görünsün."],
                           "Nasıl kullanılır", gorseller, kayma=0.45)),
        ("agac", kart("agac", "kum", "Sayfa ağacı", ["Alt sayfalar ekle, sürükleyerek düzenle."],
                      "Nasıl kullanılır", agac, kayma=0.7)),
        ("dosyalar", kart("klasor", "kirmizi", "Notlar senin", ["Bilgisayarında sıradan dosyalar olarak durur."],
                          "Nerede saklanır", dosyalar, kayma=0.95)),
        ("fazlasi", kart("arti", "murekkep", "Daha fazlası", ["Her gün işine yarayan küçük özellikler."],
                         "Hepsini gör", fazla_demo, genis=True, toplam=8.5)),
    ]


# ───────────────────────────── Kurulum ─────────────────────────────

T_ZEMIN = "#2a251f"
T_UST = "#36302a"
T_METIN = "#ece4cf"
T_SOLUK = "#a89a80"
T_ISTEM = "#d9a95b"
T_BASARI = "#a9c48a"

KURULUM = [
    # (tür, metin, önce bekleme sn) — çıktılar betiklerin gerçekte yazdırdığı metinler
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
    gen, satir_yuk, ust, sol = 1000, 27, 82, 34
    yuk = ust + len(KURULUM) * satir_yuk + 28
    harf, hiz, istem = 9.6, 0.045, "$ "
    zamanlar, t = [], 0.0
    for tur, metin, bekle in KURULUM:
        t += bekle
        sure = len(metin) * hiz if tur == "komut" else 0.0
        zamanlar.append((t, sure))
        t += sure
    s = Sahne(t + 3.5)
    govde = [f'<rect width="{gen}" height="{yuk}" rx="14" fill="{T_ZEMIN}"/>',
             f'<path d="M0 14a14 14 0 0 1 14-14h{gen - 28}a14 14 0 0 1 14 14v26H0z" fill="{T_UST}"/>',
             "".join(f'<circle cx="{24 + k * 20}" cy="20" r="6" fill="{r}"/>' for k, r in enumerate(["#e0645a", "#e3b341", "#5fb05a"])),
             yazi("Terminal — NotDefteri", gen / 2, 25, 13, T_SOLUK, text_anchor="middle", font_weight="500")]
    for i, ((tur, metin, _), (bas, sure)) in enumerate(zip(KURULUM, zamanlar)):
        y = ust + i * satir_yuk
        renk = {"komut": T_METIN, "cikti": T_METIN, "basari": T_BASARI, "soluk": T_SOLUK}[tur]
        cikis = s.toplam - 0.6
        # Satır anında belirir (terminaldeki gibi); sonda hepsi söner. Kayma yok, azaltmaya gerek yok.
        s.kareler(f"s{i}", [(0, {"opacity": 0}), (bas, {"opacity": 0}), (bas + 0.001, {"opacity": 1}),
                            (cikis, {"opacity": 1}), (cikis + 0.4, {"opacity": 0}), (s.toplam, {"opacity": 0})],
                  egri="linear", azalt=False)
        if tur == "komut":
            x0, n = sol + len(istem) * harf, len(metin)
            # Örtü + imleç harf harf sağa kayar: metin yazılıyormuş gibi açılır. Hareket azaltılsa da
            # yazma sürer; içerik yer değiştirmiyor, yalnızca beliriyor.
            s.css.append(f"@keyframes o{i} {{ 0% {{ transform: translateX(0); }} "
                         f"{s.yuzde(bas)} {{ transform: translateX(0); animation-timing-function: steps({n}, end); }} "
                         f"{s.yuzde(bas + sure)} {{ transform: translateX({n * harf:.1f}px); }} "
                         f"100% {{ transform: translateX({n * harf:.1f}px); }} }}\n.o{i} {{ animation: o{i} {s.toplam}s infinite; }}")
            sonraki = zamanlar[i + 1][0] if i + 1 < len(zamanlar) else s.toplam
            s.kareler(f"i{i}", [(0, {"opacity": 0}), (bas, {"opacity": 0}), (bas + 0.001, {"opacity": 1}),
                                (sonraki, {"opacity": 1}), (sonraki + 0.001, {"opacity": 0}), (s.toplam, {"opacity": 0})],
                      egri="linear", azalt=False)
            govde.append(
                f'<g class="s{i}">' + yazi(istem, sol, y, 16, T_ISTEM, MONO)
                + yazi(escape(metin), x0, y, 16, renk, MONO, textLength=f"{n * harf:.1f}", lengthAdjust="spacingAndGlyphs")
                + f'<g class="o{i}" transform="translate({n * harf:.1f} 0)"><rect x="{x0}" y="{y - 17}" width="{n * harf + 4:.1f}" '
                  f'height="23" fill="{T_ZEMIN}"/><rect class="i{i} gecici" x="{x0}" y="{y - 15}" width="9" height="19" fill="{T_METIN}"/></g></g>')
        else:
            govde.append(f'<g class="s{i}">' + yazi(escape(metin), sol, y, 16, renk, MONO, textLength=f"{len(metin) * harf:.1f}",
                                                    lengthAdjust="spacingAndGlyphs") + "</g>")
    return s.svg(gen, yuk, "Kurulum: depoyu indir, kısayolu kur, not yazınca uygulama açılır", "".join(govde))


if __name__ == "__main__":
    ciktilar = [("baslik.svg", baslik_svg()), ("kurulum.svg", kurulum_svg())]
    ciktilar += [(f"kart-{ad}.svg", icerik) for ad, icerik in kartlar()]
    for ad, icerik in ciktilar:
        yol = DOCS / ad
        yol.write_text(icerik, encoding="utf-8")
        print(f"{yol.relative_to(DOCS.parent)} — {yol.stat().st_size / 1024:.1f} KB")
