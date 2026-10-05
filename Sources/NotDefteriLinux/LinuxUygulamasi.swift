import CGtk
import Foundation
import NotDefteriCekirdek

protocol LinuxEditorProtokolu: AnyObject {
    func notuAc(_ url: URL)
}

package enum LinuxUygulamasi {
    package static func calistir() -> Int32 {
        GtkKoprusu.platformuKur()
        guard let uygulama = gtk_application_new("com.notdefteri.uygulama", GApplicationFlags(rawValue: 0)) else {
            FileHandle.standardError.write(Data("GTK uygulaması oluşturulamadı.\n".utf8))
            return 1
        }
        defer { g_object_unref(UnsafeMutableRawPointer(uygulama)) }
        var pencere: LinuxPencere?
        GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(uygulama), "activate") {
            if let mevcut = pencere {
                gtk_window_present(nd_window(mevcut.pencere))
                return
            }
            let yeni = LinuxPencere(uygulama: uygulama)
            pencere = yeni
            let editor = LinuxEditor(pencere: yeni)
            let panel = LinuxKenarPaneli(pencere: yeni)
            yeni.editor = editor
            yeni.kenarPaneli = panel
            panel.tasinmadanOnce = { [weak editor] in editor?.simdiKaydet() ?? false }
            panel.kaydetmedenDevam = { [weak editor] devam in editor?.kaydetmedenDevam(devam) }
            panel.notSilindi = { [weak editor] _ in editor?.bosalt() }
            panel.notYenidenAdlandirildi = { [weak editor] eski, yeni in editor?.yolDegisti(eski: eski, yeni: yeni) }
            editor.notSecimiBildir = { [weak panel] in panel?.acikNotuBildir($0) }
            editor.notKaydedildi = { [weak panel] url, metin in panel?.notIceriginiGuncelle(url, metin: metin) }
            LinuxEklentiler.kur(pencere: yeni, editor: editor)
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(yeni.pencere), "destroy") { pencere = nil }
            gtk_window_present(nd_window(yeni.pencere))
        }
        return g_application_run(nd_application(uygulama), CommandLine.argc, CommandLine.unsafeArgv)
    }
}
