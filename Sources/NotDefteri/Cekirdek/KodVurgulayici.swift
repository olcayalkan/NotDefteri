import Foundation

package enum KodTokenTuru: Equatable { case anahtarKelime, metin, sayi, yorum, tur, fonksiyon, `operator` }

package func dilAdiniNormallestir(_ etiket: String) -> String? {
    switch etiket.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
    case "swift": return "swift"
    case "go", "golang": return "go"
    case "python", "py": return "python"
    case "javascript", "js": return "javascript"
    case "typescript", "ts": return "typescript"
    case "bash", "sh", "zsh", "shell": return "bash"
    case "json", "sql", "html", "css": return etiket.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    default: return nil
    }
}

// Her dilin birleşik deseni bir kez derlenir; string/yorum içindeki kelimeler tekrar eşleşmez.
private let kodDesenleri: [String: NSRegularExpression] = {
    let kelimeler = [
        "swift": "actor associatedtype async await break case catch class continue default defer deinit do else enum extension fallthrough false fileprivate for func guard if import in init inout internal is let nil nonisolated open operator private protocol public repeat rethrows return self Self some static struct subscript super switch throw throws true try typealias var weak where while",
        "go": "break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var true false nil iota",
        "python": "and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield",
        "javascript": "async await break case catch class const continue debugger default delete do else export extends false finally for from function if import in instanceof let new null of return static super switch this throw true try typeof undefined var void while with yield",
        "typescript": "abstract any as async await boolean break case catch class const continue declare default delete do else enum export extends false finally for from function if implements import in infer instanceof interface keyof let namespace never new null number of private protected public readonly return static string super switch this throw true try type typeof undefined unknown var void while yield",
        "bash": "if then else elif fi for while until do done case esac in function select time export local readonly declare return break continue shift source",
        "json": "true false null",
        "sql": "select from where join inner outer left right full on as insert into values update set delete create table index view drop alter add primary key foreign references constraint not null distinct group by order having limit offset union all and or in is like between exists case when then else end begin commit rollback asc desc count sum avg min max true false",
        "html": "html head body title meta link script style div span p a img ul ol li table tr td th form input button section header footer main nav class id href src",
        "css": "important inherit initial unset revert none auto block inline flex grid solid relative absolute fixed sticky",
        // Dil seçilmese bile kod bloğu düz metin gibi görünmesin. Ortak liste,
        // seçili bir dilin daha kesin kurallarını asla değiştirmez.
        "genel": "and as async await break case catch class const continue def default defer do else elseif elif enum export extends false finally for from func function guard if import in init interface let local nil null package private protected public return self static struct switch then this throw throws true try type var void while with yield"
    ]
    let cYorumu = #"/\*[\s\S]*?(?:\*/|\z)|//[^\r\n]*"#
    let tirnak = #""(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'"#
    var sonuc: [String: NSRegularExpression] = [:]
    for (dil, liste) in kelimeler {
        let yorum: String
        let metin: String
        switch dil {
        case "python":
            yorum = #"#[^\r\n]*"#
            metin = #""""[\s\S]*?(?:"""|\z)|'''[\s\S]*?(?:'''|\z)|"# + tirnak
        case "bash": yorum = #"#[^\r\n]*"#; metin = tirnak
        case "sql": yorum = #"/\*[\s\S]*?(?:\*/|\z)|--[^\r\n]*"#; metin = tirnak
        case "html": yorum = #"<!--[\s\S]*?(?:-->|\z)"#; metin = tirnak
        case "css": yorum = #"/\*[\s\S]*?(?:\*/|\z)"#; metin = tirnak
        case "json": yorum = #"(?!)"#; metin = #""(?:\\[\s\S]|[^"\\])*""#
        default:
            yorum = cYorumu
            metin = #""""[\s\S]*?(?:"""|\z)|`(?:\\[\s\S]|[^`\\])*`|"# + tirnak
        }
        let anahtarlar = liste.split(separator: " ").joined(separator: "|")
        let sayi = #"\b(?:0[xX][\da-fA-F_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)\b"#
        let tur = #"\b[A-Z][A-Za-z0-9_]*\b"#
        let fonksiyon = #"\b[A-Za-z_][A-Za-z0-9_]*(?=\s*\()"#
        let islec = #"===?|!==?|=>|->|<-|&&|\|\||\?\?|\.\.\.?|[+\-*/%<>!&|=?:]"#
        let desen = "(" + yorum + ")|(" + metin + ")|(" + sayi + ")|(\\b(?:" + anahtarlar
            + #")\b)|("# + tur + ")|(" + fonksiyon + ")|(" + islec + ")"
        sonuc[dil] = try! NSRegularExpression(pattern: desen, options: dil == "sql" ? [.caseInsensitive] : [])
    }
    return sonuc
}()

package func kodVurgula(_ kod: String, dil: String?) -> [(aralik: NSRange, tur: KodTokenTuru)] {
    // Boş ya da tanınmayan dil etiketi, düzenleme sırasında yararlı olan güvenli
    // genel renklendirmeyi alır. Kaydedilen Markdown dil etiketi değiştirilmez.
    let ad = dil.flatMap(dilAdiniNormallestir) ?? "genel"
    guard let desen = kodDesenleri[ad] else { return [] }
    let turler: [KodTokenTuru] = [.yorum, .metin, .sayi, .anahtarKelime, .tur, .fonksiyon, .operator]
    return desen.matches(in: kod, range: NSRange(location: 0, length: NSString(string: kod).length)).map { eslesme in
        let grup = (1...7).first { eslesme.range(at: $0).location != NSNotFound }!
        return (eslesme.range, turler[grup - 1])
    }
}
