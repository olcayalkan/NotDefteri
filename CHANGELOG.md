# Changelog

All notable changes to NotDefteri will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- NotDefteri: macOS'ta Notion gibi blok taşıma. Her paragraf bir blok; kod bloğu, uyarı kutusu ve tablo bölünmez, liste maddesi alt maddeleriyle gider. ⌘⇧↑/↓ imlecin ya da seçimin bloklarını bir blok yukarı/aşağı taşır; fare paragrafın üstündeyken solda çıkan ⋮⋮ tutamacı sürüklenerek blok istenen yere bırakılır (tıklamak bloğu seçer). Taşıma tek adımda geri alınır, numaralı liste yeniden numaralanır.
- NotDefteri: macOS'ta ortalama kutu, liste ve alıntı satırlarında da çalışır (`> [!💡 mavi] <center>…</center>`); kod bloğu bütün olarak ortalanır ve açılış çitine `{center}` yazılır (dil etiketi bozulmaz). Seçili metne sağ tıklayınca simgeli "Ortala" ve "Sola yasla" çıkar; kutuda sağ tık seçimi korur.
- NotDefteri: macOS'ta ⌘O (Biçim > Ortala) seçili satırları Word'deki gibi ortalar, tekrar basınca sola döndürür. Satır `<center>…</center>` olarak kaydolur (Obsidian ve GitHub da ortalar), HTML dışa aktarımda da ortalıdır. Kod, kutu, liste ve tablo satırları ortalanmaz.
- NotDefteri: macOS'ta `/red` kırmızı, `/info` yeşil uyarı kutusu açar (`/uyari` gibi boşlukla hemen uygulanır).
- NotDefteri: macOS not, ana sayfa ve kenar panel sağ tık menülerinde Görünüm altında doğrudan tema seçimi.
- NotDefteri: `/table` ve `/tablo` ile tablo ekleme, kaynak Markdown yazılışını koruyan hücre düzenleme.
- NotDefteri: Terminal teması, kayıtlı tema seçimi için tek seferlik geçiş ve macOS/Linux tema yenilemesi.
- NotDefteri: Dil etiketi olmayan veya tanınmayan kod bloklarında genel sözdizimi renklendirmesi.
- NotDefteri: macOS kod bloğunda `(`, `[`, `{`, `"`, `'` otomatik kapanış; anahtar kelime + Tab ile dile göre try/catch, if, for, while, switch, fonksiyon ve sınıf kalıpları.

### Changed

- NotDefteri: macOS editöründe yazıya daha çok yer: en geniş satır 760'tan 960 pt'ye çıktı, yan pay 48'den 40 pt'ye, metnin üst/alt iç boşluğu 12'den 4 pt'ye, üstteki sayfa seçenekleri alanı 36'dan 28 pt'ye, alt bilgi şeridi 26'dan 22 pt'ye indi (`kEnGenisMetin`, `kEditorYanPayi`, `kEditorDikeyBoslugu`, `kAltBilgiYuksekligi`).
- NotDefteri: macOS'ta renkli kutu ve kod bloğunun altındaki boşluk 2 pt'ye indi; üstünde boş satır ya da başka kutu varsa ek üst boşluk yok, iki kutu arasındaki tek boş satır 6 pt yüksekliğinde.
- NotDefteri: macOS kod bloğu ve uyarı kutusunun altındaki boşluk yarıya indi; sonraki yazı kutuya daha yakın.
- NotDefteri: macOS görseller dört kenarından ve dört köşesinden boyutlandırılır: sol/sağ kenar yalnızca eni, üst/alt kenar yalnızca boyu uzatır; köşeler oranı koruyarak bütün görseli büyütür. Kenar boyunca her yer tutulabilir, imleç tutulan yöne göre değişir.
- NotDefteri: Uyarı kutusu kod bloğu gibi yazılır: boş satırda Enter kutuda kalır, Ctrl+Enter kutudan çıkar (altında boş satır varsa oraya geçer); ilk satır boşken geri silme kutuyu bozmaz.
- NotDefteri: macOS arayüzü tanıtımla uyumlu: sayfa bağları 📄 emojisiyle, köşeli parantezsiz mavi ve altı çizili (imleç bağdayken `[[ ]]` görünür), tamamlanan görevde yeşil tik, görseller yuvarlak köşeli gölgeli kart, kenar panelde "Sayfalar" başlığı ve alt sayfalı sayfalarda klasör simgesi.
- NotDefteri: macOS kenar panelde sayfaya üç tıklama sayfayı yalnızca içeriğiyle ayrı bir pencerede açar; iki tıklama yeniden adlandırır. Bu pencere ana editörün aynısıdır (yazma, biçim, tablo, görsel, geri al, sayfa seçenekleri, otomatik kayıt). Aynı sayfa iki pencerede açıkken biri kaydedince diğeri diskten yenilenir, kayıtlar birbirini ezmez; ana pencerede taşınan sayfanın yolu izlenir, silinen sayfa yeniden oluşturulmaz.
- NotDefteri: Uyarı kutusu ve kod bloğu eklenince altına boş bir satır gelir; uyarı renkleri ve çerçevesi koyulaştı.
- NotDefteri: Numaralı listede numaralar sağa hizalanır; 10 ve üstü numaralar metni kaydırmaz.
- NotDefteri: "Tam genişlik" sayfa seçeneği kaldırıldı (eski sayfalardaki `genislik: tam` satırı korunur, etkisizdir). "•••" sayfa seçenekleri alanı yalnızca düğme kadar geniş.
- NotDefteri: Krem teması kaldırıldı; kayıtlı Krem seçimi Sepya'ya döner. Tema zeminleri göz yormaması için aynı oranda koyulaştırıldı; kağıt temalarda başlık çubuğu ve kenar panel editörden ayrışacak kadar ek koyulaştı, ikincil yazılar kontrastı korumak için koyulaştı.

