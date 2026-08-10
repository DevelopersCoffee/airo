import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';

/// A fake with N synthetic ops and instrumentation the controller tests
/// assert against: how [range] was called (so a test can prove the console
/// never asks for the whole log), and injectable failures for the
/// non-happy-path tests.
class FakeOperationLogPort implements OperationLogPort {
  FakeOperationLogPort({required int opCount}) : _total = opCount {
    _ops = List.generate(opCount, (i) {
      final sequence = opCount - i; // descending, newest first
      return MindOp(
        sequence: sequence,
        kind: MindOpKind.values[i % MindOpKind.values.length],
        title: 'Op $sequence',
        contextId: 'ctx-${i % 3}',
        deviceName: i.isEven ? 'Pixel 9 Pro' : 'Desktop',
        signature: i % 5 == 0
            ? SignatureState.unverified
            : i % 7 == 0
            ? SignatureState.unsigned
            : SignatureState.verified,
        recordedAtMs: 1000000 - i * 1000,
      );
    });
  }

  final int _total;
  late final List<MindOp> _ops;

  /// Every call this fake received, in order. Tests assert against this to
  /// prove the console pages rather than bulk-loading.
  final List<({int offset, int limit})> rangeCalls = [];

  /// When set, [count] throws this instead of returning a value.
  Object? countError;

  /// When set, [range] throws this instead of returning a page.
  Object? rangeError;

  /// Sequence -> the state [verify] should return. Absent means "throw."
  final Map<int, SignatureState> verifyResults = {};

  /// Sequence -> the progress steps [replayFrom] should emit. Absent means
  /// "throw partway through" for the failure test.
  final Map<int, List<double>> replaySteps = {};
  final List<int> replayFromCalls = [];

  @override
  Future<int> count() async {
    if (countError != null) throw countError!;
    return _total;
  }

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async {
    rangeCalls.add((offset: offset, limit: limit));
    if (rangeError != null) throw rangeError!;
    if (offset >= _ops.length) return const [];
    return _ops.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<MindOp?> bySequence(int sequence) async {
    for (final op in _ops) {
      if (op.sequence == sequence) return op;
    }
    return null;
  }

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async => throw UnimplementedError();

  @override
  Future<SignatureState> verify(int sequence) async {
    final result = verifyResults[sequence];
    if (result == null) throw StateError('verify($sequence) not stubbed');
    return result;
  }

  @override
  Stream<double> replayFrom(int sequence) async* {
    replayFromCalls.add(sequence);
    final steps = replaySteps[sequence];
    if (steps == null) {
      throw StateError('replayFrom($sequence) not stubbed');
    }
    for (final step in steps) {
      yield step;
    }
  }
}
