import Foundation

/// Domain ve sunum katmanının gördüğü hata. `mesaj` kullanıcıya gösterilir.
package enum Basarisizlik: Error, Equatable {
    case dosya(String)

    package var mesaj: String {
        switch self { case .dosya(let mesaj): return mesaj }
    }
}
