import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  test('hard cap rejects a fifth session without opening it', () async {
    final opened = <_FakeSession>[];
    final pool = AiroMultiviewPool(decoderBudget: 99);

    for (var index = 0; index < 4; index++) {
      final id = 'channel-$index';
      expect(
        await pool.add(
          id: id,
          openSession: () async {
            final session = _FakeSession(id);
            opened.add(session);
            return session;
          },
        ),
        AiroMultiviewAddResult.added,
      );
    }
    var fifthFactoryCalled = false;
    expect(
      await pool.add(
        id: 'channel-4',
        openSession: () async {
          fifthFactoryCalled = true;
          return _FakeSession('channel-4');
        },
      ),
      AiroMultiviewAddResult.capacityReached,
    );

    expect(pool.capacity, kAiroMultiviewHardCap);
    expect(pool.state.count, 4);
    expect(fifthFactoryCalled, isFalse);
    expect(opened.where((session) => session.audible), [opened.first]);
    await pool.close();
  });

  test('lower decoder budget rejects excess sessions', () async {
    final pool = AiroMultiviewPool(decoderBudget: 2);
    var factoryCalls = 0;

    for (final id in ['one', 'two']) {
      expect(
        await pool.add(
          id: id,
          openSession: () async {
            factoryCalls++;
            return _FakeSession(id);
          },
        ),
        AiroMultiviewAddResult.added,
      );
    }
    expect(
      await pool.add(
        id: 'three',
        openSession: () async {
          factoryCalls++;
          return _FakeSession('three');
        },
      ),
      AiroMultiviewAddResult.capacityReached,
    );
    expect(factoryCalls, 2);
    await pool.close();
  });

  test('promotion keeps exactly one session audible', () async {
    final sessions = <String, _FakeSession>{};
    final pool = AiroMultiviewPool(decoderBudget: 4);
    for (final id in ['one', 'two', 'three']) {
      await pool.add(
        id: id,
        openSession: () async =>
            sessions.putIfAbsent(id, () => _FakeSession(id)),
      );
    }

    await pool.promote('three');

    expect(pool.state.featuredSessionId, 'three');
    expect(
      sessions.values.where((session) => session.audible).single.id,
      'three',
    );
    await pool.close();
  });

  test('removing featured promotes next and close disposes all', () async {
    final sessions = <String, _FakeSession>{};
    final pool = AiroMultiviewPool(decoderBudget: 4);
    for (final id in ['one', 'two', 'three']) {
      await pool.add(
        id: id,
        openSession: () async =>
            sessions.putIfAbsent(id, () => _FakeSession(id)),
      );
    }

    await pool.remove('one');

    expect(pool.state.featuredSessionId, 'two');
    expect(sessions['one']!.closed, isTrue);
    expect(
      sessions.values.where((session) => session.audible).single.id,
      'two',
    );

    await pool.close();
    expect(sessions.values.every((session) => session.closed), isTrue);
    expect(sessions.values.every((session) => !session.audible), isTrue);
  });

  test('open failure leaves pool unchanged', () async {
    final pool = AiroMultiviewPool(decoderBudget: 4);

    expect(
      await pool.add(
        id: 'broken',
        openSession: () async => throw StateError('decoder failed'),
      ),
      AiroMultiviewAddResult.openFailed,
    );
    expect(pool.state.count, 0);
    await pool.close();
  });
}

class _FakeSession implements AiroMultiviewSession {
  _FakeSession(this.id);

  @override
  final String id;
  bool audible = false;
  bool closed = false;

  @override
  Future<void> setAudible(bool value) async {
    audible = value;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
