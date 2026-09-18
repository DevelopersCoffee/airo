#ifndef FLUTTER_PLUGIN_AIRO_HAPTICS_PLUGIN_H_
#define FLUTTER_PLUGIN_AIRO_HAPTICS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_message_codec.h>

#include <memory>

namespace airo_haptics {

class AiroHapticsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AiroHapticsPlugin();

  virtual ~AiroHapticsPlugin();

  AiroHapticsPlugin(const AiroHapticsPlugin&) = delete;
  AiroHapticsPlugin& operator=(const AiroHapticsPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace airo_haptics

#endif  // FLUTTER_PLUGIN_AIRO_HAPTICS_PLUGIN_H_
