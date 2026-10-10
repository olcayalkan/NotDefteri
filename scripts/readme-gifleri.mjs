// docs/*.svg animasyonlarını docs/*.gif'e çevirir.
//
// SVG içindeki CSS animasyonu bazı görüntüleyicilerde oynamıyor ve "hareketi azalt" açıkken
// yalnızca solma sürümüne düşüyordu; GIF her yerde aynı oynar. Her SVG Chrome'da zamanı
// durdurularak kare kare çizilir (animasyon t anına sabitlenir), kareler ffmpeg ile GIF olur.
//
//   python3 scripts/readme-animasyonlar.py                 # önce SVG'leri üret
//   npm i --prefix .build/readme-arac puppeteer-core ffmpeg-static
//   node scripts/readme-gifleri.mjs [dosya-adi.svg ...]
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import path from 'node:path';

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const DOCS = path.join(KOK, 'docs');
const ARAC = path.join(KOK, '.build', 'readme-arac');
const gerek = createRequire(path.join(ARAC, 'package.json'));
const puppeteer = gerek('puppeteer-core');
const ffmpeg = gerek('ffmpeg-static');
const FPS = 20;
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const dosyalar = process.argv.slice(2).length ? process.argv.slice(2)
  : readdirSync(DOCS).filter(ad => ad.endsWith('.svg'));

const tarayici = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--hide-scrollbars'] });
const sayfa = await tarayici.newPage();
// GIF tam hareketle kaydedilir; azaltılmış sürüm yalnızca canlı SVG içindir.
await sayfa.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'no-preference' }]);

for (const ad of dosyalar) {
  const svg = readFileSync(path.join(DOCS, ad), 'utf8');
  const gen = Number(svg.match(/width="(\d+)"/)[1]);
  const yuk = Number(svg.match(/height="(\d+)"/)[1]);
  const sure = Number(svg.match(/animation: \S+ ([\d.]+)s/)[1]);   // döngü süresi (Sahne.toplam)
  const kareKlasoru = path.join(KOK, '.build', 'gif-kareleri', ad);
  rmSync(kareKlasoru, { recursive: true, force: true });
  mkdirSync(kareKlasoru, { recursive: true });

  await sayfa.setViewport({ width: gen, height: yuk, deviceScaleFactor: 1 });
  // Kâğıt dokusu (gren) GIF'te kalkar: 128 renge indirgenince karıncalanıyor, dosyayı da büyütüyor.
  // Köşeler kartın kendi rengiyle dolar (düz köşe): beyaz zemin koyu temada üçgen bırakıyordu,
  // saydam GIF ise ffmpeg'in "yalnızca değişen bölge" tasarrufunu bozup dosyayı 15 kat büyütüyordu.
  const zemin = svg.match(/<rect[^>]*fill="(#[0-9a-f]{6})"/)[1];
  await sayfa.setContent(`<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:${zemin}}
    rect[filter]{display:none}</style><style id="zaman"></style>${svg}`);
  await sayfa.evaluate(() => document.fonts.ready);

  const kareSayisi = Math.round(sure * FPS);
  for (let i = 0; i < kareSayisi; i++) {
    const t = i / FPS;
    await sayfa.evaluate(t => {
      document.getElementById('zaman').textContent =
        `svg *{animation-play-state:paused!important;animation-delay:-${t}s!important}`;
    }, t);
    await sayfa.screenshot({ path: path.join(kareKlasoru, `${String(i).padStart(4, '0')}.png`), omitBackground: false });
  }

  const cikti = path.join(DOCS, ad.replace(/\.svg$/, '.gif'));
  // Ortak palet + yalnızca değişen dikdörtgeni yazma: durağan kareler neredeyse yer kaplamaz.
  execFileSync(ffmpeg, ['-y', '-loglevel', 'error', '-framerate', String(FPS), '-i', path.join(kareKlasoru, '%04d.png'),
    '-vf', 'split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle',
    '-loop', '0', cikti]);
  console.log(`docs/${path.basename(cikti)} — ${kareSayisi} kare, ${sure} sn, ${(statSync(cikti).size / 1024).toFixed(0)} KB`);
}
await tarayici.close();
