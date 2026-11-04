import Foundation

// MARK: - Kod bloğunda yazım yardımı
//
// Kod bloğunda açılan parantez/tırnak kapanışıyla birlikte eklenir; satırda tek başına
// duran anahtar kelime (try, if, for…) Tab ile dilin kalıbına açılır. Platformdan
// bağımsızdır; editör yalnızca imlecin solundaki/sağındaki karakteri ve satırı verir.

/// Açılınca kapanışı da eklenen karakterler.
package let kKodEsleri: [Character: Character] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"]

package enum KodEsiEylemi: Equatable {
    /// "()" eklenir, imleç ortaya alınır.
    case ciftEkle(String)
    /// Seçili metin açılış ve kapanışla çevrelenir.
    case sarmala(acilis: String, kapanis: String)
    /// İmlecin sağındaki aynı kapanışın üstünden geçilir; ikinci bir ")" yazılmaz.
    case atla
}

/// Kod bloğunda tek karakterlik yazımın nasıl uygulanacağı; `nil` normal yazım demektir.
package func kodEsiEylemi(_ girdi: String, onceki: Character?, sonraki: Character?, secimVar: Bool) -> KodEsiEylemi? {
    guard girdi.count == 1, let karakter = girdi.first else { return nil }
    let tirnak = karakter == "\"" || karakter == "'"
    if !secimVar, sonraki == karakter, tirnak || [")", "]", "}"].contains(karakter) { return .atla }
    guard let kapanis = kKodEsleri[karakter] else { return nil }
    if secimVar { return .sarmala(acilis: String(karakter), kapanis: String(kapanis)) }
    // Kelimeye bitişik yazım eşlenmez: "don't" kesme işaretidir, "(x" mevcut ifadeyi sarar.
    if let sonraki, sonraki.isLetter || sonraki.isNumber { return nil }
    if tirnak, let onceki, onceki.isLetter || onceki.isNumber || onceki == "\\" { return nil }
    return .ciftEkle(String(karakter) + String(kapanis))
}

/// Boş eşin arasında geri silince ikisi birlikte gider: "(|)".
package func kodEsiBirlikteSilinirMi(onceki: Character?, sonraki: Character?) -> Bool {
    guard let onceki, let sonraki else { return false }
    return kKodEsleri[onceki] == sonraki
}

// MARK: - Anahtar kelime kalıpları

