import XCTest
@testable import NotDefteriCekirdek

final class YenilemePerformansTestleri: XCTestCase {
    func testSentetikTaramaArkaPlandaCalisirVeAyniAgaciGetirir() throws {
        let kok = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: kok, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: kok) }
        for i in 0..<1000 {
            let sayfa = kok.appendingPathComponent("Sayfa-\(i)")
            try FileManager.default.createDirectory(at: sayfa, withIntermediateDirectories: true)
            try "# Sentetik not\n".write(to: sayfa.appendingPathComponent("index.md"), atomically: false, encoding: .utf8)
        }
        for tekrar in 1...3 {
            let bas = DispatchTime.now().uptimeNanoseconds
            let beklenen = agaciYukle(kok).map { $0.klasorURL.lastPathComponent }
            let eskiMs = Double(DispatchTime.now().uptimeNanoseconds - bas) / 1_000_000
            XCTAssertEqual(beklenen.count, 1000)
            let tamam = expectation(description: "Tarama teslimi")
            let yenileyici = ArkaPlanYenileyici<URL, [String]>(is: { kok in
                XCTAssertFalse(Thread.isMainThread, "Disk taraması UI iş parçacığında çalışmamalı")
                return agaciYukle(kok).map { $0.klasorURL.lastPathComponent }
            })
            let istekBas = DispatchTime.now().uptimeNanoseconds
            yenileyici.iste(kok) { sonuc in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(sonuc, beklenen)
                tamam.fulfill()
            }
            let istekMs = Double(DispatchTime.now().uptimeNanoseconds - istekBas) / 1_000_000
            wait(for: [tamam], timeout: 10)
            withExtendedLifetime(yenileyici) {}
            print("TREE_MEASUREMENT repeat=\(tekrar) notes=1000 synchronous_scan_ms=\(eskiMs) async_request_ms=\(istekMs)")
        }
    }
}
