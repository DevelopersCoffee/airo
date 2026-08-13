package com.prongbang.screen_protector;

import android.app.Activity;
import android.view.Window;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** Android implementation for the screen_protector Flutter plugin. */
public final class ScreenProtectorPlugin
    implements FlutterPlugin, MethodCallHandler, ActivityAware {
  private MethodChannel channel;
  private Activity activity;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "screen_protector");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "protectDataLeakageOn":
      case "preventScreenshotOn":
        setSecureWindowEnabled(true);
        result.success(null);
        break;
      case "protectDataLeakageOff":
      case "preventScreenshotOff":
        setSecureWindowEnabled(false);
        result.success(null);
        break;
      case "isRecording":
        result.success(false);
        break;
      case "addListener":
      case "removeListener":
      case "protectDataLeakageWithBlur":
      case "protectDataLeakageWithBlurOff":
      case "protectDataLeakageWithImage":
      case "protectDataLeakageWithImageOff":
      case "protectDataLeakageWithColor":
      case "protectDataLeakageWithColorOff":
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }

  private void setSecureWindowEnabled(boolean enabled) {
    if (activity == null) {
      return;
    }
    activity.runOnUiThread(() -> {
      Window window = activity.getWindow();
      if (window == null) {
        return;
      }
      if (enabled) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE);
      } else {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
      }
    });
  }
}
