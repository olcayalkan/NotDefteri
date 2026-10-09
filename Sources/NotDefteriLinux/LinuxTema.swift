import CGtk
import Foundation
import NotDefteriCekirdek

/// macOS Tema.swift + bileşen renklerinin Linux karşılığı. Değerler macOS'takiyle birebir aynıdır:
/// tema RGB'leri, `koyulastir` miktarları (seçim 0.14, arama/düğme grupları 0.07, odak 0.16),
/// siyah metin, NSColor.darkGray başlık simgeleri, systemOrange sabitleme. Kağıt temaları hep açıktır.
final class LinuxTema {
    private typealias RGB = (r: Double, g: Double, b: Double)
    // Tema.swift ile aynı sıra ve RGB değerleri: Sepya, Yeşilimsi Kağıt, Gri Kağıt, Krem.
    private static let renkler: [(zemin: RGB, baslik: RGB, panel: RGB)] = [
        ((0.84, 0.81, 0.73), (0.78, 0.74, 0.65), (0.80, 0.77, 0.69)),
        ((0.79, 0.83, 0.76), (0.72, 0.77, 0.70), (0.75, 0.80, 0.73)),
        ((0.80, 0.80, 0.80), (0.73, 0.73, 0.73), (0.76, 0.76, 0.76)),
        ((0.86, 0.83, 0.76), (0.80, 0.76, 0.67), (0.82, 0.79, 0.71))
    ]
    /// `renkler` ile aynı sıra; Görünüm > Tema menüsü bunu listeler.
    static let adlar = ["Sepya", "Yeşilimsi Kağıt", "Gri Kağıt", "Krem"]
    private let display: OpaquePointer
    private let saglayici = gtk_css_provider_new()!

