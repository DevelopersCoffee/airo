import 'dart:async';

import 'package:feature_iptv/application/providers/tv_playlist_pairing_provider.dart';
import 'package:feature_iptv/application/services/tv_playlist_pairing_server.dart';
import 'package:feature_iptv/presentation/widgets/tv_playlist_qr_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String?> pumpAndOpen(
    WidgetTester tester,
    TvPlaylistPairingServer Function() factory,
  ) async {
    final container = ProviderContainer(
      overrides: [
        tvPlaylistPairingServerFactoryProvider.overrideWithValue(factory),
      ],
    );
    addTearDown(container.dispose);

    String? result;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const TvPlaylistQrDialog(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    return result;
  }

  testWidgets('shows the waiting state with a QR code while pending', (
    tester,
  ) async {
    await pumpAndOpen(tester, () => _FakePairingServer(never: true));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('tv-playlist-qr-waiting')),
      findsOneWidget,
    );
    expect(find.text('Waiting for your phone…'), findsOneWidget);
  });

  testWidgets('resolves with the submitted URL and closes the dialog', (
    tester,
  ) async {
    await pumpAndOpen(
      tester,
      () => _FakePairingServer(resultUrl: 'https://example.com/p.m3u'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TvPlaylistQrDialog), findsNothing);
  });

  testWidgets('shows the expired state with a regenerate action', (
    tester,
  ) async {
    await pumpAndOpen(tester, () => _FakePairingServer(resultUrl: null));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tv-playlist-qr-expired')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-playlist-qr-regenerate')),
      findsOneWidget,
    );
  });

  testWidgets('regenerate starts a fresh session', (tester) async {
    var startCount = 0;
    await pumpAndOpen(tester, () {
      startCount++;
      return _FakePairingServer(resultUrl: null);
    });
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tv-playlist-qr-regenerate')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(startCount, 2);
  });

  testWidgets('cancel stops the server and closes without a result', (
    tester,
  ) async {
    final server = _FakePairingServer(never: true);
    await pumpAndOpen(tester, () => server);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('tv-playlist-qr-cancel')));
    await tester.pumpAndSettle();

    expect(server.stopped, isTrue);
    expect(find.byType(TvPlaylistQrDialog), findsNothing);
  });
}

/// A fake that mimics [TvPlaylistPairingServer]'s public surface without
/// binding a real socket. `noSuchMethod` covers the rest of the concrete
/// class's interface (fields like `bindAddress`) that this dialog never
/// touches.
class _FakePairingServer implements TvPlaylistPairingServer {
  _FakePairingServer({this.resultUrl, this.never = false});

  final String? resultUrl;
  final bool never;
  final _resultCompleter = Completer<String?>();
  bool stopped = false;

  @override
  Future<Uri> start() async {
    return Uri.parse('http://192.168.1.5:8080/pair/fake-token');
  }

  @override
  Future<String?> get result {
    if (!never && !_resultCompleter.isCompleted) {
      _resultCompleter.complete(resultUrl);
    }
    return _resultCompleter.future;
  }

  @override
  Future<void> cancel() => stop();

  @override
  Future<void> stop() async {
    stopped = true;
    if (!_resultCompleter.isCompleted) _resultCompleter.complete(null);
  }

  @override
  bool get isRunning => !stopped;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
