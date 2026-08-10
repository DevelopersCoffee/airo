import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:feature_mind/src/provenance/presentation/widgets/entity_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _entity = ExtractedEntity(text: 'Dr. Rao', type: EntityType.person);

void main() {
  testWidgets('renders the entity text and its type', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityChip(entity: _entity, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Dr. Rao'), findsOneWidget);
    expect(find.text('person'), findsOneWidget);
  });

  testWidgets('R02 — a chip is at least 48 logical pixels tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityChip(entity: _entity, onTap: () {}),
        ),
      ),
    );

    final size = tester.getSize(find.byType(EntityChip));
    expect(size.height, greaterThanOrEqualTo(EntityChip.minimumTarget));
  });

  testWidgets('R02 — tapping the chip calls through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityChip(entity: _entity, onTap: () => taps++),
        ),
      ),
    );

    await tester.tap(find.byType(EntityChip));
    expect(taps, 1);
  });

  testWidgets('carries a semantic label naming the entity and its type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityChip(entity: _entity, onTap: () {}),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(EntityChip));
    expect(semantics.label, contains('Dr. Rao'));
    expect(semantics.label, contains('person'));
  });
}
