import 'dart:io';

import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late NotesCapability capability;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notes_screen_');
    final log = await NotesOperationLog.open('${tempDir.path}/notes.log');
    capability = NotesCapability(log);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  // `NotesScreen` does real `dart:io` file I/O (through `NotesCapability` /
  // `NotesOperationLog`) on load and after every mutation. Everything inside
  // a `testWidgets` body -- not just `pump` calls -- runs inside
  // `AutomatedTestWidgetsFlutterBinding`'s fake-async zone, and a real (not
  // `Timer`-based) I/O future never resolves there: it needs an actual event
  // -loop turn the fake zone does not deliver. Two consequences, both worked
  // around below:
  //
  // - `pumpAndSettle` alone either times out (the initial load's
  //   indeterminate `CircularProgressIndicator` schedules frames forever) or
  //   returns before the I/O actually lands -- [settle] uses
  //   `WidgetTester.runAsync` to step outside the fake zone so the real
  //   future genuinely completes, then pumps to apply the `setState` it
  //   triggered.
  // - Any *direct* `await` on [NotesCapability] from inside a `testWidgets`
  //   body (setup fixtures, or reading the projection to assert against) has
  //   the same problem and needs the same `runAsync` wrapper -- see
  //   `directly` below. `setUp`/`tearDown` are unaffected: `package:test`
  //   runs those outside the per-test fake zone.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    // Whatever is left at this point is pure animation (dialog transitions),
    // which -- unlike the spinner above -- does settle.
    await tester.pumpAndSettle();
  }

  /// Runs a real `NotesCapability`/`NotesOperationLog` future from inside a
  /// `testWidgets` body, outside the fake-async zone that would otherwise
  /// hang it forever.
  Future<T> directly<T>(WidgetTester tester, Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    return result as T;
  }

  testWidgets('renders from the projection: empty log shows the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(NotesScreen(capability: capability)));
    await settle(tester);

    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets(
    'creating a note through the UI persists it and the list reflects the projection',
    (tester) async {
      await tester.pumpWidget(wrap(NotesScreen(capability: capability)));
      await settle(tester);

      await tester.tap(find.byKey(const Key('notes_screen_create_button')));
      await settle(tester);

      await tester.enterText(
        find.byKey(const Key('notes_screen_title_field')),
        'Weekend plan',
      );
      await tester.enterText(
        find.byKey(const Key('notes_screen_body_field')),
        'Hike then brunch',
      );
      await tester.tap(find.byKey(const Key('notes_screen_save_button')));
      await settle(tester);

      expect(find.text('Weekend plan'), findsOneWidget);
      expect(find.text('Hike then brunch'), findsOneWidget);

      // The UI's own state came from a fresh projection read, not from
      // holding onto what it just wrote -- prove the capability's log
      // actually has it, independent of the widget under test.
      final projection = await directly(tester, capability.notes);
      expect(projection.length, 1);
      expect(projection.all.single.title, 'Weekend plan');
    },
  );

  testWidgets('editing a note through the UI updates the projection', (
    tester,
  ) async {
    await directly(
      tester,
      () => capability.createNote(
        id: 'n1',
        title: 'Original',
        body: 'first draft',
        recordedAtMs: 1,
      ),
    );

    await tester.pumpWidget(wrap(NotesScreen(capability: capability)));
    await settle(tester);

    await tester.tap(find.text('Original'));
    await settle(tester);

    await tester.enterText(
      find.byKey(const Key('notes_screen_title_field')),
      'Revised',
    );
    await tester.tap(find.byKey(const Key('notes_screen_save_button')));
    await settle(tester);

    expect(find.text('Revised'), findsOneWidget);
    expect(find.text('Original'), findsNothing);

    final projection = await directly(tester, capability.notes);
    expect(projection.get('n1')!.title, 'Revised');
  });

  testWidgets('deleting a note through the UI removes it from the projection', (
    tester,
  ) async {
    await directly(
      tester,
      () => capability.createNote(
        id: 'n1',
        title: 'Gone soon',
        body: '',
        recordedAtMs: 1,
      ),
    );

    await tester.pumpWidget(wrap(NotesScreen(capability: capability)));
    await settle(tester);

    expect(find.text('Gone soon'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);

    expect(find.text('Gone soon'), findsNothing);
    expect(find.text('No notes yet'), findsOneWidget);

    final projection = await directly(tester, capability.notes);
    expect(projection.isEmpty, isTrue);
  });
}
