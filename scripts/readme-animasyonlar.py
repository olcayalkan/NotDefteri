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

SLOGAN = "A simple notebook for your notes, to-dos and ideas."
ETIKETLER = [("kalem", "sari", "Formats as you type"), ("onay", "yesil", "To-dos"),
             ("gorsel", "mavi", "Images"), ("agac", "kum", "Page tree"), ("klasor", "kirmizi", "Your own files")]


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
    return s.svg(gen, yuk, "NotDefteri — " + SLOGAN + " For macOS and Linux.", "".join(govde))


# ───────────────────────────── Özellik kartları ─────────────────────────────

def demo_satiri(metin_svg, x, y):
    return f'<g transform="translate({x} {y})">{metin_svg}</g>'


def kart(simge_ad, ton, baslik, aciklama, baglanti_yazi, demo, genis=False, toplam=8.0, kayma=0.0, fare=None, sayfa=None):
    """Kart: simgeyle aynı satırda serif başlık, sans açıklama, demo sayfası, altta hizalı bağlantı.
    demo: [(svg, giriş, çıkış ya da None, yön)]; çıkışı olanlar geçicidir (kaynak, ipucu).
    fare: (başlangıç x, y, hedef x, y, tık anı) — işaretçi gelip hedefe tıklar.
    sayfa: KART_SAYFASI anahtarı; verilmezse kart türüne göre "genis" ya da "dar".
    Demo koordinatları KART_SAYFASI kutusuna göre verilir (bkz. kartlar())."""
    gen, yuk = KART_BOYU["genis" if genis else "dar"]
    s = Sahne(toplam)
    x0, karo_y, karo = (36, 32, 40) if genis else (28, 28, 40)
    # Başlık simgenin dikey ortasına oturur (serif 27–30 px'te taban, ortanın ~9–10 px altında).
    baslik_y = karo_y + karo / 2 + (10 if genis else 9)
    bag_y = yuk - (30 if genis else 26)
    if genis:
        # Açıklama başlık satırı ile alttaki bağlantı arasında dikey ortalı; üstte havada kalmasın.
        orta = (karo_y + karo + bag_y - 15) / 2
        aciklama_y = orta - (len(aciklama) - 1) * 12 + 6
    else:
        aciklama_y = karo_y + karo + 24
    govde = [f'<rect x="1" y="1" width="{gen - 2}" height="{yuk - 2}" rx="16" fill="{KAGIT}" stroke="{MUREKKEP}" '
             f'stroke-opacity="0.13" stroke-width="1.5"/>', doku(gen, yuk, 16),
             f'<g class="karo">{simge_karosu(simge_ad, x0, karo_y, ton, karo)}</g>',
             yazi(escape(baslik), x0 + karo + 12, baslik_y, 30 if genis else 27, MUREKKEP, SERIF, font_weight="bold",
                  letter_spacing="-0.6")]
    for i, satir in enumerate(aciklama):
        govde.append(yazi(escape(satir), x0, aciklama_y + i * 24, 17, SOLUK))
    # Bağlantılar her kartta aynı yükseklikte: yan yana kartlarda tek çizgi oluşturur.
    govde.append(yazi(f"{escape(baglanti_yazi)} →", x0, bag_y, 15, VURGU, font_weight="600"))
    sx, sy, sen, sboy = KART_SAYFASI[sayfa or ("genis" if genis else "dar")]
    govde.append(f'<rect x="{sx}" y="{sy}" width="{sen}" height="{sboy}" rx="11" fill="{YUZEY}" stroke="{MUREKKEP}" '
                 f'stroke-opacity="0.08"/>')
    if simge_ad == "arti":
        # "+" karosu çeyrek tur dönerek belirir: kart "daha fazlası"nı açıyormuş gibi.
        s.gir_cik("karo", 0.2 + kayma, toplam - 0.8, "rotate(-90deg) scale(0.9)", "scale(0.9)", sure=0.55)
        s.css.append(".karo { transform-box: fill-box; transform-origin: center; }")
    kaymalar = {"x": ("translateX(10px)", "translateX(-10px)"), "y": ("translateY(8px)", "translateY(8px)"),
                "o": ("translate(0, 0)", "translate(0, 0)"), "d": ("translateY(-16px) scale(0.96)", "translateY(8px)")}
    for i, (svg, gir, cik, yon) in enumerate(demo):
        giris, cikis = kaymalar[yon]
        s.gir_cik(f"d{i}", gir + kayma, (cik + kayma) if cik else toplam - 0.9 + i * 0.03, giris, cikis)
        govde.append(f'<g class="d{i}{" gecici" if cik else ""}">{svg}</g>')
    # Yapılacak işaretlenince üstü soldan sağa çizilir.
    s.kareler("cizik", [(0, {"opacity": 0, "transform": "scaleX(0)"}), (3.6 + kayma, {"opacity": 0, "transform": "scaleX(0)"}),
                        (3.61 + kayma, {"opacity": 1, "transform": "scaleX(0)"}), (3.95 + kayma, {"opacity": 1, "transform": "scaleX(1)"}),
                        (toplam - 0.9, {"opacity": 1, "transform": "scaleX(1)"}), (toplam - 0.6, {"opacity": 0, "transform": "scaleX(1)"}),
                        (toplam, {"opacity": 0, "transform": "scaleX(1)"})])
    s.css.append("[class^=d], .cizik { transform-box: fill-box; } [class^=d] { transform-origin: center; } "
                 ".cizik { transform-origin: left center; }")
    if fare:
        # İşaretçi ucu (7, 4.5) × 0.7 hedefin üstüne gelir; tıklarken uç etrafında küçülür.
        bx, by, hx, hy, tik = fare
        tik += kayma
        bas, hedef = f"translate({bx}px, {by}px)", f"translate({hx - 4.9:.1f}px, {hy - 3.2:.1f}px)"
        s.kareler("fare", [(0, {"opacity": 0, "transform": f"{bas} scale(1)"}), (tik - 0.75, {"opacity": 0, "transform": f"{bas} scale(1)"}),
                           (tik - 0.6, {"opacity": 1, "transform": f"{bas} scale(1)"}), (tik - 0.05, {"opacity": 1, "transform": f"{hedef} scale(1)"}),
                           (tik, {"opacity": 1, "transform": f"{hedef} scale(0.86)"}), (tik + 0.14, {"opacity": 1, "transform": f"{hedef} scale(1)"}),
                           (tik + 0.8, {"opacity": 1, "transform": f"{hedef} scale(1)"}), (tik + 1.1, {"opacity": 0, "transform": f"{hedef} scale(1)"}),
                           (toplam, {"opacity": 0, "transform": f"{hedef} scale(1)"})], egri=EASE_IN_OUT)
        govde.append(f'<g class="fare"><path d="M7 4.5l20 11.4-8.8 2.3L14.2 27z" transform="scale(0.7)" fill="{MUREKKEP}" '
                     f'stroke="{YUZEY}" stroke-width="2" stroke-linejoin="round"/></g>')
    return s.svg(gen, yuk, f"{baslik}: {' '.join(aciklama)}", "".join(govde))


