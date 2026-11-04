/// Tüm kullanım senaryolarının temel arayüzü: tek iş, tek giriş noktası (`usecase(girdi)`).
package protocol UseCase {
    associatedtype Girdi
    associatedtype Cikti
    func callAsFunction(_ girdi: Girdi) -> Cikti
}
