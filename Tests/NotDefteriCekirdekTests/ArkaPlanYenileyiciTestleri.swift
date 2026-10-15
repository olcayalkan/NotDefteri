import XCTest
@testable import NotDefteriCekirdek

final class ArkaPlanYenileyiciTestleri: XCTestCase {
    private final class Teslimatlar {
        private let kilit = NSLock()
        private var bekleyen: [() -> Void] = []
        private let hazir = DispatchSemaphore(value: 0)

        func ekle(_ teslim: @escaping () -> Void) {
            kilit.lock()
            bekleyen.append(teslim)
            kilit.unlock()
            hazir.signal()
        }

        func sonraki() throws -> () -> Void {
            guard hazir.wait(timeout: .now() + 2) == .success else {
                XCTFail("Arka plan sonucu teslim kuyruğuna ulaşmadı")
                throw CocoaError(.coderValueNotFound)
            }
            kilit.lock()
            defer { kilit.unlock() }
            return bekleyen.removeFirst()
        }
    }

    func testIstekIsBitmesiniBeklemez() throws {
        let basladi = DispatchSemaphore(value: 0)
        let serbest = DispatchSemaphore(value: 0)
        let dondu = DispatchSemaphore(value: 0)
        let teslimatlar = Teslimatlar()
        let yenileyici = ArkaPlanYenileyici<Int, Int>(is: {
            basladi.signal()
            _ = serbest.wait(timeout: .now() + 2)
            return $0
        }, teslimiPlanla: teslimatlar.ekle)
        defer { serbest.signal() }
        let teslimEdildi = expectation(description: "Sonuç teslim edildi")
        DispatchQueue.global().async {
            yenileyici.iste(7) {
                XCTAssertEqual($0, 7)
                teslimEdildi.fulfill()
            }
            dondu.signal()
        }
        XCTAssertEqual(basladi.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(dondu.wait(timeout: .now() + 1), .success,
                       "İstek çağıran iş parçacığını tarama boyunca bekletmemeli")
        serbest.signal()
        try teslimatlar.sonraki()()
        wait(for: [teslimEdildi], timeout: 1)
    }

    func testSiradakiEskiIstekPahaliIsiCalistirmaz() throws {
        let basladi = DispatchSemaphore(value: 0)
        let serbest = DispatchSemaphore(value: 0)
        let teslimatlar = Teslimatlar()
        var calisanlar: [Int] = []
        let yenileyici = ArkaPlanYenileyici<Int, Int>(is: { girdi in
            calisanlar.append(girdi)
            if girdi == 1 {
                basladi.signal()
                _ = serbest.wait(timeout: .now() + 2)
            }
            return girdi
        }, teslimiPlanla: teslimatlar.ekle)
        defer { serbest.signal() }
        var uygulananlar: [Int] = []
        yenileyici.iste(1) { uygulananlar.append($0) }
        XCTAssertEqual(basladi.wait(timeout: .now() + 2), .success)
        yenileyici.iste(2) { uygulananlar.append($0) }
        yenileyici.iste(3) { uygulananlar.append($0) }
        serbest.signal()
        // Aktif iş de teslim edilebilir; nesil kontrolü uygulamada onu düşürür.
        try teslimatlar.sonraki()()
        try teslimatlar.sonraki()()
        XCTAssertEqual(calisanlar, [1, 3])
        XCTAssertEqual(uygulananlar, [3])
    }

    func testTeslimBeklerkenEskiyenSonucUygulanmaz() throws {
        let teslimatlar = Teslimatlar()
        let yenileyici = ArkaPlanYenileyici<Int, Int>(is: { $0 * 2 }, teslimiPlanla: teslimatlar.ekle)
        var uygulananlar: [Int] = []
        yenileyici.iste(1) { uygulananlar.append($0) }
        let eskiTeslim = try teslimatlar.sonraki()
        yenileyici.iste(2) { uygulananlar.append($0) }
        let yeniTeslim = try teslimatlar.sonraki()
        eskiTeslim()
        XCTAssertTrue(uygulananlar.isEmpty)
        yeniTeslim()
        XCTAssertEqual(uygulananlar, [4])
    }

    func testInvalidateBekleyenTeslimiDondururVeYeniIstekCalisir() throws {
        let teslimatlar = Teslimatlar()
        let yenileyici = ArkaPlanYenileyici<Int, Int>(is: { $0 }, teslimiPlanla: teslimatlar.ekle)
        var uygulananlar: [Int] = []
        yenileyici.iste(1) { uygulananlar.append($0) }
        let eskiTeslim = try teslimatlar.sonraki()
        yenileyici.invalidate()
        eskiTeslim()
        XCTAssertTrue(uygulananlar.isEmpty)
        yenileyici.iste(2) { uygulananlar.append($0) }
        try teslimatlar.sonraki()()
        XCTAssertEqual(uygulananlar, [2])
    }

    func testInvalidateAktifSonucuVeSiradakiIsiDondurur() throws {
        let basladi = DispatchSemaphore(value: 0)
        let serbest = DispatchSemaphore(value: 0)
        let teslimatlar = Teslimatlar()
        var calisanlar: [Int] = []
        let yenileyici = ArkaPlanYenileyici<Int, Int>(is: { girdi in
            calisanlar.append(girdi)
            if girdi == 1 {
                basladi.signal()
                _ = serbest.wait(timeout: .now() + 2)
            }
            return girdi
        }, teslimiPlanla: teslimatlar.ekle)
        defer { serbest.signal() }
        var uygulananlar: [Int] = []
        yenileyici.iste(1) { uygulananlar.append($0) }
        XCTAssertEqual(basladi.wait(timeout: .now() + 2), .success)
        yenileyici.iste(2) { uygulananlar.append($0) }
        yenileyici.invalidate()
        serbest.signal()
        try teslimatlar.sonraki()()
        yenileyici.iste(3) { uygulananlar.append($0) }
        try teslimatlar.sonraki()()
        XCTAssertEqual(calisanlar, [1, 3])
        XCTAssertEqual(uygulananlar, [3])
    }
}
