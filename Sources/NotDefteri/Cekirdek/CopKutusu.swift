import Foundation

struct CopBilgisi: Codable {
    let ozgunYol: String
    let silinmeTarihi: Date
    /// nil: salt kapsayıcı, index.md: yeni düzen, diğer: eski düz not.
    let icerikDosyasi: String?
}

struct CopOgesi {
    let klasor: URL
    let bilgi: CopBilgisi
    var ad: String { (bilgi.ozgunYol as NSString).lastPathComponent }
    var icerikURL: URL? {
        guard let dosya = bilgi.icerikDosyasi else { return nil }
        return dosya == kIcerikDosyaAdi
            ? klasor.appendingPathComponent(ad).appendingPathComponent(dosya)
            : klasor.appendingPathComponent(dosya)
    }
}

/// Açılış temizliği ve kullanıcı işlemleri aynı kilidi paylaşır. UI içermez.
final class CopKutusu {
    private let kok: URL
    private let kilit = NSLock()
    private let fm = FileManager.default
    private var cop: URL { kok.appendingPathComponent(".cop", isDirectory: true) }
    private let bilgiAdi = ".cop-bilgi.json"

    init(kok: URL = notlarKlasoru()) { self.kok = kok.resolvingSymlinksInPath().standardizedFileURL }

    private func hata(_ mesaj: String) -> NSError {
        NSError(domain: "NotDefteri.CopKutusu", code: 1, userInfo: [NSLocalizedDescriptionKey: mesaj])
    }

    /// Mevcut her bileşen denetlenir; kopuk sembolik bağ da boş hedef sayılmaz.
    private func yoluDogrula(_ url: URL) throws {
        let yol = url.standardizedFileURL
        guard yol.path.hasPrefix(kok.path + "/") else { throw hata("Notlar klasörü dışındaki yol kullanılamaz.") }
        var parca = yol
        while parca.path != kok.path {
            if let tur = try? fm.attributesOfItem(atPath: parca.path)[.type] as? FileAttributeType,
               tur == .typeSymbolicLink { throw hata("Sembolik bağ içeren yol kullanılamaz: \(parca.path)") }
            parca.deleteLastPathComponent()
        }
        guard yol.resolvingSymlinksInPath().path.hasPrefix(kok.path + "/") else {
            throw hata("Yol notlar klasörünün dışına çıkıyor.")
        }
    }

    private func varMi(_ url: URL) -> Bool { (try? fm.attributesOfItem(atPath: url.path)) != nil }

