import Foundation

enum SayfaSablonu: String, CaseIterable {
    case toplanti = "Toplantı notu"
    case gunluk = "Günlük"
    case proje = "Proje"

    func markdown(tarih: Date = Date()) -> String {
        switch self {
        case .toplanti:
            return "# Toplantı notu\n\nTarih: \(gunlukSayfaAdi(tarih))\nKatılımcılar: \n\n## Gündem\n\n- \n\n## Kararlar\n\n- \n\n## Yapılacaklar\n\n- [ ] \n"
        case .gunluk:
            return "# \(gunlukSayfaAdi(tarih))\n\n## Bugünün planı\n\n- [ ] \n\n## Günün notları\n\n\n## Gün sonu\n\n"
        case .proje:
            return "# Proje\n\n## Amaç\n\n\n## Kapsam\n\n\n## Görevler\n\n- [ ] \n\n## Notlar\n\n"
        }
    }
}

func gunlukSayfaAdi(_ tarih: Date = Date()) -> String {
    let bicim = DateFormatter()
    bicim.locale = Locale(identifier: "en_US_POSIX")
    bicim.calendar = Calendar(identifier: .gregorian)
    bicim.dateFormat = "yyyy-MM-dd"
    return bicim.string(from: tarih)
}
