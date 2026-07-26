import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

typedef _OpenNative = Int32 Function(Pointer<Uint8>, Int32);
typedef _OpenDart = int Function(Pointer<Uint8>, int);
typedef _CloseNative = Int32 Function(Int32);
typedef _CloseDart = int Function(int);
typedef _MallocNative = Pointer<Void> Function(IntPtr);
typedef _MallocDart = Pointer<Void> Function(int);
typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);

void main() {
  test(
    'reads a bounded high-offset range from a retained descriptor',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'native_descriptor_source',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bytes = List<int>.generate(1024 * 1024, (index) => index % 251);
      final file = File('${directory.path}/media.bin');
      await file.writeAsBytes(bytes);
      final descriptor = _openReadOnly(file.path);
      addTearDown(() => _close(descriptor));
      final source = NativeDescriptorPhoneMediaSource(
        descriptor: descriptor,
        mediaLength: bytes.length,
      );

      const start = 900000;
      const end = start + 4096;
      final actual = await source
          .openRead(start, end)
          .fold<List<int>>([], (all, chunk) => all..addAll(chunk));

      expect(actual, bytes.sublist(start, end));
      source.close();
      expect(
        source.openRead(0, 1),
        emitsError(
          isA<PhoneMediaSourceException>().having(
            (error) => error.code,
            'code',
            PhoneMediaSourceFailureCode.closed,
          ),
        ),
      );
    },
  );
}

int _openReadOnly(String path) {
  final library = DynamicLibrary.process();
  final open = library.lookupFunction<_OpenNative, _OpenDart>('open');
  final malloc = library.lookupFunction<_MallocNative, _MallocDart>('malloc');
  final free = library.lookupFunction<_FreeNative, _FreeDart>('free');
  final encoded = utf8.encode(path);
  final pointer = malloc(encoded.length + 1).cast<Uint8>();
  try {
    pointer.asTypedList(encoded.length + 1)
      ..setRange(0, encoded.length, encoded)
      ..[encoded.length] = 0;
    final descriptor = open(pointer, 0);
    if (descriptor < 0) throw StateError('Could not open test descriptor.');
    return descriptor;
  } finally {
    free(pointer.cast<Void>());
  }
}

void _close(int descriptor) {
  final close = DynamicLibrary.process()
      .lookupFunction<_CloseNative, _CloseDart>('close');
  close(descriptor);
}
