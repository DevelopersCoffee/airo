package dev.fluttercommunity.plus.wakelock;

import android.app.Activity;
import android.view.WindowManager;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** KGP-free screen-wakelock implementation for the lean Android TV flavor. */
public final class WakelockPlusPlugin
    implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
  private static final String CHANNEL_NAME = "io.airo.tv/wakelock";

  private MethodChannel channel;
  private Activity activity;
  private boolean enabled;

  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    if (channel != null) channel.setMethodCallHandler(null);
    channel = null;
  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding) {
    activity = binding.getActivity();
    applyWindowFlag();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch (call.method) {
      case "toggle":
        if (!(call.arguments instanceof Boolean)) {
          result.error("invalid-argument", "toggle expects a boolean", null);
          return;
        }
        enabled = (Boolean) call.arguments;
        applyWindowFlag();
        result.success(null);
        return;
      case "enabled":
        result.success(enabled);
        return;
      default:
        result.notImplemented();
    }
  }

  private void applyWindowFlag() {
    final Activity currentActivity = activity;
    if (currentActivity == null) return;
    currentActivity.runOnUiThread(
        () -> {
          if (enabled) {
            currentActivity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
          } else {
            currentActivity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
          }
        });
  }
}
