// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipboardService', () {
    test(
      'clears the clipboard after the timeout when content is unchanged',
      () {
        fakeAsync((async) {
          String? clipboard;
          final service = ClipboardService(
            setData: (data) async => clipboard = data.text,
            getData: () async => ClipboardData(text: clipboard ?? ''),
          );

          service.copyWithAutoClear('secret-account-number');
          async.flushMicrotasks();
          expect(clipboard, 'secret-account-number');

          async.elapse(VaultConfig.clipboardClearDuration);
          async.flushMicrotasks();

          expect(clipboard, '');
        });
      },
    );

    test('does not clear when the user copied something else meanwhile', () {
      fakeAsync((async) {
        String? clipboard;
        final service = ClipboardService(
          setData: (data) async => clipboard = data.text,
          getData: () async => ClipboardData(text: clipboard ?? ''),
        );

        service.copyWithAutoClear('secret-account-number');
        async.flushMicrotasks();
        clipboard = 'user copied something else';

        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();

        expect(clipboard, 'user copied something else');
      });
    });

    test('a second copy cancels the first clear timer', () {
      fakeAsync((async) {
        String? clipboard;
        final service = ClipboardService(
          setData: (data) async => clipboard = data.text,
          getData: () async => ClipboardData(text: clipboard ?? ''),
        );

        service.copyWithAutoClear('first');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 20));
        service.copyWithAutoClear('second');
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 20));
        async.flushMicrotasks();
        expect(clipboard, 'second');

        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();
        expect(clipboard, '');
      });
    });

    test('an overlapping late first write cannot preserve stale content', () {
      fakeAsync((async) {
        String? clipboard;
        var delayedClearAttempts = 0;
        final firstWrite = Completer<void>();
        final service = ClipboardService(
          setData: (data) {
            if (data.text == 'first') {
              return firstWrite.future.then((_) {
                clipboard = data.text;
              });
            }
            clipboard = data.text;
            return Future<void>.value();
          },
          getData: () async {
            delayedClearAttempts++;
            return ClipboardData(text: clipboard ?? '');
          },
        );

        service.copyWithAutoClear('first');
        async.flushMicrotasks();
        expect(clipboard, isNull);

        async.elapse(const Duration(seconds: 5));
        service.copyWithAutoClear('second');
        async.flushMicrotasks();

        firstWrite.complete();
        async.flushMicrotasks();

        expect(clipboard, 'second');

        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();

        expect(clipboard, '');
        expect(delayedClearAttempts, greaterThanOrEqualTo(1));
      });
    });

    test('dispose during a pending copy prevents a later clear timer', () {
      fakeAsync((async) {
        String? clipboard;
        var clearWrites = 0;
        final pendingWrite = Completer<void>();
        final service = ClipboardService(
          setData: (data) {
            clipboard = data.text;
            if (data.text == '') {
              clearWrites++;
            }
            return data.text == 'secret-account-number'
                ? pendingWrite.future
                : Future<void>.value();
          },
          getData: () async => ClipboardData(text: clipboard ?? ''),
        );

        service.copyWithAutoClear('secret-account-number');
        async.flushMicrotasks();
        service.dispose();
        pendingWrite.complete();
        async.flushMicrotasks();

        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();

        expect(clipboard, 'secret-account-number');
        expect(clearWrites, 0);
      });
    });

    test('delayed clipboard read failures are contained', () {
      fakeAsync((async) {
        String? clipboard;
        final service = ClipboardService(
          setData: (data) async => clipboard = data.text,
          getData: () async => throw StateError('clipboard read failed'),
        );

        service.copyWithAutoClear('secret-account-number');
        async.flushMicrotasks();
        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();

        expect(clipboard, 'secret-account-number');
      });
    });

    test('an older delayed clear write cannot wipe a newer copy', () {
      fakeAsync((async) {
        String? clipboard;
        final oldClearWrite = Completer<void>();
        final service = ClipboardService(
          setData: (data) {
            if (data.text == '') {
              return oldClearWrite.future.then((_) {
                clipboard = data.text;
              });
            }
            clipboard = data.text;
            return Future<void>.value();
          },
          getData: () async => ClipboardData(text: clipboard ?? ''),
        );

        service.copyWithAutoClear('first');
        async.flushMicrotasks();
        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();
        expect(clipboard, 'first');

        service.copyWithAutoClear('second');
        async.flushMicrotasks();

        oldClearWrite.complete();
        async.flushMicrotasks();

        expect(clipboard, 'second');
      });
    });

    test('delayed clear write failures are contained', () {
      fakeAsync((async) {
        String? clipboard;
        final clearWrite = Completer<void>();
        final service = ClipboardService(
          setData: (data) {
            if (data.text == '') {
              return clearWrite.future.then<void>((_) {
                throw StateError('clipboard clear failed');
              });
            }
            clipboard = data.text;
            return Future<void>.value();
          },
          getData: () async => ClipboardData(text: clipboard ?? ''),
        );

        service.copyWithAutoClear('secret-account-number');
        async.flushMicrotasks();
        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();

        clearWrite.complete();
        async.flushMicrotasks();

        expect(clipboard, 'secret-account-number');
      });
    });

    test('provider disposal cancels the pending clear timer', () {
      fakeAsync((async) {
        String? clipboard;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboard =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return <String, Object?>{'text': clipboard};
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        final container = ProviderContainer();

        container
            .read(clipboardServiceProvider)
            .copyWithAutoClear('secret-account-number');
        async.flushMicrotasks();
        container.dispose();

        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();

        expect(clipboard, 'secret-account-number');
      });
    });
  });
}
