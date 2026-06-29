import 'dart:convert';
import 'package:drift/drift.dart';

class DurationConverter extends TypeConverter<Duration, int> {
  const DurationConverter();
  @override
  Duration fromSql(int fromDb) => Duration(milliseconds: fromDb);
  @override
  int toSql(Duration value) => value.inMilliseconds;
}

class UriConverter extends TypeConverter<Uri, String> {
  const UriConverter();
  @override
  Uri fromSql(String fromDb) => Uri.parse(fromDb);
  @override
  String toSql(Uri value) => value.toString();
}

class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();
  @override
  Map<String, dynamic> fromSql(String fromDb) => jsonDecode(fromDb) as Map<String, dynamic>;
  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}
