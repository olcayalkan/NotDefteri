#ifndef NOTDEFTERI_GTK_SHIM_H
#define NOTDEFTERI_GTK_SHIM_H

#define GDK_VERSION_MIN_REQUIRED GDK_VERSION_4_6
#define GDK_VERSION_MAX_ALLOWED GDK_VERSION_4_6
#include <gtk/gtk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/x11/gdkx.h>
#endif

/* Yerleşim/yüzey hazır değilken popup konumlandırma istemeyin. Monitör nesnesi
 * saklanmaz: ekran takılıp çıkarıldığında her çağrıda yeniden sorgulanır.
 * Bu kontrol GTK/backend içindeki yarışları onarmaz; geçersiz açılışı önler. */
static inline gboolean nd_popup_hedefi_hazir(GtkWidget *widget) {
    if (!widget || !gtk_widget_get_mapped(widget) ||
        gtk_widget_get_width(widget) <= 0 || gtk_widget_get_height(widget) <= 0)
        return FALSE;
    GtkNative *native = gtk_widget_get_native(widget);
    if (!native) return FALSE;
    GdkSurface *surface = gtk_native_get_surface(native);
    if (!surface || gdk_surface_is_destroyed(surface)) return FALSE;
    GdkMonitor *monitor = gdk_display_get_monitor_at_surface(gdk_surface_get_display(surface), surface);
    return monitor && gdk_monitor_is_valid(monitor);
}

/* İmzalar ayrı tutulur: notify gibi sinyallerin veri argümanı üçüncüdür. */
static inline gulong nd_signal_connect_void(gpointer instance, const gchar *signal,
                                           void (*callback)(gpointer, gpointer),
                                           gpointer data, GClosureNotify destroy_data) {
    return g_signal_connect_data(instance, signal, G_CALLBACK(callback), data,
                                 destroy_data, (GConnectFlags)0);
}

static inline gulong nd_signal_connect_pointer(gpointer instance, const gchar *signal,
                                              void (*callback)(gpointer, gpointer, gpointer),
                                              gpointer data, GClosureNotify destroy_data) {
    return g_signal_connect_data(instance, signal, G_CALLBACK(callback), data,
                                 destroy_data, (GConnectFlags)0);
}

static inline gulong nd_signal_connect_uint(gpointer instance, const gchar *signal,
                                           void (*callback)(gpointer, guint, gpointer),
                                           gpointer data, GClosureNotify destroy_data) {
    return g_signal_connect_data(instance, signal, G_CALLBACK(callback), data,
                                 destroy_data, (GConnectFlags)0);
}

/* GtkDialog/GtkNativeDialog response, negatif GTK_RESPONSE_* değerleri taşır. */
static inline gulong nd_signal_connect_int(gpointer instance, const gchar *signal,
                                          void (*callback)(gpointer, gint, gpointer),
                                          gpointer data, GClosureNotify destroy_data) {
    return g_signal_connect_data(instance, signal, G_CALLBACK(callback), data,
                                 destroy_data, (GConnectFlags)0);
}

/* macOS "Sabitle (her zaman üstte)". GTK4 keep-above API'sini kaldırdı; X11 pencere yöneticisine
 * _NET_WM_STATE_ABOVE istemi gönderilir. X11 dışı oturumda (Wayland) FALSE döner. */
static inline gboolean nd_ustte_tut(GtkWindow *window, gboolean ustte) {
#ifdef GDK_WINDOWING_X11
    GdkSurface *yuzey = gtk_native_get_surface(GTK_NATIVE(window));
    if (yuzey == NULL || !GDK_IS_X11_SURFACE(yuzey)) return FALSE;
    Display *ekran = gdk_x11_display_get_xdisplay(gdk_surface_get_display(yuzey));
    XEvent olay = {0};
    olay.xclient.type = ClientMessage;
    olay.xclient.window = gdk_x11_surface_get_xid(yuzey);
    olay.xclient.message_type = XInternAtom(ekran, "_NET_WM_STATE", False);
    olay.xclient.format = 32;
    olay.xclient.data.l[0] = ustte ? 1 : 0; /* _NET_WM_STATE_ADD / _REMOVE */
    olay.xclient.data.l[1] = (long)XInternAtom(ekran, "_NET_WM_STATE_ABOVE", False);
    olay.xclient.data.l[3] = 1; /* kaynak: olağan uygulama */
    XSendEvent(ekran, DefaultRootWindow(ekran), False, SubstructureRedirectMask | SubstructureNotifyMask, &olay);
    XFlush(ekran);
    return TRUE;
#else
    (void)window; (void)ustte;
    return FALSE;
#endif
}

static inline GApplication *nd_application(GtkApplication *app) { return G_APPLICATION(app); }
static inline GtkWindow *nd_window(GtkWidget *widget) { return GTK_WINDOW(widget); }
static inline GtkLabel *nd_label(GtkWidget *widget) { return GTK_LABEL(widget); }
static inline GtkBox *nd_box(GtkWidget *widget) { return GTK_BOX(widget); }
static inline GtkPaned *nd_paned(GtkWidget *widget) { return GTK_PANED(widget); }
static inline GtkHeaderBar *nd_header_bar(GtkWidget *widget) { return GTK_HEADER_BAR(widget); }
static inline GtkShortcutController *nd_shortcut_controller(GtkEventController *controller) {
    return GTK_SHORTCUT_CONTROLLER(controller);
}
static inline GtkStyleProvider *nd_style_provider(GtkCssProvider *provider) { return GTK_STYLE_PROVIDER(provider); }

#endif
