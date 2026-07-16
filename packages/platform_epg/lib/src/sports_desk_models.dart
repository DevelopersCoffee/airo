import 'package:equatable/equatable.dart';

import 'compact_epg_event_resolver.dart';
import 'compact_epg_models.dart';

enum SportsFixtureStatus {
  scheduled('scheduled'),
  live('live'),
  finalScore('final'),
  postponed('postponed');

  const SportsFixtureStatus(this.stableId);

  final String stableId;
}

class SportsFixture extends Equatable {
  const SportsFixture({
    required this.eventId,
    required this.title,
    required this.sport,
    required this.startsAt,
    this.league,
    this.homeName,
    this.awayName,
    this.regionCode,
    this.status = SportsFixtureStatus.scheduled,
  });

  final String eventId;
  final String title;
  final String sport;
  final DateTime startsAt;
  final String? league;
  final String? homeName;
  final String? awayName;
  final String? regionCode;
  final SportsFixtureStatus status;

  @override
  List<Object?> get props => [
    eventId,
    title,
    sport,
    startsAt,
    league,
    homeName,
    awayName,
    regionCode,
    status,
  ];
}

class SportsDeskRow extends Equatable {
  SportsDeskRow({
    required this.rowId,
    required this.title,
    required Iterable<SportsFixture> fixtures,
  }) : fixtures = List.unmodifiable(fixtures);

  final String rowId;
  final String title;
  final List<SportsFixture> fixtures;

  @override
  List<Object?> get props => [rowId, title, fixtures];
}

class SportsDeskFixtureResolution extends Equatable {
  const SportsDeskFixtureResolution({
    required this.fixture,
    required this.epgResolution,
  });

  final SportsFixture fixture;
  final CompactEpgEventResolution epgResolution;

  bool get hasCarriage => epgResolution.isResolved;

  @override
  List<Object?> get props => [fixture, epgResolution];
}

class SportsDeskEventResolver {
  const SportsDeskEventResolver({
    this.eventResolver = const CompactEpgEventResolver(),
  });

  final CompactEpgEventResolver eventResolver;

  List<SportsDeskFixtureResolution> resolveRow({
    required SportsDeskRow row,
    required CompactEpgSlice slice,
  }) {
    return [
      for (final fixture in row.fixtures)
        SportsDeskFixtureResolution(
          fixture: fixture,
          epgResolution: eventResolver.resolve(
            slice: slice,
            eventId: fixture.eventId,
          ),
        ),
    ];
  }
}
