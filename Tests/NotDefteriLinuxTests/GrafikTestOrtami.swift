import CGtk

/// GTK başarısız ilk denemeden sonra ikinci çağrıda true dönebilir.
/// Tüm test sınıfları aynı sonucu paylaşır; gerçek ekran olmadan pencere kurulmaz.
enum GrafikTestOrtami {
    static let hazir: Bool = gtk_init_check() != 0 && gdk_display_get_default() != nil
}