# Kart ve demo sayfası ölçüleri. Dar kartta sayfa simge ve açıklamayla aynı sol çizgide (28) durur,
# sağda da 28 pay bırakır; içerik sayfanın içinde solda 30, üstte ve altta en az 18 px boşlukla durur. Kartlar az yazıya göre sıkı: README genişliğe ölçeklediği için
# dar viewBox yazıyı büyütür, boş alan azalır. Geniş kartlar demo satırlarının sığdığı
# kadar kısa: geniş kartın sol sütununda yalnızca başlık, açıklama ve bağlantı var.
KART_BOYU = {"dar": (440, 276), "genis": (900, 226)}
# Demo sayfası kutuları (x, y, en, boy). Demolar bunların ortasına göre yerleşir: elle verilen
# kart koordinatları içerikleri kaydırıyor, "And more"ı taşırıyordu.
# Geniş kartta sayfa, sol sütundaki en uzun satırdan ~36 px sonra başlar ve sağda 22 px pay bırakır:
# "And more"ın sol sütunu kısa, sayfası da o kadar sola gelir; yoksa arada kopuk bir boşluk kalıyordu.
KART_SAYFASI = {"dar": (28, 110, 384, 112), "genis": (420, 22, 458, 182), "fazla": (336, 22, 542, 182)}