    init(display: OpaquePointer) {
        self.display = display
        gtk_style_context_add_provider_for_display(display, nd_style_provider(saglayici),
                                                   guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
        uygula()
    }

    deinit {
        gtk_style_context_remove_provider_for_display(display, nd_style_provider(saglayici))
        g_object_unref(UnsafeMutableRawPointer(saglayici))
    }

    /// macOS NSColor.koyulastir: her bileşenden `miktar` çıkarılır. Tamsayı 0–255 yazılır:
    /// GTK açılışta sistem yerel ayarını devreye alır, String(format:) Türkçe sistemde "84,0%"
    /// üretiyordu; geçersiz CSS rengi arka planı şeffaf bırakıyordu (Zorin OS).
    private static func css(_ c: RGB, koyulastir miktar: Double = 0) -> String {
        func y(_ d: Double) -> Int { Int((min(max(d - miktar, 0), 1) * 255).rounded()) }
        return "rgb(\(y(c.r)),\(y(c.g)),\(y(c.b)))"
    }

    func uygula() {
        if !Self.renkler.indices.contains(gTemaIndex) { gTemaIndex = 0 }
        let tema = Self.renkler[gTemaIndex]
        let css = """
        @define-color nd-zemin \(Self.css(tema.zemin));
        @define-color nd-baslik \(Self.css(tema.baslik));
        @define-color nd-panel \(Self.css(tema.panel));
        @define-color nd-grup \(Self.css(tema.panel, koyulastir: 0.07));
        @define-color nd-secim \(Self.css(tema.panel, koyulastir: 0.14));
        @define-color nd-odak \(Self.css(tema.panel, koyulastir: 0.16));
        @define-color nd-metin #000000;
        @define-color nd-koyu-gri #555555;

        window.notdefteri { background-color: @nd-zemin; color: @nd-metin; }
        .notdefteri label { color: inherit; }

        /* Başlık çubuğu: macOS BaslikCubugu — çerçevesiz, koyu gri simgeler, sabitlenince turuncu. */
        .notdefteri .nd-baslik { background-image: none; background-color: @nd-baslik; color: @nd-koyu-gri; box-shadow: none; }
        .notdefteri .nd-baslik button { background-image: none; background-color: transparent; box-shadow: none; border: none; color: @nd-koyu-gri; }
        .notdefteri .nd-baslik button:hover { background-color: alpha(black, 0.07); }
        .notdefteri .nd-baslik button:checked { background-color: transparent; color: #ff9500; }
        /* ☰ menü açıkken de :checked olur; turuncu yalnız sabitlemeye ait. */
        .notdefteri .nd-baslik menubutton button:checked { background-color: alpha(black, 0.07); color: @nd-koyu-gri; }

        /* Kenar panel: macOS KenarPaneli. */
        .notdefteri .nd-kenar-panel, .notdefteri .nd-kenar-panel listview { background-color: @nd-panel; color: @nd-metin; }
        .notdefteri .nd-kenar-panel listview row:selected, .notdefteri .nd-kenar-panel row:selected { background-color: alpha(@nd-secim, 0.35); color: @nd-metin; }
        .notdefteri .nd-kenar-panel image { color: alpha(black, 0.45); }
        .notdefteri .nd-kenar-panel expander title label { color: alpha(black, 0.5); font-weight: bold; font-size: 11px; }
        .notdefteri .nd-kenar-panel entry { background-image: none; background-color: @nd-grup; border: none; border-radius: 7px; box-shadow: none; outline: none; color: @nd-metin; }
        .notdefteri .nd-kenar-panel entry:focus-within { background-color: @nd-odak; }
        .notdefteri .nd-kenar-panel entry image { color: alpha(black, 0.65); }
        .notdefteri .nd-kenar-panel button.nd-duz-dugme { background-image: none; background-color: transparent; box-shadow: none; border: none; color: @nd-metin; }
        .notdefteri .nd-kenar-panel button.nd-duz-dugme:hover { background-color: alpha(black, 0.07); }
        .notdefteri .nd-kenar-panel button.nd-ana-sayfa label { font-weight: bold; font-size: 15px; }
        .notdefteri list { background-color: transparent; color: @nd-metin; }
        .notdefteri list row:selected { background-color: alpha(@nd-secim, 0.35); color: @nd-metin; }

        /* B1/B2/B3/Aa ve A−/punto/A+: macOS'taki gibi panelden koyu (0.07), köşeleri 7 px yuvarlak gruplar. */
        .notdefteri .nd-serit { background-color: @nd-grup; border-radius: 7px; padding: 2px; }
        .notdefteri .nd-serit button, .notdefteri .nd-serit label { background-image: none; background-color: transparent; box-shadow: none; border: none; color: @nd-koyu-gri; font-weight: bold; min-height: 24px; padding: 2px 4px; border-radius: 6px; }
        .notdefteri .nd-serit button:hover { background-color: alpha(black, 0.07); }
        .notdefteri .nd-serit button:active { background-color: alpha(black, 0.14); }
        .notdefteri .nd-serit label.dim-label { font-weight: normal; color: alpha(black, 0.6); opacity: 1; }
        .notdefteri .nd-serit:disabled button, .notdefteri .nd-serit:disabled label { color: alpha(black, 0.3); }

        /* Editör: siyah metin, macOS (aqua) seçim rengi. */
        .notdefteri .nd-editor, .notdefteri .nd-editor textview, .notdefteri .nd-editor textview text { background-color: @nd-zemin; color: @nd-metin; caret-color: @nd-metin; }
        .notdefteri textview text selection { background-color: #b3d7ff; color: @nd-metin; }
        /* Kod bloğu şeridi: çerçevenin üst kenarına oturan küçük etiket + Kopyala (macOS ile aynı ölçü). */
        .notdefteri .nd-kod-araci { background-color: @nd-zemin; border-radius: 4px; padding: 0 2px 0 6px; min-height: 0; }
        .notdefteri .nd-kod-araci label { font-family: monospace; font-size: 9.5px; color: alpha(black, 0.55); opacity: 1; }
        .notdefteri .nd-kod-araci button { background-image: none; background-color: transparent; box-shadow: none; border: none; min-height: 0; min-width: 0; padding: 0 4px; font-size: 10px; font-weight: 500; color: alpha(black, 0.7); }
        .notdefteri .nd-kod-araci button:hover { background-color: alpha(black, 0.07); }

        /* İçindekiler: macOS IcindekilerPaneli — çizgi siyah %30 (etkin %80), ad siyah %58 (etkin %90). */
        .notdefteri .nd-icindekiler { border-radius: 8px; }
        .notdefteri .nd-icindekiler.acik { background-color: alpha(@nd-panel, 0.95); box-shadow: 0 2px 8px alpha(black, 0.15); }
        .notdefteri .nd-icindekiler button { background-image: none; background-color: transparent; box-shadow: none; border: none; min-height: 0; padding: 3px 6px; color: alpha(black, 0.58); }
        .notdefteri .nd-icindekiler button:hover { background-color: alpha(black, 0.07); }
        .notdefteri .nd-icindekiler .nd-cizgi { background-color: alpha(black, 0.3); border-radius: 1px; }
        .notdefteri .nd-icindekiler button.nd-etkin { color: alpha(black, 0.9); font-weight: bold; }
        .notdefteri .nd-icindekiler button.nd-etkin .nd-cizgi { background-color: alpha(black, 0.8); }

        /* Yüzer paneller (seçim çubuğu, blok menüsü, bulucu, renk ve bağlam menüleri): macOS YuzerPanel
           gibi kenar panel renginde; düğmeler çerçevesiz. */
        .notdefteri popover > contents, .notdefteri popover > arrow { background-color: @nd-panel; color: @nd-metin; }
        .notdefteri popover button { background-image: none; background-color: transparent; box-shadow: none; border: none; color: @nd-metin; }
        .notdefteri popover button:hover, .notdefteri popover modelbutton:hover,
        .notdefteri popover modelbutton:focus, .notdefteri popover modelbutton:selected { background-color: alpha(black, 0.07); color: @nd-metin; }
        .notdefteri popover modelbutton arrow { color: alpha(black, 0.45); }
        .notdefteri popover entry { background-image: none; background-color: @nd-grup; border: none; box-shadow: none; outline: none; color: @nd-metin; }
        .notdefteri popover entry:focus-within { background-color: @nd-odak; box-shadow: none; outline: none; }
        .notdefteri popover list, .notdefteri popover row { background-color: transparent; color: @nd-metin; }

        /* Seçili menü/liste öğesi (blok menüsü, bulucu): mavi yerine kağıt tonu. */
        .notdefteri .nd-etkin { background-image: none; background-color: alpha(@nd-secim, 0.35); color: @nd-metin; font-weight: bold; }
        .notdefteri .nd-icindekiler button.nd-etkin { background-color: transparent; }
        """
        gtk_css_provider_load_from_data(saglayici, css, -1)
    }
}
