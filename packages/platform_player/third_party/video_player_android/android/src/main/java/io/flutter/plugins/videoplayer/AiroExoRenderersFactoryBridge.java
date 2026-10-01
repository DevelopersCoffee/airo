// Airo fork hook (#2081): optional TV PCM tap via app-hosted Media3 processor.
// Falls back to stock DefaultRenderersFactory when io.airo.app is absent.
package io.flutter.plugins.videoplayer;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultRenderersFactory;
import androidx.media3.exoplayer.RenderersFactory;

@UnstableApi
public final class AiroExoRenderersFactoryBridge {
  private AiroExoRenderersFactoryBridge() {}

  @NonNull
  public static RenderersFactory create(@NonNull Context context) {
    try {
      Class<?> tap = Class.forName("io.airo.app.AiroSpatialPcmTap");
      Object result =
          tap.getMethod("renderersFactory", Context.class).invoke(null, context);
      return (RenderersFactory) result;
    } catch (ReflectiveOperationException ignored) {
      return new DefaultRenderersFactory(context);
    }
  }
}
