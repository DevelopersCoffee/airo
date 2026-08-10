import 'package:flutter/foundation.dart';

import '../runtime/models/log_models.dart';
import '../runtime/ports/operation_log_port.dart';
import 'runtime_console_models.dart';

/// Drives the Windows/Linux Runtime Console (surface 13, issue #1460).
///
/// The one rule the whole class exists to enforce: it never asks
/// [OperationLogPort] for more than a page at a time. [count] tells it how
/// big the log is; [range] hands back rows [pageSize] at a time as the table
/// scrolls. A table over 12,000+ signed ops stays responsive only if nothing
/// ever materialises all of them, in this class or the fixture behind it.
class RuntimeConsoleController extends ChangeNotifier {
  RuntimeConsoleController({
    required OperationLogPort log,
    this.pageSize = 50,
    // ignore: prefer_initializing_formals
  }) : _log = log;

  final OperationLogPort _log;

  /// Rows fetched per [OperationLogPort.range] call.
  final int pageSize;

  final List<MindOp> _loaded = [];
  int _totalCount = 0;
  bool _isLoadingPage = false;
  bool _initialized = false;
  Object? _loadError;

  RuntimeConsoleSortField _sortField = RuntimeConsoleSortField.sequence;
  RuntimeConsoleSortDirection _sortDirection =
      RuntimeConsoleSortDirection.descending;
  MindOpKind? _kindFilter;

  /// Signature states the console has re-checked, keyed by sequence.
  ///
  /// Verifying is per-row and explicit (`verify(sequence)`), so a row keeps
  /// showing the log's stored state until someone asks for a fresh check —
  /// the console must never silently replace "unverified" with a guess.
  final Map<int, SignatureState> _verifiedOverride = {};
  final Set<int> _verifying = {};
  final Set<int> _verifyFailed = {};

  /// Replay progress by starting sequence. Absent means "not replaying."
  /// `1.0` means finished; the entry is kept so a caller can render "done"
  /// for a beat before clearing it explicitly with [dismissReplay].
  final Map<int, double> _replayProgress = {};
  final Set<int> _replayFailed = {};

  // --- Loading state ---------------------------------------------------

  int get totalCount => _totalCount;
  int get loadedCount => _loaded.length;
  bool get isLoadingPage => _isLoadingPage;
  bool get hasMore => _loaded.length < _totalCount;
  Object? get loadError => _loadError;

  /// Fetches the log's size and the first page. Safe to call more than once;
  /// only the first call does anything.
  Future<void> loadInitial() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _totalCount = await _log.count();
      _loadError = null;
    } catch (error) {
      _loadError = error;
      notifyListeners();
      return;
    }
    await _loadNextPage();
  }

  /// Fetches the next page. No-op while a page is already loading or once
  /// every row up to [totalCount] is loaded.
  Future<void> loadMore() async {
    if (_isLoadingPage || !hasMore) return;
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    _isLoadingPage = true;
    notifyListeners();
    try {
      final page = await _log.range(offset: _loaded.length, limit: pageSize);
      _loaded.addAll(page);
      _loadError = null;
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoadingPage = false;
      notifyListeners();
    }
  }

  // --- Sorting and filtering -------------------------------------------

  RuntimeConsoleSortField get sortField => _sortField;
  RuntimeConsoleSortDirection get sortDirection => _sortDirection;
  MindOpKind? get kindFilter => _kindFilter;

  /// Rows currently on screen: the loaded buffer, filtered, then sorted.
  ///
  /// Sorting reorders only what is already loaded — never a reason by itself
  /// to fetch further pages.
  List<MindOp> get rows {
    Iterable<MindOp> visible = _loaded;
    final filter = _kindFilter;
    if (filter != null) {
      visible = visible.where((op) => op.kind == filter);
    }
    final sorted = visible.toList()..sort(_compare);
    return List.unmodifiable(sorted);
  }

  /// Sorts by [field]. Tapping the column already sorted by flips direction,
  /// matching the header-click convention every sortable table uses.
  void sortBy(RuntimeConsoleSortField field) {
    if (_sortField == field) {
      _sortDirection = _sortDirection == RuntimeConsoleSortDirection.ascending
          ? RuntimeConsoleSortDirection.descending
          : RuntimeConsoleSortDirection.ascending;
    } else {
      _sortField = field;
      _sortDirection = RuntimeConsoleSortDirection.descending;
    }
    notifyListeners();
  }

  void filterByKind(MindOpKind? kind) {
    _kindFilter = kind;
    notifyListeners();
  }

  int _compare(MindOp a, MindOp b) {
    final sign = _sortDirection == RuntimeConsoleSortDirection.ascending
        ? 1
        : -1;
    switch (_sortField) {
      case RuntimeConsoleSortField.sequence:
        return sign * a.sequence.compareTo(b.sequence);
      case RuntimeConsoleSortField.time:
        return sign * a.recordedAtMs.compareTo(b.recordedAtMs);
      case RuntimeConsoleSortField.kind:
        return sign * a.kind.name.compareTo(b.kind.name);
      case RuntimeConsoleSortField.title:
        return sign * a.title.compareTo(b.title);
      case RuntimeConsoleSortField.device:
        return sign * a.deviceName.compareTo(b.deviceName);
    }
  }

  // --- Per-row signature verification -----------------------------------

  /// The signature state to render for [op]: a fresh check if one has been
  /// run, otherwise the state the log already carried.
  SignatureState signatureFor(MindOp op) =>
      _verifiedOverride[op.sequence] ?? op.signature;

  bool isVerifying(int sequence) => _verifying.contains(sequence);

  bool didVerifyFail(int sequence) => _verifyFailed.contains(sequence);

  /// Re-checks [sequence]'s signature against the device certificate that
  /// claims it. A row's rendering must follow this fresh result, not linger
  /// on the stale one it started with.
  Future<void> verifyRow(int sequence) async {
    _verifying.add(sequence);
    _verifyFailed.remove(sequence);
    notifyListeners();
    try {
      final state = await _log.verify(sequence);
      _verifiedOverride[sequence] = state;
    } catch (_) {
      _verifyFailed.add(sequence);
    } finally {
      _verifying.remove(sequence);
      notifyListeners();
    }
  }

  // --- Replay from a row --------------------------------------------------

  /// Fraction complete for a replay started at [sequence], or `null` when no
  /// replay is running or has finished for that row.
  double? replayProgressFor(int sequence) => _replayProgress[sequence];

  bool isReplaying(int sequence) {
    final progress = _replayProgress[sequence];
    return progress != null && progress < 1.0;
  }

  bool didReplayFail(int sequence) => _replayFailed.contains(sequence);

  /// Replays the log from [sequence] forward. This is a real operation
  /// against the port, not a view filter — right-clicking a row and choosing
  /// "replay from here" runs the log's own replay, and the console renders
  /// its progress as it comes in rather than a spinner over an unbounded
  /// wait.
  Future<void> replayFrom(int sequence) async {
    _replayProgress[sequence] = 0.0;
    _replayFailed.remove(sequence);
    notifyListeners();
    try {
      await for (final fraction in _log.replayFrom(sequence)) {
        _replayProgress[sequence] = fraction;
        notifyListeners();
      }
    } catch (_) {
      _replayFailed.add(sequence);
      _replayProgress.remove(sequence);
      notifyListeners();
    }
  }

  /// Clears a finished or failed replay's progress so the row returns to its
  /// resting state.
  void dismissReplay(int sequence) {
    _replayProgress.remove(sequence);
    _replayFailed.remove(sequence);
    notifyListeners();
  }
}