/// `‸` imlecin yeri, `⇥` bir girinti birimi. Etiketsiz/tanınmayan dil "genel"dir (C, Java, C# biçimi).
private let kKodKaliplari: [String: [String: String]] = [
    "swift": [
        "try": "do {\n⇥‸\n} catch {\n⇥print(error)\n}",
        "if": "if ‸ {\n⇥\n}",
        "else": "else {\n⇥‸\n}",
        "guard": "guard ‸ else {\n⇥return\n}",
        "for": "for item in ‸ {\n⇥\n}",
        "while": "while ‸ {\n⇥\n}",
        "repeat": "repeat {\n⇥‸\n} while ",
        "switch": "switch ‸ {\ncase :\n⇥break\ndefault:\n⇥break\n}",
        "func": "func ‸() {\n⇥\n}",
        "class": "class ‸ {\n⇥\n}",
        "struct": "struct ‸ {\n⇥\n}",
        "enum": "enum ‸ {\n⇥case \n}",
    ],
    "python": [
        "try": "try:\n⇥‸\nexcept Exception as e:\n⇥print(e)",
        "if": "if ‸:\n⇥pass",
        "elif": "elif ‸:\n⇥pass",
        "else": "else:\n⇥‸",
        "for": "for item in ‸:\n⇥pass",
        "while": "while ‸:\n⇥pass",
        "match": "match ‸:\n⇥case _:\n⇥⇥pass",
        "def": "def ‸():\n⇥pass",
        "class": "class ‸:\n⇥def __init__(self):\n⇥⇥pass",
        "with": "with ‸ as f:\n⇥pass",
    ],
    "javascript": [
        "try": "try {\n⇥‸\n} catch (error) {\n⇥console.error(error);\n}",
        "if": "if (‸) {\n⇥\n}",
        "else": "else {\n⇥‸\n}",
        "for": "for (let i = 0; i < ‸; i++) {\n⇥\n}",
        "while": "while (‸) {\n⇥\n}",
        "do": "do {\n⇥‸\n} while ();",
        "switch": "switch (‸) {\n⇥case :\n⇥⇥break;\n⇥default:\n⇥⇥break;\n}",
        "function": "function ‸() {\n⇥\n}",
        "class": "class ‸ {\n⇥constructor() {\n⇥⇥\n⇥}\n}",
    ],
    "go": [
        "try": "if err := ‸; err != nil {\n⇥return err\n}",
        "if": "if ‸ {\n⇥\n}",
        "else": "else {\n⇥‸\n}",
        "for": "for i := 0; i < ‸; i++ {\n⇥\n}",
        "while": "for ‸ {\n⇥\n}",
        "switch": "switch ‸ {\ncase :\n⇥\ndefault:\n⇥\n}",
        "func": "func ‸() {\n⇥\n}",
        "struct": "type ‸ struct {\n⇥\n}",
    ],
    "bash": [
        "try": "if ! ‸; then\n⇥echo \"Hata\" >&2\n⇥exit 1\nfi",
        "if": "if [ ‸ ]; then\n⇥\nfi",
        "else": "else\n⇥‸",
        "for": "for item in ‸; do\n⇥\ndone",
        "while": "while [ ‸ ]; do\n⇥\ndone",
        "case": "case ‸ in\n⇥*)\n⇥⇥;;\nesac",
        "function": "‸() {\n⇥\n}",
    ],
    "genel": [
        "try": "try {\n⇥‸\n} catch (Exception e) {\n⇥\n}",
        "if": "if (‸) {\n⇥\n}",
        "else": "else {\n⇥‸\n}",
        "for": "for (int i = 0; i < ‸; i++) {\n⇥\n}",
        "while": "while (‸) {\n⇥\n}",
        "do": "do {\n⇥‸\n} while ();",
        "switch": "switch (‸) {\n⇥case :\n⇥⇥break;\n⇥default:\n⇥⇥break;\n}",
        "function": "void ‸() {\n⇥\n}",
        "class": "class ‸ {\n⇥\n}",
    ],
]

/// Diller aynı yapıya farklı ad verir; kullanıcı alışık olduğu adı yazar ("def" → Swift'te func).
private let kKodKalibiEsAdlari: [[String]] = [
    ["func", "function", "def", "fn"], ["switch", "match", "case"], ["class", "struct"],
]

/// Satırda tek başına duran anahtar kelimenin kalıbı. `girinti` satırın kendi girintisidir,
/// sonraki satırlara eklenir; `birim` bir girinti düzeyidir (bloktaki yazımla aynı tutulur).
/// `imlec` dönen metindeki UTF-16 konumudur.
package func kodKalibi(_ kelime: String, dil: String?, girinti: String, birim: String) -> (metin: String, imlec: Int)? {
    let ad = dil.flatMap(dilAdiniNormallestir).map { $0 == "typescript" ? "javascript" : $0 } ?? "genel"
    guard let kaliplar = kKodKaliplari[ad] else { return nil }
    let adaylar = [kelime] + (kKodKalibiEsAdlari.first { $0.contains(kelime) } ?? [])
    guard let sablon = adaylar.lazy.compactMap({ kaliplar[$0] }).first else { return nil }
    let metin = sablon.replacingOccurrences(of: "⇥", with: birim).replacingOccurrences(of: "\n", with: "\n" + girinti)
    let imlec = (metin as NSString).range(of: "‸").location
    guard imlec != NSNotFound else { return nil }
    return (metin.replacingOccurrences(of: "‸", with: ""), imlec)
}
