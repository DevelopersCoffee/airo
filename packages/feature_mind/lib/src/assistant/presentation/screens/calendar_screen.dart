import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:platform_calendar/platform_calendar.dart';

/// Visibility layer for the native calendar capability. Chat remains the
/// primary way to ask "what do I have today?"
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.calendar});

  final CalendarService? calendar;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarService _calendar;
  CalendarPermission? _permission;
  List<CalendarAccount> _calendars = const [];
  List<CalendarEvent> _events = const [];
  String? _error;
  bool _loading = true;
  int _durationMs = 0;

  @override
  void initState() {
    super.initState();
    _calendar = widget.calendar ?? createCalendarService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final permission = await _calendar.permissionStatus();
      if (!permission.isGranted) {
        if (!mounted) return;
        setState(() {
          _permission = permission;
          _calendars = const [];
          _events = const [];
          _loading = false;
        });
        return;
      }
      final stopwatch = Stopwatch()..start();
      final calendars = await _calendar.listCalendars();
      final events = await _calendar.getEventsForDay(DateTime.now());
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _permission = permission;
        _calendars = calendars;
        _events = events;
        _durationMs = stopwatch.elapsedMilliseconds;
        _loading = false;
      });
    } on CalendarException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _allowAccess() async {
    try {
      await _calendar.requestPermission();
    } on CalendarException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      return;
    }
    await _load();
  }

  String get _statusLabel {
    switch (_permission?.status) {
      case CalendarPermissionStatus.granted:
        return 'Connected';
      case CalendarPermissionStatus.notDetermined:
        return 'Needs permission';
      case CalendarPermissionStatus.denied:
      case CalendarPermissionStatus.restricted:
        return 'Permission disabled';
      case CalendarPermissionStatus.unsupported:
        return 'Unsupported';
      case null:
        return 'Checking';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text('Calendar', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('● $_statusLabel', style: theme.textTheme.titleMedium),
            if (_calendars.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _calendars.map((calendar) => calendar.title).join(', '),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (_permission?.status == CalendarPermissionStatus.notDetermined)
              FilledButton(
                key: const Key('calendar_allow_access'),
                onPressed: _allowAccess,
                child: const Text('Allow Calendar Access'),
              ),
            if (_permission?.status == CalendarPermissionStatus.denied ||
                _permission?.status == CalendarPermissionStatus.restricted)
              OutlinedButton(
                onPressed: () => _calendar.openSettings(),
                child: const Text('Open system settings'),
              ),
            if (_permission?.isGranted ?? false) ...[
              Text('Today', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${_events.length} events'),
              const SizedBox(height: 12),
              if (_events.isEmpty)
                const Text('You have no calendar events today.')
              else
                for (final event in _events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.isAllDay
                              ? 'All day'
                              : TimeOfDay.fromDateTime(
                                  event.start,
                                ).format(context),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(event.title),
                        if (event.calendar != null)
                          Text(
                            event.calendar!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _calendar.openCalendarApp(),
                child: const Text('Open Calendar'),
              ),
            ],
            if (kDebugMode && (_permission?.isGranted ?? false)) ...[
              const SizedBox(height: 24),
              ExpansionTile(
                title: const Text('Diagnostics'),
                children: [
                  ListTile(
                    title: const Text('Adapter'),
                    subtitle: Text(_calendar.adapterName),
                  ),
                  ListTile(
                    title: const Text('Events returned'),
                    subtitle: Text('${_events.length}'),
                  ),
                  ListTile(
                    title: const Text('Execution'),
                    subtitle: Text('$_durationMs ms'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
