// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'phone_media_seekable_source.dart';

typedef _MallocNative = Pointer<Void> Function(IntPtr);
typedef _MallocDart = Pointer<Void> Function(int);
typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);
typedef _PreadNative = IntPtr Function(Int32, Pointer<Void>, IntPtr, Int64);
typedef _PreadDart = int Function(int, Pointer<Void>, int, int);

const _chunkSize = 256 * 1024;

/// Random-access source backed by a descriptor retained by the host platform.
///
/// Reads run on short-lived isolates and transfer bounded byte chunks without
/// reopening `/proc/self/fd` or copying the complete media asset.
class NativeDescriptorPhoneMediaSource implements PhoneMediaSeekableSource {
  NativeDescriptorPhoneMediaSource({
    required int descriptor,
    required int mediaLength,
  }) : _descriptor = descriptor,
       _mediaLength = mediaLength;

  final int _descriptor;
  final int _mediaLength;
  bool _closed = false;

  @override
  bool get isAvailable => !_closed && _descriptor >= 0 && _mediaLength >= 0;

  @override
  Future<int> length() async {
    if (_closed) {
      throw const PhoneMediaSourceException(PhoneMediaSourceFailureCode.closed);
    }
    if (!isAvailable) {
      throw const PhoneMediaSourceException(
        PhoneMediaSourceFailureCode.unavailable,
      );
    }
    return _mediaLength;
  }

  @override
  Stream<List<int>> openRead(int start, int end) {
    if (_closed) {
      return Stream.error(
        const PhoneMediaSourceException(PhoneMediaSourceFailureCode.closed),
      );
    }
    if (start < 0 || end < start || end > _mediaLength) {
      return Stream.error(
        const PhoneMediaSourceException(PhoneMediaSourceFailureCode.readFailed),
      );
    }
    return _readInWorker(_descriptor, start, end);
  }

  void close() => _closed = true;
}

Stream<List<int>> _readInWorker(int descriptor, int start, int end) {
  late StreamController<List<int>> controller;
  final events = ReceivePort();
  Isolate? worker;
  StreamSubscription<Object?>? subscription;
  var offset = start;

  Future<void> finish() async {
    await subscription?.cancel();
    events.close();
    worker?.kill(priority: Isolate.immediate);
    if (!controller.isClosed) await controller.close();
  }

  controller = StreamController<List<int>>(
    onListen: () async {
      try {
        worker = await Isolate.spawn(_descriptorReaderWorker, events.sendPort);
        subscription = events.listen((message) {
          if (message is SendPort) {
            final remaining = end - offset;
            if (remaining == 0) {
              unawaited(finish());
            } else {
              message.send([
                descriptor,
                offset,
                remaining < _chunkSize ? remaining : _chunkSize,
              ]);
            }
            return;
          }
          if (message is TransferableTypedData) {
            final bytes = message.materialize().asUint8List();
            offset += bytes.length;
            controller.add(bytes);
            if (offset >= end) {
              unawaited(finish());
            }
            return;
          }
          controller.addError(
            const PhoneMediaSourceException(
              PhoneMediaSourceFailureCode.readFailed,
            ),
          );
          unawaited(finish());
        });
      } catch (_) {
        controller.addError(
          const PhoneMediaSourceException(
            PhoneMediaSourceFailureCode.readFailed,
          ),
        );
        await finish();
      }
    },
    onCancel: finish,
  );
  return controller.stream;
}

void _descriptorReaderWorker(SendPort events) {
  final commands = ReceivePort();
  events.send(commands.sendPort);
  final library = DynamicLibrary.process();
  final malloc = library.lookupFunction<_MallocNative, _MallocDart>('malloc');
  final free = library.lookupFunction<_FreeNative, _FreeDart>('free');
  final pread = library.lookupFunction<_PreadNative, _PreadDart>(
    Platform.isAndroid ? 'pread64' : 'pread',
  );
  commands.listen((message) {
    if (message is! List || message.length != 3) {
      events.send('read_failed');
      return;
    }
    final descriptor = message[0] as int;
    final offset = message[1] as int;
    final count = message[2] as int;
    final buffer = malloc(count);
    try {
      final bytesRead = pread(descriptor, buffer, count, offset);
      if (bytesRead <= 0) {
        events.send('read_failed');
        return;
      }
      final bytes = Uint8List.fromList(
        buffer.cast<Uint8>().asTypedList(bytesRead),
      );
      events.send(TransferableTypedData.fromList([bytes]));
      events.send(commands.sendPort);
    } finally {
      free(buffer);
    }
  });
}
