import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';

import '../../domain/services/agent_connector.dart';
import 'life_track_status_connector.dart';

final LifeTrackLocalDataSource _lifeTrackDataSource =
    LifeTrackLocalDataSource();
final LifeTrackRepositoryImpl _lifeTrackRepository = LifeTrackRepositoryImpl(
  localDataSource: _lifeTrackDataSource,
);

AgentConnector createLifeTrackStatusConnector() {
  return LifeTrackStatusConnector(
    repository: _lifeTrackRepository,
    ensureInitialized: initializeLifeTrackStatusConnector,
  );
}

Future<void> initializeLifeTrackStatusConnector() async {
  try {
    await _lifeTrackDataSource.initialize();
  } catch (error) {
    debugPrint('LifeTrack local data source unavailable: $error');
  }
}

Future<void> closeLifeTrackStatusConnector() => _lifeTrackDataSource.close();
