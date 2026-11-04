import Foundation

/// Diskten okunan sayfa: ham Markdown, ayrıştırılmış üstbilgi ve gövde.
package struct Sayfa: Equatable {
    package let url: URL
    /// Dosyanın baytları aynen; kaydedici "değişmedi" kararını buna göre verir.
    package let ham: String
    package let ustbilgi: SayfaUstbilgisi
    package let govde: String
}
