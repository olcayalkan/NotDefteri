import CGtk
import Foundation
import NotDefteriCekirdek

/// Sinyal, kısayol veya GLib kaynağı closure'ı destroy notify ile bırakır.
private final class GtkEylemi<Eylem> {
    let calistir: Eylem
    var kaynakID: guint?

    init(_ calistir: Eylem) { self.calistir = calistir }
}

private func eylemiBirak(_ veri: gpointer?) {
    guard let veri else { return }
    Unmanaged<AnyObject>.fromOpaque(veri).release()
}

private func sinyalEyleminiCalistir(_ nesne: gpointer?, _ veri: gpointer?) {
    guard let veri else { return }
    Unmanaged<GtkEylemi<() -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir()
}

private func parametreliEylemiCalistir(_ nesne: gpointer?, _ parametre: gpointer?, _ veri: gpointer?) {
    guard let veri else { return }
    Unmanaged<GtkEylemi<(gpointer?) -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir(parametre)
}

private func konumEyleminiCalistir(_ nesne: gpointer?, _ konum: guint, _ veri: gpointer?) {
    guard let veri else { return }
    Unmanaged<GtkEylemi<(guint) -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir(konum)
}

private func sinyalEyleminiBirak(_ veri: gpointer?, _ closure: UnsafeMutablePointer<GClosure>?) {
    eylemiBirak(veri)
}

private func kaynakEyleminiCalistir(_ veri: gpointer?) -> gboolean {
    guard let veri else { return 0 }
    let eylem = Unmanaged<GtkEylemi<() -> Void>>.fromOpaque(veri).takeUnretainedValue()
    eylem.kaynakID = nil
    eylem.calistir()
    return 0 // G_SOURCE_REMOVE: tek atımlık.
}

private func kisayolEyleminiCalistir(_ widget: UnsafeMutablePointer<GtkWidget>?,
                                   _ argumanlar: OpaquePointer?, _ veri: gpointer?) -> gboolean {
    guard let veri else { return 0 }
    Unmanaged<GtkEylemi<() -> Void>>.fromOpaque(veri).takeUnretainedValue().calistir()
    return 1
}

enum GtkKoprusu {
    /// GObject türetmeleri C'de aynı bellek düzenindedir; Swift'te tür işaretçisine tek yerden dönüştürülür.
    static func gtkIsaretci<T>(_ p: UnsafeMutableRawPointer) -> UnsafeMutablePointer<T> {
        p.assumingMemoryBound(to: T.self)
    }

    /// Yalnızca ek parametresiz, void döndüren sinyaller: activate, clicked, changed.
    @discardableResult
    static func sinyalBagla(_ nesne: gpointer, _ ad: String, _ eylem: @escaping () -> Void) -> gulong {
        let veri = Unmanaged.passRetained(GtkEylemi(eylem)).toOpaque()
        return nd_signal_connect_void(nesne, ad, sinyalEyleminiCalistir, veri, sinyalEyleminiBirak)
    }

    /// Tek pointer parametresi olan, void döndüren sinyaller: notify, row-activated.
    /// Parametre yalnızca callback sırasında geçerlidir; kalıcı olarak saklanmaz.
    @discardableResult
    static func sinyalBagla(_ nesne: gpointer, _ ad: String, _ eylem: @escaping (gpointer?) -> Void) -> gulong {
        let veri = Unmanaged.passRetained(GtkEylemi(eylem)).toOpaque()
        return nd_signal_connect_pointer(nesne, ad, parametreliEylemiCalistir, veri, sinyalEyleminiBirak)
    }

    /// GtkListView::activate, satırın modeldeki konumunu guint olarak verir.
    @discardableResult
    static func sinyalBagla(_ nesne: gpointer, _ ad: String, _ eylem: @escaping (guint) -> Void) -> gulong {
        let veri = Unmanaged.passRetained(GtkEylemi(eylem)).toOpaque()
        return nd_signal_connect_uint(nesne, ad, konumEyleminiCalistir, veri, sinyalEyleminiBirak)
    }

    static func kisayolEylemi(_ eylem: @escaping () -> Void) -> OpaquePointer {
        let veri = Unmanaged.passRetained(GtkEylemi(eylem)).toOpaque()
        return gtk_callback_action_new(kisayolEyleminiCalistir, veri, eylemiBirak)!
    }

    /// UTF-16 konumu scalar sınırında olmalıdır; geçersiz konum sessizce kırpılmaz.
    /// Dönen iter yalnızca tampon değişene kadar geçerlidir; kalıcı konum için GtkTextMark kullanılır.
    static func iter(_ buffer: UnsafeMutablePointer<GtkTextBuffer>, utf16: Int) -> GtkTextIter {
        var bas = GtkTextIter(), sonuc = GtkTextIter()
        gtk_text_buffer_get_bounds(buffer, &bas, &sonuc)
        let metin = dilim(buffer, bas: bas, son: sonuc)
        guard utf16 >= 0 && utf16 <= (metin as NSString).length else {
            aynalamaKaymasi(buffer, "GTK UTF-16 konumu tampon dışında: \(utf16)")
            return bas
        }
        let sinir = metin.utf16.index(metin.utf16.startIndex, offsetBy: utf16)
        guard let indis = String.Index(sinir, within: metin.unicodeScalars) else {
            aynalamaKaymasi(buffer, "GTK UTF-16 konumu surrogate çiftini bölüyor: \(utf16)")
            return bas
        }
        gtk_text_buffer_get_iter_at_offset(buffer, &sonuc, Int32(metin.unicodeScalars.distance(from: metin.startIndex, to: indis)))
        return sonuc
    }