### Fixed

- NotDefteri: macOS'ta kod bloğu ve uyarı kutusunda blok tutamacı (⋮⋮) kutunun içine düşüyordu; artık çerçevenin solunda ve ilk satır hizasında. Sürüklerken taşınan blok mavi çerçeveyle işaretlenir, yarı saydam kopyası fareyle gelir, bırakma yeri iki bloğun görünen kenarlarının ortasında başında halka olan kalın çizgiyle gösterilir (kutu kenarına karışmasın diye zemin renkli haleli).
- NotDefteri: macOS'ta kutu çevresindeki boşluk komşu satır değişince de hemen güncellenir; düzenlerken görülen boşluk uygulama kapatılıp açılınca değişmez. Bitişik alıntı ile uyarı kutusu arasına kayıtta yazılan boş satır açılışta neredeyse sıfır yükseklikte çizilir (önce tam satır olarak beliriyordu).
- NotDefteri: macOS kod bloğu, uyarı kutusu, alıntı, madde, başlık ve tablo hücresinden tek satır içinde kopyalanan parça yapıştırıldığı satırı bölüp yeni blok açmaz; satır içi yapışır (koddan alınan parça satır içi kod olur, satır içi biçimler korunur). Birden çok satırlık seçim bloğunu taşımaya devam eder. Satır sonuna yapıştırılan kod bloğunun altında boş satır kalmaz.

- NotDefteri: macOS kutu çizgili tablo kaldırıldı; tablolar yerel `NSTextTable` ızgarası olarak görünür. Kutu tablosunda seçilen ya da yapıştırılan içerik silinemiyor, hücre dışında düzenleme engelleniyordu; artık hücreler diğer metin gibi seçilir, silinir, kopyalanır ve düzenlenir, tablo pencere genişliğine sığar, başlık ve çift satırlar gölgelidir. Web tablosu ve sekmeyle ayrılmış düz metin tablo olarak yapışır. Kayıt Markdown tablosudur.
- NotDefteri: macOS uyarı kutusu kopyala-yapıştırda bozuluyordu: satır ortasına yapıştırılan kutunun başlığı metne karışıyor, kutunun ortasından alınan satırlar düz alıntıya dönüyor, kutu içine yapıştırınca boş başlıklı hayalet kutu doğuyor, bütün kutuyu kesince boş kutu kalıyordu.
- NotDefteri: macOS'ta web sayfasından ya da belgeden kopyalanan tablonun hücreleri yan yana yerine alt alta satırlara dönüşüyordu; tablo artık Markdown tablosu olarak yapışır ve kaydolur (önünde ve arkasında boş satırla; hücredeki `|` kaçışlanır).
- NotDefteri: macOS kenar panelde çift tıklayınca ad düzenlemesi çift tıklama süresi kadar gecikiyordu; o arada yazılanlar editöre gidiyor, araya giren ağaç yenilemesi yazılan adı siliyordu. Düzenleme hemen açılır, ad alanına üçüncü tıklama düzenlemeyi iptal edip içerik penceresini açar.
- NotDefteri: macOS `/table` penceresinde satır ve sütun alanlarına yazılamaması.
- NotDefteri: macOS tablo satır zemini ve seçim vurgusunun tablo çerçevesinin dışına taşması.
- NotDefteri: macOS uyarı/kod kutusunda yazı seçilip silinince kutunun da silinmesi; basılı tutulan geri silme boşalan kutuda durur.
- NotDefteri: macOS'ta Enter'la açılan boş görevin kutusunun üstteki satıra binmesi.
- NotDefteri: macOS yapılacak kutularının (☐/☑) farklı boyutta çizilmesi ve boş kutulu satırların daha yüksek olması.
- NotDefteri: Sekmeyle (Obsidian) ya da üç boşlukla girintilenmiş iç listelerin ham metin görünmesi.
- NotDefteri: macOS başlık çubuğunda sayfa adı/yolunun pencerenin ortasında durmaması.
- NotDefteri: macOS İçindekiler listesinin odak kaybında ve ekran görüntüsü alınırken kapanması.
- NotDefteri: Kod bloğunda boş Enter satırlarını koruma ve Ctrl+Enter ile açık çıkış.
- NotDefteri: Ekransız Linux testlerinde GTK başlatma sonucunu paylaşarak yanlış pencere oluşturmayı önleme.
- NotDefteri: Tema değişiminde metin/kod renklerinin güncellenmesi ve Türkçe arama normalizasyonuna uygun önbellek testi beklentileri.
