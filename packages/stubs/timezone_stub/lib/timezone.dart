library;

// ignore_for_file: avoid_unused_constructor_parameters, prefer_const_constructors, use_super_parameters

final DateTime minTime = DateTime.fromMillisecondsSinceEpoch(0);
Location local = const Location('local', [], [], []);

void setLocalLocation(Location location) {
  local = location;
}

class Location {
  const Location(this.name, this.transitionAt, this.transitionZone, this.zones);

  final String name;
  final List<DateTime> transitionAt;
  final List<int> transitionZone;
  final List<TimeZone> zones;
}

class TimeZone {
  const TimeZone(
    this.offset, {
    required this.isDst,
    required this.abbreviation,
  });

  final int offset;
  final bool isDst;
  final String abbreviation;
}

class TZDateTime extends DateTime {
  TZDateTime(
    Location location,
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) : super(year, month, day, hour, minute, second, millisecond, microsecond);

  TZDateTime.now(Location location) : super.now();

  TZDateTime.from(DateTime other, Location location)
    : super(
        other.year,
        other.month,
        other.day,
        other.hour,
        other.minute,
        other.second,
        other.millisecond,
        other.microsecond,
      );
}
