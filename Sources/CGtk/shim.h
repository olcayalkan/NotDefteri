#ifndef NOTDEFTERI_GTK_SHIM_H
#define NOTDEFTERI_GTK_SHIM_H

#define GDK_VERSION_MIN_REQUIRED GDK_VERSION_4_6
#define GDK_VERSION_MAX_ALLOWED GDK_VERSION_4_6
#include <gtk/gtk.h>

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

/* Swift'ten variadic g_object_get/set çağrılmaz. */
static inline gboolean nd_settings_dark(GtkSettings *settings) {
    gboolean dark = FALSE;
    gchar *theme = NULL;
    g_object_get(settings, "gtk-application-prefer-dark-theme", &dark,
                 "gtk-theme-name", &theme, NULL);
    if (theme) {
        gchar *lower = g_ascii_strdown(theme, -1);
        dark = dark || g_str_has_suffix(lower, "-dark") || g_str_has_suffix(lower, ":dark");
        g_free(lower);
        g_free(theme);
    }
    return dark;
}

/* XFCE gibi masaüstlerinin GTK3 temaları GTK4'te renk değişkenlerini tanımlamıyor; uygulama
 * renkleri bozuk görünüyordu. GTK_THEME verilmediyse Adwaita kullanılır, koyu tercih korunur. */
static inline void nd_temayi_adwaitaya_cek(GtkSettings *settings) {
    if (g_getenv("GTK_THEME") != NULL) return;
    gchar *theme = NULL;
    g_object_get(settings, "gtk-theme-name", &theme, NULL);
    if (theme && !g_str_has_prefix(theme, "Adwaita")) {
        gchar *lower = g_ascii_strdown(theme, -1);
        if (g_strrstr(lower, "dark") != NULL) {
            g_object_set(settings, "gtk-application-prefer-dark-theme", TRUE, NULL);
        }
        g_free(lower);
        g_object_set(settings, "gtk-theme-name", "Adwaita", NULL);
    }
    g_free(theme);
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
