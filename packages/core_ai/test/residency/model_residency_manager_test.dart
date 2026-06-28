import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelResidencyPolicy', () {
    const policy = ModelResidencyPolicy();

    test('evicts opposite generation models before other residents', () {
      const currentResidents = [
        ModelResidentSpec(
          id: 'image-xl',
          residentType: ResidentRuntimeType.image,
          estimatedMemoryBytes: 900,
        ),
        ModelResidentSpec(
          id: 'classifier',
          residentType: ResidentRuntimeType.classifier,
          estimatedMemoryBytes: 200,
          pinned: true,
        ),
        ModelResidentSpec(
          id: 'tts-sidecar',
          residentType: ResidentRuntimeType.tts,
          estimatedMemoryBytes: 250,
          sidecar: true,
        ),
      ];
      const incoming = ModelResidentSpec(
        id: 'text-primary',
        residentType: ResidentRuntimeType.text,
        estimatedMemoryBytes: 700,
      );

      final plan = policy.plan(
        currentResidents: currentResidents,
        incoming: incoming,
        budgetBytes: 1500,
      );

      expect(plan.fits, isTrue);
      expect(plan.residentsToEvict.map((resident) => resident.id), [
        'image-xl',
      ]);
    });

    test(
      'keeps pinned classifier resident and uses sidecars as last resort',
      () {
        const currentResidents = [
          ModelResidentSpec(
            id: 'helper-text',
            residentType: ResidentRuntimeType.text,
            estimatedMemoryBytes: 600,
          ),
          ModelResidentSpec(
            id: 'tts-sidecar',
            residentType: ResidentRuntimeType.tts,
            estimatedMemoryBytes: 300,
            sidecar: true,
          ),
          ModelResidentSpec(
            id: 'classifier',
            residentType: ResidentRuntimeType.classifier,
            estimatedMemoryBytes: 100,
            pinned: true,
          ),
        ];
        const incoming = ModelResidentSpec(
          id: 'image-xl',
          residentType: ResidentRuntimeType.image,
          estimatedMemoryBytes: 1000,
        );

        final plan = policy.plan(
          currentResidents: currentResidents,
          incoming: incoming,
          budgetBytes: 1200,
        );

        expect(plan.fits, isTrue);
        expect(plan.residentsToEvict.map((resident) => resident.id), [
          'helper-text',
          'tts-sidecar',
        ]);
        expect(
          plan.residentsToEvict.map((resident) => resident.id),
          isNot(contains('classifier')),
        );
      },
    );

    test('refuses loads that still cannot fit after allowed evictions', () {
      const currentResidents = [
        ModelResidentSpec(
          id: 'classifier',
          residentType: ResidentRuntimeType.classifier,
          estimatedMemoryBytes: 400,
          pinned: true,
        ),
      ];
      const incoming = ModelResidentSpec(
        id: 'huge-image',
        residentType: ResidentRuntimeType.image,
        estimatedMemoryBytes: 1600,
      );

      final plan = policy.plan(
        currentResidents: currentResidents,
        incoming: incoming,
        budgetBytes: 1200,
      );

      expect(plan.fits, isFalse);
      expect(plan.refusalReason, isNotEmpty);
    });
  });

  group('ModelResidencyManager', () {
    late ModelResidencyManager manager;

    setUp(() {
      manager = ModelResidencyManager(loadBudgetBytes: () async => 1500);
    });

    test('canLoadWithoutEviction gates background warmups', () async {
      manager.markResident(
        const ModelResidentSpec(
          id: 'existing-text',
          residentType: ResidentRuntimeType.text,
          estimatedMemoryBytes: 1100,
        ),
      );

      final canLoad = await manager.canLoadWithoutEviction(
        const ModelResidentSpec(
          id: 'stt-sidecar',
          residentType: ResidentRuntimeType.stt,
          estimatedMemoryBytes: 500,
          sidecar: true,
        ),
      );

      expect(canLoad, isFalse);
      expect(manager.residents.map((resident) => resident.id), [
        'existing-text',
      ]);
    });

    test('ensureResident loads and tracks a new resident', () async {
      final result = await manager.ensureResident(
        const ModelResidentSpec(
          id: 'text-primary',
          residentType: ResidentRuntimeType.text,
          estimatedMemoryBytes: 700,
        ),
        onLoad: () async => true,
      );

      expect(result.status, EnsureResidentStatus.loaded);
      expect(manager.isResident('text-primary'), isTrue);
    });

    test(
      'makeRoomFor does not evict when the incoming runtime cannot fit',
      () async {
        manager.markResident(
          const ModelResidentSpec(
            id: 'classifier',
            residentType: ResidentRuntimeType.classifier,
            estimatedMemoryBytes: 500,
            pinned: true,
          ),
        );

        final evicted = <String>[];
        final plan = await manager.makeRoomFor(
          const ModelResidentSpec(
            id: 'huge-image',
            residentType: ResidentRuntimeType.image,
            estimatedMemoryBytes: 1600,
          ),
          onEvict: (resident) async => evicted.add(resident.id),
        );

        expect(plan.fits, isFalse);
        expect(evicted, isEmpty);
        expect(manager.residents.map((resident) => resident.id), [
          'classifier',
        ]);
      },
    );

    test('runExclusive serializes concurrent work', () async {
      final events = <String>[];

      Future<void> task(String id) {
        return manager.runExclusive<void>(id, () async {
          events.add('start:$id');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          events.add('end:$id');
        });
      }

      await Future.wait([task('a'), task('b')]);

      expect(events, ['start:a', 'end:a', 'start:b', 'end:b']);
    });
  });
}
