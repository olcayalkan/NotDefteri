import Foundation

/// Bekleyen tek atımlık zamanlayıcıyı iptal eder.
package typealias ZamanlayiciIptal = () -> Void

/// Linux girişi, çekirdeği kullanmadan önce bu iki işlemi GLib ana döngüsüne bağlar.
package enum Platform {
    package static var anaIsParcaciginda: (@escaping () -> Void) -> Void = { eylem in
        DispatchQueue.main.async(execute: eylem)
    }

    package static var zamanlayici: (TimeInterval, @escaping () -> Void) -> ZamanlayiciIptal = { aralik, eylem in
        let zamanlayici = Timer(timeInterval: aralik, repeats: false) { _ in eylem() }
        zamanlayici.tolerance = 1
        RunLoop.main.add(zamanlayici, forMode: .common)
        return { zamanlayici.invalidate() }
    }
}
