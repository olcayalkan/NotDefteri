import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Görsel kenarlarından ve köşelerinden boyutlandırılır: sol/sağ eni, üst/alt boyu uzatır;
/// köşeler oranı koruyarak bütün görseli büyütür.
final class ResimBoyutlandirmaTestleri: XCTestCase {

    private let cerceve = NSRect(x: 100, y: 50, width: 300, height: 200)   // ters çevrili: minY üst
    private let enAz = NSSize(width: kEnKucukResimEni, height: kEnKucukResimBoyu)
    private let enFazla = NSSize(width: 700, height: kEnBuyukResimBoyutu)

    private func tut(_ x: CGFloat, _ y: CGFloat) -> ResimTutamaci? {
        ResimEkiHucresi().tutamac(noktada: NSPoint(x: x, y: y), cerceve: cerceve)
    }

    func testKenarlarVeKoselerBulunur() {
        XCTAssertEqual(tut(102, 150), ResimTutamaci(yatay: -1, dikey: 0), "sol kenar")
        XCTAssertEqual(tut(398, 150), ResimTutamaci(yatay: 1, dikey: 0), "sağ kenar")
        XCTAssertEqual(tut(250, 52), ResimTutamaci(yatay: 0, dikey: -1), "üst kenar")
        XCTAssertEqual(tut(250, 248), ResimTutamaci(yatay: 0, dikey: 1), "alt kenar")
        XCTAssertEqual(tut(120, 70), nil, "ortası tutamaç değil")
        XCTAssertEqual(tut(103, 53), ResimTutamaci(yatay: -1, dikey: -1), "sol üst köşe")
        XCTAssertEqual(tut(396, 246), ResimTutamaci(yatay: 1, dikey: 1), "sağ alt köşe")
        XCTAssertEqual(tut(106, 150)?.koseMi, false, "kenarın ortası köşe sayılmaz")
        XCTAssertEqual(tut(250, 150), nil)
        XCTAssertEqual(tut(50, 150), nil, "görselin dışı")
    }

    func testSagKenarYalnizEniUzatir() {
        let yeni = ResimTutamaci(yatay: 1, dikey: 0).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 60, y: 40), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(yeni, NSSize(width: 360, height: 200))
    }

    func testSolKenarSolaCekilinceUzar() {
        let yeni = ResimTutamaci(yatay: -1, dikey: 0).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: -50, y: 0), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(yeni, NSSize(width: 350, height: 200))
    }

    func testUstKenarYukariCekilinceYalnizBoyUzar() {
        let yeni = ResimTutamaci(yatay: 0, dikey: -1).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 30, y: -80), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(yeni, NSSize(width: 300, height: 280))
    }

    func testAltKenarAsagiCekilinceYalnizBoyUzar() {
        let yeni = ResimTutamaci(yatay: 0, dikey: 1).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 0, y: 50), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(yeni, NSSize(width: 300, height: 250))
    }

    func testKoseOraniKoruyarakBuyutur() {
        let yatayCok = ResimTutamaci(yatay: 1, dikey: 1).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 150, y: 10), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(yatayCok, NSSize(width: 450, height: 300))
        let dikeyCok = ResimTutamaci(yatay: -1, dikey: -1).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 0, y: -100), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(dikeyCok, NSSize(width: 450, height: 300), "sol üst köşe yukarı çekilince büyür")
    }

    func testSinirlarAsilmaz() {
        let dar = ResimTutamaci(yatay: 1, dikey: 0).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: -1000, y: 0), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(dar.width, kEnKucukResimEni)
        let alcak = ResimTutamaci(yatay: 0, dikey: 1).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 0, y: -1000), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(alcak.height, kEnKucukResimBoyu)
        let genis = ResimTutamaci(yatay: 1, dikey: 1).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 5000, y: 0), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(genis, NSSize(width: 700, height: 467), "köşe en fazla genişlikte oranı koruyarak durur")
    }

    /// Kenardan uzatılmış görsel satıra sığdırılırken uzatılmış oranını korur.
    func testSigdirmaGosterilenOraniKorur() {
        let hucre = ResimEkiHucresi()
        hucre.enBoyOrani = 1   // doğal oran kare
        hucre.gosterimBoyutu = NSSize(width: 800, height: 200)
        let kare = hucre.cellFrame(for: NSTextContainer(), proposedLineFragment: NSRect(x: 0, y: 0, width: 400, height: 20),
                                   glyphPosition: .zero, characterIndex: 0)
        XCTAssertEqual(kare.size, NSSize(width: 400, height: 100))
    }

    /// Farklı en/boy Markdown'a yazılır ve aynen geri okunur.
    func testUzatilmisBoyutKaydolur() throws {
        let klasor = FileManager.default.temporaryDirectory.appendingPathComponent("resim-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: klasor) }
        let gorsel = NSImage(size: NSSize(width: 40, height: 40), flipped: false) { _ in NSColor.red.setFill(); NSBezierPath.fill(NSRect(x: 0, y: 0, width: 40, height: 40)); return true }
        let veri = NSBitmapImageRep(data: gorsel.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try veri.write(to: klasor.appendingPathComponent("a.png"))
        let md = "![](a.png){320x90}\n"
        let belge = MacBelgeAdaptoru.markdownuAc(md, taban: klasor)
        let ek = try XCTUnwrap(belge.attribute(.attachment, at: 0, effectiveRange: nil) as? ResimEki)
        XCTAssertEqual(ek.gosterimBoyutu, NSSize(width: 320, height: 90))
        XCTAssertEqual(markdownMetniUret(belge), md)
    }
}
