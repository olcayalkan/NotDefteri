import Foundation

/// Ham Markdown → `Sayfa` (frontmatter ayrıştırma).
extension Sayfa {
    package init(url: URL, ham: String) {
        let ayrik = sayfaUstbilgisiniAyir(ham)
        self.init(url: url, ham: ham, ustbilgi: ayrik.bilgi, govde: ayrik.govde)
    }
}