    private func ogeyiDogrula(_ klasor: URL) throws {
        try yoluDogrula(klasor)
        guard klasor.standardizedFileURL.deletingLastPathComponent() == cop,
              !klasor.lastPathComponent.hasPrefix("."),
              (try klasor.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else {
            throw hata("Geçersiz çöp öğesi: \(klasor.path)")
        }
    }

    private func bilgiyiOku(_ klasor: URL) throws -> CopOgesi {
        try ogeyiDogrula(klasor)
        let url = klasor.appendingPathComponent(bilgiAdi)
        try yoluDogrula(url)
        let cozumleyici = JSONDecoder()
        cozumleyici.dateDecodingStrategy = .iso8601
        let bilgi = try cozumleyici.decode(CopBilgisi.self, from: Data(contentsOf: url))
        let parcalar = bilgi.ozgunYol.components(separatedBy: "/")
        let dosya = bilgi.icerikDosyasi as NSString?
        guard !parcalar.isEmpty, parcalar.allSatisfy({ !$0.isEmpty && !$0.hasPrefix(".") && !$0.contains("\0") }),
              dosya == nil || bilgi.icerikDosyasi == kIcerikDosyaAdi
                || (dosya?.deletingPathExtension == parcalar.last && dosya?.pathExtension.lowercased() == "md") else {
            throw hata("Çöp öğesinin özgün yolu geçersiz.")
        }
        return CopOgesi(klasor: klasor, bilgi: bilgi)
    }

    private func klasorleriOku() throws -> [URL] {
        try yoluDogrula(cop)
        guard varMi(cop) else { return [] }
        return try fm.contentsOfDirectory(at: cop, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
    }

    func ogeler() throws -> (ogeler: [CopOgesi], hatalar: [String]) {
        kilit.lock(); defer { kilit.unlock() }
        var ogeler: [CopOgesi] = []
        var hatalar: [String] = []
        for klasor in try klasorleriOku() {
            do {
                let oge = try bilgiyiOku(klasor)
                let dal = oge.klasor.appendingPathComponent(oge.ad)
                try yoluDogrula(dal)
                if let icerik = oge.icerikURL { try yoluDogrula(icerik) }
                if varMi(dal) || oge.icerikURL.map(varMi) == true { ogeler.append(oge) }
            } catch { hatalar.append("\(klasor.lastPathComponent): \(error.localizedDescription)") }
        }
        return (ogeler.sorted { $0.bilgi.silinmeTarihi > $1.bilgi.silinmeTarihi }, hatalar)
    }

    /// İkinci taşıma başarısızsa tamamlanan adımlar ters sırayla geri alınır.
    /// Geri alma da başarısızsa hiçbir dosya silinmez; kurtarma yolları hatada bildirilir.
    private func tasi(_ yollar: [(URL, URL)]) throws {
        var tasinan: [(URL, URL)] = []
        do {
            for (kaynak, hedef) in yollar {
                try yoluDogrula(kaynak)
                try yoluDogrula(hedef)
                try fm.moveItem(at: kaynak, to: hedef)
                tasinan.append((kaynak, hedef))
            }
        } catch {
            var mesaj = error.localizedDescription
            for (kaynak, hedef) in tasinan.reversed() {
                do {
                    try yoluDogrula(kaynak)
                    try yoluDogrula(hedef)
                    try fm.moveItem(at: hedef, to: kaynak)
                } catch { mesaj += "\nGeri taşıma başarısız: \(error.localizedDescription)\nKorunan dosyalar: \(hedef.path)" }
            }
            throw hata(mesaj)
        }
    }

    @discardableResult
    func sil(_ dugum: AgacDugumu) throws -> CopOgesi {
        kilit.lock(); defer { kilit.unlock() }
        let kaynak = dugum.klasorURL.standardizedFileURL
        try yoluDogrula(kaynak)
        let goreli = String(kaynak.path.dropFirst(kok.path.count + 1))
        guard goreli.components(separatedBy: "/").allSatisfy({ !$0.hasPrefix(".") }) else {
            throw hata("Gizli klasör çöp kutusuna taşınamaz.")
        }
        try yoluDogrula(cop)
        if !varMi(cop) { try fm.createDirectory(at: cop, withIntermediateDirectories: false) }
        let tarih = Date()
        let damga = String(Int64(tarih.timeIntervalSince1970 * 1000))
        var klasor = cop.appendingPathComponent("\(damga)-\(dugum.ad)")
        var sayac = 2
        while varMi(klasor) {
            klasor = cop.appendingPathComponent("\(damga)-\(dugum.ad)-\(sayac)")
            sayac += 1
        }
        try fm.createDirectory(at: klasor, withIntermediateDirectories: false)
        let bilgi = CopBilgisi(ozgunYol: goreli, silinmeTarihi: tarih, icerikDosyasi: dugum.icerikURL?.lastPathComponent)
        let kodlayici = JSONEncoder()
        kodlayici.dateEncodingStrategy = .iso8601
        try kodlayici.encode(bilgi).write(to: klasor.appendingPathComponent(bilgiAdi), options: .atomic)
        var yollar: [(URL, URL)] = []
        if let dosya = dugum.icerikURL, dosya.lastPathComponent != kIcerikDosyaAdi {
            yollar.append((dosya, klasor.appendingPathComponent(dosya.lastPathComponent)))
        }
        if dugum.icerikURL?.lastPathComponent == kIcerikDosyaAdi || dugum.icerikURL == nil || varMi(kaynak) {
            yollar.append((kaynak, klasor.appendingPathComponent(dugum.ad)))
        }
        try tasi(yollar)
        return CopOgesi(klasor: klasor, bilgi: bilgi)
    }

    @discardableResult
    func geriYukle(_ oge: CopOgesi) throws -> URL {
        kilit.lock(); defer { kilit.unlock() }
        let oge = try bilgiyiOku(oge.klasor)
        var hedef = kok.appendingPathComponent(oge.bilgi.ozgunYol)
        let ust = hedef.deletingLastPathComponent()
        let ustVar = (try? ust.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        func hedefDoluMu(_ url: URL) -> Bool {
            // Büyük/küçük harfe duyarlı disklerde ağacın tanıdığı tüm eski uzantılar çakışır.
            varMi(url) || ["md", "MD", "Md", "mD"].contains { varMi(url.appendingPathExtension($0)) }
        }
        if !ustVar || hedefDoluMu(hedef) {
            let ad = sayfaAdiGecerliMi(oge.ad) ? oge.ad : "Yeni Sayfa"
            hedef = kok.appendingPathComponent(ad)
            var sayac = 2
            while hedefDoluMu(hedef) {
                hedef = kok.appendingPathComponent("\(ad) (\(sayac))")
                sayac += 1
            }
        }
        try yoluDogrula(hedef)
        var yollar: [(URL, URL)] = []
        let eskiDuzen = oge.bilgi.icerikDosyasi.map { $0 != kIcerikDosyaAdi } ?? false
        let dosyaHedefi = hedef.appendingPathExtension((oge.bilgi.icerikDosyasi as NSString?)?.pathExtension ?? "md")
        if eskiDuzen, let dosya = oge.icerikURL, varMi(dosya) {
            yollar.append((dosya, dosyaHedefi))
        }
        let dal = oge.klasor.appendingPathComponent(oge.ad)
        if varMi(dal) { yollar.append((dal, hedef)) }
        guard !yollar.isEmpty else { throw hata("Bu öğe zaten geri yüklenmiş veya silinmiş.") }
        try tasi(yollar)
        // Boş zarfı da burada silmeyiz; kalıcı silme/yaş temizliği kaldırır.
        return eskiDuzen ? dosyaHedefi : hedef.appendingPathComponent(kIcerikDosyaAdi)
    }

    func kaliciSil(_ oge: CopOgesi) throws {
        kilit.lock(); defer { kilit.unlock() }
        try ogeyiDogrula(oge.klasor)
        try fm.removeItem(at: oge.klasor)
    }

    /// Bir bozuk öğe diğerlerinin temizliğini engellemez; hatalar UI katmanına döner.
    func temizle(eskiOlanlar: Bool) -> [String] {
        kilit.lock(); defer { kilit.unlock() }
        var hatalar: [String] = []
        do {
            let sinir = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            for klasor in try klasorleriOku() {
                do {
                    try ogeyiDogrula(klasor)
                    if eskiOlanlar, try bilgiyiOku(klasor).bilgi.silinmeTarihi >= sinir { continue }
                    try fm.removeItem(at: klasor)
                } catch { hatalar.append("\(klasor.lastPathComponent): \(error.localizedDescription)") }
            }
        } catch { hatalar.append(error.localizedDescription) }
        return hatalar
    }
}
