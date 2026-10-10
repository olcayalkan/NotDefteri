#!/usr/bin/env python3
"""README animasyonlarını üretir: docs/baslik.svg, docs/tanitim.svg, docs/kart-*.svg, docs/kurulum.svg.

Hepsi aynı mantığı izler: Markdown kaynağı yazılır, uygulamadaki gibi biçimlenmiş hâline
dönüşür. SVG içindeki CSS animasyonu GitHub'da <img> ile kendiliğinden oynar; GIF'leri ise
GitHub "hareketi azalt" kullanıcılarında durduruyor.

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
    "ev": '<path d="M4 11l8-7 8 7v9h-5v-6h-6v6H4z"/>',
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


# README vitrini her izleyicide tam hareketle oynasın diye hareket-azaltılmış sürüm kapalı.
# GitHub GIF'leri "hareketi azalt" kullanıcılarında durduruyordu; solma sürümü de durağan sanıldı.
# Yeniden açmak için True yap: azaltılmış sürüm transform'suz, aynı zamanlamayla solar.
HAREKETI_AZALT = False


class Sahne:
    """Bir SVG'nin zaman çizelgesi. HAREKETI_AZALT açıkken her hareket iki sürümle yazılır:
    tam ve hareket-azaltılmış (transform'suz, yalnızca opacity)."""

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
        if azalt and HAREKETI_AZALT:
            self.css.append(yaz(f"{ad}-a", False))
            self.azaltilacak.append(ad)

    def gir_cik(self, ad, gir, cik, kayma="translateY(8px)", cikis_kayma=None, sure=0.45):
        """`gir`de kayarak belirir, `cik`ta söner; çıkış girişin tersinden (animate skill'i)."""
        cikis_kayma = cikis_kayma or kayma
        adimlar = [(0, {"opacity": 0, "transform": kayma}),
                   (gir, {"opacity": 0, "transform": kayma}),
                   (gir + sure, {"opacity": 1, "transform": "translate(0, 0)"})]
        # Çıkışı süre dışında olan öğe sonuna dek durur; yoksa %100'de üst üste binen kareler
        # öğeyi bütün döngü boyunca yavaşça söndürüyordu.
        if cik + 0.3 < self.toplam:
            adimlar += [(cik, {"opacity": 1, "transform": "translate(0, 0)"}),
                        (cik + 0.3, {"opacity": 0, "transform": cikis_kayma}),
                        (self.toplam, {"opacity": 0, "transform": cikis_kayma})]
        else:
            adimlar.append((self.toplam, {"opacity": 1, "transform": "translate(0, 0)"}))
        self.kareler(ad, adimlar)

    def svg(self, gen, yuk, baslik, icerik):
        azalt = " ".join(f".{ad} {{ animation-name: {ad}-a; }}" for ad in self.azaltilacak)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{gen}" height="{yuk}" viewBox="0 0 {gen} {yuk}" '
                f'role="img" aria-label="{escape(baslik)}"><title>{escape(baslik)}</title>\n<style>\n'
                # Animasyonsuz görüntüleyicide geçici öğeler (kaynak, ipucu, imleç) görünmez; son hâl kalır.
                ".gecici { opacity: 0; }\n"
                + "\n".join(self.css)
                + (f"\n@media (prefers-reduced-motion: reduce) {{ {azalt} }}" if HAREKETI_AZALT else "")
                + f"\n</style>\n{icerik}\n</svg>\n")


# ───────────────────────────── Başlık ─────────────────────────────

SLOGAN = "Notların, yapılacakların ve fikirlerin için sade bir defter."
ETIKETLER = [("kalem", "sari", "Yazarken biçimlenir"), ("onay", "yesil", "Yapılacaklar"),
             ("gorsel", "mavi", "Görseller"), ("agac", "kum", "Sayfa ağacı"), ("klasor", "kirmizi", "Kendi dosyaların")]


