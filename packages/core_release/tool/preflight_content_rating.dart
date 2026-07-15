import 'dart:convert';
import 'dart:io';

import 'package:core_release/core_release.dart';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final options = _parseOptions(args);
  final repoRoot = _repoRoot(options['repo-root']);
  final outputJson = options['output-json'];
  final outputMarkdown = options['output-markdown'];

  final preflight =
      AiroContentRatingPreflightRunner(
        matrix: AiroReleaseMatrix.v2Default(),
      ).run(
        AiroContentRatingPreflightRequest(
          profileId: options['profile'] ?? 'tv',
          targetAudienceMinimumAge: _intOption(
            options['target-audience-min-age'],
            fallback: 16,
          ),
          userProvidedExternalMedia: _optionFlag(
            options,
            'user-provided-external-media',
            fallback: true,
          ),
          hasAds: _optionFlag(options, 'has-ads'),
          hasInAppPurchases: _optionFlag(options, 'has-in-app-purchases'),
          hasGambling: _optionFlag(options, 'has-gambling'),
          hasUserChat: _optionFlag(options, 'has-user-chat'),
          hasLocationSharing: _optionFlag(options, 'has-location-sharing'),
          requiresAccountForPlayback: _optionFlag(
            options,
            'requires-account-for-playback',
          ),
          hasAppHostedMatureContent: _optionFlag(
            options,
            'has-app-hosted-mature-content',
          ),
          hasViolenceInUi: _optionFlag(options, 'has-violence-in-ui'),
          hasSexualContentInUi: _optionFlag(
            options,
            'has-sexual-content-in-ui',
          ),
          hasProfanityInUi: _optionFlag(options, 'has-profanity-in-ui'),
          appStoreConnectInScope: _optionFlag(
            options,
            'app-store-connect-in-scope',
          ),
        ),
      );

  final encoded = const JsonEncoder.withIndent(
    '  ',
  ).convert(preflight.toPublicMap());
  stdout.writeln(encoded);

  if (outputJson != null) {
    _writeFile(repoRoot, outputJson, encoded);
  }
  if (outputMarkdown != null) {
    _writeFile(repoRoot, outputMarkdown, preflight.toMarkdown());
  }

  if (!preflight.readyForConsoleEntry) {
    exitCode = 1;
  }
}

Map<String, String> _parseOptions(List<String> args) {
  final options = <String, String>{};
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (!arg.startsWith('--')) {
      stderr.writeln('Ignoring positional argument: $arg');
      continue;
    }
    final equals = arg.indexOf('=');
    if (equals > 0) {
      options[arg.substring(2, equals)] = arg.substring(equals + 1);
      continue;
    }
    final key = arg.substring(2);
    if (_booleanFlags.contains(key)) {
      options[key] = 'true';
      continue;
    }
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw ArgumentError('Missing value for --$key.');
    }
    options[key] = args[index + 1];
    index += 1;
  }
  return options;
}

const Set<String> _booleanFlags = {
  'user-provided-external-media',
  'no-user-provided-external-media',
  'has-ads',
  'has-in-app-purchases',
  'has-gambling',
  'has-user-chat',
  'has-location-sharing',
  'requires-account-for-playback',
  'has-app-hosted-mature-content',
  'has-violence-in-ui',
  'has-sexual-content-in-ui',
  'has-profanity-in-ui',
  'app-store-connect-in-scope',
};

Directory _repoRoot(String? configured) {
  if (configured != null && configured.trim().isNotEmpty) {
    return Directory(configured).absolute;
  }

  var current = Directory.current.absolute;
  while (true) {
    if (File('${current.path}/melos.yaml').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      return Directory.current.absolute;
    }
    current = parent;
  }
}

int _intOption(String? value, {required int fallback}) {
  if (value == null || value.trim().isEmpty) {
    return fallback;
  }
  return int.parse(value);
}

bool _optionFlag(
  Map<String, String> options,
  String key, {
  bool fallback = false,
}) {
  if (key == 'user-provided-external-media' &&
      options.containsKey('no-user-provided-external-media')) {
    return false;
  }
  final value = options[key];
  if (value == null) {
    return fallback;
  }
  final normalized = value.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

void _writeFile(Directory repoRoot, String path, String contents) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

void _printUsage() {
  stdout.writeln('''
Preflight Airo store content-rating questionnaire posture.

Usage:
  dart run tool/preflight_content_rating.dart [options]

Options:
  --profile <id>                         Release profile, default: tv
  --repo-root <path>                     Workspace root, auto-detected
  --target-audience-min-age <age>        Default: 16
  --no-user-provided-external-media      Override external media answer to No
  --has-ads                              Declare ads are present
  --has-in-app-purchases                 Declare purchases are present
  --has-gambling                         Declare gambling/contests are present
  --has-user-chat                        Declare chat/user interaction present
  --has-location-sharing                 Declare location sharing present
  --requires-account-for-playback        Declare account-gated playback
  --has-app-hosted-mature-content        Declare app-hosted mature content
  --has-violence-in-ui                   Declare violent UI content
  --has-sexual-content-in-ui             Declare sexual UI content
  --has-profanity-in-ui                  Declare profanity/crude humor in UI
  --app-store-connect-in-scope           Include App Store Connect as in scope
  --output-json <path>                   Write JSON report
  --output-markdown <path>               Write markdown report
  --help                                 Show this help
''');
}
