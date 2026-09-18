#ifndef FLUTTER_PLUGIN_AIRO_HAPTICS_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_AIRO_HAPTICS_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#if defined(_WIN32)
#if defined(FLUTTER_PLUGIN_IMPL)
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void AiroHapticsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}
#endif

#endif  // FLUTTER_PLUGIN_AIRO_HAPTICS_PLUGIN_C_API_H_