def baslik_svg():
    """Ortalı başlık: ad, slogan ve etiketler sayfanın ortasında; defter çizgisi yok (bir şey anlatmıyordu)."""
    gen, yuk = 1000, 300
    orta = gen / 2
    s = Sahne(9.5)
    harf = 32.4                       # 54 px tek aralıklı; textLength ile sabitlenir
    x0 = orta - 12 * harf / 2         # "# NotDefteri" ortalı yazılır
    yazim_bas, yazim_son = 0.6, 0.6 + 12 * 0.09
    s.css.append(f"@keyframes ortu {{ 0% {{ transform: translateX(0); }} "
                 f"{s.yuzde(yazim_bas)} {{ transform: translateX(0); animation-timing-function: steps(12, end); }} "
                 f"{s.yuzde(yazim_son)} {{ transform: translateX({12 * harf}px); }} 100% {{ transform: translateX({12 * harf}px); }} }}"
                 f"\n.ortu {{ animation: ortu {s.toplam}s infinite; }}")   # yazma azaltılmaz: içerik yer değiştirmiyor
    s.kareler("ortu-gizle", [(0, {"opacity": 1}), (yazim_son + 0.3, {"opacity": 1}), (yazim_son + 0.301, {"opacity": 0}),
                             (s.toplam, {"opacity": 0})], egri="linear", azalt=False)
    s.kareler("isaret", [(0, {"opacity": 1}), (2.0, {"opacity": 1}), (2.25, {"opacity": 0}), (s.toplam, {"opacity": 0})])
    # "# " silinince kalan 10 harf yine ortalı olsun diye metin bir harf sola kayar.
    s.kareler("mono", [(0, {"opacity": 1, "transform": "translateX(0)"}), (2.1, {"opacity": 1, "transform": "translateX(0)"}),
                       (2.55, {"opacity": 1, "transform": f"translateX({-harf}px)"}),
                       (2.7, {"opacity": 0, "transform": f"translateX({-harf}px)"}),
                       (s.toplam, {"opacity": 0, "transform": f"translateX({-harf}px)"})], egri=EASE_IN_OUT)
    s.gir_cik("baslik", 2.55, 8.6, kayma="translateY(4px)", sure=0.35)
    s.gir_cik("slogan", 3.0, 8.65)
    s.gir_cik("ust", 0.2, 8.7, kayma="translateY(-4px)")
    govde = [
        f'<rect width="{gen}" height="{yuk}" rx="18" fill="{SEPYA}"/>',
        yazi("MACOS · LINUX", orta, 50, 12, SOLUK, MONO, text_anchor="middle", letter_spacing="1.5", **{"class": "ust"}),
        yazi("#", x0, 134, 54, ISARET, MONO, textLength=harf, lengthAdjust="spacingAndGlyphs", **{"class": "isaret gecici"}),
        yazi("NotDefteri", x0 + 2 * harf, 134, 54, MUREKKEP, MONO, textLength=10 * harf, lengthAdjust="spacingAndGlyphs",
             **{"class": "mono gecici"}),
        # Örtü animasyonsuz görüntüleyicide yazının sağında durur ve yazma bitince gizlenir.
        f'<g class="ortu-gizle gecici"><g class="ortu" transform="translate({12 * harf} 0)">'
        f'<rect x="{x0}" y="80" width="{12 * harf + 8}" height="68" fill="{SEPYA}"/>'
        f'<rect class="imlec" x="{x0 + 2}" y="86" width="5" height="58" fill="{MUREKKEP}"/></g></g>',
        doku(gen, yuk, 18),           # örtünün üstünde: yazma sırasında örtü dokusuz bir yama gibi görünmesin
        yazi("NotDefteri", orta, 138, 84, MUREKKEP, SERIF, text_anchor="middle", font_weight="bold", letter_spacing="-2.5",
             **{"class": "baslik"}),
        yazi(escape(SLOGAN), orta, 188, 24, SOLUK, SANS, text_anchor="middle", **{"class": "slogan"}),
    ]
    # Sistem sans 15 px'te harf başına ~7.4 px: 13 sol + 18 simge + 8 boşluk + yazı + 15 sağ.
    enler = [len(etiket) * 7.4 + 54 for _, _, etiket in ETIKETLER]
    x = orta - (sum(enler) + 10 * (len(enler) - 1)) / 2
    assert x > 24, f"etiketler sığmıyor: {x}"
    for i, ((ad, ton, etiket), en) in enumerate(zip(ETIKETLER, enler)):
        s.gir_cik(f"e{i}", 3.35 + i * 0.08, 8.7 + i * 0.03)
        zemin, renk = PASTEL[ton]
        govde.append(f'<g class="e{i}"><rect x="{x:.0f}" y="222" width="{en:.0f}" height="38" rx="9" fill="{zemin}"/>'
                     + simge(ad, x + 13, 232, 18, renk)
                     + yazi(escape(etiket), f"{x + 39 + (en - 54) / 2:.0f}", 246.5, 15, MUREKKEP, text_anchor="middle",
                            font_weight="500") + "</g>")
        x += en + 10
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


