import AppKit
import NotDefteriCekirdek
import UniformTypeIdentifiers

// MARK: - NotPenceresi: Eğik çizgi komutları, başlıklar, geri al/yinele

extension NotPenceresi {

    // MARK: Eğik çizgi komutları (/1 /2 /3 /page) ve başlıklar

    /// Eski /0 düz metin komutu korunur; diğer kısayollar blok menüsündedir.
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard !metinGorunumu.blokDuzenleniyor,
              let replacementString, replacementString == " " || replacementString == "\n",
              let ns = textView.textStorage?.mutableString else { return true }
        let satir = ns.paragraphRange(for: NSRange(location: affectedCharRange.location, length: 0))
        let aralik = NSRange(location: satir.location, length: affectedCharRange.location - satir.location)
        guard ns.substring(with: aralik).trimmingCharacters(in: .whitespaces) == "/0",
              metinGorunumu.typingAttributes[kKodBloguAnahtari] == nil,
              metinGorunumu.typingAttributes[kSatirIciKodAnahtari] == nil else { return true }
        DispatchQueue.main.async { [weak self] in
            self?.metinGorunumu.baslikUygula(0, komutAraligi: aralik, tamamlayici: replacementString)
            self?.puntoGostergesiniGuncelle()
        }
        return false
    }

    /// İmlecin bulunduğu paragrafı başlığa çevirir; seviye 0 normal metne döndürür.
    func baslikSeviyesiUygula(_ seviye: Int) {
        metinGorunumu.baslikUygula(seviye)
        puntoGostergesiniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    /// "/page": açık sayfanın altına yeni bir sayfa oluşturup açar.
    private func altSayfaKomutu() {
        // Sayfanın altına dal açabilmek için önce kendisinin diskte olması gerekir.
        if mevcutDosyaURL == nil {
            kaydedici.degisiklikIsaretle()
            otomatikKaydet()
        }
        guard let ustSayfa = mevcutDosyaURL else {
            // Henüz hiç içeriği olmayan, kaydedilmemiş bir sayfadayız: yeni sayfayı
            // kardeş olarak oluştur, komut sessizce kaybolmasın.
            yeniSayfaOlustur(klasor: kenarPaneli.hedefKlasor())
            return
        }
        yeniSayfaOlustur(klasor: sayfaKlasoru(ustSayfa))
    }

    func blokMenusuKomutunuCalistir(_ komut: BlokMenusu.Komut, aralik: NSRange) {
        makeFirstResponder(metinGorunumu)
        switch komut {
        case .uyari, .uyariGri, .uyariMavi, .uyariSari, .uyariKirmizi, .uyariYesil:
            let renk = [BlokMenusu.Komut.uyariGri: "gri", .uyariMavi: "mavi", .uyariSari: "sarı",
                        .uyariKirmizi: "kırmızı", .uyariYesil: "yeşil"][komut] ?? "sarı"
            if metinGorunumu.blok(metinGorunumu.paragrafAraligi())?.tur == .uyari {
                metinGorunumu.undoManager?.beginUndoGrouping()
                metinGorunumu.blokDuzenle(aralik, yeni: NSAttributedString(),
                                          secim: NSRange(location: aralik.location, length: 0),
                                          yazim: metinGorunumu.typingAttributes)
                metinGorunumu.uyariKutusuDegistir(renk: renk)
                metinGorunumu.undoManager?.endUndoGrouping()
            } else {
                metinGorunumu.menuBlogunuUygula(MetinBlogu(tur: .uyari, renk: renk, uyariKimligi: UUID().uuidString), komutAraligi: aralik)
            }
        case .baslik1, .baslik2, .baslik3:
            metinGorunumu.baslikUygula(komut.rawValue + 1, komutAraligi: aralik)
        case .madde, .numarali, .yapilacak, .alinti, .ayirici:
            let tur: MetinBlogu.Tur
            switch komut {
            case .madde: tur = .madde
            case .numarali: tur = .numarali
            case .yapilacak: tur = .yapilacak
            case .alinti: tur = .alinti
            default: tur = .ayirici
            }
            metinGorunumu.menuBlogunuUygula(MetinBlogu(tur: tur), komutAraligi: aralik)
        case .kod:
            metinGorunumu.kodDilSeciminiBaslat(aralik)
        case .tablo:
            tabloEklemePenceresiniAc(aralik)
        case .sayfa, .gorsel:
            guard metinGorunumu.textStorage != nil else { return }
            metinGorunumu.blokDuzenle(aralik, yeni: NSAttributedString(),
                                      secim: NSRange(location: aralik.location, length: 0),
                                      yazim: metinGorunumu.typingAttributes)
            if komut == .sayfa { altSayfaKomutu() }
            else {
                let secici = NSOpenPanel()
                secici.allowedContentTypes = [.image]
                secici.allowsMultipleSelection = false
                secici.canChooseDirectories = false
                secici.beginSheetModal(for: self) { [weak self] sonuc in
                    guard let self, sonuc == .OK, let url = secici.url,
                          let gorsel = NSImage(contentsOf: url),
                          let ek = self.gorseliDiskeYaz(gorsel, bolumBasligi: nil) else { return }
                    self.metinGorunumu.ekiEkle(ek)
                }
            }
        }
        puntoGostergesiniGuncelle()
    }

    private func tabloEklemePenceresiniAc(_ aralik: NSRange) {
        let (uyari, satir, sutun) = tabloBoyutUyarisi()
        uyari.beginSheetModal(for: self) { [weak self] sonuc in
            guard let self, sonuc == .alertFirstButtonReturn,
                  let satirSayisi = tabloBoyutu(satir.stringValue, kTabloEnAzSatir...kTabloEnCokSatir),
                  let sutunSayisi = tabloBoyutu(sutun.stringValue, kTabloEnAzSutun...kTabloEnCokSutun),
                  let markdown = tabloMarkdownUret(satir: satirSayisi, sutun: sutunSayisi) else {
                return
            }
            guard let depo = self.metinGorunumu.textStorage, NSMaxRange(aralik) <= depo.length,
                  (depo.string as NSString).substring(with: aralik).hasPrefix("/") else { return }
            let taban = self.mevcutDosyaURL.map(sayfaKlasoru) ?? notlarKlasoru()
            let yeni = self.metinGorunumu.belgeAdaptoru.gorunumluBelge(markdowndenAttributedStringUret(markdown, taban: taban))
            // Tablo düz Markdown olarak eklenir; ilk başlık seçilir ki yazınca adlandırılsın.
            let ilk = (markdown as NSString).range(of: "Başlık 1")
            self.metinGorunumu.blokDuzenle(aralik, yeni: yeni,
                                           secim: NSRange(location: aralik.location + ilk.location, length: ilk.length),
                                           yazim: self.metinGorunumu.typingAttributes)
            self.puntoGostergesiniGuncelle()
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        // true, AppKit'in varsayılan açma yolunu da durdurur.
        if let url = (link as? URL) ?? URL(string: String(describing: link)), disBaglantiGecerliMi(url) {
            NSWorkspace.shared.open(url)
        }
        return true
    }

    // MARK: Geri al / Yinele

    @objc func geriAlKomutu(_ sender: Any?) { geriAl() }
    @objc func ileriAlKomutu(_ sender: Any?) { ileriAl() }

    @objc func bulKomutu(_ sender: NSMenuItem) {
        metinGorunumu.yuzerGorunumleriGizle()
        // Bul alanı odaktayken de aynı editörün yerel bulucusuna gider.
        if sender.tag == NSTextFinder.Action.showFindInterface.rawValue || sender.tag == NSTextFinder.Action.showReplaceInterface.rawValue {
            makeFirstResponder(metinGorunumu)
        }
        metinGorunumu.performFindPanelAction(sender)
    }

    func geriAl() {
        guard let yonetici = metinGorunumu.undoManager, yonetici.canUndo else { return }
        yonetici.undo()
        geriAlmaSonrasi()
    }

    func ileriAl() {
        guard let yonetici = metinGorunumu.undoManager, yonetici.canRedo else { return }
        yonetici.redo()
        geriAlmaSonrasi()
    }

    /// Geri/ileri alma metni değiştirir; kaydı ve göstergeleri tazeler, odağı metne verir.
    private func geriAlmaSonrasi() {
        icerikDegisti()
        gecmisDugmeleriniGuncelle()
        puntoGostergesiniGuncelle()
        makeFirstResponder(metinGorunumu)
    }

    func gecmisDugmeleriniGuncelle() {
        baslikCubugu.gecmisDurumunuGoster(geriAlinabilir: anaSayfa.isHidden && (metinGorunumu.undoManager?.canUndo ?? false),
                                           ileriAlinabilir: anaSayfa.isHidden && (metinGorunumu.undoManager?.canRedo ?? false))
    }

    /// Başka bir not açılırken geçmişi temizler; aksi halde ⌘Z önceki notun
    /// içeriğini şu anki notun üzerine geri getirebilir.
    func gecmisiSifirla() {
        metinGorunumu.yuzerGorunumleriGizle()
        metinGorunumu.bagTamamlamaAraligi = nil
        metinGorunumu.kapatilanBagKonumu = nil
        metinGorunumu.slashAraligi = nil
        metinGorunumu.kapatilanSlashKonumu = nil
        metinGorunumu.undoManager?.removeAllActions()
        gecmisDugmeleriniGuncelle()
    }
}

// MARK: - Tablo boyutu sorusu

/// `/tablo` boyut penceresi. NSAlert aksesuarı otomatik yerleşimle boyutlanmaz:
/// çerçevesi sıfır kalan yığın görünümünde alanlar 0×0 olur, tıklanamaz ve yazı
/// almaz. Izgara kendi ölçüsüyle kurulur, ilk odak satır alanına verilir.
func tabloBoyutUyarisi() -> (uyari: NSAlert, satir: NSTextField, sutun: NSTextField) {
    let uyari = NSAlert()
    uyari.messageText = "Tablo ekle"
    uyari.informativeText = "Satır sayısına başlık satırı dahildir. Satır \(kTabloEnAzSatir)–\(kTabloEnCokSatir), "
        + "sütun \(kTabloEnAzSutun)–\(kTabloEnCokSutun) arasında olabilir."
    uyari.addButton(withTitle: "Ekle")
    uyari.addButton(withTitle: "Vazgeç")
    let satir = NSTextField(string: "3")
    let sutun = NSTextField(string: "3")
    for alan in [satir, sutun] {
        alan.alignment = .right
        alan.widthAnchor.constraint(equalToConstant: 64).isActive = true
    }
    satir.nextKeyView = sutun
    sutun.nextKeyView = satir
    let izgara = NSGridView(views: [[NSTextField(labelWithString: "Satır (başlık dahil)"), satir],
                                    [NSTextField(labelWithString: "Sütun"), sutun]])
    izgara.rowSpacing = 8
    izgara.columnSpacing = 12
    izgara.rowAlignment = .firstBaseline
    izgara.column(at: 0).xPlacement = .trailing
    izgara.frame = NSRect(origin: .zero, size: izgara.fittingSize)
    uyari.accessoryView = izgara
    uyari.window.initialFirstResponder = satir
    return (uyari, satir, sutun)
}

/// Sayı olmayan girdi tablo eklemez; sınır dışı sayı en yakın geçerli boyuta çekilir
/// (sınırlar pencerede yazılıdır).
func tabloBoyutu(_ metin: String, _ sinir: ClosedRange<Int>) -> Int? {
    Int(metin.trimmingCharacters(in: .whitespaces)).map { min(max($0, sinir.lowerBound), sinir.upperBound) }
}
