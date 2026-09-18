#include "include/airo_haptics/airo_haptics_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "airo_haptics_plugin.h"

void AiroHapticsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  airo_haptics::AiroHapticsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