def kartlar():
    sari_z, sari_y = PASTEL["sari"]
    dx, dy, den, dboy = KART_SAYFASI["dar"]
    # Dar kart demoları sayfadaki gibi sola yaslı: sayfanın sol kenarından 30 px içeride.
    d_sol, d_orta_x, d_orta_y = dx + 30, dx + den / 2, dy + dboy / 2      # 58, 220, 166
    gx, gy, gen_, gboy = KART_SAYFASI["genis"]
    g_sol = gx + 36

    # Geniş kart: üç satır sırayla kaynaktan biçimli hâle dönüşür; satırlar sayfada dikey ortalı.
    # "approved" kendi vurgu kutusunun ortasında durur: tarayıcı fontu farklı olsa da kutudan taşmaz.
    vurgu_x, vurgu_en = 168, 104
    satirlar = [
        ([("## ", True), ("Meeting notes", False)],
         yazi("Meeting notes", 0, 0, 27, MUREKKEP, SERIF, font_weight="bold", letter_spacing="-0.4")),
        ([("**", True), ("Decision:", False), ("**", True), (" budget ", False), ("==", True), ("approved", False), ("==", True)],
         yazi("Decision:", 0, 0, 20, MUREKKEP, font_weight="700") + yazi("budget", 98, 0, 20, MUREKKEP)
         + f'<rect x="{vurgu_x}" y="-21" width="{vurgu_en}" height="29" rx="5" fill="{sari_z}"/>'
         + yazi("approved", vurgu_x + vurgu_en / 2, 0, 20, MUREKKEP, text_anchor="middle")),
        # Uyarı kutusu öteki satırlarla aynı sol çizgide başlar.
        ([("> [!💡 sarı] ", True), ("Due Friday", False)],
         f'<rect x="0" y="-27" width="220" height="40" rx="8" fill="{sari_z}"/>'
         f'<rect x="0" y="-27" width="4" height="40" rx="2" fill="{sari_y}"/>'
         + simge("ampul", 16, -17, 20, sari_y) + yazi("Due Friday", 46, 0, 19, MUREKKEP)),
    ]
    satir_ara_b = 56
    ilk = gy + gboy / 2 - satir_ara_b + 6                                  # orta satır sayfanın ortasında
    bicim_demo = []
    for i, (k, g) in enumerate(satirlar):
        y = ilk + i * satir_ara_b
        bicim_demo.append((demo_satiri(kaynak(k), g_sol, y), 0.35 + i * 0.25, 1.9 + i * 0.25, "x"))
        bicim_demo.append((demo_satiri(g, g_sol, y), 2.05 + i * 0.25, None, "y"))

    # İki iş: kaynaktan onay kutusuna dönüşür, işaretçi ilkini tikler. Blok (ilk kutunun üstünden
    # ikinci kutunun altına 55 px) sayfada dikey ortalı.
    satir1, satir2 = d_orta_y - 10.5, d_orta_y + 25.5
    yesil_y = PASTEL["yesil"][1]

    def is_satiri(metin):
        return f'<rect x="0" y="-17" width="19" height="19" rx="5" fill="none" stroke="{MUREKKEP}" stroke-width="1.75"/>' + yazi(metin, 30, 0, 19)

    gorev = [
        (demo_satiri(kaynak([("- [ ] ", True), ("Send the report", False)], boyut=18), d_sol, satir1), 0.35, 1.9, "x"),
        (demo_satiri(kaynak([("- [ ] ", True), ("Prepare the slides", False)], boyut=18), d_sol, satir2), 0.6, 2.15, "x"),
        (demo_satiri(is_satiri("Send the report"), d_sol, satir1), 2.05, None, "y"),
        (demo_satiri(is_satiri("Prepare the slides"), d_sol, satir2), 2.3, None, "y"),
        (demo_satiri(f'<rect x="0" y="-17" width="19" height="19" rx="5" fill="{yesil_y}"/>'
                     f'<path d="M4.5 -8 L8.2 -4.5 L14.5 -11.5" stroke="{YUZEY}" stroke-width="2.2" fill="none" '
                     f'stroke-linecap="round" stroke-linejoin="round"/>', d_sol, satir1), 3.45, None, "o"),
        (demo_satiri(f'<line class="cizik" x1="30" y1="-6" x2="164" y2="-6" stroke="{MUREKKEP}" stroke-width="1.75"/>',
                     d_sol, satir1), 0, None, "o"),
    ]
    gorev_fare = (300, 206, d_sol + 9.5, satir1 - 7.5, 3.45)

    # Bırakma alanı sayfanın iç boşluğunu doldurur (dikey ortalı); simge + yazı alanın içinde ortalı.
    # Bırakılan görsel ise sayfadaki gibi satır başında durur.
    alan_en, alan_boy = den - 40, 72
    ax, ay = dx + 20, d_orta_y - alan_boy / 2
    ipucu_en = 22 + 10 + 18 * 8                                            # simge + boşluk + yazı (~8 px/harf)
    mavi_z = PASTEL["mavi"][0]
    gorsel_kucuk = (f'<rect x="0" y="-25" width="72" height="50" rx="7" fill="{mavi_z}"/>'
                    f'<circle cx="52" cy="-11" r="6" fill="#e9cf86"/>'
                    f'<path d="M5 21 L25 -1 L38 12 L47 3 L67 21 Z" fill="#8aa37a"/>')
    gorseller = [
        (demo_satiri(f'<rect x="0" y="0" width="{alan_en}" height="{alan_boy}" rx="10" fill="none" stroke="{ISARET}" '
                     f'stroke-dasharray="6 5"/>' + simge("gorsel", (alan_en - ipucu_en) / 2, alan_boy / 2 - 11, 22, ISARET)
                     + yazi("Drop an image here", (alan_en - ipucu_en) / 2 + 32, alan_boy / 2 + 6, 16, SOLUK), ax, ay),
         0.35, 1.95, "o"),
        (demo_satiri(gorsel_kucuk + yazi("plan.png", 88, -3, 16, SOLUK) + yazi("Added to the page", 88, 17, 13, ISARET),
                     d_sol, d_orta_y), 2.05, None, "d"),
    ]

    # Üç satırlık ağaç: blok sayfada dikey ortalı (satırlar 28 ve 26 px arayla), sola yaslı.
    ust_taban = d_orta_y - 21

    def agac_satirlari(ust_simge, ust_ton, ust_yazi, alt):
        sol = d_sol
        return [(demo_satiri(simge(ust_simge, 0, -17, 20, PASTEL[ust_ton][1]) + yazi(escape(ust_yazi), 30, 0, 17, MUREKKEP,
                                                                                       font_weight="600"), sol, ust_taban),
                 0.35, None, "y")] + \
               [(demo_satiri(a, sol + 28, ust_taban + 28 + j * 26), 0.9 + j * 0.5, None, "y") for j, a in enumerate(alt)]

    agac = agac_satirlari("klasor", "kum", "Project", [simge("sayfa", 0, -16, 18, SOLUK) + yazi("Meeting notes", 28, 0, 16, SOLUK),
                                                       simge("sayfa", 0, -16, 18, SOLUK) + yazi("Budget", 28, 0, 16, SOLUK)])
    dosyalar = agac_satirlari("klasor", "kirmizi", "Documents  ›  NotDefteri",
                              [simge("sayfa", 0, -16, 18, SOLUK) + yazi("Meeting notes", 28, 0, 16, SOLUK),
                               yazi("Opens in Obsidian, VS Code and other editors", 0, 0, 14, ISARET, font_style="italic")])

    # "And more": 2 sütun × 3 satır; en uzun öge (simge + "Restore within 30 days") ~180 px.
    # Blok sayfada dikey ve yatay ortalı.
    ogeler = [("ara", "Quick finder", "⌘P to any page"), ("bag", "Page links", "Link pages with [["),
              ("gecmis", "Page history", "Restore older versions"), ("cop", "Trash", "Restore within 30 days"),
              ("disa", "Export", "PDF or web page"), ("kayit", "Autosave", "Saves as you type")]
    fx, fy, fen, fboy = KART_SAYFASI["fazla"]
    sutun_en, satir_ara, oge_boy, oge_en = 244, 54, 40, 180
    blok_en, blok_boy = sutun_en + oge_en, 2 * satir_ara + oge_boy
    bx0, by0 = fx + (fen - blok_en) / 2, fy + (fboy - blok_boy) / 2
    fazla_demo = []
    for i, (sim, ad, alt) in enumerate(ogeler):
        x, y = bx0 + (i % 2) * sutun_en, by0 + (i // 2) * satir_ara
        fazla_demo.append((demo_satiri(simge(sim, 0, 0, 22) + yazi(escape(ad), 34, 16, 16, MUREKKEP, font_weight="600")
                                       + yazi(escape(alt), 34, 36, 13, SOLUK), x, y), 0.6 + i * 0.08, None, "y"))

    return [
        ("bicim", kart("kalem", "sari", "Formats as you type",
                       ["Type the marks, the text takes shape instantly.", "Headings, bold, highlights, callouts and more."],
                       "How it works", bicim_demo, genis=True, toplam=9.0)),
        ("yapilacaklar", kart("onay", "yesil", "To-dos", ["All your tasks in one list on the Home page."],
                              "How it works", gorev, kayma=0.2, fare=gorev_fare)),
        ("gorseller", kart("gorsel", "mavi", "Images", ["Drag and drop; the image shows up on the page."],
                           "How it works", gorseller, kayma=0.45)),
        ("agac", kart("agac", "kum", "Page tree", ["Add sub-pages and reorder them by dragging."],
                      "How it works", agac, kayma=0.7)),
        ("dosyalar", kart("klasor", "kirmizi", "Your own files", ["Notes stay on your computer as plain files."],
                          "Where they're stored", dosyalar, kayma=0.95)),
        ("fazlasi", kart("arti", "murekkep", "And more", ["Small features you'll use every day."],
                         "See all", fazla_demo, genis=True, toplam=8.5, sayfa="fazla")),
    ]


# ───────────────────────────── Tanıtım ─────────────────────────────
# brag-output/work/sahne.html'deki tanıtımın vektör karşılığı (aynı sahneler, aynı zamanlama;
# özgün çizelge 23,2 sn, kanca atlanınca 19,8 sn). GIF'i GitHub "hareketi azalt" kullanıcılarında durduruyor; SVG kendiliğinden
# oynar ve birkaç MB yerine birkaç on KB tutar. Ses yalnızca docs/tanitim.mp4'te.

class KaymaliSahne(Sahne):
    """Zamanları `kayma` kadar öne alır: tanıtım "Bugün" kancası olmadan doğrudan başlıkla açılır,
    sahneler MP4'teki özgün zamanlarıyla yazılmaya devam eder."""

    def __init__(self, toplam, kayma):
        super().__init__(toplam - kayma)
        self.kayma = kayma

    def yuzde(self, t):
        return super().yuzde(t - self.kayma)


def tanitim_svg():
    G, Y = 1920, 1080
    T = 23.2                           # özgün süre; ilk 3.4 sn (kanca) atlanır
    s = KaymaliSahne(T, 3.4)
    PANEL, BASLIK_CUBUGU, SECIM = "#ccc4b0", "#c7bda6", "#b8ae98"
    pay = 1.1                          # sans yazı genişliği tarayıcı fontuna göre değişir; örtü cömert

    def goster(ad, bas, bit):
        """Anında belirip kaybolan öğe (imleç, kısayolla değişen satır)."""
        s.kareler(ad, [(0, {"opacity": 0}), (bas, {"opacity": 0}), (bas + 0.001, {"opacity": 1}),
                       (bit, {"opacity": 1}), (bit + 0.001, {"opacity": 0}), (T, {"opacity": 0})], egri="linear", azalt=False)

    def sahne(ad, gir, cik):
        s.kareler(ad, [(0, {"opacity": 0}), (gir, {"opacity": 0}), (gir + 0.45, {"opacity": 1}),
                       (cik, {"opacity": 1}), (cik + 0.4, {"opacity": 0}), (T, {"opacity": 0})])

    def yazma(ad, x, y_ust, yuk, bas, n, hiz, genislik, zemin, imlec_bit, imlec_yuk, imlec_en=4, cizgiler=False,
              imlec_bas=None, kirp=False):
        """Örtü + imleç adım adım sağa kayar: metin harf harf yazılıyormuş gibi açılır.
        kirp: örtü kendi metninin alanında kırpılır; aynı satırda sağda duran metni sonunda örtmez."""
        bitis = bas + n * hiz
        s.css.append(f"@keyframes {ad} {{ 0% {{ transform: translateX(0); }} "
                     f"{s.yuzde(bas)} {{ transform: translateX(0); animation-timing-function: steps({n}, end); }} "
                     f"{s.yuzde(bitis)} {{ transform: translateX({genislik:.1f}px); }} 100% {{ transform: translateX({genislik:.1f}px); }} }}"
                     f"\n.{ad} {{ animation: {ad} {s.toplam}s infinite; }}")
        if imlec_bas is None:
            imlec_bas = min(bas, imlec_bit) - 0.25 if bas - 0.25 > 0 else 0
        goster(f"{ad}-i", imlec_bas, imlec_bit)
        orta = y_ust + (yuk - imlec_yuk) / 2
        # Defter sayfasında örtü altındaki çizgileri de taşır: yatay çizgi yatay kayınca fark edilmez.
        cizgi = "".join(f'<line x1="{x}" y1="{c}" x2="{x + genislik + 12:.1f}" y2="{c}" stroke="#a0947a" stroke-opacity="0.28"/>'
                        for c in range(64, Y, 64) if y_ust <= c <= y_ust + yuk) if cizgiler else ""
        ortu = (f'<g class="{ad}" transform="translate({genislik:.1f} 0)"><rect x="{x}" y="{y_ust}" width="{genislik + 12:.1f}" '
                f'height="{yuk}" fill="{zemin}"/>{cizgi}<rect class="{ad}-i gecici" x="{x}" y="{orta}" width="{imlec_en}" '
                f'height="{imlec_yuk}" fill="{MUREKKEP}"/></g>')
        if not kirp:
            return ortu
        return (f'<clipPath id="{ad}-k"><rect x="{x}" y="{y_ust}" width="{genislik:.1f}" height="{yuk}"/></clipPath>'
                f'<g clip-path="url(#{ad}-k)">{ortu}</g>')

    govde = [f'<rect width="{G}" height="{Y}" fill="{SEPYA}"/>',
             "".join(f'<line x1="0" y1="{y}" x2="{G}" y2="{y}" stroke="#a0947a" stroke-opacity="0.28"/>' for y in range(64, Y, 64)),
             f'<line x1="140.5" y1="0" x2="140.5" y2="{Y}" stroke="{KENAR}" stroke-width="3" stroke-opacity="0.75"/>',
             '<defs><filter id="golge" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="28" '
             'stdDeviation="30" flood-color="#46321a" flood-opacity="0.35"/></filter>'
             '<filter id="golge-k" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="12" '
             'stdDeviation="14" flood-color="#46321a" flood-opacity="0.22"/></filter>'
             '<clipPath id="pencere-kirp"><rect x="210" y="96" width="1500" height="820" rx="16"/></clipPath>'
             '<clipPath id="dosya-kirp"><rect x="410" y="297" width="1100" height="268" rx="16"/></clipPath></defs>']

    # 2 · Açılış
    sahne("s2", 3.4, 6.0)          # kayma sonrası 0 sn: video doğrudan başlıkla açılır
    s.gir_cik("a-ad", 3.45, 99, kayma="translateY(24px)")
    s.gir_cik("a-slogan", 3.7, 99, kayma="translateY(16px)")
    govde.append('<g class="s2">'
                 + yazi("NotDefteri", 214, 480, 176, MUREKKEP, SERIF, font_weight="bold", letter_spacing="-5", **{"class": "a-ad"})
                 + yazi(escape(SLOGAN), 220, 610, 46, SOLUK, **{"class": "a-slogan"}) + "</g>")

    # 3–5 · Uygulama penceresi
    sahne("s3", 6.4, 16.3)
    s.kareler("pencere", [(0, {"transform": "translateY(30px) scale(0.97)"}), (6.4, {"transform": "translateY(30px) scale(0.97)"}),
                          (6.95, {"transform": "translateY(0) scale(1)"}), (16.25, {"transform": "translateY(0) scale(1)"}),
                          (16.7, {"transform": "translateY(0) scale(0.96)"}), (T, {"transform": "translateY(0) scale(0.96)"})],
              azalt=False)
    s.css.append(".pencere { transform-box: fill-box; transform-origin: center; }")
    # Bağ tıklanınca seçim "Meeting notes"tan "Q3 Report"a kayar; kalın yazı da onunla geçer.
    acilis = 13.55
    s.kareler("secim", [(0, {"transform": "translateY(0)"}), (acilis, {"transform": "translateY(0)"}),
                        (acilis + 0.4, {"transform": "translateY(48px)"}), (T, {"transform": "translateY(48px)"})],
              egri=EASE_IN_OUT, azalt=False)
    goster("p-ilk", 0, acilis + 0.2)
    goster("p-son", acilis + 0.2, 99)
    satirlar = [("ev", "Home", 0, "", ""), (None, "Pages", 0, "", ""), ("klasor", "Project", 0, "▾", ""),
                (None, "Meeting notes", 1, "", "ilk"), (None, "Q3 Report", 1, "", "son"), (None, "Budget", 1, "", ""),
                ("klasor", "Journal", 0, "▸", ""), ("sayfa", "Reading list", 0, "", "")]
    panel = [f'<rect x="210" y="148" width="330" height="768" fill="{PANEL}"/>',
             f'<rect x="226" y="170" width="298" height="42" rx="9" fill="{MUREKKEP}" fill-opacity="0.07"/>',
             yazi("Search…", 242, 198, 18, SOLUK),
             f'<rect class="secim" x="226" y="370" width="298" height="48" rx="8" fill="{SECIM}"/>']
    y = 234
    for sim, ad, alt, ok, secili in satirlar:
        if ad == "Pages":
            panel.append(yazi("Pages", 240, y + 30, 14, SOLUK, letter_spacing="0.6"))
            y += 40
            continue
        if ok:
            panel.append(yazi(ok, 240, y + 30, 13, SOLUK))
        if sim:
            panel.append(simge(sim, 258, y + 14, 20, MUREKKEP))
        x_ad = 270 if alt else 288
        if secili:
            # Seçili sayfa kalın; seçim kayınca kalınlık öteki satıra geçer.
            diger = "son" if secili == "ilk" else "ilk"
            panel.append(f'<g class="p-{secili}">' + yazi(escape(ad), x_ad, y + 31, 22, MUREKKEP, font_weight="600") + "</g>"
                         + f'<g class="p-{diger}">' + yazi(escape(ad), x_ad, y + 31, 22, MUREKKEP) + "</g>")
        else:
            panel.append(yazi(escape(ad), x_ad, y + 31, 22, MUREKKEP))
        y += 48
    s.kareler("yol", [(0, {"opacity": 1}), (acilis, {"opacity": 1}), (acilis + 0.15, {"opacity": 0}),
                      (acilis + 0.3, {"opacity": 1}), (T, {"opacity": 1})], egri="linear", azalt=False)
    pencere = [f'<rect x="210" y="96" width="1500" height="820" rx="16" fill="{SEPYA}" filter="url(#golge)"/>',
               '<g clip-path="url(#pencere-kirp)">',
               f'<rect x="210" y="96" width="1500" height="52" fill="{BASLIK_CUBUGU}"/>',
               "".join(f'<circle cx="{239 + i * 24}" cy="122" r="7" fill="{r}"/>' for i, r in enumerate(["#e0645a", "#e3b341", "#5fb05a"])),
               '<g class="yol"><g class="p-ilk">'
               + yazi(f'Project  ›  <tspan fill="{MUREKKEP}" font-weight="600">Meeting notes</tspan>', 960, 128, 19, SOLUK,
                      text_anchor="middle") + '</g><g class="p-son">'
               + yazi(f'Project  ›  <tspan fill="{MUREKKEP}" font-weight="600">Q3 Report</tspan>', 960, 128, 19, SOLUK,
                      text_anchor="middle") + "</g></g>",
               *panel]

    # Sayfa 1 · Meeting notes: bağ tıklanınca yukarı kayarak söner.
    s.kareler("sayfa1", [(0, {"opacity": 1, "transform": "translateY(0)"}), (acilis, {"opacity": 1, "transform": "translateY(0)"}),
                         (acilis + 0.25, {"opacity": 0, "transform": "translateY(-10px)"}),
                         (T, {"opacity": 0, "transform": "translateY(-10px)"})], azalt=False)
    sayfa1 = [yazi("Meeting notes", 636, 272, 66, MUREKKEP, font_weight="700", letter_spacing="-1")]

    # Görev 1: "[] " kısayolu onay kutusuna dönüşür, "Send the report" yazılır.
    goster("g1-kaynak", 6.75, 7.11)
    s.kareler("g1-kutu", [(0, {"opacity": 0}), (7.11, {"opacity": 0}), (7.3, {"opacity": 1}), (T, {"opacity": 1})], azalt=False)
    sayfa1 += [
        f'<g class="g1-kaynak gecici">{yazi("[] ", 636, 354, 36, ISARET, MONO)}'
        + yazma("g1-k-ortu", 636, 318, 50, 6.75, 3, 0.12, 3 * 21.6, SEPYA, 7.11, 40) + "</g>",
        f'<rect class="g1-kutu" x="636" y="323" width="38" height="38" rx="9" fill="none" stroke="{MUREKKEP}" stroke-width="3"/>',
        yazi("Send the report", 692, 355, 38, MUREKKEP),
        yazma("g1-ortu", 692, 318, 50, 7.25, 15, 0.055, 263 * pay, SEPYA, 8.225, 40)]
    # İşaretçi ilk kutuya gidip tıklar: kutu dolar, üstü çizilir.
    tik = 10.0
    s.kareler("g1-dolu", [(0, {"opacity": 0}), (tik, {"opacity": 0}), (tik + 0.18, {"opacity": 1}), (T, {"opacity": 1})], azalt=False)
    s.kareler("g1-cizik", [(0, {"transform": "scaleX(0)"}), (tik + 0.1, {"transform": "scaleX(0)"}),
                           (tik + 0.45, {"transform": "scaleX(1)"}), (T, {"transform": "scaleX(1)"})], azalt=False)
    s.css.append(".g1-cizik { transform-box: fill-box; transform-origin: left center; }")
    sayfa1 += [f'<g class="g1-dolu"><rect x="634.5" y="321.5" width="41" height="41" rx="10" fill="{PASTEL["yesil"][1]}"/>'
               f'<path d="M644 343l7 7 14-15" stroke="{YUZEY}" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/></g>',
               f'<rect class="g1-cizik" x="692" y="340" width="{263 * 1.04:.0f}" height="3" fill="{MUREKKEP}"/>']

    # Biten işin altına ayrıntının bağı: g2 64 px aşağı kayıp yer açar, "Details: [[Q3" yazılır,
    # öneri seçilince bağa dönüşür. Satır g1'in hemen altında (382–446); metin genişlikleri Chrome ölçüsü.
    secim, bag_tik = 12.6, 13.45
    goster("detay", 10.8, 99)
    goster("d-kaynak", 10.8, secim)
    goster("d-imlec", secim, 12.9)
    s.kareler("d-bag", [(0, {"opacity": 0}), (secim, {"opacity": 0}), (secim + 0.25, {"opacity": 1}),
                        (bag_tik, {"opacity": 1}), (bag_tik + 0.001, {"opacity": 0.6}), (bag_tik + 0.14, {"opacity": 0.6}),
                        (bag_tik + 0.141, {"opacity": 1}), (T, {"opacity": 1})], egri="linear", azalt=False)
    sayfa1.append('<g class="detay">' + yazi("Details:", 692, 427, 34, SOLUK)
                  + yazma("d-on-ortu", 692, 392, 48, 10.85, 9, 0.05, 115, SEPYA, 11.4, 42, imlec_bas=10.85, kirp=True)
                  + f'<g class="d-kaynak gecici">{yazi("[[Q3", 807, 427, 32, MUREKKEP, MONO)}'
                  + yazma("d-k-ortu", 807, 392, 48, 11.4, 4, 0.12, 77, SEPYA, secim, 42, imlec_bas=11.4, kirp=True) + "</g>"
                  + f'<g class="d-bag">{yazi("Q3 Report", 807, 427, 34, VURGU)}<rect x="807" y="432" width="152" height="2.5" fill="{VURGU}"/></g>'
                  + f'<rect class="d-imlec gecici" x="965" y="393" width="4" height="42" fill="{MUREKKEP}"/></g>')
    # Görev 2: Enter ile liste sürer; ayrıntı satırı gelince aşağı kayar.
    goster("g2", 8.325, 99)
    s.kareler("g2-kay", [(0, {"transform": "translateY(0)"}), (10.5, {"transform": "translateY(0)"}),
                         (10.9, {"transform": "translateY(64px)"}), (T, {"transform": "translateY(64px)"})], egri=EASE_IN_OUT, azalt=False)
    sayfa1.append(f'<g class="g2-kay"><g class="g2"><rect x="636" y="403" width="38" height="38" rx="9" fill="none" stroke="{MUREKKEP}" stroke-width="3"/>'
                  + yazi("Prepare the slides", 692, 435, 38, MUREKKEP)
                  + yazma("g2-ortu", 692, 398, 50, 8.425, 18, 0.055, 306 * pay, SEPYA, 9.6, 40) + "</g></g>")
    # Öneri listesi alttaki görevin üstünde açılır.
    s.kareler("oneri", [(0, {"opacity": 0, "transform": "translateY(8px) scale(0.97)"}),
                        (11.95, {"opacity": 0, "transform": "translateY(8px) scale(0.97)"}),
                        (12.2, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
                        (secim - 0.05, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
                        (secim + 0.12, {"opacity": 0, "transform": "translateY(0) scale(1)"}),
                        (T, {"opacity": 0, "transform": "translateY(0) scale(1)"})], azalt=False)
    s.css.append(".oneri { transform-box: fill-box; transform-origin: 20px 0; }")
    sayfa1.append(f'<g class="oneri"><rect x="799" y="441" width="470" height="182" rx="12" fill="{KAGIT}" stroke="{MUREKKEP}" '
                  f'stroke-opacity="0.12"/><rect x="807" y="449" width="454" height="83" rx="8" fill="{SECIM}"/>'
                  + yazi("Q3 Report", 825, 486, 28, MUREKKEP) + yazi("Project", 825, 514, 19, SOLUK)
                  + yazi("Q3 Budget", 825, 569, 28, MUREKKEP) + yazi("Project › Budget", 825, 597, 19, SOLUK) + "</g>")
    pencere.append('<g class="sayfa1">' + "".join(sayfa1) + "</g>")

    # Sayfa 2 · Q3 Report: ayrıntı sayfası, görseliyle birlikte açılır.
    s.kareler("sayfa2", [(0, {"opacity": 0, "transform": "translateY(14px)"}), (acilis + 0.25, {"opacity": 0, "transform": "translateY(14px)"}),
                         (acilis + 0.7, {"opacity": 1, "transform": "translateY(0)"}), (T, {"opacity": 1, "transform": "translateY(0)"})],
              azalt=False)
    s.kareler("grafik", [(0, {"opacity": 0, "transform": "translateY(12px) scale(0.97)"}),
                         (acilis + 0.45, {"opacity": 0, "transform": "translateY(12px) scale(0.97)"}),
                         (acilis + 0.95, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
                         (T, {"opacity": 1, "transform": "translateY(0) scale(1)"})], azalt=False)
    s.css.append(".grafik { transform-box: fill-box; transform-origin: left top; }")
    cubuklar = [(64, 186), (152, 158), (240, 170), (328, 128), (416, 104)]
    grafik = ('<g class="grafik"><g transform="translate(636 395)">'
              f'<rect width="620" height="300" rx="14" fill="{YUZEY}" filter="url(#golge-k)"/>'
              f'<rect x="0.5" y="0.5" width="619" height="299" rx="14" fill="none" stroke="{MUREKKEP}" stroke-opacity="0.1"/>'
              + "".join(f'<line x1="44" y1="{c}" x2="576" y2="{c}" stroke="{MUREKKEP}" stroke-opacity="0.08"/>' for c in (70, 140, 210))
              + "".join(f'<rect x="{x}" y="{y}" width="56" height="{260 - y}" rx="7" fill="#d6c9a8"/>' for x, y in cubuklar)
              + '<rect x="504" y="62" width="56" height="198" rx="7" fill="#7f9a6e"/>'
              + f'<line x1="44" y1="260.5" x2="576" y2="260.5" stroke="{MUREKKEP}" stroke-opacity="0.25" stroke-width="1.5"/></g></g>')
    pencere.append('<g class="sayfa2">' + yazi("Q3 Report", 636, 272, 66, MUREKKEP, font_weight="700", letter_spacing="-1")
                   + yazi("Sent to the team on Friday.", 636, 355, 38, MUREKKEP) + grafik + "</g>")
    pencere += ["</g>", f'<rect x="210.5" y="96.5" width="1499" height="819" rx="16" fill="none" stroke="{MUREKKEP}" stroke-opacity="0.12"/>']

    # İşaretçi önce kutuyu tikler; görünmezken bekleme yerine geçer, sonra bağa gidip sayfayı açar.
    kutu, bag = "translate(650px, 336px)", "translate(875px, 416px)"
    s.kareler("isaretci", [(0, {"opacity": 0, "transform": "translate(1250px, 880px) scale(1)"}),
                           (9.35, {"opacity": 0, "transform": "translate(1250px, 880px) scale(1)"}),
                           (9.45, {"opacity": 1, "transform": "translate(1250px, 880px) scale(1)"}),
                           (9.95, {"opacity": 1, "transform": f"{kutu} scale(1)"}),
                           (tik, {"opacity": 1, "transform": f"{kutu} scale(0.86)"}),
                           (tik + 0.14, {"opacity": 1, "transform": f"{kutu} scale(1)"}),
                           (10.6, {"opacity": 1, "transform": f"{kutu} scale(1)"}),
                           (10.9, {"opacity": 0, "transform": f"{kutu} scale(1)"}),
                           (12.8, {"opacity": 0, "transform": "translate(1180px, 760px) scale(1)"}),
                           (12.95, {"opacity": 1, "transform": "translate(1180px, 760px) scale(1)"}),
                           (13.4, {"opacity": 1, "transform": f"{bag} scale(1)"}),
                           (bag_tik, {"opacity": 1, "transform": f"{bag} scale(0.86)"}),
                           (bag_tik + 0.14, {"opacity": 1, "transform": f"{bag} scale(1)"}),
                           (14.2, {"opacity": 1, "transform": f"{bag} scale(1)"}),
                           (14.5, {"opacity": 0, "transform": f"{bag} scale(1)"}),
                           (T, {"opacity": 0, "transform": f"{bag} scale(1)"})], egri=EASE_IN_OUT, azalt=False)
    s.gir_cik("yazi3", 7.0, 10.6, kayma="translateY(18px)")
    s.gir_cik("yazi4", 10.75, 13.3, kayma="translateY(18px)")
    s.gir_cik("yazi6", 13.5, 16.2, kayma="translateY(18px)")
    govde.append('<g class="s3"><g class="pencere">' + "".join(pencere) + "</g>"
                 '<g class="isaretci"><path d="M7 4.5l20 11.4-8.8 2.3L14.2 27z" fill="#2f2a24" stroke="#f6f2e7" stroke-width="2" '
                 'stroke-linejoin="round"/></g>'
                 + yazi("Formats as you type. Check off to-dos in one click.", 960, 1002, 40, MUREKKEP, text_anchor="middle", **{"class": "yazi3"})
                 + yazi(f'Link pages with <tspan font-family="{MONO}">[[</tspan>', 960, 1002, 40, MUREKKEP,
                        text_anchor="middle", **{"class": "yazi4"})
                 + yazi("Click a link to open the page.", 960, 1002, 40, MUREKKEP, text_anchor="middle", **{"class": "yazi6"}) + "</g>")

    # 6 · Dosyalar: açılan sayfa bilgisayarda bir klasör.
    sahne("s5", 16.7, 20.0)
    s.gir_cik("dosyalar", 16.75, 99, kayma="translateY(30px) scale(0.97)")
    s.css.append(".dosyalar { transform-box: fill-box; transform-origin: center; }")
    dosya = [f'<rect x="410" y="297" width="1100" height="268" rx="16" fill="{KAGIT}" filter="url(#golge)"/>',
             '<g clip-path="url(#dosya-kirp)">', f'<rect x="410" y="297" width="1100" height="84" fill="{YUZEY}"/>',
             simge("klasor", 440, 325, 28, SOLUK),
             yazi(f'Documents  ›  NotDefteri  ›  Project  ›  <tspan fill="{MUREKKEP}" font-weight="700">Q3 Report</tspan>', 482, 349, 27, SOLUK),
             f'<rect x="410" y="380" width="1100" height="1" fill="{MUREKKEP}" fill-opacity="0.1"/>']
    for i, (sim, ad, aciklama) in enumerate([("sayfa", "index.md", "The page text"), ("gorsel", "Images", "Images you added")]):
        y0 = 381 + i * 92
        s.gir_cik(f"d{i}", 17.05 + i * 0.12, 99, kayma="translateY(12px)")
        dosya.append(f'<g class="d{i}">' + simge(sim, 446, y0 + 29, 34, MUREKKEP) + yazi(escape(ad), 500, y0 + 57, 32, MUREKKEP)
                     + yazi(escape(aciklama), 1474, y0 + 56, 23, SOLUK, text_anchor="end")
                     + (f'<rect x="410" y="{y0 + 91}" width="1100" height="1" fill="{MUREKKEP}" fill-opacity="0.07"/>' if i == 0 else "")
                     + "</g>")
    dosya += ["</g>", f'<rect x="410.5" y="297.5" width="1099" height="267" rx="16" fill="none" stroke="{MUREKKEP}" stroke-opacity="0.12"/>']
    s.gir_cik("yazi5", 17.0, 99, kayma="translateY(18px)")
    govde.append('<g class="s5"><g class="dosyalar">' + "".join(dosya) + "</g>"
                 + yazi("Your notes stay on your computer as plain files.", 960, 1002, 40, MUREKKEP, text_anchor="middle",
                        **{"class": "yazi5"}) + "</g>")

    # 7 · Kapanış; döngü başa dönmeden önce sayfaya söner.
    sahne("s6", 20.4, T - 0.45)
    s.gir_cik("son-ad", 20.45, 99, kayma="translateY(24px)")
    s.gir_cik("son-slogan", 20.65, 99, kayma="translateY(16px)")
    s.gir_cik("son-meta", 20.85, 99, kayma="translateY(10px)")
    govde.append('<g class="s6">'
                 + yazi("NotDefteri", 960, 490, 176, MUREKKEP, SERIF, text_anchor="middle", font_weight="bold", letter_spacing="-5",
                        **{"class": "son-ad"})
                 + yazi(escape(SLOGAN), 960, 606, 46, SOLUK, text_anchor="middle", **{"class": "son-slogan"})
                 + yazi("MACOS · LINUX  —  GITHUB.COM/OLCAYALKAN/NOTDEFTERI", 960, 706, 26, SOLUK, MONO, text_anchor="middle",
                        letter_spacing="3", **{"class": "son-meta"}) + "</g>")
    return s.svg(G, Y, "NotDefteri intro: a simple notebook that formats as you type, with to-dos, page links that open "
                       "with one click, and notes that stay on your computer as plain files.", "".join(govde))


# ───────────────────────────── Kurulum ─────────────────────────────

T_ZEMIN = "#2a251f"
T_UST = "#36302a"
T_METIN = "#ece4cf"
T_SOLUK = "#a89a80"
T_ISTEM = "#d9a95b"
T_BASARI = "#a9c48a"

KURULUM = [
    # (tür, metin, önce bekleme sn) — çıktılar betiklerin yazdırdığı metinlerin İngilizcesi
    ("komut", "git clone https://github.com/olcayalkan/NotDefteri.git", 0.6),
    ("cikti", "Cloning into 'NotDefteri'...", 0.5),
    ("komut", "cd NotDefteri", 0.6),
    ("komut", "./scripts/kisayol-kur.sh", 0.5),
    ("basari", "Installed. Just type 'not' in the terminal.", 0.4),
    ("komut", "not", 0.8),
    ("cikti", "Building...", 0.3),
    ("soluk", "Build complete! (41.20s)", 1.4),
    ("cikti", "Launching...", 0.3),
    ("basari", "Opened (pid 4242). Notes: ~/Documents/NotDefteri/", 0.5),
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
    return s.svg(gen, yuk, "Installation: clone the repository, install the shortcut, type not to open the app", "".join(govde))


if __name__ == "__main__":
    ciktilar = [("baslik.svg", baslik_svg()), ("kurulum.svg", kurulum_svg()), ("tanitim.svg", tanitim_svg())]
    ciktilar += [(f"kart-{ad}.svg", icerik) for ad, icerik in kartlar()]
    for ad, icerik in ciktilar:
        yol = DOCS / ad
        yol.write_text(icerik, encoding="utf-8")
        print(f"{yol.relative_to(DOCS.parent)} — {yol.stat().st_size / 1024:.1f} KB")
