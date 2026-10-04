import AppKit

/// Editörle aynı sözdizimini okur; HTML'e yalnızca kaçırılmış metin ve izinli bağlar girer.
func htmlKacir(_ metin: String) -> String {
    metin.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

func htmlGorseli(_ url: URL) throws -> String {
    // SVG gibi etkin içerik taşıyabilen kaynaklar da durağan PNG'ye çevrilir.
    guard let resim = NSImage(contentsOf: url), let tiff = resim.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let veri = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path])
    }
    // ponytail: büyük görseller de gömülür; boyut sınırı veya ayrı dosya yönetimi yok.
    return "data:image/png;base64," + veri.base64EncodedString()
}

func htmlUret(markdown: String, baslik: String, taban: URL) throws -> String {
    let sayfa = sayfaUstbilgisiniAyir(markdown)
    let metin = markdowndenAttributedStringUret(sayfa.govde, taban: taban)
    var govde = "<header><h1>\(htmlKacir(baslik))</h1></header>"
    let ns = metin.string as NSString
    var konum = 0
    while konum < metin.length {
        var aralik = ns.paragraphRange(for: NSRange(location: konum, length: 0))
        let o = metin.attributes(at: konum, effectiveRange: nil)
        if o[kKodBloguAnahtari] != nil {
            _ = metin.attribute(kKodBloguAnahtari, at: konum, longestEffectiveRange: &aralik,
                                in: NSRange(location: 0, length: metin.length))
        }
        var icerik = ""
        var hata: Error?
        metin.enumerateAttributes(in: aralik) { oznitelikler, alt, _ in
            guard oznitelikler[kBlokIsaretiAnahtari] as? Bool != true,
                  oznitelikler[kBosKodSatiriAnahtari] as? Bool != true else { return }
            if let ek = oznitelikler[.attachment] as? ResimEki, let url = ek.dosyaURL {
                // Notlar klasörü dışındaki görsel gömülmez (alt metin kaynakta tutulmadığından boş kalır).
                let kok = notlarKlasoru().standardizedFileURL.resolvingSymlinksInPath().path + "/"
                guard url.standardizedFileURL.resolvingSymlinksInPath().path.hasPrefix(kok) else { return }
                do {
                    icerik += "<img alt=\"\" style=\"width:\(Int(ek.gosterimBoyutu.width))px\" src=\"\(try htmlGorseli(url))\">"
                } catch { hata = error }
                return
            }
            var yazi = htmlKacir(ns.substring(with: alt))
            if o[kKodBloguAnahtari] == nil {
                let font = oznitelikler[.font] as? NSFont ?? varsayilanFont()
                if oznitelikler[kSatirIciKodAnahtari] as? Bool == true { yazi = "<code>\(yazi)</code>" }
                else {
                    if kalinMi(font) { yazi = "<strong>\(yazi)</strong>" }
                    if italikMi(font) { yazi = "<em>\(yazi)</em>" }
                    if oznitelikler[kUstuCiziliAnahtari] as? Bool == true { yazi = "<del>\(yazi)</del>" }
                    if oznitelikler[kVurguAnahtari] as? Bool == true { yazi = "<mark>\(yazi)</mark>" }
                }
                if oznitelikler[kSayfaBagiAnahtari] == nil,
                   let url = oznitelikler[.link] as? URL, disBaglantiGecerliMi(url) {
                    yazi = "<a href=\"\(htmlKacir(url.absoluteString))\">\(yazi)</a>"
                }
            }
            icerik += yazi
        }
        if let hata { throw hata }
        if o[kKodBloguAnahtari] != nil { govde += "<pre><code>\(icerik)</code></pre>" }
        else if let blok = o[kMetinBloguAnahtari] as? MetinBlogu {
            let girinti = "style=\"margin-left:\(blok.seviye * 24)px\""
            switch blok.tur {
            case .madde: govde += "<ul \(girinti)><li>\(icerik)</li></ul>"
            case .numarali: govde += "<ol start=\"\(blok.numara)\" \(girinti)><li>\(icerik)</li></ol>"
            case .yapilacak:
                govde += "<div class=gorev \(girinti)><input type=checkbox disabled \(blok.tamamlandi ? "checked" : "")> \(icerik)</div>"
            case .alinti: govde += "<blockquote \(girinti)>\(icerik)</blockquote>"
            case .ayirici: govde += "<hr>"
            case .uyari:
                let renk = ["gri": "128,128,128", "mavi": "40,120,220", "sarı": "230,180,20", "kırmızı": "220,60,60", "yeşil": "40,160,80"][blok.renk] ?? "128,128,128"
                govde += "<div class=uyari style=\"--renk:\(renk);margin-left:\(blok.seviye * 24)px\">\(blok.devam ? "" : htmlKacir(blok.emoji) + " ")\(icerik)</div>"
            }
        } else if let seviye = o[kBaslikSeviyesiAnahtari] as? Int {
            let h = min(6, max(1, seviye))
            govde += "<h\(h)>\(icerik)</h\(h)>"
        } else { govde += "<p>\(icerik.isEmpty ? "<br>" : icerik)</p>" }
        konum = NSMaxRange(aralik)
    }
    return """
    <!doctype html><html lang="tr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>\(htmlKacir(baslik))</title><style>
    :root{color-scheme:light dark;--zemin:#fff;--metin:#202124;--kod:#eef0f2;--bag:#1464b4}
    @media(prefers-color-scheme:dark){:root{--zemin:#202124;--metin:#eee;--kod:#303438;--bag:#8ab4f8}}
    body{max-width:760px;margin:40px auto;padding:0 24px;background:var(--zemin);color:var(--metin);font:16px/1.6 -apple-system,sans-serif;overflow-wrap:anywhere}
    img{max-width:100%;height:auto}
    p,.gorev,li,blockquote,.uyari{white-space:pre-wrap}ul,ol{margin-top:0;margin-bottom:0}
    a{color:var(--bag)}pre{overflow:auto;white-space:pre-wrap}code{background:var(--kod);padding:2px 4px;border-radius:3px}
    blockquote{border-left:3px solid #999;padding-left:16px}mark{background:#ffe68a;color:#222}
    .uyari{background:rgba(var(--renk),.14);border-left:4px solid rgb(var(--renk));padding:12px;border-radius:6px}
    @media print{:root{--zemin:#fff;--metin:#202124;--kod:#eef0f2;--bag:#1464b4}body{margin:0}}
    </style><body>\(govde)</body></html>
    """
}
