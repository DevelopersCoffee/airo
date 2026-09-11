import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/anya_repository.dart';
import '../../pdf/syncfusion_anya_pdf_extractor.dart';

final anyaRepositoryProvider = Provider<AnyaRepository>((ref) {
  throw StateError('AnyaRepository must be overridden by the shell');
});

final anyaPdfExtractorProvider = Provider<AnyaPdfTextExtractor>((ref) {
  return const SyncfusionAnyaPdfExtractor();
});

final anyaCatalogProvider = Provider<List<CatalogMeal>>((ref) {
  return seedMealCatalog();
});

/// Clock seam so Today can be tested without depending on the host weekday.
final anyaNowProvider = Provider<DateTime>((ref) => DateTime.now());

class AnyaSessionState {
  const AnyaSessionState({
    this.hydrated = false,
    this.snapshot = const AnyaSnapshot(),
    this.pendingProgram,
    this.pendingValidation,
    this.emptyExtract = false,
    this.busy = false,
    this.errorMessage,
  });

  final bool hydrated;
  final AnyaSnapshot snapshot;
  final DietProgram? pendingProgram;
  final ExtractionValidation? pendingValidation;
  final bool emptyExtract;
  final bool busy;
  final String? errorMessage;

  DietProfile? get profile => snapshot.profile;
  WeeklyPlan? get weeklyPlan => snapshot.weeklyPlan;
  List<DietProgram> get programs => snapshot.programs;
  DietProgram? get activeProgram => snapshot.activeProgram;
  GroceryList get groceryList => snapshot.groceryList;

