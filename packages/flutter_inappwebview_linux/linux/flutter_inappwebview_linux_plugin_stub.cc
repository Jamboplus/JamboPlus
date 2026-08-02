#include "include/flutter_inappwebview_linux/flutter_inappwebview_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>

#define FLUTTER_INAPPWEBVIEW_LINUX_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_inappwebview_linux_plugin_get_type(), \
                              FlutterInappwebviewLinuxPlugin))

struct _FlutterInappwebviewLinuxPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterInappwebviewLinuxPlugin, flutter_inappwebview_linux_plugin,
              g_object_get_type())

static void flutter_inappwebview_linux_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(flutter_inappwebview_linux_plugin_parent_class)->dispose(object);
}

static void flutter_inappwebview_linux_plugin_class_init(
    FlutterInappwebviewLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_inappwebview_linux_plugin_dispose;
}

static void flutter_inappwebview_linux_plugin_init(FlutterInappwebviewLinuxPlugin* self) {}

void flutter_inappwebview_linux_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  // No-op stub: WPE WebKit is not bundled for desktop Linux builds.
  FlutterInappwebviewLinuxPlugin* plugin = FLUTTER_INAPPWEBVIEW_LINUX_PLUGIN(
      g_object_new(flutter_inappwebview_linux_plugin_get_type(), nullptr));
  g_object_unref(plugin);
  (void)registrar;
}