    /// Gizli metin ve child anchor (U+FFFC) da konum hesabına katılır.
    static func utf16(_ iter: GtkTextIter) -> Int {
        var hedef = iter
        let buffer = gtk_text_iter_get_buffer(&hedef)!
        var tarama = GtkTextIter()
        gtk_text_buffer_get_start_iter(buffer, &tarama)
        return (dilim(buffer, bas: tarama, son: hedef) as NSString).length
    }

    /// Anlamsal metin eldeyse paragraf boyunca karakter başına C çağrısı gerekmez.
    static func iterler(_ tampon: UnsafeMutablePointer<GtkTextBuffer>, _ aralik: NSRange,
                       metin: NSString, baslangic: GtkTextIter? = nil) -> (GtkTextIter, GtkTextIter) {
        guard aralik.location >= 0, aralik.length >= 0, aralik.location <= metin.length,
              aralik.length <= metin.length - aralik.location else {
            aynalamaKaymasi(tampon, "GTK aralığı belge dışında: \(aralik)")
            var bas = GtkTextIter()
            gtk_text_buffer_get_start_iter(tampon, &bas)
            return (bas, bas)
        }
        for sinir in [aralik.location, NSMaxRange(aralik)] where sinir > 0 && sinir < metin.length {
            if (0xD800...0xDBFF).contains(metin.character(at: sinir - 1)),
               (0xDC00...0xDFFF).contains(metin.character(at: sinir)) {
                aynalamaKaymasi(tampon, "GTK aralığı surrogate çiftini bölüyor: \(aralik)")
                var bas = GtkTextIter()
                gtk_text_buffer_get_start_iter(tampon, &bas)
                return (bas, bas)
            }
        }
        var bas = GtkTextIter()
        let onEk = metin.substring(to: aralik.location).unicodeScalars.count
        if let baslangic {
            bas = baslangic
            gtk_text_iter_forward_chars(&bas, Int32(onEk))
        } else { gtk_text_buffer_get_iter_at_offset(tampon, &bas, Int32(onEk)) }
        var son = bas
        gtk_text_iter_forward_chars(&son, Int32(metin.substring(with: aralik).unicodeScalars.count))
        return (bas, son)
    }

    /// Dönüşüm hatası not yeniden yüklenene kadar kayıt güvenlik ağında kalır.
    static func aynalamaKaymasi(_ tampon: UnsafeMutablePointer<GtkTextBuffer>, _ neden: String) {
        FileHandle.standardError.write(Data("[NotDefteri] Aynalama kayması: \(neden)\n".utf8))
        guard aynalamaHatasi(tampon) == nil else { return }
        let veri = Unmanaged.passRetained(neden as NSString).toOpaque()
        g_object_set_data_full(UnsafeMutableRawPointer(tampon).assumingMemoryBound(to: GObject.self),
                               "nd-aynalama-hatasi", veri, { veri in
            if let veri { Unmanaged<NSString>.fromOpaque(veri).release() }
        })
        if let izleyici = g_object_get_data(UnsafeMutableRawPointer(tampon).assumingMemoryBound(to: GObject.self),
                                           "nd-aynalama-izleyici") {
            Unmanaged<GtkEylemi<(String) -> Void>>.fromOpaque(izleyici).takeUnretainedValue().calistir(neden)
        }
    }

    static func aynalamaHatasiniIzle(_ tampon: UnsafeMutablePointer<GtkTextBuffer>, _ eylem: @escaping (String) -> Void) {
        let veri = Unmanaged.passRetained(GtkEylemi(eylem)).toOpaque()
        g_object_set_data_full(UnsafeMutableRawPointer(tampon).assumingMemoryBound(to: GObject.self),
                               "nd-aynalama-izleyici", veri, eylemiBirak)
    }

    static func aynalamaHatasi(_ tampon: UnsafeMutablePointer<GtkTextBuffer>) -> String? {
        guard let veri = g_object_get_data(UnsafeMutableRawPointer(tampon).assumingMemoryBound(to: GObject.self),
                                          "nd-aynalama-hatasi") else { return nil }
        return Unmanaged<NSString>.fromOpaque(veri).takeUnretainedValue() as String
    }

    static func aynalamaHatasiniSifirla(_ tampon: UnsafeMutablePointer<GtkTextBuffer>) {
        g_object_set_data(UnsafeMutableRawPointer(tampon).assumingMemoryBound(to: GObject.self),
                          "nd-aynalama-hatasi", nil)
    }

    /// Gizli metin ve ekler dahil; child anchor'lar U+FFFC olarak döner.
    static func dilim(_ tampon: UnsafeMutablePointer<GtkTextBuffer>, bas: GtkTextIter, son: GtkTextIter) -> String {
        var b = bas, s = son
        guard let ham = gtk_text_buffer_get_slice(tampon, &b, &s, 1) else { return "" }
        defer { g_free(ham) }
        return String(cString: ham)
    }

    static func platformuKur() {
        Platform.anaIsParcaciginda = { eylem in
            let veri = Unmanaged.passRetained(GtkEylemi(eylem)).toOpaque()
            g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, kaynakEyleminiCalistir, veri, eylemiBirak)
        }
        Platform.zamanlayici = { aralik, eylem in
            let kutu = GtkEylemi(eylem)
            let veri = Unmanaged.passRetained(kutu).toOpaque()
            let milisaniye = aralik.isFinite ? min(max(aralik * 1_000, 1), Double(guint.max)) : Double(guint.max)
            kutu.kaynakID = g_timeout_add_full(G_PRIORITY_DEFAULT, guint(milisaniye),
                                             kaynakEyleminiCalistir, veri, eylemiBirak)
            return {
                guard let kimlik = kutu.kaynakID else { return }
                kutu.kaynakID = nil
                g_source_remove(kimlik)
            }
        }
    }
}
