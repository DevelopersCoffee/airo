import 'package:drift/drift.dart';

mixin AuditMetadata on Table {
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
}

mixin WorkspaceIsolation on Table {
  TextColumn get workspaceId => text()();
}

mixin SoftDelete on Table {
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
