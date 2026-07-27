import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/feature_flags.dart';
import 'phone_media_local_picker.dart';

/// Shell adapter for the shared IPTV feature package.
///
/// The module is available to both the mobile super-app and focused TV app.
/// Each host owns its shell chrome while this adapter preserves IPTV's stable
/// route identities.
class IptvFeatureModule extends AppModule {
  @override
  String get id => 'iptv';

  @override
  Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.tv};

  @override
  List<RouteBase> routesFor(ShellId shell) {
    if (shell == ShellId.mobile) {
      return [
        GoRoute(
          path: '/iptv',
          name: 'iptv',
          builder: (context, state) => IPTVScreen(
            onOpenVod: () => context.go('/vod'),
            onPickLocalMediaForTv: kEnablePhoneMediaReceiverExperimental
                ? pickPhoneLocalMediaForTv
                : null,
            deepLinkIntent: IptvDeepLinkIntent.tryParse(state.uri),
            onShareVideoFrame: _shareIptvVideoFrame,
          ),
        ),
        GoRoute(
          path: '/iptv/player',
          name: 'iptv_player',
          builder: (context, state) {
            final channelId = state.uri.queryParameters['channelId'];
            return IPTVScreen(
              key: channelId != null ? ValueKey<String>(channelId) : null,
            );
          },
        ),
        GoRoute(
          path: '/vod',
          name: 'VOD',
          builder: (context, state) => const VodScreen(),
        ),
      ];
    }

    return [
      GoRoute(
        path: '/iptv',
        name: 'iptv',
        builder: (context, state) => const IPTVScreen(),
      ),
      GoRoute(
        path: '/iptv/player',
        name: 'iptv_player',
        builder: (context, state) {
          final channelId = state.uri.queryParameters['channelId'];
          return IPTVScreen(
            key: channelId != null ? ValueKey<String>(channelId) : null,
          );
        },
      ),
    ];
  }
}

Future<void> _shareIptvVideoFrame(Uint8List pngBytes) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'airo-tv-frame.png',
        ),
      ],
      subject: 'Airo TV video frame',
    ),
  );
}
