import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// issues/04-recovery-states.md: dead-link reports must remain local until
// the user explicitly opts to send them -- this storage class never makes
// a network call, only SharedPreferences.
void main() {
  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    return container;
  }

  test('saves and reads back a report, most recent first', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final storage = container.read(deadLinkReportStorageProvider);

    await storage.save(
      DeadLinkReport(
        channelName: 'City News',
        diagnosticCode: 'httpForbidden',
        userMessage: 'Your provider rejected this stream.',
        technicalDetail: 'source=https://example.com',
        reportedAt: DateTime(2026, 1, 1),
      ),
    );
    await storage.save(
      DeadLinkReport(
        channelName: 'Sports 24',
        diagnosticCode: 'timeout',
        userMessage: 'The stream timed out.',
        reportedAt: DateTime(2026, 1, 2),
      ),
    );

    final reports = storage.readAll();
    expect(reports, hasLength(2));
    expect(reports.first.channelName, 'Sports 24');
    expect(reports.last.channelName, 'City News');
    expect(reports.last.technicalDetail, 'source=https://example.com');
  });

  test('bounds stored reports to the most recent 20', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final storage = container.read(deadLinkReportStorageProvider);

    for (var i = 0; i < 25; i++) {
      await storage.save(
        DeadLinkReport(
          channelName: 'Channel $i',
          diagnosticCode: 'timeout',
          userMessage: 'The stream timed out.',
          reportedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );
    }

    final reports = storage.readAll();
    expect(reports, hasLength(deadLinkReportsMaxStored));
    expect(reports.first.channelName, 'Channel 24');
  });

  test('persists across a fresh provider read (survives restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await first
        .read(deadLinkReportStorageProvider)
        .save(
          DeadLinkReport(
            channelName: 'City News',
            diagnosticCode: 'httpForbidden',
            userMessage: 'Your provider rejected this stream.',
            reportedAt: DateTime(2026, 1, 1),
          ),
        );
    first.dispose();

    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);

    expect(second.read(deadLinkReportStorageProvider).readAll(), hasLength(1));
  });
}