  AnyaSessionState copyWith({
    bool? hydrated,
    AnyaSnapshot? snapshot,
    DietProgram? pendingProgram,
    ExtractionValidation? pendingValidation,
    bool? emptyExtract,
    bool? busy,
    String? errorMessage,
    bool clearPending = false,
    bool clearError = false,
  }) => AnyaSessionState(
    hydrated: hydrated ?? this.hydrated,
    snapshot: snapshot ?? this.snapshot,
    pendingProgram: clearPending ? null : pendingProgram ?? this.pendingProgram,
    pendingValidation: clearPending
        ? null
        : pendingValidation ?? this.pendingValidation,
    emptyExtract: emptyExtract ?? this.emptyExtract,
    busy: busy ?? this.busy,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

class AnyaSession extends Notifier<AnyaSessionState> {
  @override
  AnyaSessionState build() => const AnyaSessionState();

  AnyaRepository get _repo => ref.read(anyaRepositoryProvider);

  Future<void> hydrate() async {
    final snapshot = await _repo.load();
    state = state.copyWith(hydrated: true, snapshot: snapshot);
  }

  Future<void> saveProfile(DietProfile profile) async {
    await _persistPlan(profile: profile, program: state.activeProgram);
  }

  Future<void> regeneratePlan() async {
    final profile = state.profile;
    if (profile == null) return;
    await _persistPlan(profile: profile, program: state.activeProgram);
  }

  WeeklyPlan _planFor(DietProfile profile, DietProgram? program) {
    return generateWeeklyPlan(
      profile: profile,
      catalog: ref.read(anyaCatalogProvider),
      weekStartIso: _weekStartIso(DateTime.now()),
      importedRules: program?.rules ?? const DietRule(),
    );
  }

  Future<void> _persistPlan({
    required DietProfile profile,
    DietProgram? program,
    AnyaSnapshot? base,
  }) async {
    final snapshot = (base ?? state.snapshot).copyWith(
      profile: profile,
      weeklyPlan: _planFor(profile, program),
    );
    await _repo.save(snapshot);
    state = state.copyWith(snapshot: snapshot);
  }

  Future<void> importPdf({
    required String fileName,
    required List<int> bytes,
  }) async {
    state = state.copyWith(busy: true, emptyExtract: false, clearError: true);
    try {
      final pages = await ref
          .read(anyaPdfExtractorProvider)
          .extractPages(bytes);
      await _normalizeImport(title: fileName, pages: pages);
    } catch (error) {
      state = state.copyWith(
        busy: false,
        errorMessage: 'Could not read this PDF. Try a text-based diet plan.',
      );
    }
  }

  Future<void> importPastedText({
    required String title,
    required String text,
  }) async {
    state = state.copyWith(busy: true, emptyExtract: false, clearError: true);
    final pages = [ExtractedPdfPage(pageNumber: 1, text: text)];
    await _normalizeImport(title: title, pages: pages);
  }

  Future<void> _normalizeImport({
    required String title,
    required List<ExtractedPdfPage> pages,
  }) async {
    final hasText = pages.any((page) => page.hasTextLayer);
    if (!hasText) {
      state = state.copyWith(
        busy: false,
        emptyExtract: true,
        clearPending: true,
      );
      return;
    }
    const normalizer = DietPdfNormalizer();
    final program = normalizer.parseProgram(
      id: 'import_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      pages: pages,
    );
    final validation = normalizer.validate(pages: pages, program: program);
    state = state.copyWith(
      busy: false,
      pendingProgram: program,
      pendingValidation: validation,
      emptyExtract: false,
    );
  }

  void updatePendingProgram(DietProgram program) {
    state = state.copyWith(pendingProgram: program);
  }

  Future<void> confirmPendingProgram() async {
    final program = state.pendingProgram;
    if (program == null) return;
    final programs = [...state.programs, program];
    var snapshot = state.snapshot.copyWith(
      programs: programs,
      activeProgramId: program.id,
    );
    final profile = snapshot.profile;
    if (profile != null) {
      snapshot = snapshot.copyWith(weeklyPlan: _planFor(profile, program));
    }
    await _repo.save(snapshot);
    state = state.copyWith(snapshot: snapshot, clearPending: true);
  }

  Future<void> activateProgram(String id) async {
    var snapshot = state.snapshot.copyWith(activeProgramId: id);
    final profile = snapshot.profile;
    if (profile != null) {
      snapshot = snapshot.copyWith(
        weeklyPlan: _planFor(profile, snapshot.activeProgram),
      );
    }
    await _repo.save(snapshot);
    state = state.copyWith(snapshot: snapshot);
  }

  Future<void> deleteProgram(String id) async {
    final programs = [
      for (final program in state.programs)
        if (program.id != id) program,
    ];
    final clearing = state.snapshot.activeProgramId == id;
    var snapshot = state.snapshot.copyWith(
      programs: programs,
      clearActiveProgram: clearing,
    );
    final profile = snapshot.profile;
    if (profile != null && clearing) {
      snapshot = snapshot.copyWith(weeklyPlan: _planFor(profile, null));
    }
    await _repo.save(snapshot);
    state = state.copyWith(snapshot: snapshot);
  }

  Future<void> swapPlannedMeal({
    required String plannedMealId,
    required CatalogMeal replacement,
  }) async {
    final plan = state.weeklyPlan;
    if (plan == null) return;
    final snapshot = state.snapshot.copyWith(
      weeklyPlan: replacePlannedMeal(
        plan: plan,
        plannedMealId: plannedMealId,
        replacement: replacement,
      ),
    );
    await _repo.save(snapshot);
    state = state.copyWith(snapshot: snapshot);
  }

  Future<void> toggleGroceryLine(String key) async {
    final next = {...state.snapshot.checkedGroceryKeys};
    if (!next.add(key)) next.remove(key);
    final snapshot = state.snapshot.copyWith(checkedGroceryKeys: next);
    await _repo.save(snapshot);
    state = state.copyWith(snapshot: snapshot);
  }
}

final anyaSessionProvider = NotifierProvider<AnyaSession, AnyaSessionState>(
  AnyaSession.new,
);

String _weekStartIso(DateTime now) {
  final monday = now.subtract(Duration(days: now.weekday - DateTime.monday));
  final y = monday.year.toString().padLeft(4, '0');
  final m = monday.month.toString().padLeft(2, '0');
  final d = monday.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
