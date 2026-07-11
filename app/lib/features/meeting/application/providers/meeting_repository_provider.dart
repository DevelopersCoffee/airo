import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database_native.dart';
import '../../domain/repositories/meeting_repository.dart';
import '../../infrastructure/storage/drift_meeting_repository.dart';

final meetingAppDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  final database = ref.watch(meetingAppDatabaseProvider);
  return DriftMeetingRepository(database);
});
