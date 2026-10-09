import Foundation
import XCTest
@testable import NotDefteriCekirdek

final class TemaAyarlariTestleri: XCTestCase {
    private func depoyla(_ eylem: (UserDefaults) -> Void) {
        let ad = "NotDefteri.tema-test.\(UUID().uuidString)"
        let depo = UserDefaults(suiteName: ad)!
        defer { depo.removePersistentDomain(forName: ad) }
        eylem(depo)
    }

    func testEskiTemalarYalnizcaBirKezTasinir() {
        for (eski, yeni) in [(0, 0), (1, 2), (2, 3), (3, 4)] {
            depoyla { depo in
                depo.set(eski, forKey: "temaIndex")
                XCTAssertEqual(temaSeciminiYukle(depo), yeni)
                XCTAssertEqual(temaSeciminiYukle(depo), yeni)
                XCTAssertEqual(depo.integer(forKey: "temaDuzeniSurumu"), 2)
            }
        }
    }

    func testTerminalSecimiYenidenAcilistaKorunur() {
        depoyla { depo in
            depo.set(2, forKey: "temaDuzeniSurumu")
            depo.set(1, forKey: "temaIndex")
            XCTAssertEqual(temaSeciminiYukle(depo), 1)
        }
    }

    func testGecersizIndekslerTasmaz() {
        for surum in [0, 2] {
            for indeks in [Int.min, -1, 5, Int.max] {
                depoyla { depo in
                    depo.set(surum, forKey: "temaDuzeniSurumu")
                    depo.set(indeks, forKey: "temaIndex")
                    XCTAssertEqual(temaSeciminiYukle(depo), 0)
                }
            }
        }
    }
}
