import Foundation

/// Kaydedilmiş dosyanın sabit görüntüsü; Markdown baytları dışa aktarımda aynen korunur.
package struct MarkdownAktarimSayfasi {
    package let url: URL
    package let veri: Data
    package let markdown: String
}

package enum MarkdownDisaAktar {
    package static func oku(_ url: URL, kok: URL = notlarKlasoru()) throws -> MarkdownAktarimSayfasi {
        try notlarYolunuDogrula(url, kok: kok)
        let veri = try Data(contentsOf: url)
        guard let markdown = String(data: veri, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return MarkdownAktarimSayfasi(url: url, veri: veri, markdown: markdown)
    }

    /// HTML çağırıcısı da görsel dosyalarını okumadan önce aynı kaynak sınırını kullanır.
    package static func gorselKaynaklariniDogrula(_ sayfa: MarkdownAktarimSayfasi, kok: URL = notlarKlasoru()) throws {
        _ = try gorseller(sayfa, kok: kok)
    }

    /// Kullanıcı hedefi seçer. Codec kontrolü platformda kalır; yollar ve kopyalama çekirdektedir.
    package static func aktar(_ sayfa: MarkdownAktarimSayfasi, hedef: URL, kok: URL = notlarKlasoru(),
                              gorselDogrula: (URL) -> Bool = { _ in true }) throws {
        try notlarYolunuDogrula(sayfa.url, kok: kok)
        let taban = sayfaKlasoru(sayfa.url).standardizedFileURL.resolvingSymlinksInPath()
        let klasor = hedef.deletingLastPathComponent()
        guard klasor.standardizedFileURL.resolvingSymlinksInPath() != taban else {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSLocalizedDescriptionKey: "Kaynak sayfanın dışında bir klasör seçin."])
        }
        let kaynaklar = try gorseller(sayfa, kok: kok)
        try FileManager.default.createDirectory(at: try aktarimYolu(kGorsellerKlasorAdi, klasor: klasor), withIntermediateDirectories: true)
        var hata: Error?
        for gorsel in kaynaklar {
            do {
                try notlarYolunuDogrula(gorsel.kaynak, kok: kok)
                guard gorselDogrula(gorsel.kaynak) else { continue }
                try notlarYolunuDogrula(gorsel.kaynak, kok: kok)
                let veri = try Data(contentsOf: gorsel.kaynak)
                try gorseliKopyala(veri, hedef: aktarimYolu(gorsel.yol, klasor: klasor))
            } catch { hata = error }
        }
        if let hata { throw hata }
        // Seçilen klasörün dışına çıkan bir hedef symlink'i de yazılmaz.
        let dosya = try aktarimYolu(hedef.lastPathComponent, klasor: klasor)
        try sayfa.veri.write(to: dosya, options: .atomic)
    }

    private static func gorseller(_ sayfa: MarkdownAktarimSayfasi, kok: URL) throws -> [(yol: String, kaynak: URL)] {
        try notlarYolunuDogrula(sayfa.url, kok: kok)
        let belge = markdowndenAttributedStringUret(sayfaUstbilgisiniAyir(sayfa.markdown).govde, taban: sayfaKlasoru(sayfa.url))
        var sonuc: [(yol: String, kaynak: URL)] = []
        belge.enumerateAttribute(kGorselAnahtari, in: NSRange(location: 0, length: belge.length)) { deger, _, _ in
            guard let gorsel = deger as? [String: Any], let url = gorsel["dosyaURL"] as? URL,
                  let yol = gorsel["yol"] as? String else { return }
            sonuc.append((yol, url))
        }
        for gorsel in sonuc { try notlarYolunuDogrula(gorsel.kaynak, kok: kok) }
        return sonuc
    }

    private static func aktarimYolu(_ yol: String, klasor: URL) throws -> URL {
        let hedef = klasor.appendingPathComponent(yol).standardizedFileURL.resolvingSymlinksInPath()
        guard hedef.path.hasPrefix(klasor.standardizedFileURL.resolvingSymlinksInPath().path + "/") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return hedef
    }

    private static func gorseliKopyala(_ veri: Data, hedef: URL) throws {
        if dosyaYoluVarMi(hedef) {
            guard try Data(contentsOf: hedef) == veri else {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: hedef.path])
            }
            return
        }
        try FileManager.default.createDirectory(at: hedef.deletingLastPathComponent(), withIntermediateDirectories: true)
        try veri.write(to: hedef, options: .withoutOverwriting)
    }
}
