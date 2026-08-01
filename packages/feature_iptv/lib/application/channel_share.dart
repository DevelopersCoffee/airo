import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

typedef ChannelShareTemplateSelector = int Function(int templateCount);

final class ChannelShareMessageComposer {
  const ChannelShareMessageComposer({
    this.selectTemplate = _selectFirstTemplate,
  });

  final ChannelShareTemplateSelector selectTemplate;

  static const _playableTemplates = <String>[
    'Found it. You bring the snacks. 🍿\n'
        'Watch {channel} in Airo:\n{link}',
    'The remote has spoken. 📺 {channel} is on.\n'
        'Open it in Airo: {link}',
    'No spoilers—just a watchable link. 👀\n'
        'Watch {channel} in Airo: {link}',
    'Your group chat now has programming. 😄\n'
        'Open {channel} in Airo: {link}',
  ];

  String compose({
    required String channelName,
    required Uri link,
    required bool isPlayable,
  }) {
    if (!isPlayable) {
      return 'Open $channelName in Airo. '
          'You’ll need the same playlist: $link';
    }
    final selected = selectTemplate(_playableTemplates.length);
    final index = selected.clamp(0, _playableTemplates.length - 1).toInt();
    return _playableTemplates[index]
        .replaceAll('{channel}', channelName)
        .replaceAll('{link}', link.toString());
  }
}

int _selectFirstTemplate(int _) => 0;

abstract interface class ChannelShareGateway {
  Future<bool> share({required String subject, required String text});
}

final class PlatformChannelShareGateway implements ChannelShareGateway {
  const PlatformChannelShareGateway();

  @override
  Future<bool> share({required String subject, required String text}) async {
    final result = await SharePlus.instance.share(
      ShareParams(subject: subject, text: text),
    );
    return result.status != ShareResultStatus.unavailable;
  }
}

final channelShareMessageComposerProvider =
    Provider<ChannelShareMessageComposer>((ref) {
      final utcDay =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
      return ChannelShareMessageComposer(
        selectTemplate: (templateCount) => utcDay % templateCount,
      );
    });

final channelShareGatewayProvider = Provider<ChannelShareGateway>(
  (ref) => const PlatformChannelShareGateway(),
);
