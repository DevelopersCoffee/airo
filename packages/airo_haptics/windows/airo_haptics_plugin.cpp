#include "airo_haptics_plugin.h"

#include <windows.h>

namespace airo_haptics {

// static
void AiroHapticsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "airo_haptics",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AiroHapticsPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AiroHapticsPlugin::AiroHapticsPlugin() {}

AiroHapticsPlugin::~AiroHapticsPlugin() {}

void AiroHapticsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method_name = method_call.method_name();

  if (method_name == "getCapabilities") {
    flutter::EncodableMap capabilities;
    capabilities[flutter::EncodableValue("hasHaptics")] = flutter::EncodableValue(false);
    capabilities[flutter::EncodableValue("supportsCustomPatterns")] = flutter::EncodableValue(false);
    capabilities[flutter::EncodableValue("supportsPredefinedEffects")] = flutter::EncodableValue(false);
    capabilities[flutter::EncodableValue("supportsWaveformComposition")] = flutter::EncodableValue(false);
    capabilities[flutter::EncodableValue("supportsAmplitudeControl")] = flutter::EncodableValue(false);
    capabilities[flutter::EncodableValue("supportsFrequencyControl")] = flutter::EncodableValue(false);
    capabilities[flutter::EncodableValue("maxChannels")] = flutter::EncodableValue(0);
    capabilities[flutter::EncodableValue("minIntensity")] = flutter::EncodableValue(0.0);
    capabilities[flutter::EncodableValue("maxIntensity")] = flutter::EncodableValue(1.0);
    result->Success(flutter::EncodableValue(capabilities));
  } else if (method_name == "performFeedback" ||
             method_name == "performImpact" ||
             method_name == "playPattern" ||
             method_name == "stopPattern" ||
             method_name == "stopAll" ||
             method_name == "updateSettings") {
    result->Success();
  } else if (method_name == "getDiagnostics") {
    flutter::EncodableMap diag;
    diag[flutter::EncodableValue("activePlatform")] = flutter::EncodableValue("windows");
    diag[flutter::EncodableValue("isEngineReady")] = flutter::EncodableValue(true);
    diag[flutter::EncodableValue("totalEventsPlayed")] = flutter::EncodableValue(0);
    diag[flutter::EncodableValue("lastEventTimestamp")] = flutter::EncodableValue("");
    result->Success(flutter::EncodableValue(diag));
  } else {
    result->NotImplemented();
  }
}

}  // namespace airo_haptics
