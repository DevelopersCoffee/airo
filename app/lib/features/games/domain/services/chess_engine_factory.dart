import 'chess_engine.dart';
// Stub-by-default: dart.library.html is false under dart2wasm, so keying the
// web factory off html would link the real (dart:io-backed) native factory
// into a wasm web build. Keying the NATIVE file off dart.library.io makes
// every non-native target -- js web and wasm web alike -- fall back to the
// web factory.
import 'chess_engine_factory_web.dart'
    if (dart.library.io) 'chess_engine_factory_native.dart'
    as engine_impl;

/// Factory to create the appropriate chess engine for the platform
class ChessEngineFactory {
  static ChessEngine create() => engine_impl.createChessEngine();
}
