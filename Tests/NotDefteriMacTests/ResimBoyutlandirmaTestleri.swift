import XCTest
import AppKit
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

/// Görsel kenarlarından kırpılır (her kenar kendi tarafını keser), köşelerinden oranı
/// koruyarak boyutlandırılır.
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

    func testTutamacAlaniGorunenTutamactanGenis() {
        XCTAssertEqual(tut(110, 150), ResimTutamaci(yatay: -1, dikey: 0), "sol kenara 10 pt")
        XCTAssertEqual(tut(115, 65), ResimTutamaci(yatay: -1, dikey: -1), "sol üst köşeye 15 pt")
        XCTAssertNil(tut(113, 150), "kenardan 13 pt içerisi görselin kendisi")
    }

    func testKoseImleciYonGosterir() {
        for (yatay, dikey) in [(-1.0, -1.0), (1, -1), (-1, 1), (1, 1)] {
            XCTAssertNotEqual(ResimTutamaci(yatay: yatay, dikey: dikey).imlec, .crosshair)
        }
        XCTAssertEqual(ResimTutamaci(yatay: 1, dikey: 0).imlec, .resizeLeftRight)
        XCTAssertEqual(ResimTutamaci(yatay: 0, dikey: 1).imlec, .resizeUpDown)
    }

    private func kirp(_ yatay: CGFloat, _ dikey: CGFloat, _ fark: NSPoint, _ k: GorselKirpma = .tam) -> (NSSize, GorselKirpma) {
        ResimTutamaci(yatay: yatay, dikey: dikey).kirp(baslangic: cerceve.size, kirpma: k, fark: fark, enAz: enAz, enFazla: enFazla)
    }

    func testSolKenarSoldanKirpar() {
        let (boyut, k) = kirp(-1, 0, NSPoint(x: 60, y: 30))
        XCTAssertEqual(boyut, NSSize(width: 240, height: 200), "boy değişmez")
        XCTAssertEqual(k.x, 0.2, accuracy: 0.0001)
        XCTAssertEqual(k.w, 0.8, accuracy: 0.0001, "sağ kenar yerinde kalır")
        XCTAssertEqual(k.y, 0); XCTAssertEqual(k.h, 1)
    }

    func testSagKenarSagdanKirpar() {
        let (boyut, k) = kirp(1, 0, NSPoint(x: -75, y: 0))
        XCTAssertEqual(boyut.width, 225)
        XCTAssertEqual(k.x, 0); XCTAssertEqual(k.w, 0.75, accuracy: 0.0001)
    }

    func testUstVeAltKenarKendiTarafiniKirpar() {
        let (ust, ku) = kirp(0, -1, NSPoint(x: 0, y: 50))
        XCTAssertEqual(ust, NSSize(width: 300, height: 150))
        XCTAssertEqual(ku.y, 0.25, accuracy: 0.0001); XCTAssertEqual(ku.h, 0.75, accuracy: 0.0001)
        let (alt, ka) = kirp(0, 1, NSPoint(x: 0, y: -50))
        XCTAssertEqual(alt.height, 150)
        XCTAssertEqual(ka.y, 0); XCTAssertEqual(ka.h, 0.75, accuracy: 0.0001)
    }

    func testKirpilanGeriAcilirAmaGorseldenTasmaz() {
        let kirpik = GorselKirpma(x: 0.2, y: 0, w: 0.8, h: 1)   // 300 pt = kaynağın %80'i
        let (acik, k) = kirp(-1, 0, NSPoint(x: -500, y: 0), kirpik)
        XCTAssertEqual(acik.width, 375, "yalnızca kırpılan %20 açılır")
        XCTAssertEqual(k.x, 0, accuracy: 0.0001); XCTAssertEqual(k.w, 1, accuracy: 0.0001)
        let (sag, _) = kirp(1, 0, NSPoint(x: 100, y: 0), kirpik)
        XCTAssertEqual(sag.width, 300, "sağda kırpılmış kısım yok")
    }

    func testKoseOraniKoruyarakBuyutur() {
        let yatayCok = ResimTutamaci(yatay: 1, dikey: 1).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 150, y: 10), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(yatayCok, NSSize(width: 450, height: 300))
        let dikeyCok = ResimTutamaci(yatay: -1, dikey: -1).yeniBoyut(baslangic: cerceve.size, fark: NSPoint(x: 0, y: -100), enAz: enAz, enFazla: enFazla)
        XCTAssertEqual(dikeyCok, NSSize(width: 450, height: 300), "sol üst köşe yukarı çekilince büyür")
    }

    func testSinirlarAsilmaz() {
        let (dar, k) = kirp(1, 0, NSPoint(x: -1000, y: 0))
        XCTAssertEqual(dar.width, kEnKucukResimEni)
        XCTAssertTrue(k.gecerliMi)
        let (alcak, _) = kirp(0, 1, NSPoint(x: 0, y: -1000))
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

    func testKirpmaEkeTasinirVeKaydolur() throws {
        let klasor = FileManager.default.temporaryDirectory.appendingPathComponent("resim-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: klasor) }
        let gorsel = NSImage(size: NSSize(width: 40, height: 40), flipped: false) { _ in NSColor.red.setFill(); NSBezierPath.fill(NSRect(x: 0, y: 0, width: 40, height: 40)); return true }
        let veri = NSBitmapImageRep(data: gorsel.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try veri.write(to: klasor.appendingPathComponent("a.png"))
        let md = "![](a.png){240x300 kirp=0.2,0,0.8,1}\n"
        let belge = MacBelgeAdaptoru.markdownuAc(md, taban: klasor)
        let ek = try XCTUnwrap(belge.attribute(.attachment, at: 0, effectiveRange: nil) as? ResimEki)
        XCTAssertEqual(ek.kirpma, GorselKirpma(x: 0.2, y: 0, w: 0.8, h: 1))
        XCTAssertEqual(markdownMetniUret(belge), md)
    }
}
