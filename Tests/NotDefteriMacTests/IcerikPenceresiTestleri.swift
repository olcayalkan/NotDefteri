import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Kenar panelde iki tıklama yeniden adlandırır, üç tıklama sayfayı yalnızca içeriğiyle açar.
final class IcerikPenceresiTestleri: XCTestCase {

    func testAgacTiklamaSayisiniPaneleIletir() throws {
        _ = NSApplication.shared
        let agac = KenarAgaci(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        var gelen: [Int] = []
        agac.tiklamaGeldi = { sayi, _ in gelen.append(sayi); return true }
        for sayi in 1...3 {
            let olay = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: sayi, pressure: 1))
            agac.mouseDown(with: olay)
        }
        XCTAssertEqual(gelen, [1, 2, 3])
    }

    /// Çift tıklamanın ad düzenlemesi bekler; üçüncü ya da yeni tek tıklama onu iptal eder.
    func testUcuncuVeYeniTiklamaAdDuzenlemesiniIptalEder() {
        let panel = KenarPaneli(frame: .zero)
        for (sayi, iptal) in [(1, true), (2, false), (3, true)] {
            let bekleyen = DispatchWorkItem {}
            panel.bekleyenAdDuzenleme = bekleyen
            _ = panel.agacTiklandi(sayi, satir: -1)
            XCTAssertEqual(bekleyen.isCancelled, iptal, "tıklama \(sayi)")
        }
    }

    func testIcerikPenceresiSaltOkunurVeTekKezAcilir() throws {
        _ = NSApplication.shared
        let klasor = FileManager.default.temporaryDirectory.appendingPathComponent("icerik-\(UUID().uuidString)/Sayfa")
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: klasor.deletingLastPathComponent()) }
        let url = klasor.appendingPathComponent(kIcerikDosyaAdi)
        try "---\nyazi: kucuk\n---\n# Başlık\n\n- [ ] görev\n".write(to: url, atomically: true, encoding: .utf8)

        IcerikPenceresi.ac(url, yanindaki: nil)
        IcerikPenceresi.ac(url, yanindaki: nil)
        let pencereler = NSApp.windows.compactMap { $0 as? IcerikPenceresi }.filter { $0.sayfaURL == url }
        XCTAssertEqual(pencereler.count, 1)
        let pencere = try XCTUnwrap(pencereler.first)
        defer { pencere.close() }
        XCTAssertFalse(pencere.metinGorunumu.isEditable)
        XCTAssertEqual(pencere.titleVisibility, .hidden)
        XCTAssertEqual(markdownMetniUret(pencere.metinGorunumu.textStorage!), "# Başlık\n\n- [ ] görev\n",
                       "üstbilgi gösterilmez, içerik kayıpsız")
        XCTAssertEqual(pencere.metinGorunumu.belgeAdaptoru.olcek, 0.85, accuracy: 0.001, "küçük yazı uygulanır")
    }
}
