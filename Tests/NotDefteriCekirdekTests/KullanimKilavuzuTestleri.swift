import XCTest
@testable import NotDefteriCekirdek

final class KullanimKilavuzuTestleri: XCTestCase {
    private var kok: URL!

    override func setUpWithError() throws {
        kok = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kilavuz-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: kok, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: kok) }

    func testBosKokeKilavuzEklenirVeSonrakiAcilistaKorunur() throws {
        let url = try XCTUnwrap(ilkKullanimKilavuzunuHazirla(kok: kok))
        XCTAssertEqual(url.lastPathComponent, kIcerikDosyaAdi)
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, kKullanimKilavuzuSayfaAdi)
        XCTAssertTrue((try String(contentsOf: url, encoding: .utf8)).hasPrefix("# NOT DEFTERI KULLANIM KILAVUZU"))
        XCTAssertEqual(agaciYukle(kok).map(\.ad), [kKullanimKilavuzuSayfaAdi])

        try "Kullanıcının notu".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertNil(try ilkKullanimKilavuzunuHazirla(kok: kok))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "Kullanıcının notu")
    }

    func testMevcutNotlarinYaninaDokunmaz() throws {
        let mevcut = kok.appendingPathComponent("Mevcut", isDirectory: true)
        try FileManager.default.createDirectory(at: mevcut, withIntermediateDirectories: true)
        try "# Mevcut".write(to: mevcut.appendingPathComponent(kIcerikDosyaAdi), atomically: true, encoding: .utf8)

        XCTAssertNil(try ilkKullanimKilavuzunuHazirla(kok: kok))
        XCTAssertFalse(FileManager.default.fileExists(atPath: kok.appendingPathComponent(kKullanimKilavuzuSayfaAdi).path))
    }
}
