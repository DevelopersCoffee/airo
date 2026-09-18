#include "include/airo_haptics/airo_haptics_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define AIRO_HAPTICS_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), airo_haptics_plugin_get_type(), \
                              AiroHapticsPlugin))

struct _AiroHapticsPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(AiroHapticsPlugin, airo_haptics_plugin, g_object_get_type())

static void airo_haptics_plugin_handle_method_call(
    AiroHapticsPlugin* self,
    FlMethodCall* method_call) {
  g_autorelease FlMethodResponse* response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (g_strcmp0(method, "getCapabilities") == 0) {
    g_autorelease FlValue* capabilities = fl_value_new_map();
    fl_value_set_string_take(capabilities, "hasHaptics", fl_value_new_bool(false));
    fl_value_set_string_take(capabilities, "supportsCustomPatterns", fl_value_new_bool(false));
    fl_value_set_string_take(capabilities, "supportsPredefinedEffects", fl_value_new_bool(false));
    fl_value_set_string_take(capabilities, "supportsWaveformComposition", fl_value_new_bool(false));
    fl_value_set_string_take(capabilities, "supportsAmplitudeControl", fl_value_new_bool(false));
    fl_value_set_string_take(capabilities, "supportsFrequencyControl", fl_value_new_bool(false));
    fl_value_set_string_take(capabilities, "maxChannels", fl_value_new_int(0));
    fl_value_set_string_take(capabilities, "minIntensity", fl_value_new_float(0.0));
    fl_value_set_string_take(capabilities, "maxIntensity", fl_value_new_float(1.0));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(capabilities));
  } else if (g_strcmp0(method, "performFeedback") == 0 ||
             g_strcmp0(method, "performImpact") == 0 ||
             g_strcmp0(method, "playPattern") == 0 ||
             g_strcmp0(method, "stopPattern") == 0 ||
             g_strcmp0(method, "stopAll") == 0 ||
             g_strcmp0(method, "updateSettings") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "getDiagnostics") == 0) {
    g_autorelease FlValue* diag = fl_value_new_map();
    fl_value_set_string_take(diag, "activePlatform", fl_value_new_string("linux"));
    fl_value_set_string_take(diag, "isEngineReady", fl_value_new_bool(true));
    fl_value_set_string_take(diag, "totalEventsPlayed", fl_value_new_int(0));
    fl_value_set_string_take(diag, "lastEventTimestamp", fl_value_new_string(""));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(diag));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void airo_haptics_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(airo_haptics_plugin_parent_class)->dispose(object);
}

static void airo_haptics_plugin_class_init(AiroHapticsPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = airo_haptics_plugin_dispose;
}

static void airo_haptics_plugin_init(AiroHapticsPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  AiroHapticsPlugin* plugin = AIRO_HAPTICS_PLUGIN(user_data);
  airo_haptics_plugin_handle_method_call(plugin, method_call);
}

void airo_haptics_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  AiroHapticsPlugin* plugin = AIRO_HAPTICS_PLUGIN(
      g_object_new(airo_haptics_plugin_get_type(), nullptr));

  g_autorelease FlStandardMethodCodec* codec = fl_standard_method_codec_new();
  g_autorelease FlMethodChannel* channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "airo_haptics", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
