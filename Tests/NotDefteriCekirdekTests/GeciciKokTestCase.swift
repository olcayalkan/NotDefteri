import XCTest
@testable import NotDefteriCekirdek

/// Her test kendi geçici not kökünde çalışır. NOTDEFTERI_KOK da oraya ayarlanır:
/// varsayılan kökü (`notlarKlasoru()`) kullanan fonksiyonlar gerçek notlara dokunmasın,
/// kök dışı yol yüzünden hata/uyarı yoluna da düşmesin.
class GeciciKokTestCase: XCTestCase {

    var kok: URL!
    let fm = FileManager.default
    private var oncekiKok: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        kok = Self.tabanKlasor()
            .appendingPathComponent("notdefteri-test-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: kok, withIntermediateDirectories: true)
        oncekiKok = ProcessInfo.processInfo.environment["NOTDEFTERI_KOK"]
        setenv("NOTDEFTERI_KOK", kok.path, 1)
    }

    override func tearDownWithError() throws {
        if let oncekiKok { setenv("NOTDEFTERI_KOK", oncekiKok, 1) } else { unsetenv("NOTDEFTERI_KOK") }
        try? fm.removeItem(at: kok)
        try super.tearDownWithError()
    }

    /// macOS'ta geçici klasör /var -> /private/var bağının altında; dizin listelemesi yolları
    /// /private ile, kök ise /private'sız döndüğü için yol doğrulaması bunları kök dışı sayıyor
    /// (bkz. #12). Testler davranışı ölçsün diye bağsız bir kök kullanılır.
    private static func tabanKlasor() -> URL {
        #if os(macOS)
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #else
        return URL(fileURLWithPath: NSTemporaryDirectory())
        #endif
    }

    /// Yeni düzende sayfa kurar: `<yol>/index.md`. Dönen değer içerik dosyasıdır.
    @discardableResult
    func sayfaKur(_ yol: String, metin: String? = nil) throws -> URL {
        let klasor = kok.appendingPathComponent(yol, isDirectory: true)
        try fm.createDirectory(at: klasor, withIntermediateDirectories: true)
        let icerik = klasor.appendingPathComponent(kIcerikDosyaAdi)
        try (metin ?? "# \(klasor.lastPathComponent)\n").write(to: icerik, atomically: true, encoding: .utf8)
        return icerik
    }

    /// Eski düzende düz not kurar: `<yol>.md`.
    @discardableResult
    func duzNotKur(_ yol: String, metin: String? = nil) throws -> URL {
        let dosya = kok.appendingPathComponent(yol + ".md")
        try fm.createDirectory(at: dosya.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (metin ?? "# \(dosya.deletingPathExtension().lastPathComponent)\n")
            .write(to: dosya, atomically: true, encoding: .utf8)
        return dosya
    }

    func oku(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }

    func varMi(_ yol: String) -> Bool { fm.fileExists(atPath: kok.appendingPathComponent(yol).path) }

    /// Ağaçta ada göre düğüm (yalnızca verilen düzeyde).
    func dugum(_ ad: String, _ dugumler: [AgacDugumu]? = nil) throws -> AgacDugumu {
        try XCTUnwrap((dugumler ?? agaciYukle(kok)).first { $0.ad == ad }, "\(ad) ağaçta yok")
    }
}
