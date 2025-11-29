import 'chess_engine.dart';
import 'chess_engine_factory_native.dart'
    if (dart.library.html) 'chess_engine_factory_web.dart'
    as engine_impl;

/// Factory to create the appropriate chess engine for the platform
class ChessEngineFactory {
  static ChessEngine create() => engine_impl.createChessEngine();
}
