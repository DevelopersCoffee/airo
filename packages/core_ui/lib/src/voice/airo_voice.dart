import 'dart:math';

/// A pool of interchangeable message variants for one UI situation.
class MessagePool {
  const MessagePool(this.variants);

  final List<String> variants;

  /// A random variant from the pool.
  String pick() => variants[AiroVoice._random.nextInt(variants.length)];

  /// A random variant, with [detail] preserved on a second line.
  String pickWith({String? detail}) {
    final headline = pick();
    if (detail == null || detail.isEmpty) return headline;
    return '$headline\n$detail';
  }
}

/// Rotating catalog of modern user-facing status and error messages.
///
/// Mixes three vibes per pool: AI-assistant, playful, and minimal.
/// Internal error plumbing (Failure messages, logs) must NOT use this.
abstract final class AiroVoice {
  static Random _random = Random();

  /// Deterministic picks for tests.
  static void seed(int value) => _random = Random(value);

  static const loading = MessagePool([
    'Thinking…',
    'Warming up…',
    'Summoning pixels…',
    'Reticulating splines…',
    'One sec…',
    'Almost there…',
    'Getting things ready…',
  ]);

  static const thinking = MessagePool([
    'Thinking…',
    'Pondering deeply…',
    'Consulting the neurons…',
    'Crunching thoughts…',
    'One moment of genius…',
    'Working on it…',
  ]);

  static const searching = MessagePool([
    'Scanning the airwaves…',
    'Looking around…',
    'Sniffing out devices…',
    'Casting a wide net…',
    'Searching…',
    'On the hunt…',
  ]);

  static const buffering = MessagePool([
    'Warming up the stream…',
    'Buffering brilliance…',
    'Rolling the tape…',
    'Tuning in…',
    'One sec…',
    'Loading your show…',
  ]);

  static const errorGeneric = MessagePool([
    'Hmm, that didn’t work.',
    'Well, that was unexpected.',
    'Gremlins in the machine.',
    'Something went sideways.',
    'That didn’t go as planned.',
    'Oops — hit a snag.',
  ]);

  static const errorNetwork = MessagePool([
    'The internet blinked.',
    'Lost the signal for a moment.',
    'Network’s being shy.',
    'Can’t reach the mothership.',
    'Connection hiccup.',
  ]);

  static const empty = MessagePool([
    'Nothing here yet.',
    'A blank canvas.',
    'Crickets…',
    'All quiet for now.',
    'Empty — for now.',
  ]);
}