# ───────────────────────────── Tanıtım ─────────────────────────────
# brag-output/work/sahne.html'deki 20,5 sn'lik tanıtımın vektör karşılığı (aynı sahneler,
# aynı zamanlama). GIF'i GitHub "hareketi azalt" kullanıcılarında durduruyor; SVG kendiliğinden
# oynar ve birkaç MB yerine birkaç on KB tutar. Ses yalnızca docs/tanitim.mp4'te.

def tanitim_svg():
    G, Y = 1920, 1080
    s = Sahne(20.5)
    T = s.toplam
    PANEL, BASLIK_CUBUGU, SECIM = "#ccc4b0", "#c7bda6", "#b8ae98"
    pay = 1.1                          # sans yazı genişliği tarayıcı fontuna göre değişir; örtü cömert

    def goster(ad, bas, bit):
        """Anında belirip kaybolan öğe (imleç, kısayolla değişen satır)."""
        s.kareler(ad, [(0, {"opacity": 0}), (bas, {"opacity": 0}), (bas + 0.001, {"opacity": 1}),
                       (bit, {"opacity": 1}), (bit + 0.001, {"opacity": 0}), (T, {"opacity": 0})], egri="linear", azalt=False)

    def sahne(ad, gir, cik):
        s.kareler(ad, [(0, {"opacity": 0}), (gir, {"opacity": 0}), (gir + 0.45, {"opacity": 1}),
                       (cik, {"opacity": 1}), (cik + 0.4, {"opacity": 0}), (T, {"opacity": 0})])

    def yazma(ad, x, y_ust, yuk, bas, n, hiz, genislik, zemin, imlec_bit, imlec_yuk, imlec_en=4, cizgiler=False):
        """Örtü + imleç adım adım sağa kayar: metin harf harf yazılıyormuş gibi açılır."""
        bitis = bas + n * hiz
        s.css.append(f"@keyframes {ad} {{ 0% {{ transform: translateX(0); }} "
                     f"{s.yuzde(bas)} {{ transform: translateX(0); animation-timing-function: steps({n}, end); }} "
                     f"{s.yuzde(bitis)} {{ transform: translateX({genislik:.1f}px); }} 100% {{ transform: translateX({genislik:.1f}px); }} }}"
                     f"\n.{ad} {{ animation: {ad} {T}s infinite; }}")
        goster(f"{ad}-i", min(bas, imlec_bit) - 0.25 if bas - 0.25 > 0 else 0, imlec_bit)
        orta = y_ust + (yuk - imlec_yuk) / 2
        # Defter sayfasında örtü altındaki çizgileri de taşır: yatay çizgi yatay kayınca fark edilmez.
        cizgi = "".join(f'<line x1="{x}" y1="{c}" x2="{x + genislik + 12:.1f}" y2="{c}" stroke="#a0947a" stroke-opacity="0.28"/>'
                        for c in range(64, Y, 64) if y_ust <= c <= y_ust + yuk) if cizgiler else ""
        return (f'<g class="{ad}" transform="translate({genislik:.1f} 0)"><rect x="{x}" y="{y_ust}" width="{genislik + 12:.1f}" '
                f'height="{yuk}" fill="{zemin}"/>{cizgi}<rect class="{ad}-i gecici" x="{x}" y="{orta}" width="{imlec_en}" '
                f'height="{imlec_yuk}" fill="{MUREKKEP}"/></g>')

    govde = [f'<rect width="{G}" height="{Y}" fill="{SEPYA}"/>',
             "".join(f'<line x1="0" y1="{y}" x2="{G}" y2="{y}" stroke="#a0947a" stroke-opacity="0.28"/>' for y in range(64, Y, 64)),
             f'<line x1="140.5" y1="0" x2="140.5" y2="{Y}" stroke="{KENAR}" stroke-width="3" stroke-opacity="0.75"/>',
             '<defs><filter id="golge" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="28" '
             'stdDeviation="30" flood-color="#46321a" flood-opacity="0.35"/></filter>'
             '<clipPath id="pencere-kirp"><rect x="210" y="96" width="1500" height="820" rx="16"/></clipPath>'
             '<clipPath id="dosya-kirp"><rect x="410" y="250" width="1100" height="362" rx="16"/></clipPath></defs>']

    # 1 · Kanca: "## Bugün" yazılır, "## " kaybolur, başlık olur.
    sahne("s1", 0, 3.0)
    harf = 72                                      # 120 px tek aralıklı
    s.kareler("k-mono", [(0, {"opacity": 1, "transform": "translateX(0)"}), (1.55, {"opacity": 1, "transform": "translateX(0)"}),
                         (1.75, {"opacity": 0, "transform": "translateX(-27px)"}), (T, {"opacity": 0, "transform": "translateX(-60px)"})],
              egri=EASE_IN_OUT, azalt=False)
    goster("k-ortu-g", 0, 1.5)
    s.gir_cik("k-baslik", 1.7, 99, kayma="translateY(10px)", sure=0.45)
    govde.append(
        '<g class="s1">'
        f'<g class="k-mono">{yazi("##", 220, 520, 120, ISARET, MONO, textLength=2 * harf, lengthAdjust="spacingAndGlyphs")}'
        f'{yazi("Bugün", 220 + 3 * harf, 520, 120, MUREKKEP, MONO, textLength=5 * harf, lengthAdjust="spacingAndGlyphs")}</g>'
        f'<g class="k-ortu-g">{yazma("k-ortu", 220, 420, 130, 0.35, 8, 0.11, 8 * harf, SEPYA, 1.5, 128, 8, cizgiler=True)}</g>'
        + yazi("Bugün", 214, 532, 168, MUREKKEP, SERIF, font_weight="bold", letter_spacing="-5", **{"class": "k-baslik"}) + "</g>")

    # 2 · Açılış
    sahne("s2", 3.4, 6.0)
    s.gir_cik("a-ad", 3.45, 99, kayma="translateY(24px)")
    s.gir_cik("a-slogan", 3.7, 99, kayma="translateY(16px)")
    govde.append('<g class="s2">'
                 + yazi("NotDefteri", 214, 480, 176, MUREKKEP, SERIF, font_weight="bold", letter_spacing="-5", **{"class": "a-ad"})
                 + yazi(escape(SLOGAN), 220, 610, 46, SOLUK, **{"class": "a-slogan"}) + "</g>")

    # 3–4 · Uygulama penceresi
    sahne("s3", 6.4, 14.3)
    s.kareler("pencere", [(0, {"transform": "translateY(30px) scale(0.97)"}), (6.4, {"transform": "translateY(30px) scale(0.97)"}),
                          (6.95, {"transform": "translateY(0) scale(1)"}), (14.25, {"transform": "translateY(0) scale(1)"}),
                          (14.7, {"transform": "translateY(0) scale(0.96)"}), (T, {"transform": "translateY(0) scale(0.96)"})],
              azalt=False)
    s.css.append(".pencere { transform-box: fill-box; transform-origin: center; }")
    satirlar = [("ev", "Ana Sayfa", 0, "", False), (None, "Sayfalar", 0, "", False), ("klasor", "Proje", 0, "▾", False),
                (None, "Toplantı notları", 1, "", True), (None, "Proje Planı", 1, "", False), (None, "Bütçe", 1, "", False),
                ("klasor", "Günlük", 0, "▸", False), ("sayfa", "Okuma listesi", 0, "", False)]
    panel = [f'<rect x="210" y="148" width="330" height="768" fill="{PANEL}"/>',
             f'<rect x="226" y="170" width="298" height="42" rx="9" fill="{MUREKKEP}" fill-opacity="0.07"/>',
             yazi("Ara…", 242, 198, 18, SOLUK)]
    y = 234
    for sim, ad, alt, ok, secili in satirlar:
        if ad == "Sayfalar":
            panel.append(yazi("Sayfalar", 240, y + 30, 14, SOLUK, letter_spacing="0.6"))
            y += 40
            continue
        if secili:
            panel.append(f'<rect x="226" y="{y}" width="298" height="48" rx="8" fill="{SECIM}"/>')
        if ok:
            panel.append(yazi(ok, 240, y + 30, 13, SOLUK))
        if sim:
            panel.append(simge(sim, 258, y + 14, 20, MUREKKEP))
        panel.append(yazi(escape(ad), 270 if alt else 288, y + 31, 22, MUREKKEP, font_weight="600" if secili else "400"))
        y += 48
    pencere = [f'<rect x="210" y="96" width="1500" height="820" rx="16" fill="{SEPYA}" filter="url(#golge)"/>',
               '<g clip-path="url(#pencere-kirp)">',
               f'<rect x="210" y="96" width="1500" height="52" fill="{BASLIK_CUBUGU}"/>',
               "".join(f'<circle cx="{239 + i * 24}" cy="122" r="7" fill="{r}"/>' for i, r in enumerate(["#e0645a", "#e3b341", "#5fb05a"])),
               yazi(f'Proje  ›  <tspan fill="{MUREKKEP}" font-weight="600">Toplantı notları</tspan>', 960, 128, 19, SOLUK,
                    text_anchor="middle"),
               *panel,
               yazi("Toplantı notları", 636, 272, 66, MUREKKEP, font_weight="700", letter_spacing="-1"),
               f'<rect x="210.5" y="96.5" width="1499" height="819" rx="16" fill="none" stroke="{MUREKKEP}" stroke-opacity="0.12"/>']

    # Görev 1: "[] " kısayolu onay kutusuna dönüşür, "Raporu gönder" yazılır.
    goster("g1-kaynak", 6.75, 7.11)
    s.kareler("g1-kutu", [(0, {"opacity": 0}), (7.11, {"opacity": 0}), (7.3, {"opacity": 1}), (T, {"opacity": 1})], azalt=False)
    pencere += [
        f'<g class="g1-kaynak gecici">{yazi("[] ", 636, 354, 36, ISARET, MONO)}'
        + yazma("g1-k-ortu", 636, 318, 50, 6.75, 3, 0.12, 3 * 21.6, SEPYA, 7.11, 40) + "</g>",
        f'<rect class="g1-kutu" x="636" y="323" width="38" height="38" rx="9" fill="none" stroke="{MUREKKEP}" stroke-width="3"/>',
        yazi("Raporu gönder", 692, 355, 38, MUREKKEP),
        yazma("g1-ortu", 692, 318, 50, 7.25, 13, 0.065, 253 * pay, SEPYA, 8.245, 40)]
    # Görev 2: Enter ile liste sürer.
    goster("g2", 8.345, 99)
    pencere += [f'<g class="g2"><rect x="636" y="403" width="38" height="38" rx="9" fill="none" stroke="{MUREKKEP}" stroke-width="3"/>'
                + yazi("Sunumu hazırla", 692, 435, 38, MUREKKEP)
                + yazma("g2-ortu", 692, 398, 50, 8.445, 14, 0.065, 266 * pay, SEPYA, 9.655, 40) + "</g>"]
    # İşaretçi ilk kutuya gidip tıklar: kutu dolar, üstü çizilir.
    tik = 10.0
    s.kareler("g1-dolu", [(0, {"opacity": 0}), (tik, {"opacity": 0}), (tik + 0.18, {"opacity": 1}), (T, {"opacity": 1})], azalt=False)
    s.kareler("g1-cizik", [(0, {"transform": "scaleX(0)"}), (tik + 0.1, {"transform": "scaleX(0)"}),
                           (tik + 0.45, {"transform": "scaleX(1)"}), (T, {"transform": "scaleX(1)"})], azalt=False)
    s.css.append(".g1-cizik { transform-box: fill-box; transform-origin: left center; }")
    pencere += [f'<g class="g1-dolu"><rect x="634.5" y="321.5" width="41" height="41" rx="10" fill="{PASTEL["yesil"][1]}"/>'
                f'<path d="M644 343l7 7 14-15" stroke="{YUZEY}" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/></g>',
                f'<rect class="g1-cizik" x="692" y="340" width="{253 * 1.04:.0f}" height="3" fill="{MUREKKEP}"/>']

    # 4 · "[[Pro" yazılır, öneri açılır, seçilen sayfa bağa dönüşür.
    secim = 12.75
    goster("g3", 11.0, 99)
    goster("g3-kaynak", 11.0, secim)
    s.kareler("g3-bag", [(0, {"opacity": 0}), (secim, {"opacity": 0}), (secim + 0.25, {"opacity": 1}), (T, {"opacity": 1})], azalt=False)
    goster("g3-imlec", secim, 14.0)
    s.kareler("oneri", [(0, {"opacity": 0, "transform": "translateY(8px) scale(0.97)"}),
                        (11.85, {"opacity": 0, "transform": "translateY(8px) scale(0.97)"}),
                        (12.1, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
                        (secim - 0.05, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
                        (secim + 0.12, {"opacity": 0, "transform": "translateY(0) scale(1)"}),
                        (T, {"opacity": 0, "transform": "translateY(0) scale(1)"})], azalt=False)
    s.css.append(".oneri { transform-box: fill-box; transform-origin: 20px 0; }")
    bx = 636 + 182                                 # "Ayrıntılar: " genişliği (Helvetica ölçüsü + pay)
    pencere += [f'<g class="g3">' + yazi("Ayrıntılar:", 636, 529, 38, MUREKKEP)
                + f'<g class="g3-kaynak gecici">{yazi("[[Pro", bx, 528, 36, MUREKKEP, MONO)}'
                + yazma("g3-ortu", bx, 492, 50, 11.3, 5, 0.12, 5 * 21.6, SEPYA, secim, 40) + "</g>"
                + f'<g class="g3-bag">{yazi("Proje Planı", bx, 529, 38, VURGU)}'
                f'<rect x="{bx}" y="536" width="{185 * 1.04:.0f}" height="2.5" fill="{VURGU}"/></g>'
                + f'<rect class="g3-imlec gecici" x="{bx + 185 * 1.06 + 8:.0f}" y="501" width="4" height="40" fill="{MUREKKEP}"/>'
                + "</g>",
                f'<g class="oneri"><rect x="841" y="552" width="470" height="190" rx="12" fill="{KAGIT}" stroke="{MUREKKEP}" '
                f'stroke-opacity="0.12"/><rect x="849" y="560" width="454" height="84" rx="8" fill="{SECIM}"/>'
                + yazi("Proje Planı", 867, 597, 28, MUREKKEP) + yazi("Proje", 867, 625, 19, SOLUK)
                + yazi("Proje bütçesi", 867, 689, 28, MUREKKEP) + yazi("Proje › Bütçe", 867, 717, 19, SOLUK) + "</g>"]
    pencere.append("</g>")
    s.kareler("isaretci", [(0, {"opacity": 0, "transform": "translate(1250px, 880px) scale(1)"}),
                           (9.2, {"opacity": 0, "transform": "translate(1250px, 880px) scale(1)"}),
                           (9.3, {"opacity": 1, "transform": "translate(1250px, 880px) scale(1)"}),
                           (9.95, {"opacity": 1, "transform": "translate(650px, 336px) scale(1)"}),
                           (tik, {"opacity": 1, "transform": "translate(650px, 336px) scale(0.86)"}),
                           (tik + 0.14, {"opacity": 1, "transform": "translate(650px, 336px) scale(1)"}),
                           (10.6, {"opacity": 1, "transform": "translate(650px, 336px) scale(1)"}),
                           (10.9, {"opacity": 0, "transform": "translate(650px, 336px) scale(1)"}),
                           (T, {"opacity": 0, "transform": "translate(650px, 336px) scale(1)"})], egri=EASE_IN_OUT, azalt=False)
    s.gir_cik("yazi3", 7.0, 10.75, kayma="translateY(18px)")
    s.gir_cik("yazi4", 11.1, 14.1, kayma="translateY(18px)")
    govde.append('<g class="s3"><g class="pencere">' + "".join(pencere) + "</g>"
                 '<g class="isaretci"><path d="M7 4.5l20 11.4-8.8 2.3L14.2 27z" fill="#2f2a24" stroke="#f6f2e7" stroke-width="2" '
                 'stroke-linejoin="round"/></g>'
                 + yazi("Yazarken biçimlenir, yapılacaklar tek tıkla.", 960, 1002, 40, MUREKKEP, text_anchor="middle", **{"class": "yazi3"})
                 + yazi(f'Sayfaları <tspan font-family="{MONO}">[[</tspan> ile birbirine bağla.', 960, 1002, 40, MUREKKEP,
                        text_anchor="middle", **{"class": "yazi4"}) + "</g>")

    # 5 · Dosyalar
    sahne("s5", 14.7, 17.3)
    s.gir_cik("dosyalar", 14.75, 99, kayma="translateY(30px) scale(0.97)")
    s.css.append(".dosyalar { transform-box: fill-box; transform-origin: center; }")
    dosya = [f'<rect x="410" y="250" width="1100" height="362" rx="16" fill="{KAGIT}" filter="url(#golge)"/>',
             '<g clip-path="url(#dosya-kirp)">', f'<rect x="410" y="250" width="1100" height="84" fill="{YUZEY}"/>',
             simge("klasor", 440, 278, 28, SOLUK),
             yazi(f'Belgeler  ›  NotDefteri  ›  <tspan fill="{MUREKKEP}" font-weight="700">Proje</tspan>', 482, 302, 27, SOLUK),
             f'<rect x="410" y="333" width="1100" height="1" fill="{MUREKKEP}" fill-opacity="0.1"/>']
    for i, (sim, ad, aciklama) in enumerate([("sayfa", "index.md", "Sayfanın metni"), ("gorsel", "Görseller", "Eklediğin görseller"),
                                             ("klasor", "Toplantı notları", "Alt sayfa")]):
        y0 = 334 + i * 92
        s.gir_cik(f"d{i}", 15.05 + i * 0.12, 99, kayma="translateY(12px)")
        dosya.append(f'<g class="d{i}">' + simge(sim, 446, y0 + 29, 34, MUREKKEP) + yazi(escape(ad), 500, y0 + 57, 32, MUREKKEP)
                     + yazi(escape(aciklama), 1474, y0 + 56, 23, SOLUK, text_anchor="end")
                     + f'<rect x="410" y="{y0 + 91}" width="1100" height="1" fill="{MUREKKEP}" fill-opacity="0.07"/></g>')
    dosya += ["</g>", f'<rect x="410.5" y="250.5" width="1099" height="361" rx="16" fill="none" stroke="{MUREKKEP}" stroke-opacity="0.12"/>']
    s.gir_cik("yazi5", 15.0, 99, kayma="translateY(18px)")
    govde.append('<g class="s5"><g class="dosyalar">' + "".join(dosya) + "</g>"
                 + yazi("Notların bilgisayarında sıradan dosyalar olarak kalır.", 960, 1002, 40, MUREKKEP, text_anchor="middle",
                        **{"class": "yazi5"}) + "</g>")

    # 6 · Kapanış; döngü başa dönmeden önce sayfaya söner.
    sahne("s6", 17.7, T - 0.45)
    s.gir_cik("son-ad", 17.75, 99, kayma="translateY(24px)")
    s.gir_cik("son-slogan", 17.95, 99, kayma="translateY(16px)")
    s.gir_cik("son-meta", 18.15, 99, kayma="translateY(10px)")
    govde.append('<g class="s6">'
                 + yazi("NotDefteri", 960, 490, 176, MUREKKEP, SERIF, text_anchor="middle", font_weight="bold", letter_spacing="-5",
                        **{"class": "son-ad"})
                 + yazi(escape(SLOGAN), 960, 606, 46, SOLUK, text_anchor="middle", **{"class": "son-slogan"})
                 + yazi("MACOS · LINUX  —  GITHUB.COM/OLCAYALKAN/NOTDEFTERI", 960, 706, 26, SOLUK, MONO, text_anchor="middle",
                        letter_spacing="3", **{"class": "son-meta"}) + "</g>")
    return s.svg(G, Y, "NotDefteri tanıtımı: yazdığın anda biçimlenen sade bir defter; yapılacaklar, sayfa bağları ve "
                       "bilgisayarında sıradan dosyalar olarak duran notlar.", "".join(govde))


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
    ciktilar = [("baslik.svg", baslik_svg()), ("kurulum.svg", kurulum_svg()), ("tanitim.svg", tanitim_svg())]
    ciktilar += [(f"kart-{ad}.svg", icerik) for ad, icerik in kartlar()]
    for ad, icerik in ciktilar:
        yol = DOCS / ad
        yol.write_text(icerik, encoding="utf-8")
        print(f"{yol.relative_to(DOCS.parent)} — {yol.stat().st_size / 1024:.1f} KB")
