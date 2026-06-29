import 'package:equatable/equatable.dart';

class EventMetadata extends Equatable {
  final Map<String, dynamic> _data;

  const EventMetadata([Map<String, dynamic>? data]) : _data = data ?? const {};
  
  Map<String, dynamic> toMap() => Map.unmodifiable(_data);

  @override
  List<Object?> get props => [_data];
}
