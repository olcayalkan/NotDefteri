import AppKit

// MARK: - KenarPaneli: NSOutlineView veri kaynağı ve delegesi

extension KenarPaneli {

    // MARK: Ağaç veri kaynağı

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        cocuklar(item).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        cocuklar(item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // Sadece alt sayfası olan düğümde açma oku çıkar.
        !((item as? AgacDugumu)?.cocuklar.isEmpty ?? true)
    }

    private func cocuklar(_ item: Any?) -> [AgacDugumu] {
        guard let dugum = item as? AgacDugumu else { return kokDugumler }
        return dugum.cocuklar
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let kimlik = NSUserInterfaceItemIdentifier("NotSatiri")
        if let yenidenKullan = outlineView.makeView(withIdentifier: kimlik, owner: self) as? NotSatirGorunumu {
            return yenidenKullan
        }
        let satir = NotSatirGorunumu()
        satir.identifier = kimlik
        return satir
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let dugum = item as? AgacDugumu else { return nil }
        let kimlik = NSUserInterfaceItemIdentifier("NotHucresi")
        let hucre: NSTableCellView
        if let yenidenKullan = outlineView.makeView(withIdentifier: kimlik, owner: self) as? NSTableCellView {
            hucre = yenidenKullan
        } else {
            hucre = NSTableCellView()
            hucre.identifier = kimlik

            let ikon = NSImageView()
            ikon.imageScaling = .scaleProportionallyDown
            ikon.translatesAutoresizingMaskIntoConstraints = false
            hucre.addSubview(ikon)
            hucre.imageView = ikon

            let etiket = NSTextField(labelWithString: "")
            etiket.font = NSFont.systemFont(ofSize: 12.5)
            etiket.textColor = .darkGray
            etiket.lineBreakMode = .byTruncatingTail
            etiket.translatesAutoresizingMaskIntoConstraints = false
            hucre.addSubview(etiket)
            hucre.textField = etiket

            NSLayoutConstraint.activate([
                ikon.leadingAnchor.constraint(equalTo: hucre.leadingAnchor, constant: 2),
                ikon.centerYAnchor.constraint(equalTo: hucre.centerYAnchor),
                ikon.widthAnchor.constraint(equalToConstant: 14),
                ikon.heightAnchor.constraint(equalToConstant: 14),
                etiket.leadingAnchor.constraint(equalTo: ikon.trailingAnchor, constant: 5),
                etiket.trailingAnchor.constraint(equalTo: hucre.trailingAnchor, constant: -6),
                etiket.centerYAnchor.constraint(equalTo: hucre.centerYAnchor)
            ])
        }
        // Alt sayfası olan sayfa dolu, olmayan boş belge simgesiyle gösterilir.
        let sembol: String
        if !dugum.sayfaMi {
            sembol = "folder"
        } else {
            sembol = dugum.cocuklar.isEmpty ? "doc.text" : "doc.on.doc"
        }
        hucre.imageView?.image = renklendirilmisSembol(sembol,
                                                        renk: NSColor.black.withAlphaComponent(dugum.sayfaMi ? 0.45 : 0.6),
                                                        boyut: 12)
        hucre.textField?.stringValue = dugum.ad
        hucre.textField?.font = NSFont.systemFont(ofSize: 12.5, weight: dugum.sayfaMi ? .regular : .medium)
        return hucre
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !programatikSecimYapiliyor else { return }
        guard let dugum = tablo.item(atRow: tablo.selectedRow) as? AgacDugumu,
              let icerik = dugum.icerikURL else { return }
        acikNotURL = icerik
        notSecildi?(icerik)
    }

    /// Çift tıklamak adı satırın üzerinde düzenlemeye açar (Finder gibi).
    @objc func cifteTiklandi() {
        let satir = tablo.clickedRow
        guard satir >= 0, let dugum = tablo.item(atRow: satir) as? AgacDugumu else { return }
        adiYerindeDuzenle(dugum: dugum, satir: satir)
    }

    func adiYerindeDuzenle(dugum: AgacDugumu, satir: Int) {
        guard let hucre = tablo.view(atColumn: 0, row: satir, makeIfNecessary: true) as? NSTableCellView,
              let alan = hucre.textField else { return }
        duzenlenenDugum = dugum
        adDuzenlemesiIptal = false
        alan.isEditable = true
        alan.isSelectable = true
        alan.isBordered = true
        alan.drawsBackground = true
        alan.backgroundColor = .textBackgroundColor
        alan.textColor = .textColor
        alan.focusRingType = .default
        alan.delegate = self
        alan.stringValue = dugum.ad
        window?.makeFirstResponder(alan)
        alan.currentEditor()?.selectAll(nil)
    }

    func adDuzenlemesiniBitir(_ alan: NSTextField) {
        alan.isEditable = false
        alan.isSelectable = false
        alan.isBordered = false
        alan.drawsBackground = false
        alan.textColor = .darkGray
        guard let dugum = duzenlenenDugum else { return }
        duzenlenenDugum = nil

        let yeniAd = alan.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        guard !adDuzenlemesiIptal, !yeniAd.isEmpty, yeniAd != dugum.ad else {
            alan.stringValue = dugum.ad   // Vazgeçildi: eski adı geri yaz.
            return
        }
        adiDegistir(dugum, yeniAd: yeniAd)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let dugum = notification.userInfo?["NSObject"] as? AgacDugumu else { return }
        acikKlasorYollari.insert(dugum.cocuklarKlasoru.path)
        acikKlasorleriKaydet()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let dugum = notification.userInfo?["NSObject"] as? AgacDugumu else { return }
        acikKlasorYollari.remove(dugum.cocuklarKlasoru.path)
        acikKlasorleriKaydet()
    }
}
