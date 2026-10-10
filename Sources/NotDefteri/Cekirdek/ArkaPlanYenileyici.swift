import Foundation

/// Ağır yenilemeleri tek kuyrukta çalıştırır; yalnızca son isteğin sonucu uygulanır.
/// Girdi ve sonuç, çağıranın değişen UI durumunu taşımayan bağımsız anlık görüntüler olmalı.
package final class ArkaPlanYenileyici<Girdi, Sonuc> {
    private let kuyruk = DispatchQueue(label: "NotDefteri.arkaPlanYenileme", qos: .userInitiated)
    private let kilit = NSLock()
    private var nesil: UInt64 = 0
    private let islem: (Girdi) -> Sonuc
    private let teslimiPlanla: (@escaping () -> Void) -> Void

    package init(is islem: @escaping (Girdi) -> Sonuc,
                 teslimiPlanla: @escaping (@escaping () -> Void) -> Void = { teslim in
                     DispatchQueue.main.async(execute: teslim)
                 }) {
        self.islem = islem
        self.teslimiPlanla = teslimiPlanla
    }

    /// Çağıran iş parçacığını bekletmez. Kuyrukta eskiyen işler taramaya başlamadan düşer.
    package func iste(_ girdi: Girdi, uygula: @escaping (Sonuc) -> Void) {
        let beklenen = sonrakiNesil()
        kuyruk.async { [weak self] in
            guard let self, self.guncelMi(beklenen) else { return }
            let sonuc = self.islem(girdi)
            self.teslimiPlanla { [weak self] in
                guard let self, self.guncelMi(beklenen) else { return }
                uygula(sonuc)
            }
        }
    }

    /// Aktif iş tamamlanabilir; sonucu ve henüz başlamayan istekler uygulanmaz.
    package func invalidate() {
        _ = sonrakiNesil()
    }

    private func sonrakiNesil() -> UInt64 {
        kilit.lock()
        defer { kilit.unlock() }
        nesil &+= 1
        return nesil
    }

    private func guncelMi(_ beklenen: UInt64) -> Bool {
        kilit.lock()
        defer { kilit.unlock() }
        return nesil == beklenen
    }
}
