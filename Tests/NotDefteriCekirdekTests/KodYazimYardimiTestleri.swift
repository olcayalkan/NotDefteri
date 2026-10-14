import XCTest
@testable import NotDefteriCekirdek

final class KodYazimYardimiTestleri: XCTestCase {

    // MARK: Eşli karakterler

    func testAcilisKapanisiylaEklenir() {
        for (acilis, cift) in [("(", "()"), ("[", "[]"), ("{", "{}"), ("\"", "\"\""), ("'", "''")] {
            XCTAssertEqual(kodEsiEylemi(acilis, onceki: " ", sonraki: nil, secimVar: false), .ciftEkle(cift), acilis)
        }
    }

    func testAyniKapanisUstundenGecilir() {
        for karakter in [")", "]", "}", "\"", "'"] {
            XCTAssertEqual(kodEsiEylemi(karakter, onceki: "x", sonraki: Character(karakter), secimVar: false), .atla)
        }
        XCTAssertNil(kodEsiEylemi(")", onceki: "x", sonraki: nil, secimVar: false))
    }

    func testKelimeyeBitisikYazimEslenmez() {
        XCTAssertNil(kodEsiEylemi("'", onceki: "n", sonraki: "t", secimVar: false), "don't")
        XCTAssertNil(kodEsiEylemi("'", onceki: "n", sonraki: nil, secimVar: false))
        XCTAssertNil(kodEsiEylemi("\"", onceki: "\\", sonraki: nil, secimVar: false))
        XCTAssertNil(kodEsiEylemi("(", onceki: " ", sonraki: "x", secimVar: false))
        XCTAssertEqual(kodEsiEylemi("(", onceki: "f", sonraki: ")", secimVar: false), .ciftEkle("()"))
    }

    func testSecimSarmalanir() {
        XCTAssertEqual(kodEsiEylemi("[", onceki: nil, sonraki: "a", secimVar: true), .sarmala(acilis: "[", kapanis: "]"))
        XCTAssertNil(kodEsiEylemi("a", onceki: nil, sonraki: nil, secimVar: true))
        XCTAssertNil(kodEsiEylemi("()", onceki: nil, sonraki: nil, secimVar: false))
    }

    func testBosEsBirlikteSilinir() {
        XCTAssertTrue(kodEsiBirlikteSilinirMi(onceki: "(", sonraki: ")"))
        XCTAssertTrue(kodEsiBirlikteSilinirMi(onceki: "\"", sonraki: "\""))
        XCTAssertFalse(kodEsiBirlikteSilinirMi(onceki: "(", sonraki: "]"))
        XCTAssertFalse(kodEsiBirlikteSilinirMi(onceki: nil, sonraki: ")"))
    }

    // MARK: Kalıplar

    private func imlecli(_ kalip: (metin: String, imlec: Int)?) -> String? {
        guard let kalip else { return nil }
        let ns = NSMutableString(string: kalip.metin)
        ns.insert("‸", at: kalip.imlec)
        return ns as String
    }

    func testTryHerDildeKendiYapisinaAcilir() {
        XCTAssertEqual(imlecli(kodKalibi("try", dil: "swift", girinti: "", birim: "    ")),
                       "do {\n    ‸\n} catch {\n    print(error)\n}")
        XCTAssertEqual(imlecli(kodKalibi("try", dil: "py", girinti: "", birim: "    ")),
                       "try:\n    ‸\nexcept Exception as e:\n    print(e)")
        XCTAssertEqual(imlecli(kodKalibi("try", dil: "ts", girinti: "", birim: "\t")),
                       "try {\n\t‸\n} catch (error) {\n\tconsole.error(error);\n}")
        XCTAssertEqual(imlecli(kodKalibi("try", dil: "", girinti: "", birim: "\t")),
                       "try {\n\t‸\n} catch (Exception e) {\n\t\n}")
        XCTAssertEqual(imlecli(kodKalibi("try", dil: "java", girinti: "", birim: "\t")),
                       "try {\n\t‸\n} catch (Exception e) {\n\t\n}")
    }

    func testTemelYapilarVarVeImlecIcinde() {
        let kelimeler = ["try", "if", "else", "for", "while", "switch", "func", "class"]
        for dil in ["swift", "python", "javascript", "go", "bash", ""] {
            for kelime in kelimeler {
                guard let kalip = kodKalibi(kelime, dil: dil, girinti: "", birim: "    ") else {
                    if !(dil == "bash" && kelime == "class") { XCTFail("\(dil) \(kelime)") }
                    continue
                }
                XCTAssertFalse(kalip.metin.contains("‸") || kalip.metin.contains("⇥"), "\(dil) \(kelime)")
                XCTAssertLessThanOrEqual(kalip.imlec, (kalip.metin as NSString).length)
            }
        }
    }

    func testEsAdlarDilinYapisinaGider() {
        XCTAssertEqual(imlecli(kodKalibi("def", dil: "swift", girinti: "", birim: "    ")), "func ‸() {\n    \n}")
        XCTAssertEqual(imlecli(kodKalibi("function", dil: "python", girinti: "", birim: "    ")), "def ‸():\n    pass")
        XCTAssertEqual(imlecli(kodKalibi("switch", dil: "bash", girinti: "", birim: "  ")), "case ‸ in\n  *)\n    ;;\nesac")
        XCTAssertEqual(imlecli(kodKalibi("while", dil: "go", girinti: "", birim: "\t")), "for ‸ {\n\t\n}")
    }

    func testGirintiSonrakiSatirlaraEklenir() {
        XCTAssertEqual(imlecli(kodKalibi("if", dil: "javascript", girinti: "    ", birim: "    ")),
                       "if (‸) {\n        \n    }")
    }

    func testBilinmeyenKelimeVeVeriDiliAcilmaz() {
        XCTAssertNil(kodKalibi("print", dil: "swift", girinti: "", birim: "    "))
        XCTAssertNil(kodKalibi("if", dil: "json", girinti: "", birim: "    "))
        XCTAssertNil(kodKalibi("if", dil: "sql", girinti: "", birim: "    "))
    }
}
