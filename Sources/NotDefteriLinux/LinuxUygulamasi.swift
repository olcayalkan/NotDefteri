import CGtk
import Foundation
import NotDefteriCekirdek

package enum LinuxUygulamasi {
    package static func calistir() -> Int32 {
        GtkKoprusu.platformuKur()
        // XFCE gibi masaüstlerinin GTK3 temaları GTK4'te renk değişkenlerini tanımlamıyor: açılışta
        // "Theme parser error" basılıyor ve renkler bozuluyordu. Tema GTK açılmadan seçilmeli;
        // kullanıcı GTK_THEME verdiyse dokunulmaz.
        // Kağıt temaları macOS'taki gibi hep açıktır; masaüstü koyu olsa da açık Adwaita kullanılır.
        if g_getenv("GTK_THEME") == nil { g_setenv("GTK_THEME", "Adwaita", 1) }
        // Wayland'de "her zaman üstte" istemi yok (GNOME/Mutter, Zorin); sabitleme düğmesi işe
        // yaramıyordu. XWayland varsa pencere X11 olarak açılır, _NET_WM_STATE_ABOVE çalışır.
        // Kullanıcı GDK_BACKEND verdiyse dokunulmaz.
        if g_getenv("GDK_BACKEND") == nil, g_getenv("WAYLAND_DISPLAY") != nil, g_getenv("DISPLAY") != nil {
            g_setenv("GDK_BACKEND", "x11", 1)
        }
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
            panel.islemOncesi = { [weak editor] devam in editor?.islemOncesi(devam) }
            panel.notSilindi = { [weak editor] silinen in editor?.bosalt(silinen: silinen) }
            panel.notYenidenAdlandirildi = { [weak editor] eski, yeni in editor?.yolDegisti(eski: eski, yeni: yeni) }
            editor.otomatikAdIstendi = { [weak panel] url, ad in panel?.otomatikAdlandir(url, yeniAd: ad) }
            editor.notSecimiBildir = { [weak panel] in panel?.acikNotuBildir($0) }
            panel.baglarYenidenYazildi = { [weak editor] in editor?.baglariYenidenYaz($0) }
            panel.anaSayfaIstendi = { [weak yeni] in yeni?.icerigiGoster(anaSayfa: true) }
            editor.kayitSonrasi.append { [weak panel] url, metin in panel?.notIceriginiArkaPlandaGuncelle(url, metin: metin) }
            LinuxEklentiler.kur(pencere: yeni, editor: editor, panel: panel)
            GtkKoprusu.sinyalBagla(UnsafeMutableRawPointer(yeni.pencere), "destroy") { pencere = nil }
            gtk_window_present(nd_window(yeni.pencere))
        }
        return g_application_run(nd_application(uygulama), CommandLine.argc, CommandLine.unsafeArgv)
    }
}
