#!/usr/bin/env python3
"""README'nin animasyonlu başlığını (docs/baslik.gif) üretir.

Uygulamanın canlı Markdown dönüşümünü gösterir: "# NotDefteri" yazılır, "# " kaybolur ve
metin başlığa dönüşür. Gereksinim yalnızca Pillow; fontlar macOS sistem fontlarıdır.

    python3 -m venv .build/gif-venv && .build/gif-venv/bin/pip install pillow
    .build/gif-venv/bin/python scripts/readme-baslik.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

GEN, YUK = 1000, 250
FPS = 20
CIKTI = Path(__file__).resolve().parent.parent / "docs" / "baslik.gif"

# Sepya teması (Tema.swift) ve defter ayrıntıları.
ZEMIN = (214, 207, 186)
CIZGI = (206, 199, 177)
KENAR_CIZGISI = (190, 128, 112)
METIN = (58, 48, 38)
ISARET = (150, 134, 108)
ALT_METIN = (96, 84, 68)
ETIKET_ZEMIN = (199, 189, 166)

FONTLAR = "/System/Library/Fonts"
MONO = ImageFont.truetype(f"{FONTLAR}/Menlo.ttc", 54)
BASLIK = ImageFont.truetype(f"{FONTLAR}/Supplemental/Georgia Bold.ttf", 74)
ALT = ImageFont.truetype(f"{FONTLAR}/Supplemental/Georgia Italic.ttf", 25)
ETIKET = ImageFont.truetype(f"{FONTLAR}/Supplemental/Georgia.ttf", 18)

SOL = 96            # kenar çizgisinin sağı: yazı buradan başlar
BASLIK_Y = 62
ALT_METIN_YAZI = "macOS ve Linux için sade, hızlı, Markdown tabanlı bir not uygulaması"
ETIKETLER = ["Markdown", "AppKit", "GTK 4", "Bağımlılıksız", ".md dosyaları"]


def yumusak(t):
    """Hızlı başlayıp yavaşça oturan hareket (ease-out cubic)."""
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def karistir(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def zemin():
    kare = Image.new("RGB", (GEN, YUK), ZEMIN)
    c = ImageDraw.Draw(kare)
    for y in range(44, YUK, 34):          # defter çizgileri
        c.line([(0, y), (GEN, y)], fill=CIZGI, width=1)
    c.line([(SOL - 26, 0), (SOL - 26, YUK)], fill=KENAR_CIZGISI, width=2)
    return kare


def yazi(kare, xy, metin, font, renk, saydamlik=1.0):
    """Zemin rengine karıştırarak yazar; GIF'te gerçek saydamlık yok."""
    if saydamlik <= 0:
        return
    ImageDraw.Draw(kare).text(xy, metin, font=font, fill=karistir(ZEMIN, renk, saydamlik))


def imlec(kare, x, gorunur):
    if gorunur:
        ImageDraw.Draw(kare).rectangle([x + 3, BASLIK_Y + 6, x + 6, BASLIK_Y + 66], fill=METIN)


def baslik_satiri(kare, adet, imlec_acik):
    """Yazım evresi: "# NotDefteri"nin ilk `adet` harfi tek aralıklı fontla."""
    metin = "# NotDefteri"[:adet]
    isaret, govde = metin[:2], metin[2:]
    yazi(kare, (SOL, BASLIK_Y), isaret, MONO, ISARET)
    x = SOL + ImageDraw.Draw(kare).textlength(isaret, font=MONO)
    yazi(kare, (x, BASLIK_Y), govde, MONO, METIN)
    imlec(kare, x + ImageDraw.Draw(kare).textlength(govde, font=MONO), imlec_acik)


def donusum(kare, t):
    """İki adım: "# " silinip metin sola kayar, ardından tek aralıklı font başlığa geçer.
    Fontlar aynı anda yarı saydam kalmasın diye geçiş kısa ve çapraz değil, ardışık."""
    isaret_gen = ImageDraw.Draw(kare).textlength("# ", font=MONO)
    a = yumusak(t / 0.5)
    b = yumusak((t - 0.5) / 0.5)
    yazi(kare, (SOL, BASLIK_Y), "# ", MONO, ISARET, 1 - a)
    yazi(kare, (SOL + isaret_gen * (1 - a), BASLIK_Y), "NotDefteri", MONO, METIN, max(0.0, 1 - 2 * b))
    yazi(kare, (SOL, BASLIK_Y - 6 * (1 - b)), "NotDefteri", BASLIK, METIN, min(1.0, max(0.0, 2 * b - 0.4)))


def alt_bolum(kare, t_alt, t_etiket):
    e = yumusak(t_alt)
    yazi(kare, (SOL + 2, 158 + 12 * (1 - e)), ALT_METIN_YAZI, ALT, ALT_METIN, e)
    c = ImageDraw.Draw(kare)
    x = SOL
    for sira, ad in enumerate(ETIKETLER):
        s = yumusak((t_etiket - sira * 0.12) / 0.4)   # sırayla belirir
        gen = c.textlength(ad, font=ETIKET) + 22
        if s > 0:
            dolgu = karistir(ZEMIN, ETIKET_ZEMIN, s)
            y = 200 + 8 * (1 - s)
            c.rounded_rectangle([x, y, x + gen, y + 30], radius=15, fill=dolgu)
            yazi(kare, (x + 11, y + 5), ad, ETIKET, ALT_METIN, s)
        x += gen + 10


def kareler():
    """(kare, süre ms) listesi. Bekleyişler tek kare + uzun süre: dosya küçük kalır."""
    sonuc = []
    adim = 1000 // FPS

    def ekle(ciz, sure=adim):
        k = zemin()
        ciz(k)
        sonuc.append((k, sure))

    for i in range(6):                                     # boş sayfa, imleç yanıp söner
        ekle(lambda k, i=i: baslik_satiri(k, 0, i % 4 < 2), adim * 2)
    for adet in range(1, 13):                              # harf harf yazım
        ekle(lambda k, a=adet: baslik_satiri(k, a, True), adim * 2)
    ekle(lambda k: baslik_satiri(k, 12, False), 350)
    for i in range(14):                                    # "# " kaybolur, başlık olur
        ekle(lambda k, t=i / 13: donusum(k, t))
    for i in range(16):                                    # alt başlık ve etiketler
        ekle(lambda k, t=i / 15: (donusum(k, 1), alt_bolum(k, t * 1.6, t * 1.6)))
    ekle(lambda k: (donusum(k, 1), alt_bolum(k, 1, 2)), 3200)
    for i in range(8):                                     # sayfaya geri sön, döngü
        def solan(k, t=i / 7):
            donusum(k, 1)
            alt_bolum(k, 1, 2)
            k.paste(Image.blend(k, zemin(), yumusak(t)))
        ekle(solan)
    return sonuc


def kaydet():
    liste = kareler()
    # Ortak palet: kareler arası renk titremesi olmaz, dosya küçülür.
    palet = liste[len(liste) // 2][0].quantize(colors=64, method=Image.Quantize.MEDIANCUT)
    gorseller = [k.quantize(palette=palet, dither=Image.Dither.NONE) for k, _ in liste]
    CIKTI.parent.mkdir(parents=True, exist_ok=True)
    gorseller[0].save(CIKTI, save_all=True, append_images=gorseller[1:],
                      duration=[s for _, s in liste], loop=0, optimize=True, disposal=1)
    sure = sum(s for _, s in liste) / 1000
    print(f"{CIKTI} — {len(liste)} kare, {sure:.1f} sn, {CIKTI.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    kaydet()
