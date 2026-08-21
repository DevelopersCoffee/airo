import 'dart:io';

import 'package:feature_mind/src/notebook/application/notebook_share_port.dart';
import 'package:feature_mind/src/notebook/application/super_summary_recap_port.dart';
import 'package:feature_mind/src/notebook/domain/notebook_document.dart';
import 'package:feature_mind/src/notes/domain/notes_operation_log.dart';
import 'package:feature_mind/src/notes/notes_capability.dart';
import 'package:feature_mind/src/notes/presentation/notes_screen.dart';
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

  testWidgets('search and tag chips filter the library', (tester) async {
    await directly(tester, () async {
      await capability.createNote(
        id: 'n1',
        title: 'Standup',
        body: const NotebookDocument(
          body: 'pods',
          tags: ['work'],
          summary: 'Adopt Kubernetes',
        ).encode(),
        recordedAtMs: 1,
      );
      await capability.createNote(
        id: 'n2',
        title: 'Lecture',
        body: const NotebookDocument(
          transcript: 'backpropagation',
          tags: ['study'],
        ).encode(),
        recordedAtMs: 2,
      );
    });

    await tester.pumpWidget(wrap(NotesScreen(capability: capability)));
    await settle(tester);

    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Lecture'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('notes_screen_search_field')),
      'kubernetes',
    );
    await tester.pump();
    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Lecture'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('notes_screen_search_field')),
      '',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('notes_screen_tag_chip_study')));
    await tester.pump();
    expect(find.text('Lecture'), findsOneWidget);
    expect(find.text('Standup'), findsNothing);
  });

  testWidgets('Super Summary combines two selected notes', (tester) async {
    await directly(tester, () async {
      await capability.createNote(
        id: 'a',
        title: 'One',
        body: const NotebookDocument(
          summary: 'First',
          keyPoints: ['Do A'],
        ).encode(),
        recordedAtMs: 1,
      );
      await capability.createNote(
        id: 'b',
        title: 'Two',
        body: const NotebookDocument(
          summary: 'Second',
          keyPoints: ['Do B'],
        ).encode(),
        recordedAtMs: 2,
      );
    });

    await tester.pumpWidget(wrap(NotesScreen(capability: capability)));
    await settle(tester);

    await tester.tap(
      find.byKey(const Key('notes_screen_super_summary_button')),
    );
    await tester.pump();
    await tester.tap(find.text('One'));
    await tester.tap(find.text('Two'));
    await tester.tap(find.byKey(const Key('notes_screen_combine_button')));
    await settle(tester);

    expect(find.text('Super summary · 2 notes'), findsOneWidget);
    final projection = await directly(tester, capability.notes);
    expect(projection.length, 3);
  });

  testWidgets(
    'Super Summary uses the generated recap when the port returns one',
    (tester) async {
      await directly(tester, () async {
        await capability.createNote(
          id: 'a',
          title: 'One',
          body: const NotebookDocument(summary: 'First').encode(),
          recordedAtMs: 1,
        );
        await capability.createNote(
          id: 'b',
          title: 'Two',
          body: const NotebookDocument(summary: 'Second').encode(),
          recordedAtMs: 2,
        );
      });

      var asked = false;
      final recapPort = SuperSummaryRecapPort((notes) async {
        asked = true;
        expect(notes.map((n) => n.title), ['One', 'Two']);
        return '''
# Summary
LLM recap of both threads.

# Key points
- Call the customer
''';
      });

      await tester.pumpWidget(
        wrap(NotesScreen(capability: capability, recapPort: recapPort)),
      );
      await settle(tester);

      await tester.tap(
        find.byKey(const Key('notes_screen_super_summary_button')),
      );
      await tester.pump();
      await tester.tap(find.text('One'));
      await tester.tap(find.text('Two'));
      await tester.tap(find.byKey(const Key('notes_screen_combine_button')));
      await settle(tester);

      expect(asked, isTrue);
      expect(find.text('Super summary · 2 notes'), findsOneWidget);
      final projection = await directly(tester, capability.notes);
      final recap = projection.all.singleWhere(
        (note) => note.title.startsWith('Super summary'),
      );
      expect(recap.body, contains('LLM recap of both threads'));
    },
  );

  testWidgets('copy writes markdown through the share port', (tester) async {
    final share = MemoryNotebookSharePort();
    await directly(
      tester,
      () => capability.createNote(
        id: 'n1',
        title: 'Standup',
        body: const NotebookDocument(
          summary: 'Ship Friday.',
          keyPoints: ['Ship Friday'],
        ).encode(),
        recordedAtMs: 1,
      ),
    );

    await tester.pumpWidget(
      wrap(NotesScreen(capability: capability, sharePort: share)),
    );
    await settle(tester);
    await tester.tap(find.text('Standup'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('notes_screen_copy_button')));
    await tester.pump();

    expect(share.lastCopied, contains('# Standup'));
    expect(share.lastCopied, contains('Ship Friday'));
  });

  testWidgets('Hindi locale localizes the empty state', (tester) async {
    await tester.pumpWidget(
      wrap(NotesScreen(capability: capability, localeCode: 'hi')),
    );
    await settle(tester);

    expect(find.text('नोट्स'), findsOneWidget);
    expect(find.text('अभी कोई नोट नहीं'), findsOneWidget);
  });
}
