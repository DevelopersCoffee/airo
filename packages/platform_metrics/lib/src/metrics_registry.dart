import 'package:platform_identity/platform_identity.dart';

abstract class Metric {
  const Metric(this.name);
  final String name;
}

class Counter extends Metric {
  Counter(super.name);
  int _value = 0;
  void increment([int count = 1]) => _value += count;
  int get value => _value;
}

class Gauge extends Metric {
  Gauge(super.name);
  double _value = 0.0;
  void set(double value) => _value = value;
  double get value => _value;
}

class Histogram extends Metric {
  Histogram(super.name);
  final List<double> _values = [];
  void record(double value) => _values.add(value);
  List<double> get values => List.unmodifiable(_values);
}

class Timer extends Metric {
  Timer(super.name);
  final Stopwatch _stopwatch = Stopwatch();
  void start() => _stopwatch.start();
  void stop() => _stopwatch.stop();
  Duration get elapsed => _stopwatch.elapsed;
}

class Span extends Metric {
  Span(super.name, this.traceId);
  final String traceId;
  final Timer _timer = Timer('');
  
  void start() => _timer.start();
  void end() => _timer.stop();
  Duration get duration => _timer.elapsed;
}

class Trace extends Metric {
  Trace(super.name, this.traceId);
  final String traceId;
  final List<Span> _spans = [];

  Span startSpan(String spanName) {
    final span = Span(spanName, traceId);
    span.start();
    _spans.add(span);
    return span;
  }
}

abstract class MetricsRegistry {
  Counter counter(String name);
  Gauge gauge(String name);
  Histogram histogram(String name);
  Timer timer(String name);
  Trace trace(String name, String traceId);
}
