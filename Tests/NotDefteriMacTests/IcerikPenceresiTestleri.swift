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

    // MARK: İçerik penceresi: ana editörle aynı, düzenlenebilir

    private var kok: URL!
    private var oncekiKok: String?

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        kok = FileManager.default.temporaryDirectory.appendingPathComponent("icerik-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: kok, withIntermediateDirectories: true)
        oncekiKok = ProcessInfo.processInfo.environment["NOTDEFTERI_KOK"]
        setenv("NOTDEFTERI_KOK", kok.path, 1)
    }

    override func tearDown() {
        for pencere in NotPenceresi.icerikPencereleri { pencere.close() }
        if let oncekiKok { setenv("NOTDEFTERI_KOK", oncekiKok, 1) } else { unsetenv("NOTDEFTERI_KOK") }
        try? FileManager.default.removeItem(at: kok)
        super.tearDown()
    }

    private func sayfaYaz(_ ad: String, _ icerik: String) throws -> URL {
        let url = kok.appendingPathComponent(ad).appendingPathComponent(kIcerikDosyaAdi)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try icerik.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func diskten(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }

    private func sonunaYaz(_ pencere: NotPenceresi, _ metin: String) {
        let uzunluk = (pencere.metinGorunumu.string as NSString).length
        pencere.metinGorunumu.setSelectedRange(NSRange(location: uzunluk, length: 0))
        pencere.metinGorunumu.insertText(metin, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    func testIcerikPenceresiDuzenlenebilirVeTekKezAcilir() throws {
        let url = try sayfaYaz("Sayfa", "---\nyazi: kucuk\n---\n# Başlık\n\n- [ ] görev\n")

        let pencere = NotPenceresi.icerikPenceresiAc(url, yanindaki: nil)
        XCTAssertTrue(NotPenceresi.icerikPenceresiAc(url, yanindaki: nil) === pencere, "aynı sayfa ikinci kez açılmaz")
        XCTAssertTrue(pencere.icerikModu)
        XCTAssertTrue(pencere.metinGorunumu.isEditable)
        XCTAssertTrue(pencere.metinGorunumu.allowsUndo)
        XCTAssertTrue(pencere.kenarPaneli.isHidden, "yalnızca içerik: kenar panel kapalı")
        XCTAssertEqual(pencere.mevcutDosyaURL, url)
        XCTAssertEqual(markdownMetniUret(pencere.metinGorunumu.textStorage!), "# Başlık\n\n- [ ] görev\n",
                       "üstbilgi gösterilmez, içerik kayıpsız")
        XCTAssertEqual(pencere.metinGorunumu.belgeAdaptoru.olcek, 0.85, accuracy: 0.001, "küçük yazı uygulanır")
    }

    func testIcerikPenceresindeYazilanUstbilgiyleKaydedilir() throws {
        let url = try sayfaYaz("Sayfa", "---\nyazi: kucuk\n---\nilk\n")
        let pencere = NotPenceresi.icerikPenceresiAc(url, yanindaki: nil)

        sonunaYaz(pencere, "eklenen")
        XCTAssertTrue(pencere.kaydedici.duzenlendiMi)
        pencere.otomatikKaydet()

        XCTAssertFalse(pencere.kaydedici.duzenlendiMi)
        XCTAssertTrue(diskten(url).hasPrefix("---\nyazi: kucuk\n---\n"), "sayfa seçenekleri korunur")
        XCTAssertTrue(diskten(url).contains("ilk"))
        XCTAssertTrue(diskten(url).contains("eklenen"))
    }

    /// Aynı sayfa ana pencerede de açıkken biri kaydedince diğeri diskten yenilenir;
    /// sonraki kayıt öncekini ezmez.
    func testIkiPencereBirbirininKaydiniEzmez() throws {
        let url = try sayfaYaz("Ortak", "baş\n")
        // Ana pencere son açılan notu ayarlara yazar; gerçek ayar test sonrası geri konur.
        let oncekiNot = gAyarlar.string(forKey: "sonNotYolu")
        let ana = NotPenceresi()
        defer { ana.close(); gAyarlar.set(oncekiNot, forKey: "sonNotYolu") }
        ana.notuAc(url)
        let icerik = NotPenceresi.icerikPenceresiAc(url, yanindaki: ana)

        sonunaYaz(icerik, "içerikten")
        icerik.otomatikKaydet()
        XCTAssertTrue(ana.metinGorunumu.string.contains("içerikten"), "ana pencere kaydı duyup yenilenir")

        sonunaYaz(ana, " anadan")
        ana.otomatikKaydet()
        XCTAssertTrue(diskten(url).contains("içerikten"), "içerik penceresinin yazdığı korunur")
        XCTAssertTrue(diskten(url).contains("anadan"))
        XCTAssertTrue(icerik.metinGorunumu.string.contains("anadan"), "içerik penceresi de yenilenir")
    }

    func testKaydedilmemisDegisiklikDisktenEzilmez() throws {
        let url = try sayfaYaz("Sayfa", "ilk\n")
        let pencere = NotPenceresi.icerikPenceresiAc(url, yanindaki: nil)
        sonunaYaz(pencere, "yazılıyor")
        try "dışarıdan\n".write(to: url, atomically: true, encoding: .utf8)

        pencere.diskleEsitle()
        XCTAssertTrue(pencere.metinGorunumu.string.contains("yazılıyor"))
    }

    func testTasinanSayfaIcerikPenceresindeYeniYoluIzler() throws {
        let url = try sayfaYaz("Eski", "metin\n")
        let pencere = NotPenceresi.icerikPenceresiAc(url, yanindaki: nil)
        let eskiKlasor = url.deletingLastPathComponent()
        let yeniKlasor = kok.appendingPathComponent("Yeni")
        try FileManager.default.moveItem(at: eskiKlasor, to: yeniKlasor)
        let yeni = yeniKlasor.appendingPathComponent(kIcerikDosyaAdi)

        NotPenceresi.icerikPencereleriniTasi(eskiKlasor: eskiKlasor, yeniKlasor: yeniKlasor, eskiIcerik: url, yeniIcerik: yeni)
        XCTAssertEqual(pencere.mevcutDosyaURL, yeni)
        sonunaYaz(pencere, "sonra")
        pencere.otomatikKaydet()
        XCTAssertTrue(diskten(yeni).contains("sonra"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "eski yolda sayfa yeniden oluşmaz")
    }

    func testSilinenSayfaIcerikPenceresindeYenidenOlusmaz() throws {
        let url = try sayfaYaz("Silinen", "metin\n")
        let pencere = NotPenceresi.icerikPenceresiAc(url, yanindaki: nil)
        sonunaYaz(pencere, "geç")
        try FileManager.default.removeItem(at: url.deletingLastPathComponent())

        pencere.kayitHatasiBildirildi = true  // Testte modal uyarı açılmasın.
        XCTAssertFalse(pencere.kaydetURLe(url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        pencere.kaydedici.temizIsaretle()
    }
}
