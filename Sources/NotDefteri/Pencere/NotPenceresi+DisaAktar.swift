import AppKit
import NotDefteriCekirdek
import UniformTypeIdentifiers

extension NotPenceresi {
    /// Bekleyen düzenlemeyi mevcut kayıt yoluyla tamamlar; çıktı diskten okunur.
    private func aktarilacakSayfa() throws -> MarkdownAktarimSayfasi? {
        guard anaSayfa.isHidden else { return nil }
        otomatikKayitBekleyeniIptalEt()
        if let url = mevcutDosyaURL {
            guard kaydetURLe(url, panelYenile: false) else { return nil }
        } else {
            let url = benzersizDosyaURL(taban: otomatikBaslikUret(icerik: metinGorunumu.string))
            guard kaydetURLe(url) else { return nil }
        }
        guard let url = mevcutDosyaURL else { return nil }
        return try MarkdownDisaAktar.oku(url)
    }

    private func aktarimHatasiniBildir(_ hata: Error) {
        let uyari = NSAlert()
        uyari.alertStyle = .critical
        uyari.messageText = "Sayfa dışa aktarılamadı"
        uyari.informativeText = hata.localizedDescription
        uyari.runModal()
    }

    private func aktarimHedefi(ad: String, uzanti: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "\(uzanti.uppercased()) olarak kaydet"
        panel.nameFieldStringValue = ad + "." + uzanti
        panel.allowedContentTypes = [UTType(filenameExtension: uzanti) ?? .plainText]
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    @objc func markdownOlarakKopyala(_ sender: Any?) {
        do {
            guard let sayfa = try aktarilacakSayfa() else { return }
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(sayfa.markdown, forType: .string) else { throw CocoaError(.fileWriteUnknown) }
        } catch { aktarimHatasiniBildir(error) }
    }

    @objc func disaAktarHTML(_ sender: Any?) {
        do {
            guard let sayfa = try aktarilacakSayfa(),
                  let hedef = aktarimHedefi(ad: sayfaAdi(sayfa.url), uzanti: "html") else { return }
            try MarkdownDisaAktar.gorselKaynaklariniDogrula(sayfa)
            let html = try MacBelgeAdaptoru.htmlGorselleriniUyarla(
                htmlUret(markdown: sayfa.markdown, baslik: sayfaAdi(sayfa.url), taban: sayfaKlasoru(sayfa.url)))
            try html.write(to: hedef, atomically: true, encoding: .utf8)
        } catch { aktarimHatasiniBildir(error) }
    }

    @objc func disaAktarMarkdown(_ sender: Any?) {
        do {
            guard let sayfa = try aktarilacakSayfa(),
                  let hedef = aktarimHedefi(ad: sayfaAdi(sayfa.url), uzanti: "md") else { return }
            try MarkdownDisaAktar.aktar(sayfa, hedef: hedef, gorselDogrula: { NSImage(contentsOf: $0) != nil })
        } catch { aktarimHatasiniBildir(error) }
    }

    @objc func disaAktarPDF(_ sender: Any?) {
        do {
            guard let sayfa = try aktarilacakSayfa(),
                  let hedef = aktarimHedefi(ad: sayfaAdi(sayfa.url), uzanti: "pdf") else { return }
            let bilgi = NSPrintInfo.shared.copy() as! NSPrintInfo
            bilgi.orientation = .portrait
            bilgi.paperSize = NSSize(width: 595.28, height: 841.89)
            bilgi.topMargin = 40; bilgi.bottomMargin = 40
            bilgi.leftMargin = 40; bilgi.rightMargin = 40
            bilgi.horizontalPagination = .fit
            bilgi.verticalPagination = .automatic
            bilgi.isHorizontallyCentered = false
            bilgi.isVerticallyCentered = false
            bilgi.jobDisposition = .save
            bilgi.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = hedef
            let genislik = bilgi.paperSize.width - bilgi.leftMargin - bilgi.rightMargin
            let baski = NotMetinGorunumu(frame: NSRect(x: 0, y: 0, width: genislik, height: 1))
            baski.appearance = NSAppearance(named: .aqua)
            baski.isEditable = false; baski.isSelectable = false
            baski.drawsBackground = true; baski.backgroundColor = .white
            baski.textContainerInset = NSSize(width: 0, height: 8)
            baski.isVerticallyResizable = true
            baski.textContainer?.widthTracksTextView = false
            baski.textContainer?.size = NSSize(width: genislik, height: .greatestFiniteMagnitude)
            let metin = NSMutableAttributedString()
            metin.append(NSAttributedString(string: sayfaAdi(sayfa.url) + "\n\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 26)]))
            let govde = NSMutableAttributedString(attributedString: metinGorunumu.attributedString())
            // Eki kopyalamak canlı editörün görsel boyutunu ve tutamaçlarını değiştirmez.
            govde.enumerateAttribute(.attachment, in: NSRange(location: 0, length: govde.length)) { deger, aralik, _ in
                guard let ek = deger as? ResimEki, let resim = (ek.attachmentCell as? NSTextAttachmentCell)?.image else { return }
                let oran = min(1, (genislik - 10) / max(1, ek.gosterimBoyutu.width), 600 / max(1, ek.gosterimBoyutu.height))
                let gorsel = NSMutableAttributedString(attributedString: baskiGorseli(resim,
                    boyut: NSSize(width: ek.gosterimBoyutu.width * oran, height: ek.gosterimBoyutu.height * oran)))
                var o = govde.attributes(at: aralik.location, effectiveRange: nil)
                o.removeValue(forKey: .attachment)
                gorsel.addAttributes(o, range: NSRange(location: 0, length: gorsel.length))
                govde.replaceCharacters(in: aralik, with: gorsel)
            }
            metin.append(govde)
            let tumu = NSRange(location: 0, length: metin.length)
            metin.addAttribute(.foregroundColor, value: NSColor.black, range: tumu)
            metin.enumerateAttributes(in: tumu) { o, aralik, _ in
                if o[kVurguAnahtari] as? Bool == true { metin.addAttribute(.backgroundColor, value: NSColor(calibratedRed: 1, green: 0.9, blue: 0.55, alpha: 1), range: aralik) }
                else if o[kKodBloguAnahtari] != nil || o[kSatirIciKodAnahtari] as? Bool == true {
                    metin.addAttribute(.backgroundColor, value: NSColor(white: 0.94, alpha: 1), range: aralik)
                } else { metin.removeAttribute(.backgroundColor, range: aralik) }
            }
            baski.textStorage?.setAttributedString(metin)
            if let kap = baski.textContainer, let yerlesim = baski.layoutManager {
                yerlesim.ensureLayout(for: kap)
                baski.setFrameSize(NSSize(width: genislik, height: max(1, yerlesim.usedRect(for: kap).height + 16)))
            }
            let islem = NSPrintOperation(view: baski, printInfo: bilgi)
            islem.showsPrintPanel = false
            islem.showsProgressPanel = true
            guard islem.run() else { throw CocoaError(.fileWriteUnknown) }
        } catch { aktarimHatasiniBildir(error) }
    }

    private func baskiGorseli(_ resim: NSImage, boyut: NSSize) -> NSAttributedString {
        let kopya = resim.copy() as! NSImage
        kopya.size = boyut
        let ek = NSTextAttachment()
        ek.attachmentCell = NSTextAttachmentCell(imageCell: kopya)
        return NSAttributedString(attachment: ek)
    }
}
