import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  group('PersonalChannelRepository', () {
    late _MemoryStore store;
    late PersonalChannelRepository repository;

    setUp(() {
      store = _MemoryStore();
      repository = PersonalChannelRepository(store);
    });

    test('stores, reads, updates, and removes one direct stream', () async {
      final first = await repository.upsert(
        name: '9XM',
        streamUrl: 'https://media.example.com/9xm/master.m3u8',
      );
      final updated = await repository.upsert(
        name: '9XM HD',
        streamUrl: 'https://media.example.com/9xm/master.m3u8',
      );

      expect(updated.id, first.id);
      expect(await repository.list(), [updated]);
      expect(
        (await repository.findByStreamUrl(updated.streamUrl))?.name,
        '9XM HD',
      );

      await repository.remove(updated.id);
      expect(await repository.list(), isEmpty);
    });

    test('uses a stable personal id for normalized URLs', () {
      final first = repository.buildChannel(
        name: 'Channel',
        streamUrl: 'HTTPS://MEDIA.EXAMPLE.COM/live.m3u8',
      );
      final second = repository.buildChannel(
        name: 'Renamed',
        streamUrl: 'https://media.example.com/live.m3u8',
      );

      expect(first.id, second.id);
      expect(first.group, 'Personal Channels');
    });

    test('rejects private and credential-bearing shared streams', () {
      expect(
        () => repository.buildChannel(
          name: 'Private',
          streamUrl: 'http://192.168.1.10/live.m3u8',
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.buildChannel(
          name: 'Secret',
          streamUrl: 'https://media.example.com/live.m3u8?token=secret',
        ),
        throwsArgumentError,
      );
    });

    test('drops corrupt indexed records without failing the library', () async {
      await store.setStringList('personal_channels.index.v1', ['broken']);
      await store.setString('personal_channels.record.v1.broken', '{not-json');

      expect(await repository.list(), isEmpty);
      expect(await store.getStringList('personal_channels.index.v1'), isEmpty);
    });
  });
}

final class _MemoryStore implements KeyValueStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool> clear() async {
    _values.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async =>
      (_values[key] as List<String>?)?.toList();

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _values[key] = value.toList();
    return true;
  }
}
